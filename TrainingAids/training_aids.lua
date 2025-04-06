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
		if v and v.enabled and task then
			task(now)
		end
	end	

	--schedule next poll----------------------------------
	return now + training_aids.poll_interval
end

----------------------------------------------------------------------------------------------------

training_aids.toggleFeature = function(featureName,enable, showComms)
	local feature = training_aids.features[featureName]
	
	if not feature then return end

	if showComms == nil then
		showComms = feature.showComms
	else
		feature.showComms = showComms
	end
	
	feature.enabled = enable
	if enable and feature.onEnable~=nil then helms.util.safeCall(feature.onEnable,{},training_aids.catchError) end
	if (not enable) and feature.onDisable~=nil then helms.util.safeCall(feature.onDisable,{},training_aids.catchError) end

	local msg = feature.commsText
	local prefix = "- "
	
	if enable then
		msg = msg .. " enabled"
	else
		msg = msg .." disabled"
		prefix = "+ "
	end

	helms.ui.messageForCoalitionOrAll(nil,msg,10,false) -- no clear screen

	if feature.showComms then
		training_aids.commsPathBase = helms.ui.ensureSubmenu(nil, "Training Aids")

		if feature.commsIndex then helms.ui.removeItem(training_aids.commsPathBase, feature.commsIndex) end

		feature.commsIndex = helms.ui.addCommand(training_aids.commsPathBase,prefix .. feature.commsText,training_aids.toggleFeature,featureName,not enable)
	end 
end

--------------------------------------------------------------------------------------------------
-- Feature definitions

-- missile defeat hints
training_aids.features["missileDefeatHints"] = 
{
	enabled = false, 
	showComms = false,
	commsIndex = nil, 
	commsText = "Missile Defeat Hints",
	--callbacks
	onEnable = function()
		for k,v in pairs(training_aids.trackedShots_) do
			if (not v.wpnObj) or (not v.wpnObj:isExist()) then
				training_aids.trackedShots_[k] = nil
			end
		end
	end,
	onDisable = nil,

	onPoll = function(now)
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
}
--#######################################################################################################
-- training_aids(PART 2)

helms.dynamic.scheduleFunction(training_aids.doPoll_,nil,timer.getTime()+training_aids.poll_interval)
return training_aids