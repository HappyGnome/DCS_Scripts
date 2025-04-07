--#######################################################################################################
-- TrainingAids
-- Run once at mission start after initializing HeLMS
-- 
-- Various aids to squad training. For example missile defeat hints.
--
-- Script by HappyGnome

if not helms then return end
if helms.version < 1.15 then 
	helms.log_e.log("Invalid HeLMS version for TrainingAids")
end

--#######################################################################################################
-- training_aids
training_aids = {}

-- MODULE OPTIONS:----------------------------------------------------------------------------------------
training_aids.poll_interval = 1 --seconds, time between updates of group availability
training_aids.missile_defeat_mach_diff = 0.2
training_aids.missile_defeat_activation_s = 2
----------------------------------------------------------------------------------------------------------

--[[
key = group name in mission
value = training_aids
--]]
training_aids.trackedShots_={} 
training_aids.features = {}
training_aids.commsPathBase= nil

--------------------------------------------------------------------------------------------------------

--[[
Loggers for this module
--]]
training_aids.log_i=helms.logger.new("training_aids","info")
training_aids.log_e=helms.logger.new("training_aids","error")

--error handler for xpcalls. wraps training_aids.log_e:error
training_aids.catchError=function(err)
	training_aids.log_e.log(err)
end 

-----------------------------------------------------------------------------------------------------------
-- Event handlers

training_aids.eventHandler = { 
	onEvent = function(self,event)
        if (event.id == world.event.S_EVENT_SHOT) then
            helms.util.safeCall(training_aids.shotHandler,{event.initiator, event.time, event.weapon},training_aids.catchError)
		end

        if (event.id == world.event.S_EVENT_HIT) then
            helms.util.safeCall(training_aids.hitHandler,{event.target, event.time, event.weapon},training_aids.catchError)
		end
	end
}
world.addEventHandler(training_aids.eventHandler)


training_aids.shotHandler = function(initiator, time, weapon)
    if not weapon then return end
    if not initiator then return end

	local tgt = weapon:getTarget()

	if not tgt then return end

	local now=timer.getTime()	

    local newShot =
    {
        wpnObj = weapon
		,tgtObj = tgt
		,shotTime = now
	}

	table.insert(training_aids.trackedShots_,newShot)
end

training_aids.hitHandler = function(target, time, weapon)
	for k,v in pairs(training_aids.trackedShots_) do
		if v.wpnObj == weapon and v.tgtObj == target then
			training_aids.trackedShots_[k] = nil
			return
		end
	end
end

--POLL----------------------------------------------------------------------------------------------------

training_aids.doPoll_=function()

	local now=timer.getTime()	
	
	for k,v in pairs(training_aids.features) do

		local task = v.onPoll
		if task then
			task(now)
		end
	end	

	--schedule next poll----------------------------------
	return now + training_aids.poll_interval
end

----------------------------------------------------------------------------------------------------

-- stateName can be a string index into the named feature, or the integer value that that index points to
training_aids.toggleFeature = function(featureName, stateName, showComms)
	local feature = training_aids.features[featureName]
	
	-- Validation

	if (not feature) or (not feature.stateConfig) then
		training_aids.log_e.log({"Feature name not found", featureName,stateName})
		return 
	end

	local stateHandle = stateName
	if type(stateName) == "string" then
		stateHandle = feature[stateName]
	end

	if (not stateHandle) then 
		training_aids.log_e.log({"Feature state handle invalid", featureName,stateName})
		return 
	end
	
	local newStateConfig = feature.stateConfig[stateHandle]
	if (not newStateConfig) then
		training_aids.log_e.log({"Feature not configured properly", featureName,stateName})
		return 
	end

	-- Update state and do callbacks
	if showComms == nil then
		showComms = feature.showComms
	else
		feature.showComms = showComms
	end
	
	local callback = feature[newStateConfig.callback]
	if feature.currentState ~= stateHandle and callback then
	
		helms.util.safeCall(callback,{},training_aids.catchError) 
	end 

	feature.currentState = stateHandle

	training_aids.log_i.log({"Feature mode changed", featureName,feature.currentState})

	-- Update comms menus

	if type(feature.commsText) ~= "string" then return end

	local msg = feature.commsText
	
	if type(newStateConfig.msgText) == "string" then
		msg = msg .. ": " .. newStateConfig.msgText
		helms.ui.messageForCoalitionOrAll(nil,msg,10,false) -- no clear screen
	end

	if feature.showComms then
		training_aids.commsPathBase = helms.ui.ensureSubmenu(nil, "Training Aids")
		feature.commsSubmenuPath = helms.ui.ensureSubmenu(training_aids.commsPathBase, feature.commsText)

		for k,v in pairs(feature.stateConfig) do

			if (v.commsIndex) then helms.ui.removeItem(feature.commsSubmenuPath, v.commsIndex) end 

			if k == feature.currentState then
				v.commsIndex = nil
			elseif v.commsLabel then
				v.commsIndex = helms.ui.addCommand(feature.commsSubmenuPath,v.commsLabel,training_aids.toggleFeature,featureName,k)
			end
		end
	end 
end

--------------------------------------------------------------------------------------------------
-- Feature definitions

-- missile defeat hints
training_aids.features["missileDefeatHints"] = (function()
	local builder = 
	{
		--state handles (also defines comms menu order)
		["ENABLED"] = 1,
		["DISABLED"] = 2,
		--

		showComms = false,
		commsSubmenuPath = nil, 
		commsText = "Missile Defeat Hints"
	}

	--callbacks
	builder.onEnable = function()
		for k,v in pairs(training_aids.trackedShots_) do
			if (not v.wpnObj) or (not v.wpnObj:isExist()) then
				training_aids.trackedShots_[k] = nil
			end
		end
	end

	builder.onPoll = function(now)
		
		if builder.currentState ~= builder.ENABLED then return end

		local pollShot = function(wpn,tgt, key)

			local keep = false

			if wpn and tgt and tgt:isExist() then
				keep = wpn:isExist() and (helms.physics.estimateMach(wpn) - helms.physics.estimateMach(tgt) > training_aids.missile_defeat_mach_diff )
			end

			if not keep then 
				if tgt:isExist() then trigger.action.outTextForUnit(tgt:getID(), "Missile defeated!",5,false) end
				training_aids.trackedShots_[key] = nil 
			end
		end
		
		--do group poll
		for k,v in pairs(training_aids.trackedShots_) do
			if now > v.shotTime + training_aids.missile_defeat_activation_s then
				helms.util.safeCall(pollShot,{v.wpnObj,v.tgtObj, k},training_aids.catchError)
			end
		end
	end


	builder.stateConfig = 
	{
		[builder.ENABLED] = {commsLabel = "Enable", msgText = "Enabled", callback = "onEnable", commsIndex = nil},
		[builder.DISABLED] = {commsLabel = "Disable", msgText = "Disabled", commsIndex = nil }
	}
	builder.currentState = builder.DISABLED

	return builder
end)()

---------

--#######################################################################################################
-- training_aids(PART 2)

helms.dynamic.scheduleFunction(training_aids.doPoll_,nil,timer.getTime()+training_aids.poll_interval)
return training_aids