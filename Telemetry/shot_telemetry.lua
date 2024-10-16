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
shot_telemetry.mach_threshold_max = 2.0
shot_telemetry.mach_threshold_min = 0.8
shot_telemetry.mach_log_min_delta = 0.1
----------------------------------------------------------------------------------------------------------

shot_telemetry.active_missiles={} -- {wpnObj, lastMach, launchTime, launchPoint, launchVel, [type data], nonLethalMachTime, nonLethalMachPoint, nonLethalMachDist, flightDistAccum, tgtObj, nonLethalEnergyTime, nonLethalEnergyTime, nonLethalEnergyTime, lastPoint, lastEnergy}

shot_telemetry.history_missiles={} -- {wpnObj, lastMach, launchTime, launchPoint, launchVel, [type data], nonLethalMachTime, nonLethalMachPoint, nonLethalMachDist, flightDistAccum, tgtObj, nonLethalEnergyTime, nonLethalEnergyTime, nonLethalEnergyTime, lastPoint, lastEnergy}

shot_telemetry.next_shot_id = 0

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

    local p = weapon:getPoint()

    local newShot =
    {
        wpnObj = weapon
        ,shotId = shot_telemetry.next_shot_id 
        ,launchEnergy = helms.physics.getSpecificEnergyWindRel(initiator)
        ,launchMach = helms.physics.estimateMach(initiator)
        ,launchTAS = helms.physics.TasKts(initiator)
        ,launchTime = time
        ,launchPoint = p
        ,maxShotAltm = p.y
        ,maxEnergy = 0
        ,launchVel = initiator:getVelocity()
        ,typeName = weapon:getTypeName()
        ,flightDistAccum3Dm = 0
        ,flightDistAccum2Dm = 0

        ,samples = {
            -- {
            -- mach = 
            -- ,time = 
            -- ,point = {x,y,z}
            -- ,dist2Dm = 
            -- ,dist3Dm = 
            -- ,vel = {x,y,z}
            -- ,specEnergy =
            --}
        }
        ,lastPoint = p
        ,lastEnergy = 0
        ,lastMach = 0
    }

    newShot.lastMach = newShot.launchMach
    newShot.lastEnergy = newShot.launchEnergy
    newShot.maxEnergy = newShot.launchEnergy
    
    shot_telemetry.active_missiles[#shot_telemetry.active_missiles + 1] = newShot
    shot_telemetry.next_shot_id = shot_telemetry.next_shot_id + 1
end


shot_telemetry.missionEndHandler = function()

    shot_telemetry.log_i.log(shot_telemetry.colHeadings())

    for k,v in pairs( shot_telemetry.active_missiles) do
        for l,w in pairs (v.samples) do
            shot_telemetry.log_i.log(shot_telemetry.teleRowToString(v,w))
        end
    end

    for k,v in pairs(shot_telemetry.history_missiles) do
        for l,w in pairs (v.samples) do
            shot_telemetry.log_i.log(shot_telemetry.teleRowToString(v, w))
        end
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

    local lastSample = nil
    if shot.samples then
        lastSample = shot.samples[#shot.samples]  
    else
        shot.samples = {}
    end

    if continueTrack then
        local newMach = helms.physics.estimateMach(weapon)
        local lethal = false

        if newMach >= shot_telemetry.mach_threshold_min or newE >= shot.lastEnergy then
            lethal = true
        end

        if (not lastSample )
                or (math.abs(lastSample.mach - newMach) => shot_telemetry.mach_log_min_delta )
                or (not lethal) then

            shot.samples[#shot.samples] = 
            {
                mach = newMach
                ,time = now
                ,point = p
                ,dist2Dm = shot.flightDistAccum2Dm
                ,dist3Dm = shot.flightDistAccum3Dm
                ,vel = weapon:getVelocity()
            }     
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
--TODO update
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

    cols[12] = 'minRangeToTgt nm'
    cols[13] = 'minRangeToTgt Alt ft'
    cols[14] = 'tgt Alt at min range'
    cols[15] = 'minRangeToTgt Mach'
    cols[16] = 'tgt Mach at min range'
    cols[17] = 'minRangeToTgtTime  s'
    cols[18] = 'flight dist minRangeToTgt nm'
    cols[19] = 'flight track miles (2D) to minRangeToTgt nm'
    cols[20] = 'flight track miles (3D) to minRangeToTgt nm'

    cols[21] = 'flight time to mach thr s '
    cols[22] = 'flight dist to mach thr nm'
    cols[23] = 'flight track miles (2D) to mach thr nm'
    cols[24] = 'flight track miles (3D) to mach thr nm'

    cols[25] = 'flight time to energy thr s '
    cols[26] = 'flight dist to energy thr nm'
    cols[27] = 'flight track miles (2D) to energy thr nm'
    cols[28] = 'flight track miles (3D) to energy thr nm'

    cols[29] = 'launch specific energy (wind relative) kJ/kg '
    cols[30] = 'max specific energy (wind relative) kJ/kg '

    for i = 1,colCount do
        if cols[i] then
            result = result .. cols[i]
        end
        result = result .. ","
    end

    return result
end

shot_telemetry.teleRowToString = function(shot, sample)
    local result = ''

    if not shot then return result end

    local cols = {}
    local colCount = 30

    local i
    for i = 1,colCount do
        cols[i] = ""
    end
--TODO update
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

        cols[12] = shot.minSlantRangeToTgtm * helms.maths.m2nm  -- minRangeToTgt nm
        cols[13] = shot.minSlantRangeToTgtPoint.y * helms.maths.m2ft -- 'minRangeToTgt Alt ft'
        cols[14] = shot.tgtPointMinSlantRange.y * helms.maths.m2ft -- 'tgt Alt at min range'
        cols[15] = shot.minSlantRangeToTgtMach -- minRangeToTgtMach
        cols[16] = shot.tgtMachMinSlantRange  --'tgt Mach at min range'
        cols[17] = shot.minSlantRangeToTgtTime - shot.launchTime -- minRangeToTgtTime 

        cols[18] = helms.maths.get2DDist(shot.minSlantRangeToTgtPoint, shot.launchPoint) * helms.maths.m2nm  --'flight dist minRangeToTgt nm'
        cols[19] = shot.minSlantRangeToTgtDist2Dm * helms.maths.m2nm --'flight track miles (2D) to minRangeToTgt nm'
        cols[20] = shot.minSlantRangeToTgtDist3Dm * helms.maths.m2nm --'flight track miles (3D) to minRangeToTgt nm'
    end


    if shot.nonLethalMachTime then
        cols[21] = shot.nonLethalMachTime - shot.launchTime -- lethal flight time (mach)
        cols[22] = helms.maths.get2DDist(shot.nonLethalMachPoint, shot.launchPoint) * helms.maths.m2nm -- lethal flight range (mach)
        cols[23] = shot.nonLethalMachDist2Dm * helms.maths.m2nm -- lethal flight trackMiles2D (mach)
        cols[24] = shot.nonLethalMachDist3Dm * helms.maths.m2nm -- lethal flight trackMiles3D (mach)
    end

    if shot.nonLethalEnergyTime then
        cols[25] = shot.nonLethalEnergyTime - shot.launchTime -- lethal flight time (energy)
        cols[26] = helms.maths.get2DDist(shot.nonLethalEnergyPoint, shot.launchPoint) * helms.maths.m2nm -- lethal flight range (energy)
        cols[27] = shot.nonLethalEnergyDist2Dm * helms.maths.m2nm -- lethal flight trackMiles2D (energy)
        cols[28] = shot.nonLethalEnergyDist3Dm * helms.maths.m2nm -- lethal flight trackMiles3D (energy)
    end

    cols[29] = shot.launchEnergy / 1000 -- launch Specific Energy (wind relative) kJ/kg 
    cols[30] = shot.maxEnergy / 1000 -- max Specific Energy (wind relative) kJ/kg 

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