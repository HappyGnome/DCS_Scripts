--#######################################################################################################
-- Game_ammo_mode (PART 1)
-- Run once at mission start after initializing HeLMS
--
-- Script by HappyGnome

--doFile returns single global instance, or creates one
if game_ammo_mode then
	return game_ammo_mode
end

if not helms then return end
if helms.version < 1.16 then 
	helms.log_e.log("Invalid HeLMS version for game_ammo_mode")
end

--NAMESPACES----------------------------------------------------------------------------------------------
game_ammo_mode={testCount = 5}

game_ammo_mode.version = 1.0

-- MODULE OPTIONS:----------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------


----------------------------------------------------------------------------------------------------------

--[[
Loggers for this module
--]]
game_ammo_mode.log_i=helms.logger.new("game_ammo_mode","info")
game_ammo_mode.log_e=helms.logger.new("game_ammo_mode","error")

--error handler for xpcalls. wraps game_ammo_mode.log_e.log
game_ammo_mode.catchError=function(err)
	game_ammo_mode.log_e.log(err)
end 
-----------------------------------------------------------------------------------------------------------
-- Event handlers

game_ammo_mode.shotHandler = function(unit, weapon)
    if (unit==nil or weapon == nil) then return end

    if(game_ammo_mode.testCount > 0) then
        game_ammo_mode.testCount = game_ammo_mode.testCount - 1

    else

        helms.dynamic.scheduleFunction(Object.destroy, {weapon}, timer.getTime() + 5, true)
        --weapon:destroy()

        trigger.action.outTextForUnit(unit:getID(), "Nope", 5, false)
    end

    return true -- continue polling 
end

 game_ammo_mode.eventHandler = { 
 	onEvent = function(self,event)
 		--[[if (event.id == world.event.S_EVENT_HIT) then
 			helms.util.safeCall(game_ammo_mode.hitHandler,{event.target,event.initiator},game_ammo_mode.catchError)
 		elseif (event.id == world.event.S_EVENT_KILL) then
 			helms.util.safeCall(game_ammo_mode.killHandler,{event.target,event.initiator},game_ammo_mode.catchError)
         elseif (event.id == world.event.S_EVENT_DEAD) then
            helms.util.safeCall(game_ammo_mode.deadHandler,{event.initiator, event.time},game_ammo_mode.catchError)
         --elseif (event.id == world.event.S_EVENT_PILOT_DEAD) then
             --helms.util.safeCall(game_ammo_mode.deadHandler,{event.initiator},game_ammo_mode.catchError)
         --elseif (event.id == world.event.S_EVENT_UNIT_LOST) then
             helms.util.safeCall(game_ammo_mode.deadHandler,{event.initiator, event.time},game_ammo_mode.catchError)
         --else]]if(event.id == world.event.S_EVENT_SHOT) then
             helms.util.safeCall(game_ammo_mode.shotHandler, {event.initiator,event.weapon},game_ammo_mode.catchError)
 		end
 	end
 }
 world.addEventHandler(game_ammo_mode.eventHandler)

-----------------------------------------------------------------------------------------------------------

--#######################################################################################################
-- Game_ammo_mode (PART 2)
--
return game_ammo_mode
