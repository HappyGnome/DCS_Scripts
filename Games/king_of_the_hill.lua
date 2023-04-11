--#######################################################################################################
-- King_of_the_hill (PART 1)
-- Run once at mission start after initializing HeLMS
--
-- Script by HappyGnome

--doFile returns single global instance, or creates one
if king_of_the_hill then
	return king_of_the_hill
end

if not helms then return end
if helms.version < 1 then 
	helms.log_e.log("Invalid HeLMS version for king_of_the_hill")
end

--NAMESPACES----------------------------------------------------------------------------------------------
king_of_the_hill={}

-- MODULE OPTIONS:----------------------------------------------------------------------------------------
king_of_the_hill.poll_interval = 1 -- seconds
king_of_the_hill.flare_interval = 10 -- seconds
king_of_the_hill.smoke_count = 5 
king_of_the_hill.smoke_elevation_interval = 1000 -- m
king_of_the_hill.crown_respawn_delay = 30
king_of_the_hill.max_loss_to_kill_time = 15
king_of_the_hill.return_to_zone_time = 30
king_of_the_hill.crown_cap_radius = 300
king_of_the_hill.score_reminder_cooldown = 60 --seconds
----------------------------------------------------------------------------------------------------------

king_of_the_hill.running = false
king_of_the_hill.games={}

----------------------------------------------------------------------------------------------------------

--[[
Loggers for this module
--]]
king_of_the_hill.log_i=helms.logger.new("king_of_the_hill","info")
king_of_the_hill.log_e=helms.logger.new("king_of_the_hill","error")

--error handler for xpcalls. wraps king_of_the_hill.log_e.log
king_of_the_hill.catchError=function(err)
	king_of_the_hill.log_e.log(err)
end 
-----------------------------------------------------------------------------------------------------------
-- Event handlers

king_of_the_hill.eventHandler = { 
	onEvent = function(self,event)
		if (event.id == world.event.S_EVENT_HIT) then
			helms.util.safeCall(king_of_the_hill.hitHandler,{event.target,event.initiator},king_of_the_hill.catchError)
		elseif (event.id == world.event.S_EVENT_KILL) then
			helms.util.safeCall(king_of_the_hill.killHandler,{event.target,event.initiator},king_of_the_hill.catchError)
		end
	end
}
world.addEventHandler(king_of_the_hill.eventHandler)

king_of_the_hill.hitHandler = function(target, initiator)
    --TODO multipliers when king scores hits
end

king_of_the_hill.killHandler = function(target, initiator)
    king_of_the_hill.log_i.log({target, initiator}) --TODO
    if not target or not initiator then return end
    local tgtName = target:getName()
    local initName = initiator:getName()

    king_of_the_hill.log_i.log({tgtName , initName}) --TODO

    if initName == tgtName then return end

    for k,v in pairs(king_of_the_hill.games) do
        if v.rules.kingUnitName == tgtName 
        or (v.rules.prevKingUnitName == tgtName
            and v.rules.kingLostAt
            and timer.getTime() - v.rules.kingLostAt < king_of_the_hill.max_loss_to_kill_time) then
            king_of_the_hill.log_i.log("kingKilled") --TODO
            king_of_the_hill.kingKilled_(v,initName)
        end
    end
end
-----------------------------------------------------------------------------------------------------------
king_of_the_hill.doPoll_ = function()
    local now = timer.getTime()

    --king_of_the_hill.log_i.log("Poll")

    king_of_the_hill.running = false

    for k,v in pairs(king_of_the_hill.games) do
        king_of_the_hill.running = king_of_the_hill.pollGame_(v, now) or king_of_the_hill.running
    end
    --king_of_the_hill.log_i.log({"running",king_of_the_hill.running})
    if king_of_the_hill.running then
        return now + king_of_the_hill.poll_interval
    else
        return nil
    end
end

king_of_the_hill.pollGame_ = function(game, now)

    if not game.running then return false end

    if game.rules.kingUnitName then
        helms.util.safeCall(king_of_the_hill.pollGameWithKing_,{game, now},king_of_the_hill.catchError)
    else
        helms.util.safeCall(king_of_the_hill.pollGameWithoutKing_,{game, now},king_of_the_hill.catchError)
    end

    if game.lastScoreReminder and now - game.lastScoreReminder > king_of_the_hill.score_reminder_cooldown then
        helms.util.safeCall(king_of_the_hill.printScore_ ,{game,10, now},king_of_the_hill.catchError)
    end

    --king_of_the_hill.log_i.log({"game running",game.running})
    return game.running
end

king_of_the_hill.pollGameWithKing_ = function(game, now)
    if not game.rules.kingUnitName then return end
    local unit = Unit.getByName(game.rules.kingUnitName)

    if unit == nil then
        king_of_the_hill.loseCrown_(game, now)
        game.rules.kingLostAt = now
        return 
    end
    -- check for king out of zone
    local point = unit:getPoint()

    if helms.maths.get2DDist(point, game.zone.centre) > game.zone.radius
     or not unit:inAir() then
        if game.rules.boundsWarningTime and now - game.rules.boundsWarningTime > king_of_the_hill.return_to_zone_time then
            king_of_the_hill.loseCrown_(game, now)
        elseif not game.rules.boundsWarningTime then
            trigger.action.outText("King " .. game.rules.kingUnitFriendlyName .. " left the zone. GET BACK!",10)
            game.rules.boundsWarningTime = now
        end
    else
        game.rules.boundsWarningTime = nil
    end

    -- check for win
    local scoreThisKing = king_of_the_hill.scoreThisKing_(game,now)

    if game.rules.kingTeam  and game.rules.scores[game.rules.kingTeam] + scoreThisKing >= game.rules.firstToScore then
        game.rules.scores[game.rules.kingTeam] = game.rules.scores[game.rules.kingTeam] + scoreThisKing
        king_of_the_hill.endGame_ (game)
    end
end

king_of_the_hill.printScore_ = function(game, t, now)
    local score = {blue = game.rules.scores.blue, red = game.rules.scores.red}

    if game.rules.kingTeam and now then
        score[game.rules.kingTeam] = score[game.rules.kingTeam] + king_of_the_hill.scoreThisKing_(game,now)
    end
    trigger.action.outText("BLUE: "..score.blue.." | RED:"  .. score.red,t)
    game.lastScoreReminder = now
end

king_of_the_hill.getUnitInCapRange_ = function(game, side)
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

    --king_of_the_hill.log_i.log({"units",#units})

    local idx = helms.dynamic.getKeyOfObjWithin2D (units,game.rules.crownPoint, king_of_the_hill.crown_cap_radius, pred)
    if idx then
        return units[idx]
    end
    return nil
end

king_of_the_hill.pollGameWithoutKing_ = function(game, now)
    -- check for new king
    local redUnit = king_of_the_hill.getUnitInCapRange_(game, coalition.side.RED)
    local blueUnit = king_of_the_hill.getUnitInCapRange_(game, coalition.side.BLUE)

    if (redUnit and blueUnit) or (not redUnit and not blueUnit) then return end

    local unit = redUnit

    if redUnit then
        game.rules.kingTeam = "red"
    else 
        unit = blueUnit
        game.rules.kingTeam = "blue"
    end

    game.rules.kingUnitName = unit:getName()
    game.rules.crownPoint = nil
    game.rules.kingUnitFriendlyName = unit:getPlayerName()
    if not game.rules.kingUnitFriendlyName then
        game.rules.kingUnitFriendlyName = game.rules.kingUnitName
    end
    game.rules.kingSince = now
    game.rules.boundsWarningTime = nil
    king_of_the_hill.smokeOnCrown_(game)

    trigger.action.outText(string.upper(game.rules.kingTeam) .. " player " .. game.rules.kingUnitFriendlyName .. " is King!",10)
end
------------------------------------------------------------------------------------------------------------
king_of_the_hill.kingKilled_ = function(game, killedByUnitName)

    if not killedByUnitName then return end
    local killedByUnit = Unit.getByName(killedByUnitName)
    if not killedByUnit then return end

    local killedByGroup = killedByUnit:getGroup()
    local groupCategory = killedByGroup:getCategory()

    --king_of_the_hill.log_i.log({"gpcat",groupCategory})--TODO
    if groupCategory ~= Group.Category.AIRPLANE and groupCategory ~= Group.Category.HELICOPTER then return end

    local killedByUnitFriendlyName = killedByUnit:getPlayerName()
    if not killedByUnitFriendlyName then killedByUnitFriendlyName = killedByUnitName end

    local newKingTeamEnum = killedByUnit:getCoalition()
    local newKingTeam = nil

    if newKingTeamEnum == coalition.side.RED then
        newKingTeam = "red"
    elseif newKingTeamEnum == coalition.side.BLUE then
        newKingTeam = "blue"
    else 
        return
    end

    local now = timer.getTime()

    trigger.action.outText("King killed by " .. killedByUnitFriendlyName,10)
    trigger.action.outText(string.upper(newKingTeam) .. " player " .. killedByUnitFriendlyName .. " is King!",10)

    -- update scores
    if game.rules.kingUnitName and game.rules.kingTeam then
        game.rules.scores[game.rules.kingTeam] = game.rules.scores[game.rules.kingTeam] + king_of_the_hill.scoreThisKing_(game,now)
        if game.rules.scores[game.rules.kingTeam] >= game.rules.firstToScore then
            king_of_the_hill.endGame_ (game)
        end
        game.rules.prevKingUnitName = game.rules.kingUnitName
    end

    -- reset king details
    game.rules.crownHidden = false
    game.rules.boundsWarningTime = nil
    game.rules.kingUnitName = killedByUnitName    
    game.rules.crownPoint = nil
    game.rules.kingTeam = newKingTeam
    game.rules.kingSince = now
    game.rules.kingLostAt = nil

    -- update smoke
    king_of_the_hill.smokeOnCrown_ (game)
end

king_of_the_hill.endGame_ = function(game)
    king_of_the_hill.printScore_(game, 30)

    if game.rules.scores.blue == game.rules.scores.red then
        trigger.action.outText("It's a TIE!",30)
    elseif game.rules.scores.blue > game.rules.scores.red then
        trigger.action.outText("BLUE wins!",30)
    else
        trigger.action.outText("RED wins!",30)
    end

    game.rules.crownHidden = true
    king_of_the_hill.smokeOnCrown_(game)
    game.running = false

    king_of_the_hill.resetComms_ (game)
end
--
king_of_the_hill.startGame_ = function(gameName, rulesetInd)

    --king_of_the_hill.log_i.log("Pre Poll - 1")
    if gameName == nil or rulesetInd == nil  then return end

    local game = king_of_the_hill.games[gameName]

    if game == nil or game.running or game.ruleOptions[rulesetInd] == nil then return end

    local now = timer.getTime()
    game.rules = {
        scores = {blue = 0, red = 0},
        kingUnitName = nil,
        prevKingUnitName = nil,
        kingTeam = nil, -- index into scores
        kingSince = nil,
        crownHidden = false,
        crownPoint = {x = 0, y = 0},
        boundsWarningTime = nil,
        firstToScore = game.ruleOptions[rulesetInd].firstToScore,
        kingLostAt = nil
    }
    game.lastScoreReminder = now

    --king_of_the_hill.log_i.log("Pre Poll0")
    for k,v in pairs(game.ruleOptions) do
        helms.ui.removeItem(game.subMenuPath,v.commsIndex)
    end
    --king_of_the_hill.log_i.log("Pre Poll")
    if not king_of_the_hill.running then
        helms.dynamic.scheduleFunctionSafe(king_of_the_hill.doPoll_,nil,now + king_of_the_hill.poll_interval,nil, king_of_the_hill.catchError)
    end
    king_of_the_hill.running = true
    game.running = true
    -------------------------------------------------------------------
    helms.dynamic.scheduleFunctionSafe(king_of_the_hill.flareOnCrownPeriodic_,{game},now + king_of_the_hill.flare_interval,nil, king_of_the_hill.catchError) -- start flares
    king_of_the_hill.loseCrown_(game, now)
end

king_of_the_hill.getFlarePos = function(game)
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

king_of_the_hill.flareOnCrown_ = function(game)
    --helms.log_i.log("smoke!")

    local pos, yDir = king_of_the_hill.getFlarePos(game)
    if pos then
        local azimuth = helms.maths.getHeading({x = 0, y = 0, z = 0}, yDir)
        trigger.action.signalFlare(pos, trigger.flareColor.White, azimuth * helms.maths.deg2rad)
        trigger.action.signalFlare(pos, trigger.flareColor.White, (azimuth + 90) * helms.maths.deg2rad)
        trigger.action.signalFlare(pos, trigger.flareColor.White, (azimuth + 180) * helms.maths.deg2rad)
        trigger.action.signalFlare(pos, trigger.flareColor.White, (azimuth + 270) * helms.maths.deg2rad)
        --trigger.action.smoke(pos, trigger.smokeColor.Green)
    end
end

king_of_the_hill.flareOnCrownPeriodic_ = function(game)

    if game == nil then return end

    if game.running then
        if not game.rules.crownHidden then king_of_the_hill.flareOnCrown_(game) end
        --helms.log_i.log("smoke next!" .. timer.getTime() + king_of_the_hill.flare_interval)
        return timer.getTime() + king_of_the_hill.flare_interval
    else 
        return nil
    end
end

king_of_the_hill.smokeOnCrown_ = function(game)

    local stopStatic = false

    if game.rules.prevKingUnitName and Unit.getByName(game.rules.prevKingUnitName) then
        trigger.action.ctfColorTag(game.rules.prevKingUnitName, 0)
    end

    if game.rules.kingUnitName ~= nil then
        stopStatic = true

        if Unit.getByName(game.rules.kingUnitName) then
            if game.rules.crownHidden then
                trigger.action.ctfColorTag(game.rules.kingUnitName, 0)
            else 
                trigger.action.ctfColorTag(game.rules.kingUnitName, 4)
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
            local pos = king_of_the_hill.getFlarePos(game)

            for i = 1,king_of_the_hill.smoke_count do
                local smokeName = game.gameName .. "_smoke_"..i
                trigger.action.effectSmokeStop(smokeName)
                trigger.action.effectSmokeBig(pos,2,0.5,smokeName)
                pos.y = pos.y + king_of_the_hill.smoke_elevation_interval
            end
        end
    end

    if stopStatic then
        for i = 1,king_of_the_hill.smoke_count do
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

king_of_the_hill.crownAppears_ = function(game)

    if game.rules.kingUnitName then  return end

    --king_of_the_hill.log_i.log("Crown appears") 
    local newPos = helms.maths.randomInCircle(game.zone.radius, game.zone.centre)
    game.rules.kingUnitName = nil
    game.rules.crownPoint = newPos
    game.rules.crownHidden = false
    game.rules.kingLostAt = nil

    king_of_the_hill.smokeOnCrown_ (game)
    trigger.action.outText("Crown re-appeared!",10)
end

king_of_the_hill.loseCrown_ = function(game, now)

    if game.rules.kingUnitName  then trigger.action.outText(game.rules.kingUnitFriendlyName .. " lost the crown!",10) end
    game.rules.crownHidden = true
    
    --king_of_the_hill.log_i.log("Crown lost")
    helms.dynamic.scheduleFunctionSafe(king_of_the_hill.crownAppears_,{game},now + king_of_the_hill.crown_respawn_delay, nil, king_of_the_hill.catchError)

    -- update scores
    if game.rules.kingUnitName and game.rules.kingTeam then
        game.rules.scores[game.rules.kingTeam] = game.rules.scores[game.rules.kingTeam] + king_of_the_hill.scoreThisKing_(game,now)
    end

    -- reset king details
    game.rules.boundsWarningTime = nil
    game.rules.prevKingUnitName = game.rules.kingUnitName
    game.rules.kingUnitName = nil
    game.rules.kingTeam = nil
    game.rules.kingSince = nil

    -- update smoke
    king_of_the_hill.smokeOnCrown_ (game)
end

king_of_the_hill.scoreThisKing_ = function(game, now)
    if not game.rules.kingSince then return 0 end
    return math.floor(now - game.rules.kingSince)
end

king_of_the_hill.resetComms_ = function(game)
    local gamesMenuPath, _ = helms.ui.ensureSubmenu(nil,"Games")
    game.subMenuPath = helms.ui.ensureSubmenu(gamesMenuPath, game.gameName)

    for k,v in pairs(game.ruleOptions) do
        v.commsIndex = helms.ui.addCommand(game.subMenuPath,v.label,helms.util.safeCallWrap(king_of_the_hill.startGame_,king_of_the_hill.catchError),game.gameName,k)
    end

    return game
end
----------------------------------------------------------------------------------------------------------
-- API

king_of_the_hill.AddGame = function(zoneName, gameName)
    local zone = trigger.misc.getZone(zoneName)

	if zone == nil then return nil end
    --Add comms options
    local timeOptions = {[1]={firstToScore = 1800, label = "First to 1800" --[[, commsIndex = ]]}}

    local newGame = {
        zone = {
            zoneName = zoneName, 
            centre = {x = zone.point.x, y = zone.point.z},
            radius = zone.radius
        },
        --subMenuPath = subMenuPath,
        ruleOptions = timeOptions,
        gameName = gameName,
        running = false,
        lastScoreReminder = nil,
        rules = {
            scores = {blue = 0, red = 0},
            kingUnitName = nil,
            kingUnitFriendlyName = nil,
            prevKingUnitName = nil,
            kingTeam = nil, -- index into scores
            kingSince = nil,
            crownHidden = false,
            crownPoint = {x = 0, y = 0},
            boundsWarningTime = nil,
            firstToScore = 0,
            kingLostAt = nil
        }
    }
    king_of_the_hill.resetComms_ (newGame)
    king_of_the_hill.games[gameName] = newGame    
end

--#######################################################################################################
-- King_of_the_hill (PART 2)
--
return king_of_the_hill