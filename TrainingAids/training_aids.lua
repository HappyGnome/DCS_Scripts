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
training_aids.poll_interval = 0.3 --seconds, time between updates of group availability
training_aids.missile_defeat_mach_diff = 0.2
training_aids.missile_pitbull_range_nm = 8
training_aids.missile_defeat_ATA = 80
training_aids.missile_defeat_activation_s = 2.5
----------------------------------------------------------------------------------------------------------

--[[
key = group name in mission
value = training_aids
--]]
training_aids.trackedShots_ = {}
training_aids.features = {}
training_aids.commsPathBase = nil

--------------------------------------------------------------------------------------------------------

--[[
Loggers for this module
--]]
training_aids.log_i = helms.logger.new("training_aids", "info")
training_aids.log_e = helms.logger.new("training_aids", "error")

--error handler for xpcalls. wraps training_aids.log_e:error
training_aids.catchError = function(err)
    training_aids.log_e.log(err)
end

-----------------------------------------------------------------------------------------------------------
-- Event handlers

training_aids.eventHandler = {
    onEvent = function(self, event)
        if (event.id == world.event.S_EVENT_SHOT) then
            helms.util.safeCall(training_aids.shotHandler, { event.initiator, event.time, event.weapon },
                training_aids.catchError)
        end

        if (event.id == world.event.S_EVENT_HIT) then
            helms.util.safeCall(training_aids.hitHandler, { event.target, event.time, event.weapon },
                training_aids.catchError)
        end
    end
}
world.addEventHandler(training_aids.eventHandler)


training_aids.shotHandler = function(initiator, time, weapon)
    if not weapon then return end
    if not initiator then return end

    local tgt = weapon:getTarget()

    if not tgt then return end

    local now = timer.getTime()

    local newShot =
    {
        wpnObj = weapon
        ,
        tgtObj = tgt
        ,
        shooterObj = initiator
        ,
        shotTime = now
    }

    table.insert(training_aids.trackedShots_, newShot)
end

training_aids.hitHandler = function(target, time, weapon)
    for k, v in pairs(training_aids.trackedShots_) do
        if v.wpnObj == weapon and v.tgtObj == target then
            training_aids.trackedShots_[k] = nil
            return
        end
    end
end

--POLL----------------------------------------------------------------------------------------------------

training_aids.doPoll_ = function()
    local now = timer.getTime()

    for k, v in pairs(training_aids.features) do
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
        training_aids.log_e.log({ "Feature name not found", featureName, stateName })
        return
    end

    local stateHandle = stateName
    if type(stateName) == "string" then
        stateHandle = feature[stateName]
    end

    if (not stateHandle) then
        training_aids.log_e.log({ "Feature state handle invalid", featureName, stateName })
        return
    end

    local newStateConfig = feature.stateConfig[stateHandle]
    if (not newStateConfig) then
        training_aids.log_e.log({ "Feature not configured properly", featureName, stateName })
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
        helms.util.safeCall(callback, {}, training_aids.catchError)
    end

    feature.currentState = stateHandle

    training_aids.log_i.log({ "Feature mode changed", featureName, feature.currentState })

    -- Update comms menus

    if type(feature.commsText) ~= "string" then return end

    local msg = feature.commsText

    if type(newStateConfig.msgText) == "string" then
        msg = msg .. ": " .. newStateConfig.msgText
        helms.ui.messageForCoalitionOrAll(nil, msg, 10, false) -- no clear screen
    end

    if feature.showComms then
        training_aids.commsPathBase = helms.ui.ensureSubmenu(nil, "Training Aids")
        feature.commsSubmenuPath = helms.ui.ensureSubmenu(training_aids.commsPathBase, feature.commsText)

        -- Clear comms submenu
        for k, v in pairs(feature.stateConfig) do

            if (v.commsIndex) then helms.ui.removeItem(feature.commsSubmenuPath, v.commsIndex) end

            v.commsIndex = nil
        end

        -- Re-add comms options that now apply
        for k, v in pairs(feature.stateConfig) do

            if k ~= feature.currentState then
                v.commsIndex = helms.ui.addCommand(feature.commsSubmenuPath, v.commsLabel,
                    training_aids.toggleFeature, featureName, k)
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
        ["IN_RAIL"] = 1,
        ["IN_ACT"] = 2,
        ["OUT"] = 3,
        ["DISABLED"] = 4,
        --

        showComms = false,
        commsSubmenuPath = nil,
        commsText = "Missile Defeat Hints"
    }

    --callbacks
    builder.onEnable = function()
        for k, v in pairs(training_aids.trackedShots_) do
            if (not v.wpnObj) or (not v.wpnObj:isExist()) then
                training_aids.trackedShots_[k] = nil
            end
        end
    end

    builder.onPoll = function(now)
        if builder.currentState == builder.DISABLED then return end

        local clearScreen = true

        local pollShot = function(wpn, tgt, shooter, key)
            if (not wpn) or (not wpn:isExist()) or (not tgt) or (not tgt:isExist()) then
                training_aids.trackedShots_[key] = nil
                return
            end

            local wpnPos = wpn:getPosition()
            local r = helms.maths.lin3D(wpnPos.p, 1, tgt:getPoint(), -1)

            local dist = math.sqrt(helms.maths.dot3D(r, r))

            if dist <= 0.1 then dist = 1 end
            local distToActNm = (dist * helms.maths.m2nm) - training_aids.missile_pitbull_range_nm

            if builder.currentState == builder.IN_ACT and distToActNm > 0 then
                return
            end

            local rvel = helms.maths.lin3D(wpn:getVelocity(), 1, tgt:getVelocity(), -1)

            local closureMps = -helms.maths.dot3D(r, rvel) / dist

            local wpnMach = helms.physics.estimateMach(wpn)
            local tgtMach = helms.physics.estimateMach(tgt)

            local cosAta = -helms.maths.dot3D(r, wpnPos.x) / dist

            local ata = math.acos(cosAta) / helms.maths.deg2rad

            local defeated_mach = wpnMach - tgtMach < training_aids.missile_defeat_mach_diff
            local defeated_ata = ata > training_aids.missile_defeat_ATA

            local tHitS = -1
            local tPitS = -1
            if closureMps > 0 then
                tHitS = dist / closureMps
                tPitS = distToActNm / (helms.maths.m2nm * closureMps)
            end

            local msg = string.format("Range (nm): %.1f", dist * helms.maths.m2nm)
            msg = msg .. string.format("\nMach: %.1f", wpnMach)
            if (tPitS > 0) then
                msg = msg .. string.format("\nA: %d", tPitS)
            elseif (tHitS > 0) then
                msg = msg .. string.format("\nT: %d", tHitS)
            end

            msg = msg .. string.format("\nATA: %d", ata)
            if (defeated_ata) then
                msg = msg .. " (OUT OF SEEKER)"
            end

            msg = msg .. string.format("\nΔM: %.1f", (wpnMach - tgtMach))
            if (defeated_mach) then
                msg = msg .. " (DEFEATED)"
            end

            if builder.currentState == builder.OUT then
                if shooter and shooter:isExist() then
                    trigger.action.outTextForUnit(shooter:getID(), msg, 5, clearScreen)
                end
            else
                trigger.action.outTextForUnit(tgt:getID(), msg, 5, clearScreen)
            end

            clearScreen = false
        end

        --do group poll
        for k, v in pairs(training_aids.trackedShots_) do
            if now > v.shotTime + training_aids.missile_defeat_activation_s then
                helms.util.safeCall(pollShot, { v.wpnObj, v.tgtObj, v.shooterObj, k }, training_aids.catchError)
            end
        end
    end


    builder.stateConfig =
    {
        [builder.IN_RAIL] = { commsLabel = "All incoming", msgText = "All incoming", callback = "onEnable", commsIndex = nil },
        [builder.IN_ACT] = { commsLabel = "Active incoming", msgText = "Active incoming", callback = "onEnable", commsIndex = nil },
        [builder.OUT] = { commsLabel = "Outgoing", msgText = "Outgoing", callback = "onEnable", commsIndex = nil },
        [builder.DISABLED] = { commsLabel = "Disable", msgText = "Disabled", commsIndex = nil }
    }
    builder.currentState = builder.DISABLED

    return builder
end)()

---------

--#######################################################################################################
-- training_aids(PART 2)

helms.dynamic.scheduleFunction(training_aids.doPoll_, nil, timer.getTime() + training_aids.poll_interval)
return training_aids
