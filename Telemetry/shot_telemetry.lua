--#######################################################################################################
-- shot_telemetry (PART 1)
-- Run once at mission start after initializing HeLMS
--
-- Script by HappyGnome

--doFile returns single global instance, or creates one
if shot_telemetry then
	return shot_telemetry
end

if not helms then return end
if helms.version < 1.11 then 
	helms.log_e.log("Invalid HeLMS version for shot_telemetry")
end

--NAMESPACES----------------------------------------------------------------------------------------------
shot_telemetry={}

shot_telemetry.version = 1.0

-- MODULE OPTIONS:----------------------------------------------------------------------------------------
shot_telemetry.poll_interval = 1 -- seconds
shot_telemetry.min_lethal_mach = 1.0
----------------------------------------------------------------------------------------------------------

shot_telemetry.active_missiles={} -- {wpnObj, lastMach, launchTime, launchPoint, launchVel, [type data], nonLethalMachTime, nonLethalMachPoint, nonLethalMachDist, flightDistAccum, tgtObj, nonLethalEnergyTime, nonLethalEnergyTime, nonLethalEnergyTime, lastPoint, lastEnergy}

shot_telemetry.history_missiles={} -- {wpnObj, lastMach, launchTime, launchPoint, launchVel, [type data], nonLethalMachTime, nonLethalMachPoint, nonLethalMachDist, flightDistAccum, tgtObj, nonLethalEnergyTime, nonLethalEnergyTime, nonLethalEnergyTime, lastPoint, lastEnergy}


--[[
Loggers for this module
--]]
shot_telemetry.log_i=helms.logger.new("shot_telemetry","info")
shot_telemetry.log_e=helms.logger.new("shot_telemetry","error")

--error handler for xpcalls. wraps shot_telemetry.log_e.log
shot_telemetry.catchError=function(err)
	shot_telemetry.log_e.log(err)
end 
-----------------------------------------------------------------------------------------------------------
-- Event handlers

shot_telemetry.eventHandler = { 
	onEvent = function(self,event)
        if (event.id == world.event.S_EVENT_SHOT) then
            helms.util.safeCall(shot_telemetry.shotHandler,{event.initiator, event.time, event.weapon},shot_telemetry.catchError)
		end

        if (event.id == world.event.S_EVENT_MISSION_END) then
            helms.util.safeCall(shot_telemetry.missionEndHandler,{},shot_telemetry.catchError)
		end
	end
}
world.addEventHandler(shot_telemetry.eventHandler)


shot_telemetry.shotHandler = function(initiator, time, weapon)
    if not weapon then return end
    if not initiator then return end

    -- {wpnObj, launchMach, launchTime, launchPoint, launchVel, [type data], nonLethalMachTime, nonLethalMachPoint, nonLethalMachDist, flightDistAccum, tgtObj, nonLethalEnergyTime, nonLethalEnergyTime, nonLethalEnergyTime, lastPoint, lastEnergy}

    local p = weapon:getPoint()

    local newShot =
    {
        wpnObj = weapon
        ,launchEnergy = helms.physics.getSpecificEnergyWindRel(initiator)
        ,launchMach = helms.physics.estimateMach(initiator)
        ,launchTAS = helms.physics.TasKts(initiator)
        ,launchTime = time
        ,launchPoint = p
        ,maxShotAltm = p.y
        ,maxEnergy = 0
        ,launchVel = initiator:getVelocity()
        ,typeName = weapon:getTypeName()
        ,nonLethalMachTime = nil
        ,nonLethalMachPoint = nil
        ,nonLethalMachDist2Dmm = nil
        ,nonLethalMachDist3Dmm = nil
        ,flightDistAccum3Dm = 0
        ,flightDistAccum2Dm = 0
        ,tgtObj =  weapon:getTarget()
        ,tgtlaunchMach = nil
        ,tgtlaunchPoint = nil
        ,tgtLaunchVel = nil
        ,minSlantRangeToTgtm = nil
        ,minSlantRangeToTgtMach = nil
        ,minSlantRangeToTgtTime = nil
        ,nonLethalEnergyPoint = nil
        ,nonLethalEnergyTime = nil
        ,nonLethalEnergyDist3Dm = nil
        ,nonLethalEnergyDist2Dm = nil
        ,lastPoint = p
        ,lastEnergy = 0
        ,lastMach = 0
    }

    newShot.lastMach = newShot.launchMach
    newShot.lastEnergy = newShot.launchEnergy
    newShot.maxEnergy = newShot.launchEnergy

    if newShot.tgtObj and newShot.tgtObj:isExist() then 
        newShot.tgtlaunchMach = helms.physics.estimateMach(newShot.tgtObj)
        newShot.tgtlaunchPoint = newShot.tgtObj:getPoint()
        newShot.tgtLaunchVel = newShot.tgtObj:getVelocity()
        newShot.minSlantRangeToTgtm = helms.maths.get3DDist(p,newShot.tgtObj:getPoint())
        newShot.minSlantRangeToTgtMach = newShot.launchMach
        newShot.minSlantRangeToTgtTime = time
    end

    shot_telemetry.active_missiles[#shot_telemetry.active_missiles + 1] = newShot

end


shot_telemetry.missionEndHandler = function()

    shot_telemetry.log_i.log(shot_telemetry.colHeadings())

    for k,v in pairs( shot_telemetry.active_missiles) do
        shot_telemetry.log_i.log(shot_telemetry.teleRowToString(v))
    end

    for k,v in pairs(shot_telemetry.history_missiles) do
        shot_telemetry.log_i.log(shot_telemetry.teleRowToString(v))
    end
end

-----------------------------------------------------------------------------------------------------------
shot_telemetry.doPoll_ = function()
    local now = timer.getTime()

    for k,v in pairs(shot_telemetry.active_missiles) do
        if not shot_telemetry.pollShot_(v, now) then
            shot_telemetry.history_missiles[#shot_telemetry.history_missiles + 1] = v
            shot_telemetry.active_missiles[k] = nil
        end
    end

	--schedule next poll----------------------------------
	return now + shot_telemetry.poll_interval
end

shot_telemetry.pollShot_ = function(shot, now)

    if not shot then return false end

    local weapon = shot.wpnObj
    if not weapon then return false end

    if not weapon:isExist() then return false end

    local continueTrack = true
    local p = weapon:getPoint()

    if (not p) then continueTrack = false end

    shot.flightDistAccum2Dm =  shot.flightDistAccum2Dm + helms.maths.get2DDist(shot.lastPoint, p)
    shot.flightDistAccum3Dm =  shot.flightDistAccum3Dm + helms.maths.get3DDist(shot.lastPoint, p)

    local newE = helms.physics.getSpecificEnergyWindRel(weapon)

    if p.y > shot.maxShotAltm then
        shot.maxShotAltm = p.y
    end

    if newE > shot.maxEnergy then
        shot.maxEnergy = newE
    end

    if continueTrack then
        local newMach = helms.physics.estimateMach(weapon)
        local lethal = false

        if newMach < shot_telemetry.min_lethal_mach and shot.nonLethalMachTime == nil and newE < shot.lastEnergy then
            shot.nonLethalMachTime = now
            shot.nonLethalMachPoint = p
            shot.nonLethalMachDist2Dm = shot.flightDistAccum2Dm
            shot.nonLethalMachDist3Dm = shot.flightDistAccum3Dm
        else 
            lethal = true
        end

        if shot.tgtObj and shot.tgtObj:isExist() then

            local dist2Tgt = helms.maths.get3DDist(shot.tgtObj:getPoint() ,p)

            if shot.minSlantRangeToTgtm > dist2Tgt then
                shot.minSlantRangeToTgtm = dist2Tgt
                shot.minSlantRangeToTgtMach = newMach
                shot.minSlantRangeToTgtTime = now
            end

            if helms.physics.getSpecificEnergyWindRel(shot.tgtObj) > newE and newE <= shot.lastEnergy then
                shot.nonLethalEnergyPoint = p
                shot.nonLethalEnergyTime = now
                shot.nonLethalEnergyDist3Dm = shot.flightDistAccum3Dm
                shot.nonLethalEnergyDist2Dm = shot.flightDistAccum2Dm
            else
                lethal = true
            end
        end

        shot.lastPoint = p
        shot.lastEnergy = newE 
        shot.lastMach = newMach
        continueTrack = lethal
    end

    return continueTrack

end

----------------------------------------------------------------------------------------------------------

shot_telemetry.colHeadings = function()
    local result = ''

    local cols = {}
    local colCount = 30

    local i
    for i = 1,colCount do
        cols[i] = ""
    end

    cols[1] = 'type  '
    cols[2] = 'launch Mach'
    cols[3] = 'launch TAS kts'
    cols[4] = 'launch alt ft'
    cols[5] = 'loft deg'
    cols[6] = 'maxShotAlt ft'

    cols[7] = 'target Mach'
    cols[8] = 'launch range to target nm'
    cols[9] = 'Tgt launch ATA deg'
    cols[10] = 'Tgt launch Aspect deg'
    cols[11] = 'Tgt launch alt ft'
    cols[12] = 'minRangeToTgt ft'
    cols[13] = 'minRangeToTgtMach'
    cols[14] = 'minRangeToTgtTime  s'

    cols[15] = 'flight time to mach thr s '
    cols[16] = 'flight dist to mach thr nm'
    cols[17] = 'flight track miles (2D) to mach thr nm'
    cols[18] = 'flight track miles (3D) to mach thr nm'

    cols[19] = 'flight time to energy thr s '
    cols[20] = 'flight dist to energy thr nm'
    cols[21] = 'flight track miles (2D) to energy thr nm'
    cols[22] = 'flight track miles (3D) to energy thr nm'

    cols[23] = 'launch specific energy (wind relative) kJ/kg '
    cols[24] = 'max specific energy (wind relative) kJ/kg '

    for i = 1,colCount do
        if cols[i] then
            result = result .. cols[i]
        end
        result = result .. ","
    end

    return result
end

shot_telemetry.teleRowToString = function(shot)
    local result = ''

    if not shot then return result end

    local cols = {}
    local colCount = 30

    local i
    for i = 1,colCount do
        cols[i] = ""
    end

    cols[1] = shot.typeName    
    cols[2] = shot.launchMach
    cols[3] = shot.launchTAS -- TAS kts
    cols[4] = shot.launchPoint.y * helms.maths.m2ft -- alt ft
    cols[5] = helms.maths.getPitch(shot.launchVel)/helms.maths.deg2rad -- loft degrees 
    cols[6] = shot.maxShotAltm * helms.maths.m2ft -- maxShotAlt

    if shot.tgtlaunchPoint then
        cols[7] = shot.tgtlaunchMach -- target Mach
        cols[8] = helms.maths.get3DDist(shot.tgtlaunchPoint,shot.launchPoint) * helms.maths.m2nm -- launch range to target
        cols[9] = helms.maths.thetaToDest(shot.launchVel, shot.launchPoint, shot.tgtlaunchPoint)/helms.maths.deg2rad -- Tgt launch ATA
        if shot.tgtLaunchVel then
            cols[10] = helms.maths.thetaToDest(shot.tgtLaunchVel, shot.tgtlaunchPoint, shot.launchPoint)/helms.maths.deg2rad  -- Tgt launch Aspect (off tgt nose)
        end
        cols[11] = shot.tgtlaunchPoint.y * helms.maths.m2ft -- Tgt launch alt
        cols[12] = shot.minSlantRangeToTgtm * helms.maths.m2ft  -- minRangeToTgt
        cols[13] = shot.minSlantRangeToTgtMach -- minRangeToTgtMach
        cols[14] = shot.minSlantRangeToTgtTime - shot.launchTime -- minRangeToTgtTime 
    end


    if shot.nonLethalMachTime then
        cols[15] = shot.nonLethalMachTime - shot.launchTime -- lethal flight time (mach)
        cols[16] = helms.maths.get2DDist(shot.nonLethalMachPoint, shot.launchPoint) * helms.maths.m2nm -- lethal flight range (mach)
        cols[17] = shot.nonLethalMachDist2Dm * helms.maths.m2nm -- lethal flight trackMiles2D (mach)
        cols[18] = shot.nonLethalMachDist3Dm * helms.maths.m2nm -- lethal flight trackMiles3D (mach)
    end

    if shot.nonLethalEnergyTime then
        cols[19] = shot.nonLethalEnergyTime - shot.launchTime -- lethal flight time (energy)
        cols[20] = helms.maths.get2DDist(shot.nonLethalEnergyPoint, shot.launchPoint) * helms.maths.m2nm -- lethal flight range (energy)
        cols[21] = shot.nonLethalEnergyDist2Dm * helms.maths.m2nm -- lethal flight trackMiles2D (energy)
        cols[22] = shot.nonLethalEnergyDist3Dm * helms.maths.m2nm -- lethal flight trackMiles3D (energy)
    end

    cols[23] = shot.launchEnergy / 1000 -- launch Specific Energy (wind relative) kJ/kg 
    cols[24] = shot.maxEnergy / 1000 -- max Specific Energy (wind relative) kJ/kg 

    for i = 1,colCount do
        if cols[i] then
            result = result .. cols[i]
        end
        result = result .. ","
    end

    return result
end
----------------------------------------------------------------------------------------------------------
-- API



--#######################################################################################################
-- shot_telemetry (PART 2)
--
helms.dynamic.scheduleFunction(shot_telemetry.doPoll_,nil,timer.getTime()+shot_telemetry.poll_interval)

return shot_telemetry