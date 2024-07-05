--#######################################################################################################
-- Quick_Suppression_Script
-- Run once at mission start after initializing HeLMS
--
-- Script by HappyGnome

--doFile returns single global instance, or creates one
if quick_suppression_script then
	return quick_suppression_script
end

if not helms then return end
if helms.version < 1.11 then 
	helms.log_e.log("Invalid HeLMS version for quick_suppression_script")
end

--NAMESPACES----------------------------------------------------------------------------------------------
quick_suppression_script={}

quick_suppression_script.version = 1.0

-- MODULE OPTIONS:----------------------------------------------------------------------------------------
quick_suppression_script.defaultMinSuppressionSeconds = 30
quick_suppression_script.defaultMaxSuppressionSeconds = 180
quick_suppression_script.resuppressionCooldownSeconds = 30
----------------------------------------------------------------------------------------------------------

quick_suppression_script.resumeTimes = {}

----------------------------------------------------------------------------------------------------------

--[[
Loggers for this module
--]]
quick_suppression_script.log_i=helms.logger.new("quick_suppression_script","info")
quick_suppression_script.log_e=helms.logger.new("quick_suppression_script","error")

--error handler for xpcalls. wraps quick_suppression_script.log_e.log
quick_suppression_script.catchError=function(err)
	quick_suppression_script.log_e.log(err)
end 
-----------------------------------------------------------------------------------------------------------
-- Event handlers

quick_suppression_script.eventHandler = { 
	onEvent = function(self,event)
		if (event.id == world.event.S_EVENT_HIT) then
			helms.util.safeCall(quick_suppression_script.hitHandler,{event.target,event.initiator},quick_suppression_script.catchError)
		end
	end
}
world.addEventHandler(quick_suppression_script.eventHandler)

quick_suppression_script.hitHandler = function(target, initiator)

    if not target or not initiator then return end
    if target:getCategory() ~= Object.Category.UNIT or initiator:getCategory() ~= Object.Category.UNIT then return end

    if target:getDesc().category ~= Unit.Category.GROUND_UNIT then return end
    if initiator:getDesc().category ~= Unit.Category.AIRPLANE and initiator:getDesc().category ~= Unit.Category.HELICOPTER then return end

    local tgtGroup = target:getGroup()

    if not tgtGroup then return end
    local gpName = tgtGroup:getName()
    
    local now = timer.getTime()

    -- Randomize re-activation
    local minSuppressionSeconds = math.max(quick_suppression_script.defaultMinSuppressionSeconds,1)
    local maxSuppressionSeconds = math.max(quick_suppression_script.defaultMaxSuppressionSeconds,minSuppressionSeconds)

    local resumeTime = now + minSuppressionSeconds + math.random(maxSuppressionSeconds - minSuppressionSeconds)
    local prevPause = quick_suppression_script.resumeTimes[gpName]

    -- update re-activation time
    if (not prevPause) 
        or (now > prevPause.pauseAt + quick_suppression_script.resuppressionCooldownSeconds
            and resumeTime > prevPause.resumeAt) then
   
        local tgtController = helms.ai._getController(gpName)

        if tgtController then tgtController:setOnOff(false) end

   
        quick_suppression_script.log_i.log(gpName .. " suppressed at " .. now .. ". Resuming at " .. resumeTime)
        quick_suppression_script.resumeTimes[gpName] = {pauseAt = now, resumeAt = resumeTime}
        helms.dynamic.scheduleFunctionSafe(quick_suppression_script.checkResume_,{gpName},resumeTime,true, quick_suppression_script.catchError)
    end 

    
end

-----------------------------------------------------------------------------------------------------------
quick_suppression_script.checkResume_ = function(gpName)
    if not quick_suppression_script.resumeTimes[gpName] then return end

    local now = timer.getTime()

    if quick_suppression_script.resumeTimes[gpName].resumeAt <= now + 1 then
        local tgtController = helms.ai._getController(gpName)

        if tgtController then tgtController:setOnOff(true) end

        quick_suppression_script.resumeTimes[gpName] = nil
        quick_suppression_script.log_i.log(gpName .." AI resumed at " .. now)
    end

end

--#######################################################################################################
--
return quick_suppression_script