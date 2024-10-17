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
            -- ,tas_kts =
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

    if (not p) then return false end

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

    local newMach = helms.physics.estimateMach(weapon)
    local sampleStarted = false

    if newE < shot.lastEnergy then
        if newMach < shot_telemetry.mach_threshold_min then
            continueTrack = false
        end
        
        if newMach <= shot_telemetry.mach_threshold_max then
            sampleStarted = true
        end
    end

    if 
    (
            sampleStarted
        and
        (       
                (not lastSample)
            or  (math.abs(lastSample.mach - newMach) >= shot_telemetry.mach_log_min_delta )
            or  (not continueTrack) 
        )
            
    ) then

        shot.samples[#shot.samples + 1] = 
        {
            mach = newMach
            ,time = now
            ,point = p
            ,dist2Dm = shot.flightDistAccum2Dm
            ,dist3Dm = shot.flightDistAccum3Dm
            ,vel = weapon:getVelocity()
            ,tas_kts = helms.physics.TasKts(weapon)
            ,specEnergy  = newE
        }     
    end

    shot.lastPoint = p
    shot.lastEnergy = newE 
    shot.lastMach = newMach

    return continueTrack

end

----------------------------------------------------------------------------------------------------------

shot_telemetry.colHeadings = function()
    local result = ''

    local cols = {}
    local colCount = 18

    local i
    for i = 1,colCount do
        cols[i] = ""
    end

    cols[1] = 'type'
    cols[2] = 'shot_id'
    cols[3] = 'lnch_mach'
    cols[4] = 'lnch_tas_kts'
    cols[5] = 'lnch_alt_ft'
    cols[6] = 'lnch_loft_deg'
    cols[7] = 'lnch_spec_e_kj_kg'
    
    cols[8] = 'max_alt_ft'
    cols[9] = 'max_spec_e_kj_kg'

    cols[10] = 'flgt_time_s'
    cols[11] = 'flgt_dist_nm'
    cols[12] = 'trk_dist_2d_nm'
    cols[13] = 'trk_dist_3d_nm'
    cols[14] = 'alt_ft'
    cols[15] = 'spec_e_kj_kg'
    cols[16] = 'mach'
    cols[17] = 'tas_kts'
    cols[18] = 'vs_fpm'

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
    local colCount = 18

    local i
    for i = 1,colCount do
        cols[i] = ""
    end

    cols[1] = shot.typeName    
    cols[2] = shot.shotId  
    cols[3] = shot.launchMach
    cols[4] = shot.launchTAS -- TAS kts
    cols[5] = shot.launchPoint.y * helms.maths.m2ft -- alt ft
    cols[6] = helms.maths.getPitch(shot.launchVel)/helms.maths.deg2rad -- loft degrees 
    cols[7] = shot.launchEnergy / 1000 -- launch Specific Energy (wind relative) kJ/kg 

    cols[8] = shot.maxShotAltm * helms.maths.m2ft -- maxShotAlt
    cols[9] = shot.maxEnergy / 1000 -- max Specific Energy (wind relative) kJ/kg 

    cols[10] = sample.time - shot.launchTime        --'flgt_time_s'
    cols[11] = helms.maths.get2DDist(sample.point, shot.launchPoint) * helms.maths.m2nm --'flgt_dist_nm'
    cols[12] = sample.dist2Dm * helms.maths.m2nm    --'trk_dist_2d_nm'
    cols[13] = sample.dist3Dm * helms.maths.m2nm    --'trk_dist_3d_nm'
    cols[14] = sample.point.y * helms.maths.m2ft    --'alt_ft'
    cols[15] = sample.specEnergy / 1000             --'spec_e_kj_kg'
    cols[16] = sample.mach                          --'mach'
    cols[17] = sample.tas_kts                       --'tas_kts'
    cols[18] = sample.vel.y * helms.maths.m2ft * 60 --'vs_fpm'    

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