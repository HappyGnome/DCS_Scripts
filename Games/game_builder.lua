--#######################################################################################################
-- game_builder (PART 1)
-- Run once at mission start after initializing HeLMS
--
-- Script by HappyGnome

--doFile returns single global instance, or creates one
if game_builder then
	return game_builder
end

if not helms then return end
if helms.version < 1.15 then 
	helms.log_e.log("Invalid HeLMS version for game_builder")
end

--NAMESPACES----------------------------------------------------------------------------------------------
game_builder={}

game_builder.version = 1.0

-- MODULE OPTIONS:----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------

game_builder.games={}

----------------------------------------------------------------------------------------------------------

--[[
Loggers for this module
--]]
game_builder.log_i=helms.logger.new("game_builder","info")
game_builder.log_e=helms.logger.new("game_builder","error")

--error handler for xpcalls. wraps game_builder.log_e.log
game_builder.catchError=function(err)
	game_builder.log_e.log(err)
end 
-----------------------------------------------------------------------------------------------------------
-- Event handlers
helms.events.enableHitLogging()
helms.events.enableSpawnLogging()

game_builder.eventHandler = { 
	onEvent = function(self,event)
        if (event.id == world.event.S_EVENT_UNIT_LOST) then
            helms.util.safeCall(game_builder.deadHandler,{event.initiator, event.time},game_builder.catchError)
		end
	end
}
world.addEventHandler(game_builder.eventHandler)

game_builder.deadHandler = function(initiator, time)
    if not initiator then return end
    local initName = initiator:getName()

    local lastHitEvent = helms.events.getLastHitBy(initName) 
    if not lastHitEvent then return end

    for _,game in pairs(game_builder.games) do
        -- TODO: check target doesn't meet safety predicate and that the hit was after the last time it did 
    end
end -- TODO optionally make dying/respawning in specified zones or friendly airbases to not count as a kill

-----------------------------------------------------------------------------------------------------------
game_builder.doPoll_ = function() local now = timer.getTime()

    --game_builder.log_i.log("Poll")

    game_builder.running = false

    for k,v in pairs(game_builder.games) do
        game_builder.running = game_builder.pollGame_(v, now) or game_builder.running
    end
    --game_builder.log_i.log({"running",game_builder.running})
    if game_builder.running then
        return now + game_builder.poll_interval
    else
        return nil
    end
end

game_builder.pollGame_ = function(game, now)

    if not game.running then return false end

    if game.rules.kingUnitName then
        helms.util.safeCall(game_builder.pollGameWithKing_,{game, now},game_builder.catchError)
    else
        helms.util.safeCall(game_builder.pollGameWithoutKing_,{game, now},game_builder.catchError)
    end

    if game.lastScoreReminder and now - game.lastScoreReminder > game_builder.score_reminder_cooldown then
        helms.util.safeCall(game_builder.printScore_ ,{game,10, now},game_builder.catchError)
    end

    --game_builder.log_i.log({"game running",game.running})
    return game.running
end

game_builder.pollGameWithKing_ = function(game, now)
    if not game.rules.kingUnitName then return end
    local unit = Unit.getByName(game.rules.kingUnitName)

    if unit == nil then
        game_builder.loseCrown_(game, now)
        --game.rules.kingLostAt = now
        return 
    end
    -- check for king out of zone
    local point = unit:getPoint()

    if helms.maths.get2DDist(point, game.zone.centre) > game.zone.radius
     or not unit:inAir() then
        if game.rules.boundsWarningTime and now - game.rules.boundsWarningTime > game_builder.return_to_zone_time then
            game_builder.loseCrown_(game, now)
        elseif not game.rules.boundsWarningTime then
            trigger.action.outText("King " .. game.rules.kingUnitFriendlyName .. " left the zone. GET BACK!",10)
            game.rules.boundsWarningTime = now
        end
    else
        game.rules.boundsWarningTime = nil
    end

    game_builder.refreshCtfSmokeOnCrown_(game)

     -- update scores on multiplier cooldown
    local runningTeamScore = 0 

    if game.rules.kingTeam then
        runningTeamScore = game_builder.currentScoreSegment_(game,now) + game.rules.scores[game.rules.kingTeam]
    end

    -- check for win or check for multiplier change
    if game.rules.kingTeam and runningTeamScore >= game.rules.firstToScore then

        game.rules.scores[game.rules.kingTeam] = game.rules.firstToScore
        game_builder.endGame_ (game)

    elseif game.rules.kingMultiplierUntil and  game.rules.kingMultiplierUntil < now and runningTeamScore > 0 then

        game_builder.nextScoreSegment(game, now, true) 

        trigger.action.outText("Multiplier reset!",10)

    end

end

game_builder.nextScoreSegment = function(game, now, clearMultiplier)

    game_builder.endScoreSegment(game, now, clearMultiplier)

    game.rules.scoreSegmentStart = now
end

game_builder.endScoreSegment = function(game, now, clearMultiplier)

    if game.rules.kingTeam then
        game.rules.scores[game.rules.kingTeam] = game.rules.scores[game.rules.kingTeam] + game_builder.currentScoreSegment_(game,now)
    end    

    if clearMultiplier then
        game.rules.kingMultiplierUntil = nil
        game.rules.kingMultiplier = 1
    end 

end

game_builder.printScore_ = function(game, t, now)
    local score = {blue = game.rules.scores.blue, red = game.rules.scores.red}
    local suffix = {['red'] = '', ['blue'] = ''}

    local kingName = ""

    if game.rules.kingTeam and now then
        score[game.rules.kingTeam] = score[game.rules.kingTeam] + game_builder.currentScoreSegment_(game,now)
        suffix[game.rules.kingTeam] = '↑'
        if game.rules.kingMultiplier > 1 then
            suffix[game.rules.kingTeam]  = suffix[game.rules.kingTeam]  .. '×' .. game.rules.kingMultiplier
        end
         suffix[game.rules.kingTeam] =  suffix[game.rules.kingTeam]

        kingName = ' | ♔' .. game.rules.kingUnitFriendlyName
    end
    trigger.action.outText("BLUE: "..score.blue..suffix['blue'].." | RED: "  .. score.red  .. suffix['red'] .. kingName,t)
    game.lastScoreReminder = now
end

game_builder.getUnitInCapRange_ = function(game, side)
    local units = {}

    if not game.rules.crownPoint then return end

    local pred = function (unit)
        return unit and unit:inAir()
    end
    for k,v in pairs(coalition.getGroups(side,Group.Category.AIRPLANE)) do
        for l,w in pairs(v:getUnits()) do
            units[#units + 1] = w
        end
    end

    for k,v in pairs(coalition.getGroups(side,Group.Category.HELICOPTER)) do
        for l,w in pairs(v:getUnits()) do
            units[#units + 1] = w
        end
    end

    --game_builder.log_i.log({"units",#units})

    local idx = helms.dynamic.getKeyOfObjWithin2D (units,game.rules.crownPoint, game_builder.crown_cap_radius, pred)
    if idx then
        return units[idx]
    end
    return nil
end

game_builder.pollGameWithoutKing_ = function(game, now)
    -- check for new king
    local redUnit = game_builder.getUnitInCapRange_(game, coalition.side.RED)
    local blueUnit = game_builder.getUnitInCapRange_(game, coalition.side.BLUE)

    if (redUnit and blueUnit) or (not redUnit and not blueUnit) then return end

    local unit = redUnit

    if not redUnit then
        unit = blueUnit
    end

    local kingTeam = game_builder.unitTeamString_(unit)
    if not kingTeam then return false end

    game_builder.nextScoreSegment(game, now, true)
    game_builder.setNewKing_(game, now, unit:getName(),unit:getPlayerName(), kingTeam)

    trigger.action.outText(string.upper(game.rules.kingTeam) .. " player " .. game.rules.kingUnitFriendlyName .. " is King!",10)
end

game_builder.setNewKing_ = function (game, now, kingUnitName, kingFriendlyName, kingTeam)
    
    game.rules.kingUnitName = kingUnitName
    game.rules.crownPoint = nil
    game.rules.kingUnitFriendlyName = kingFriendlyName

    if not game.rules.kingUnitFriendlyName then
        game.rules.kingUnitFriendlyName = game.rules.kingUnitName
    end

    if kingUnitName ~= nil then
        game.rules.kingSince = now
        game.rules.crownHidden = false
    else
        game.rules.kingSince = nil
        game.rules.crownHidden = true
    end

    game.rules.boundsWarningTime = nil
    game.rules.kingTeam = kingTeam

    game_builder.smokeOnCrown_(game)
end

game_builder.unitTeamString_ = function(unit)
    if unit then
        local newTeamEnum = unit:getCoalition()

        if newTeamEnum == coalition.side.RED then
            return "red"
        elseif newTeamEnum == coalition.side.BLUE then
            return "blue"
        else
            return nil
        end
    end
end
------------------------------------------------------------------------------------------------------------
game_builder.kingKilled_ = function(game, killedByUnitName)

    if not killedByUnitName or not game.running then return false end
    local killedByUnit = Unit.getByName(killedByUnitName)
    if not killedByUnit then return false end

    local killedByGroup = killedByUnit:getGroup()
    local groupCategory = killedByGroup:getCategory()

    --game_builder.log_i.log({"gpcat",groupCategory})
    if groupCategory ~= Group.Category.AIRPLANE and groupCategory ~= Group.Category.HELICOPTER then return false end

    local killedByUnitFriendlyName = killedByUnit:getPlayerName()
    if not killedByUnitFriendlyName then killedByUnitFriendlyName = killedByUnitName end

    local newKingTeam = game_builder.unitTeamString_(killedByUnit)
    if not newKingTeam then return false end

    local now = timer.getTime()

    trigger.action.outText("King killed by " .. killedByUnitFriendlyName,10)
    trigger.action.outText(string.upper(newKingTeam) .. " player " .. killedByUnitFriendlyName .. " is King!",10)

    -- update scores
    if killedByUnitName then
        game_builder.nextScoreSegment(game, now, true)
    else
        game_builder.endScoreSegment(game, now, true)
    end

    if game.rules.kingUnitName and game.rules.kingTeam then

        if game.rules.scores[game.rules.kingTeam] >= game.rules.firstToScore then
            game_builder.endGame_ (game)
        end

        game.rules.prevKingUnitName = game.rules.kingUnitName
    end

    game_builder.setNewKing_ (game, now, killedByUnitName, killedByUnitFriendlyName, newKingTeam)
    return true -- handled
end

game_builder.kingGetKill_ = function(game, killedUnit)
    if not killedUnit or not game.running then return end
    local killedUnitName = killedUnit:getName()

    local killedGroup = killedUnit:getGroup()
    local groupCategory = killedGroup:getCategory()

    --game_builder.log_i.log({"gpcat",groupCategory})
    --if groupCategory ~= Group.Category.AIRPLANE and groupCategory ~= Group.Category.HELICOPTER then return end

    local killedUnitFriendlyName = killedUnit:getPlayerName()
    if not killedUnitFriendlyName then killedUnitFriendlyName = killedUnitName end

    local now = timer.getTime()

    game_builder.nextScoreSegment(game, now, false) --no multiplier reset

    game.rules.kingMultiplier = game.rules.kingMultiplier + game_builder.score_bonus_per_kill
    
    if game_builder.multiplier_reset_time > 0 then  
        game.rules.kingMultiplierUntil = now + game_builder.multiplier_reset_time
    end 

    trigger.action.outText("King killed  " .. killedUnitFriendlyName,10)
    trigger.action.outText("Multiplier increased to " .. game.rules.kingMultiplier,10)
end

game_builder.endGame_ = function(game)
    game_builder.printScore_(game, 30)

    if game.rules.scores.blue == game.rules.scores.red then
        trigger.action.outText("It's a TIE!",30)
    elseif game.rules.scores.blue > game.rules.scores.red then
        trigger.action.outText("BLUE wins!",30)
    else
        trigger.action.outText("RED wins!",30)
    end

    game.rules.crownHidden = true
    game_builder.smokeOnCrown_(game)
    game.running = false

    helms.effect.stopSmokeOnZone(game.zone.zoneName)

    game_builder.resetComms_ (game)
end
--
game_builder.startGame_ = function(gameName, rulesetInd)

    --game_builder.log_i.log(rulesetInd)
    if gameName == nil or rulesetInd == nil  then return end

    local game = game_builder.games[gameName]

    if game == nil or game.running or game.ruleOptions[rulesetInd] == nil then return end

    local now = timer.getTime()
    game.rules = {
        scores = {blue = 0, red = 0},
        kingUnitName = nil,
        prevKingUnitName = nil,
        kingTeam = nil, -- index into scores
        kingSince = nil,
        scoreSegmentStart = nil,
        crownHidden = false,
        crownPoint = {x = 0, y = 0},
        boundsWarningTime = nil,
        firstToScore = game.ruleOptions[rulesetInd].firstToScore,
        --kingLostAt = nil,
        kingMultiplier = 1,
        kingMultiplierUntil = nil
    }
    game.lastScoreReminder = now

    --game_builder.log_i.log("Pre Poll0")
    for k,v in pairs(game.ruleOptions) do
        helms.ui.removeItem(game.subMenuPath,v.commsIndex)
    end
    --game_builder.log_i.log("Pre Poll")
    if not game_builder.running then
        helms.dynamic.scheduleFunctionSafe(game_builder.doPoll_,nil,now + game_builder.poll_interval,nil, game_builder.catchError)
    end
    game_builder.running = true
    game.running = true
    -------------------------------------------------------------------
    helms.dynamic.scheduleFunctionSafe(game_builder.flareOnCrownPeriodic_,{game},now + game_builder.flare_interval,nil, game_builder.catchError) -- start flares
    game_builder.loseCrown_(game, now)

    trigger.action.outText("KING OF THE HILL v" .. game_builder.version,30)

    local startMessage = "Hold the crown in zone (" .. game.zone.zoneName .. ") to score points.\n"
    startMessage = startMessage .. "First team to " .. game.rules.firstToScore .. " wins!"

    helms.effect.startSmokeOnZone(game.zone.zoneName, nil, game_builder.zone_border_smoke_colour, game_builder.zone_border_smokes)

    trigger.action.outText(startMessage,30)
end

game_builder.getFlarePos = function(game)
    if game == nil then return end

    local unit = nil
    if game.rules.kingUnitName then unit = Unit.getByName(game.rules.kingUnitName) end

    local pos = nil
    local yDir = {x = 0, y = 0, z = 1.0}

    if unit then
        local posit = unit:getPosition() 
        pos = posit.p
        yDir = posit.y
    elseif game.rules.crownPoint then
        pos = helms.maths.as3D(game.rules.crownPoint)
        pos.y = land.getHeight(helms.maths.as2D(pos))
    end

    return pos, yDir
end

game_builder.flareOnCrown_ = function(game)
    --helms.log_i.log("smoke!")

    local pos, yDir = game_builder.getFlarePos(game)
    if pos then
        local azimuth = helms.maths.getHeading({x = 0, y = 0, z = 0}, yDir)
        trigger.action.signalFlare(pos, trigger.flareColor.White, azimuth * helms.maths.deg2rad)
        trigger.action.signalFlare(pos, trigger.flareColor.White, (azimuth + 90) * helms.maths.deg2rad)
        trigger.action.signalFlare(pos, trigger.flareColor.White, (azimuth + 180) * helms.maths.deg2rad)
        trigger.action.signalFlare(pos, trigger.flareColor.White, (azimuth + 270) * helms.maths.deg2rad)
        --trigger.action.smoke(pos, trigger.smokeColor.Green)
    end
end

game_builder.flareOnCrownPeriodic_ = function(game)

    if game == nil then return end

    if game.running then
        if not game.rules.crownHidden then game_builder.flareOnCrown_(game) end
        --helms.log_i.log("smoke next!" .. timer.getTime() + game_builder.flare_interval)
        return timer.getTime() + game_builder.flare_interval
    else 
        return nil
    end
end

game_builder.refreshCtfSmokeOnCrown_ = function(game)
    if game.rules.kingUnitName ~= nil then
        local unit = Unit.getByName(game.rules.kingUnitName)
        if unit then
            local point = unit:getPoint()
            if not game.rules.crownHidden and game.rules.smokeAlt and point and point.y < game.rules.smokeAlt then
                game.rules.smokeAlt = point.y
                trigger.action.ctfColorTag(game.rules.kingUnitName, 4,0)
                --helms.log_i.log({"smoke on for",game.rules.kingUnitName})
            end
        end
    end
end

game_builder.smokeOnCrown_ = function(game)

    local stopStatic = false

    if not game then return end

    if game.rules.prevKingUnitName and Unit.getByName(game.rules.prevKingUnitName) then
        trigger.action.ctfColorTag(game.rules.prevKingUnitName, 0)
        --helms.log_i.log({"smoke off for",game.rules.prevKingUnitName})
    end

    if game.rules.kingUnitName ~= nil then
        stopStatic = true

        local unit = Unit.getByName(game.rules.kingUnitName)
        if unit then
            if game.rules.crownHidden then
                trigger.action.ctfColorTag(game.rules.kingUnitName, 0)
                --helms.log_i.log({"smoke off for",game.rules.kingUnitName})
            else 
                local point = unit:getPoint()
                game.rules.smokeAlt = point.y
                trigger.action.ctfColorTag(game.rules.kingUnitName, 4,0)
                --helms.log_i.log({"smoke on for",game.rules.kingUnitName})
            end
            
            --[[
                Disable 0
                Green   1
                Red     2
                White   3
                Orange  4
                Blue    5
            ]]
        end
    else
        if game.rules.crownHidden then
            stopStatic = true
        else
            local pos = game_builder.getFlarePos(game)
            
            for i = 1,game_builder.smoke_count do
                local smokeName = game.gameName .. "_smoke_"..i
                trigger.action.effectSmokeStop(smokeName)
                trigger.action.effectSmokeBig(pos,2,0.5,smokeName)
                pos.y = pos.y + game_builder.smoke_elevation_interval
            end
        end
    end

    if stopStatic then
        for i = 1,game_builder.smoke_count do
            local smokeName = game.gameName .. "_smoke_"..i
            trigger.action.effectSmokeStop(smokeName)
                --[[
                    1 = small smoke and fire
                    2 = medium smoke and fire
                    3 = large smoke and fire
                    4 = huge smoke and fire
                    5 = small smoke
                    6 = medium smoke 
                    7 = large smoke
                    8 = huge smoke 
                ]]
        end
    end
end

game_builder.crownAppears_ = function(game)

    if game.rules.kingUnitName then  return end

    --game_builder.log_i.log("Crown appears") 
    local newPos = helms.maths.randomInCircle(game.crownSpawnZone.radius, game.crownSpawnZone.centre)
    game.rules.kingUnitName = nil
    game.rules.kingUnitFriendlyName = nil
    --game.rules.lastUnitHitKing = nil
    game.rules.kingMultiplier = 1
    game.rules.kingMultiplierUntil = nil
    game.rules.crownPoint = newPos
    game.rules.crownHidden = false
    --game.rules.kingLostAt = nil
    game.rules.prevKingUnitName = nil

    game_builder.smokeOnCrown_ (game)
    trigger.action.outText("Crown re-appeared!",10)
    trigger.action.outText("Look for the fires",10)
end

game_builder.loseCrown_ = function(game, now)

    local handled = false
    if game.rules.kingUnitName then

        local lastHitEvent = helms.events.getLastHitBy(game.rules.kingUnitName)

        local initiatorSpawnedAt = nil
        local initiatorCanSteal = true
        local kingKilledByInitiator = false 

        --game_builder.log_i.log(lastHitEvent)
        if lastHitEvent then
            local initiatorSpawn = helms.events.getLastSpawn(lastHitEvent.initiatorName)

            if initiatorSpawn then
                initiatorSpawnedAt = initiatorSpawn.time
            end

            --game_builder.log_i.log(initiatorSpawnedAt)
            kingKilledByInitiator = game.rules.kingSince 
                                    and game.rules.kingSince < lastHitEvent.time -- current king was active at the time of the hit 
        
            --game_builder.log_i.log(initiatorSpawnedAt)
            -- Check that the initiator did not just spawn (reduce risk of crown going to the initiator who respawns between firing and impact)
            initiatorCanSteal = initiatorSpawnedAt and initiatorSpawnedAt + game_builder.enable_crown_stealing_after < lastHitEvent.time
            if kingKilledByInitiator and not initiatorCanSteal then
                if lastHitEvent.initiatorName then 
                    trigger.action.outText(lastHitEvent.initiatorName .. " killed the king too soon after spawning to steal the crown.",10) 
                end
            end
        end
        if kingKilledByInitiator and initiatorCanSteal then
            handled = game_builder.kingKilled_(game,lastHitEvent.initiatorName)
        else
            if game.rules.kingUnitName  then trigger.action.outText(game.rules.kingUnitFriendlyName .. " lost the crown!",10) end
            game.rules.crownHidden = true
                --game_builder.log_i.log("Crown lost")
        end
    end

    -- Clear current king, update scores, schedule crown re-appearance
    if not handled then
        helms.dynamic.scheduleFunctionSafe(game_builder.crownAppears_,{game},now + game_builder.crown_respawn_delay, nil, game_builder.catchError)

        game_builder.endScoreSegment(game, now, true)

        -- update scores
        if game.rules.kingUnitName and game.rules.kingTeam then
            game.rules.prevKingUnitName = game.rules.kingUnitName
            
        end

        game_builder.setNewKing_ (game, now, nil, nil, nil)
    end
end

game_builder.currentScoreSegment_ = function(game, now)
    if not game.rules.scoreSegmentStart then return 0 end
    return math.floor(now - game.rules.scoreSegmentStart) * game.rules.kingMultiplier
end

game_builder.resetComms_ = function(game)

    if game.subMenuPath == nil then
        local gamesMenuPath, _ = helms.ui.ensureSubmenu(nil,"Games")
        game.subMenuPath = helms.ui.ensureSubmenu(gamesMenuPath, game.gameName)
    end 

    for k,v in pairs(game.ruleOptions) do
        if v.commsIndex then helms.ui.removeItem(game.subMenuPath,v.commsIndex) end
        v.commsIndex = helms.ui.addCommand(game.subMenuPath,v.label,helms.util.safeCallWrap(game_builder.startGame_,game_builder.catchError),game.gameName,k)
    end

    return game
end
----------------------------------------------------------------------------------------------------------
-- API

game_builder.AddGame = function(zoneName, gameName, firstToScore, zoneSpawnScale)
    local zone = trigger.misc.getZone(zoneName)

	if zone == nil then return nil end
    if firstToScore == nil then firstToScore = 1800 end
    if zoneSpawnScale == nil then zoneSpawnScale = 1.0 end 

    local timeOptions = {firstToScore = firstToScore, label = "First to "..firstToScore --[[, commsIndex = ]]}
    local newGame

    if not game_builder.games[gameName] then
        --Add comms options      

        newGame = {
            zone = {
                zoneName = zoneName, 
                centre = {x = zone.point.x, y = zone.point.z},
                radius = zone.radius,
            },
            crownSpawnZone = {
                centre = {x = zone.point.x, y = zone.point.z},
                radius = zone.radius * zoneSpawnScale,
            },
            --subMenuPath = subMenuPath,
            ruleOptions = {[1]=timeOptions},
            gameName = gameName,
            running = false,
            lastScoreReminder = nil,
            rules = {
                scores = {blue = 0, red = 0},
                kingUnitName = nil,
                kingUnitFriendlyName = nil,
                prevKingUnitName = nil,
                --lastUnitHitKing = nil,
                kingTeam = nil, -- index into scores
                kingSince = nil,
                scoreSegmentStart = nil,
                crownHidden = false,
                crownPoint = {x = 0, y = 0},
                boundsWarningTime = nil,
                firstToScore = 0,
                kingMultiplier = 1,
                kingMultiplierUntil = nil
                --kingLostAt = nil
            }
        }
        game_builder.games[gameName] = newGame  
    else
        newGame = game_builder.games[gameName]
        newGame.ruleOptions[#newGame.ruleOptions + 1] = timeOptions
    end

    if not newGame.running then
        game_builder.resetComms_ (newGame)
    end
      
end

----------------------------------------------------------------------------------------------------------
-- Test API

game_builder.Test_SetKing = function(gameName, unitName)
    local unit

    if unitName then
        unit = Unit.getByName(unitName)
    end
    if game_builder.games[gameName] and unit then

        local game = game_builder.games[gameName]
        local now = timer.getTime()

        game_builder.nextScoreSegment(game, now, true)

        game_builder.setNewKing_(game, now, unitName, unitName, game_builder.unitTeamString_(unit))
    end
end

game_builder.Test_KingGetKill = function(gameName, unitKilledName)
    local unit

    if unitKilledName then
        unit = Unit.getByName(unitKilledName)
    end
    if game_builder.games[gameName] and unit then
        helms.log_i.log("Test_KingGetKill " .. gameName .." " .. unitKilledName)
        game_builder.kingGetKill_(game_builder.games[gameName], unit)
    end
end

game_builder.Test_KingKilled = function(gameName, unitKilledName)

    if game_builder.games[gameName] and unitName then
        game_builder.kingKilled_(game_builder.games[gameName], unitName)
    end
end

game_builder.Test_LoseCrown = function(gameName)

    if game_builder.games[gameName]then
        game_builder.loseCrown_(game_builder.games[gameName], timer.getTime())
    end
end

--#######################################################################################################
-- game_builder (PART 2)
--
return game_builder