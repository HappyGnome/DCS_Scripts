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
if helms.version < 1.17 then 
	helms.log_e.log("Invalid HeLMS version for game_ammo_mode")
end

---NAMESPACES----------------------------------------------------------------------------------------------
game_ammo_mode = {}

game_ammo_mode.version = 1.0

game_ammo_mode.trackedPlayers = {}
game_ammo_mode.trackedUnits = {}
---------------------------------------------------------------------------------------------------------

--[[
Loggers for this module
--]]
game_ammo_mode.log_i=helms.logger.new("game_ammo_mode","info")
game_ammo_mode.log_e=helms.logger.new("game_ammo_mode","error")

--error handler for xpcalls. wraps game_ammo_mode.log_e.log
game_ammo_mode.catchError=function(err)
	game_ammo_mode.log_e.log(err)
end 

----------------------------------------------------------------------------------------------------------
if not env.mission.forcedOptions["weapons"] then
    game_ammo_mode.log_e.log("Game ammo mode requires the unlimited ammo option!")
    return
end

-- MODULE OPTIONS:----------------------------------------------------------------------------------------
--
game_ammo_mode.default_spawn_ammo = 1

--game_ammo_mode.ammo_classes = 
--{
--    -- TODO: complete list
--    ["Fox-1"] = {["weapons.missiles.AIM_7"] = {}, ["weapons.missiles.AIM-7F"] = {}},
--    ["Fox-2"] = {["AIM_9"] = {}, ["AIM_9X"] = {}, },
--    ["Fox-3"] = {["weapons.missiles.AIM_120C"] = {}, ["weapons.missiles.AIM_120"] = {}}
--}

--[[
-- guidance = 2 = Fox-2 ?
-- guidance = 3 = Fox-3 ?
-- guidance = 4 = Fox-1 ?
--
-- missile.Category = 1 => A/A?
-- missile.Category = 6 => A/G?
--]]

--[[
{1:{count:578, desc:{life:2, warhead:{explosiveMass:0.1, type:1, caliber:20, mass:0.1, }, _origin:"", category:0, box:{min:{y:-0.12504199147224, x:-6.61008644104, z:-0.12113920599222, }, max:{y:0.12504191696644, x:2.2344591617584, z:0.12113922089338, }, }, typeName:"weapons.shells.M61_20_HE", displayName:"20mm HE", }, }, 2:{count:1, desc:{box:{min:{y:-0.22206851840019, x:-1.4489378929138, z:-0.22206874191761, }, max:{y:0.22206851840019, x:1.4489378929138, z:0.22206874191761, }, }, rangeMaxAltMin:7000, fuseDist:7, category:1, guidance:2, Nmax:40, rangeMin:300, altMax:18000, RCS:0.029999999329448, displayName:"AIM-9M", altMin:-1, life:2, missileCategory:1, warhead:{explosiveMass:9.4399995803833, type:1, caliber:127, mass:9.4399995803833, }, rangeMaxAltMax:14000, typeName:"AIM_9", _origin:"", }, }, 3:{count:1, desc:{box:{min:{y:-0.16119800508022, x:-1.5114271640778, z:-0.16260071098804, }, max:{y:0.16142548620701, x:1.5114271640778, z:0.16295923292637, }, }, rangeMaxAltMin:11000, fuseDist:7, category:1, guidance:2, Nmax:55, rangeMin:200, altMax:18000, RCS:0.029999999329448, displayName:"AIM-9X", altMin:-1, life:2, missileCategory:1, warhead:{explosiveMass:9.4399995803833, type:1, caliber:127, mass:9.4399995803833, }, rangeMaxAltMax:14000, typeName:"AIM_9X", _origin:"", }, }, 4:{count:2, desc:{box:{min:{y:-0.23215164244175, x:-1.8384801149368, z:-0.23418514430523, }, max:{y:0.23215164244175, x:1.8384801149368, z:0.23418514430523, }, }, rangeMaxAltMin:16000, fuseDist:15, category:1, guidance:3, Nmax:30, rangeMin:700, altMax:26000, RCS:0.070000000298023, displayName:"AIM-120C", altMin:1, life:2, missileCategory:1, warhead:{explosiveMass:18.700000762939, type:1, caliber:169, mass:18.700000762939, }, rangeMaxAltMax:61000, typeName:"weapons.missiles.AIM_120C", _origin:"", }, }, 5:{count:2, desc:{box:{min:{y:-0.23215164244175, x:-1.8384801149368, z:-0.23418514430523, }, max:{y:0.23215164244175, x:1.8384801149368, z:0.23418514430523, }, }, rangeMaxAltMin:14000, fuseDist:15, category:1, guidance:3, Nmax:30, rangeMin:700, altMax:20000, RCS:0.070000000298023, displayName:"AIM-120B", altMin:1, life:2, missileCategory:1, warhead:{explosiveMass:18.700000762939, type:1, caliber:169, mass:18.700000762939, }, rangeMaxAltMax:57000, typeName:"weapons.missiles.AIM_120", _origin:"", }, }, 6:{count:2, desc:{missileCategory:1, rangeMaxAltMax:50000, rangeMin:1500, _origin:"", rangeMaxAltMin:20000, altMax:24400, RCS:0.079999998211861, displayName:"AIM-7M", altMin:1, life:2, fuseDist:12, category:1, guidance:4, warhead:{explosiveMass:39, type:1, caliber:203, mass:39, }, typeName:"weapons.missiles.AIM_7", Nmax:25, }, }, 7:{count:1, desc:{box:{min:{y:-0.45607706904411, x:-2.1185023784637, z:-0.45607694983482, }, max:{y:0.45607706904411, x:2.1185023784637, z:0.45607697963715, }, }, rangeMaxAltMin:151000, fuseDist:7, category:1, guidance:5, Nmax:12, rangeMin:3500, altMax:24400, RCS:0.079999998211861, displayName:"AGM-88C", altMin:-1, life:2, missileCategory:6, warhead:{explosiveMass:18.420000076294, type:1, caliber:254, mass:62.479999542236, }, rangeMaxAltMax:134000, typeName:"weapons.missiles.AGM_88", _origin:"", }, }, 8:{count:1, desc:{missileCategory:1, rangeMaxAltMax:50000, rangeMin:1500, _origin:"", rangeMaxAltMin:20000, altMax:24400, RCS:0.079999998211861, displayName:"AIM-7F", altMin:1, life:2, fuseDist:12, category:1, guidance:4, warhead:{explosiveMass:39, type:1, caliber:203, mass:39, }, typeName:"weapons.missiles.AIM-7F", Nmax:25, }, }, }
--]]

----------------------------------------------------------------------------------------------------------

--[[
-- List currently ammo count
--]]
game_ammo_mode.sayAmmoCount = function(trackedPlayer)

    local unitName = trackedPlayer.unitName
    local unit = Unit.getByName(unitName)
    local trackedUnit = game_ammo_mode.trackedUnits[unitName]

    if (not unit) or (not trackedUnit) or (not trackedUnit.ammoAll) then return end

    local msg = "Ammo : " .. trackedUnit.ammoAll

    if trackedUnit.ammoAll <= 0 then
        msg = "Ammo : EMPTY"
    end

    trigger.action.outTextForUnit(unit:getID(),msg,5,false)
end

-- TODO: in comms menu, show ammo of all in the group...
----[[
---- Set comms menus for the current jammer state
----]]
--game_ammo_mode.resetCommsMenus = function(trackedPlayer)
--
--    if trackedPlayer.commsParent then
--        helms.ui.removeChildItems(trackedPlayer.commsParent)
--    elseif trackedPlayer.groupName then
--        trackedPlayer.commsParent = helms.ui.ensureSubmenuForGroup(trackedPlayer.groupName, game_ammo_mode.menu_jammer_label)
--    end
--
--    if not trackedPlayer.commsParent then
--        game_ammo_mode.log_e.log("No comms parent for group")
--        return
--    end
--
--    if trackedPlayer.jammerActive then
--        helms.ui.addCommand(trackedPlayer.commsParent,"Audio",game_ammo_mode.repeatAudio, trackedPlayer)
--        helms.ui.addCommand(trackedPlayer.commsParent,"Off",game_ammo_mode.handleCommOff, trackedPlayer)
--    else
--
--        helms.ui.addCommand(trackedPlayer.commsParent,"Audio",game_ammo_mode.repeatAudio, trackedPlayer)
--        for _,v in pairs(trackedPlayer.jammerProfiles) do
--    
--            helms.ui.addCommand(trackedPlayer.commsParent,"On: "..v,game_ammo_mode.handleCommOn, trackedPlayer, v)
--        end
--    end
--
--end

-- TODO : Handle unit gain ammo
-- TODO : periodically print ammo count for all players

-----------------------------------------------------------------------------------------------------------
--EVENTS----------------------------------------------------------------------------------------------------
--
--[[
-- For units in the mission to start with, simulate spawn events
--]]
game_ammo_mode.simulateInitialSpawns = function()

    -- Simulate spawn event for all existing units
    for _,coa in pairs(coalition.side) do
        for _,gp in pairs(coalition.getGroups(coa)) do
            for _, unit in pairs(gp:getUnits()) do
                game_ammo_mode.handleUnitSpawn(unit)
            end
        end
    end
end

--[[
-- Called when a unit spawns : reset ammo counter for the unit. Create comms menus if it's a player
--]]
game_ammo_mode.handleUnitSpawn = function(unit)
    if not unit then return end

    local unitName = unit:getName()


    game_ammo_mode.trackedUnits[unitName] = {ammoAll = game_ammo_mode.default_spawn_ammo}

    local playerName = unit:getPlayerName()

    if playerName then

        local trackedPlayer = {unitName = unitName, playerName = playerName}

        game_ammo_mode.trackedPlayers[unitName] = trackedPlayer
        --game_ammo_mode.resetCommsMenus(trackedPlayer)
    end
end
--
--[[
-- Called when a unit dies : Delete ammo count
--]]
game_ammo_mode.handleUnitDead = function(unit)
    if not unit then return end

    local unitName = unit:getName()

    game_ammo_mode.trackedUnits[unitName] = nil
end

--[[
-- Handle a shot. Check against the shooter's ammo count, and despawn the store if they were out of ammo. Send messages to the player.
--]]
game_ammo_mode.shotHandler = function(unit, weapon)
    --TODO
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

--[[
-- Main event handler object
--]]
 game_ammo_mode.eventHandler = { 
 	onEvent = function(self,event)

        if (event.id == world.event.S_EVENT_BIRTH) then
            helms.util.safeCall(game_ammo_mode.handleUnitSpawn, { event.initiator }, game_ammo_mode.catchError)
        elseif (event.id == world.event.S_EVENT_DEAD) then
            helms.util.safeCall(game_ammo_mode.handleUnitDead, { event.initiator }, game_ammo_mode.catchError)
         elseif(event.id == world.event.S_EVENT_SHOT) then
             helms.util.safeCall(game_ammo_mode.shotHandler, {event.initiator,event.weapon},game_ammo_mode.catchError)
 		end
 	end
 }
 world.addEventHandler(game_ammo_mode.eventHandler)

-----------------------------------------------------------------------------------------------------------

--#######################################################################################################
-- Game_ammo_mode (PART 2)
--
--

game_ammo_mode.simulateInitialSpawns()

return game_ammo_mode
