--#######################################################################################################
-- Chain_Drive (PART 1)
-- Run once at mission start after initializing HeLMS
--
-- Script by HappyGnome

--doFile returns single global instance, or creates one
if chain_drive then
	return chain_drive
end

if not helms then return end
if helms.version < 1.9 then 
	helms.log_e.log("Invalid HeLMS version for chain_drive")
end

--NAMESPACES----------------------------------------------------------------------------------------------
chain_drive={}

-- MODULE OPTIONS:----------------------------------------------------------------------------------------
chain_drive.poll_interval = 1 -- seconds
chain_drive.flare_interval = 10 -- seconds
chain_drive.smoke_count = 5 
chain_drive.smoke_elevation_interval = 1000 -- m
chain_drive.crown_respawn_delay = 30
chain_drive.max_loss_to_kill_time = 15
chain_drive.return_to_zone_time = 30
chain_drive.crown_cap_radius = 500 --m
chain_drive.score_reminder_cooldown = 60 --seconds
----------------------------------------------------------------------------------------------------------

chain_drive.running = false
chain_drive.games={}

----------------------------------------------------------------------------------------------------------

--[[
Loggers for this module
--]]
chain_drive.log_i=helms.logger.new("chain_drive","info")
chain_drive.log_e=helms.logger.new("chain_drive","error")

--error handler for xpcalls. wraps chain_drive.log_e.log
chain_drive.catchError=function(err)
	chain_drive.log_e.log(err)
end 
-----------------------------------------------------------------------------------------------------------
-- Event handlers
helms.events.enableHitLogging()

chain_drive.eventHandler = { 
	onEvent = function(self,event)
		--[[if (event.id == world.event.S_EVENT_HIT) then
			helms.util.safeCall(chain_drive.hitHandler,{event.target,event.initiator},chain_drive.catchError)
		elseif (event.id == world.event.S_EVENT_KILL) then
			helms.util.safeCall(chain_drive.killHandler,{event.target,event.initiator},chain_drive.catchError)
        elseif (event.id == world.event.S_EVENT_DEAD) then
           helms.util.safeCall(chain_drive.deadHandler,{event.initiator, event.time},chain_drive.catchError)
        --elseif (event.id == world.event.S_EVENT_PILOT_DEAD) then
            --helms.util.safeCall(chain_drive.deadHandler,{event.initiator},chain_drive.catchError)
        --else]]if (event.id == world.event.S_EVENT_UNIT_LOST) then
            helms.util.safeCall(chain_drive.deadHandler,{event.initiator, event.time},chain_drive.catchError)
		end
	end
}
world.addEventHandler(chain_drive.eventHandler)

--[[chain_drive.hitHandler = function(target, initiator)

    if not target or not initiator then return end
    local tgtName = target:getName()
    local initName = initiator:getName()

    if target:getCoalition() == initiator:getCoalition() then return end

    for k,v in pairs(chain_drive.games) do
        if v.rules.kingUnitName == tgtName then
            --chain_drive.log_i.log("kingKilled") 
            v.rules.lastUnitHitKing = initName
        end
    end
end--]]

chain_drive.deadHandler = function(initiator, time)
    if not initiator then return end
    local initName = initiator:getName()

    local lastHitEvent = helms.events.getLastHitBy(initName) 
    if not lastHitEvent then return end
    --chain_drive.log_i.log({initiator,lastHitEvent})
    for k,v in pairs(chain_drive.games) do

        if v.rules.kingSince and v.rules.kingSince < lastHitEvent.time then
            if v.rules.kingUnitName == lastHitEvent.initiatorName then
                chain_drive.kingGetKill_ (v, initiator)
            --[[elseif v.rules.kingUnitName == initName then
                chain_drive.kingKilled_(v,lastHitEvent.initiatorName)]]
            end
        end
    end
end

--[[chain_drive.killHandler = function(target, initiator)
    --chain_drive.log_i.log({target, initiator}) 
    if not target or not initiator then return end
    local tgtName = target:getName()
    local initName = initiator:getName()

    --chain_drive.log_i.log({tgtName , initName})

    if initName == tgtName then return end
    if target:getCoalition() == initiator:getCoalition() then return end

    for k,v in pairs(chain_drive.games) do
        if v.rules.kingUnitName == tgtName 
        or (v.rules.prevKingUnitName == tgtName
            and v.rules.kingLostAt
            and timer.getTime() - v.rules.kingLostAt < chain_drive.max_loss_to_kill_time) then
            --chain_drive.log_i.log("kingKilled") 
            chain_drive.kingKilled_(v,initName)
        elseif v.rules.kingUnitName == initName then
            chain_drive.kingGetKill_ (v, target)
        end
    end
end]]
-----------------------------------------------------------------------------------------------------------
chain_drive.doPoll_ = function()
    local now = timer.getTime()

    --chain_drive.log_i.log("Poll")

    chain_drive.running = false

    for k,v in pairs(chain_drive.games) do
        chain_drive.running = chain_drive.pollGame_(v, now) or chain_drive.running
    end
    --chain_drive.log_i.log({"running",chain_drive.running})
    if chain_drive.running then
        return now + chain_drive.poll_interval
    else
        return nil
    end
end

chain_drive.pollGame_ = function(game, now)

    if not game.running then return false end

    if game.rules.kingUnitName then
        helms.util.safeCall(chain_drive.pollGameWithKing_,{game, now},chain_drive.catchError)
    else
        helms.util.safeCall(chain_drive.pollGameWithoutKing_,{game, now},chain_drive.catchError)
    end

    if game.lastScoreReminder and now - game.lastScoreReminder > chain_drive.score_reminder_cooldown then
        helms.util.safeCall(chain_drive.printScore_ ,{game,10, now},chain_drive.catchError)
    end

    --chain_drive.log_i.log({"game running",game.running})
    return game.running
end

chain_drive.pollGameWithKing_ = function(game, now)
    if not game.rules.kingUnitName then return end
    local unit = Unit.getByName(game.rules.kingUnitName)

    if unit == nil then
        chain_drive.loseCrown_(game, now)
        --game.rules.kingLostAt = now
        return 
    end
    -- check for king out of zone
    local point = unit:getPoint()

    if helms.maths.get2DDist(point, game.zone.centre) > game.zone.radius
     or not unit:inAir() then
        if game.rules.boundsWarningTime and now - game.rules.boundsWarningTime > chain_drive.return_to_zone_time then
            chain_drive.loseCrown_(game, now)
        elseif not game.rules.boundsWarningTime then
            trigger.action.outText("King " .. game.rules.kingUnitFriendlyName .. " left the zone. GET BACK!",10)
            game.rules.boundsWarningTime = now
        end
    else
        game.rules.boundsWarningTime = nil
    end

    chain_drive.refreshCtfSmokeOnCrown_(game)

    -- check for win
    local scoreThisKing = chain_drive.scoreThisKing_(game,now)

    if game.rules.kingTeam  and game.rules.scores[game.rules.kingTeam] + scoreThisKing >= game.rules.firstToScore then
        game.rules.scores[game.rules.kingTeam] = game.rules.scores[game.rules.kingTeam] + scoreThisKing
        chain_drive.endGame_ (game)
    end
end

chain_drive.printScore_ = function(game, t, now)
    local score = {blue = game.rules.scores.blue, red = game.rules.scores.red}
    local suffix = {['red'] = '', ['blue'] = ''}

    if game.rules.kingTeam and now then
        score[game.rules.kingTeam] = score[game.rules.kingTeam] + chain_drive.scoreThisKing_(game,now)
        suffix[game.rules.kingTeam] = '↑'
        if game.rules.kingMultiplier > 1 then
            suffix[game.rules.kingTeam]  = suffix[game.rules.kingTeam]  .. '×' .. game.rules.kingMultiplier
        end
    end
    trigger.action.outText("BLUE: "..score.blue..suffix['blue'].." | RED: "  .. score.red  .. suffix['red'],t)
    game.lastScoreReminder = now
end

chain_drive.getUnitInCapRange_ = function(game, side)
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

    --chain_drive.log_i.log({"units",#units})

    local idx = helms.dynamic.getKeyOfObjWithin2D (units,game.rules.crownPoint, chain_drive.crown_cap_radius, pred)
    if idx then
        return units[idx]
    end
    return nil
end

chain_drive.pollGameWithoutKing_ = function(game, now)
    -- check for new king
    local redUnit = chain_drive.getUnitInCapRange_(game, coalition.side.RED)
    local blueUnit = chain_drive.getUnitInCapRange_(game, coalition.side.BLUE)

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
    chain_drive.smokeOnCrown_(game)

    trigger.action.outText(string.upper(game.rules.kingTeam) .. " player " .. game.rules.kingUnitFriendlyName .. " is King!",10)
end
------------------------------------------------------------------------------------------------------------
chain_drive.instance_meta_ =
{
    endGame_ = function(self)
        chain_drive.printScore_(game, 30)

        if game.rules.scores.blue == game.rules.scores.red then
            trigger.action.outText("It's a TIE!",30)
        elseif game.rules.scores.blue > game.rules.scores.red then
            trigger.action.outText("BLUE wins!",30)
        else
            trigger.action.outText("RED wins!",30)
        end

        game.rules.crownHidden = true
        chain_drive.smokeOnCrown_(game)
        game.running = false

        chain_drive.resetComms_ (game)
    end,
    --
    startGame_ = function(self)

        --chain_drive.log_i.log("Pre Poll - 1")
        if gameName == nil then return end

        local game = chain_drive.games[gameName]

        if game == nil or game.running then return end

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
            --kingLostAt = nil,
            kingMultiplier = 1
        }
        game.lastScoreReminder = now

        --chain_drive.log_i.log("Pre Poll0")
        for k,v in pairs(game.ruleOptions) do
            helms.ui.removeItem(game.subMenuPath,v.commsIndex)
        end
        --chain_drive.log_i.log("Pre Poll")
        if not chain_drive.running then
            helms.dynamic.scheduleFunctionSafe(chain_drive.doPoll_,nil,now + chain_drive.poll_interval,nil, chain_drive.catchError)
        end
        chain_drive.running = true
        game.running = true
        -------------------------------------------------------------------
        helms.dynamic.scheduleFunctionSafe(chain_drive.flareOnCrownPeriodic_,{game},now + chain_drive.flare_interval,nil, chain_drive.catchError) -- start flares
        chain_drive.loseCrown_(game, now)
    end,

    resetComms_ = function(self)
        local gamesMenuPath, _ = helms.ui.ensureSubmenu(nil,"Games")
        game.subMenuPath = helms.ui.ensureSubmenu(gamesMenuPath, game.gameName)

        for k,v in pairs(game.ruleOptions) do
            v.commsIndex = helms.ui.addCommand(game.subMenuPath,v.label,helms.util.safeCallWrap(chain_drive.startGame_,chain_drive.catchError),game.gameName,k)
        end

        return game
    end,

    -------------------------------------------------------------------
    -- Public methods

    AddStage = function(self, parMinutes, substring)
        local gamesMenuPath, _ = helms.ui.ensureSubmenu(nil,"Games")
        game.subMenuPath = helms.ui.ensureSubmenu(gamesMenuPath, game.gameName)

        for k,v in pairs(game.ruleOptions) do
            v.commsIndex = helms.ui.addCommand(game.subMenuPath,v.label,helms.util.safeCallWrap(chain_drive.startGame_,chain_drive.catchError),game.gameName,k)
        end

        return game
    end
}
----------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------
-- API

chain_drive.AddGame = function(gameName)

    local newGame = {
        gameName = gameName,
        running = false,
        lastScoreReminder = nil,
        substrings = substrings
    }
    chain_drive.resetComms_ (newGame)
    chain_drive.games[gameName] = newGame   
    return newGame 
end

chain_drive.GetGame = function(gameName)
    return chain_drive.games[gameName] 
end
--#######################################################################################################
-- chain_drive (PART 2)
--
return chain_drive