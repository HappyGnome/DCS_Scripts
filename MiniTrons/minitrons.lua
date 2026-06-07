--#######################################################################################################
-- MINITRONS 
-- Run once at mission start after initializing HeLMS
-- 
-- Add some basic SAM jamming functionality
--
-- Script by HappyGnome

if not helms then return end
if helms.version < 1.17 then 
	helms.log_e.log("Invalid HeLMS version for MiniTrons")
end

minitrons = {}

-- MODULE OPTIONS:----------------------------------------------------------------------------------------
minitrons.poll_interval = 13.5 --seconds, time between updates of jamming effects
--
minitrons.heat_decay = 120 -- per second up to 3600
minitrons.heat_growth = 120 -- per second up to 3600
minitrons.heat_cutout = 3600

minitrons.default_jam_range = 10000
minitrons.default_audio_range = 20000

minitrons.jammerProfiles =
{
    ["SA-3"]={jammedUnitTypes = {--[[ TypeName = {} ]]}}
}


----------------------------------------------------------------------------------------------------------

minitrons.polledUnits =
{
    -- ["UnitName"] = {heat = 0, jammerActive = false, jammerProfiles = {}, jammedUnits={}, activeProfile = ""}
}

minitrons.jammableUnits =
{
    -- [n] = unit
}

minitrons.jammableUnitsEx =
{
    --[UnitName] = {jammerCount = 0}
}


--------------------------------------------------------------------------------------------------------

--[[
Loggers for this module
--]]
minitrons.log_i=helms.logger.new("minitrons","info")
minitrons.log_e=helms.logger.new("minitrons","error")

--error handler for xpcalls. wraps minitrons.log_e:error
minitrons.catchError=function(err)
	minitrons.log_e.log(err)
end 

--POLL----------------------------------------------------------------------------------------------------

--[[
-- Unset Jamming effect on one jammed unit
--]]
minitrons.unJamUnit = function(jammedUnitName)
    local jux = minitrons.jammableUnitsEx[jammedUnitName]

    if not jux then
        minitrons.log_e.log("unJamUnit: Named unit is not a jammed unit: " .. jammedUnitName)
        return
    end

    if jux.jammerCount > 1 then
        jux.jammerCount = jux.jammerCount - 1
    elseif jux.jammerCount == 1 then

        local unit = Unit.getByName(jammedUnitName)
        local group
        local controller

        if unit then
            group = unit:getGroup()
        end

        if group then
            controller = group:getController()
        end

        if controller then
            controller:setOnOff(true)
        end

        jux.jammerCount = 0
    else
        jux.jammerCount = 0
    end
end

--[[
-- Set Jamming effect on one jammed unit
--]]
minitrons.jamUnit = function(jammedUnitName)
    local jux = minitrons.jammableUnitsEx[jammedUnitName]

    if not jux then
        minitrons.log_e.log("jamUnit: Named unit is not a jammed unit: " .. jammedUnitName)
        return
    end

    jux.jammerCount = jux.jammerCount + 1
    
    if jux.jammerCount == 1 then -- first jammer creates the effect
        local unit = Unit.getByName(jammedUnitName)
        local group
        local controller

        if unit then
            group = unit:getGroup()
        end

        if group then
            controller = group:getController()
        end

        if controller then
            controller:setOnOff(false)
        end
    end
end

--[[
-- Clear Jammer effects
--]]
minitrons.handleJammerOff = function(polledUnit)
    if #polledUnit.jammedUnits > 0 then

        for juName,_ in pairs(polledUnit.jammedUnits) do
            minitrons.unJamUnit(juName)
        end

        polledUnit.jammedUnits = {}
    end
end

--[[
-- Apply Jammer effects. Requires a nonce for visibility of which units were jammed this round
--]]
minitrons.handleJammerOnUnit = function(polledUnit, jammedUnitName, nonce)
    
    -- If newly-jammed
    if not polledUnit.jammedUnits[jammedUnitName] then
        minitrons.jamUnit(jammedUnitName)    
    end
    
    polledUnit.jammedUnits[jammedUnitName]  = nonce

end

--[[
-- Remove Jammer effects for a single unit
--]]
minitrons.handleJammerOffUnit = function(polledUnit, jammedUnitName)
    
    polledUnit.jammedUnits[jammedUnitName] = nil
    minitrons.unJamUnit(jammedUnitName)    
end


--[[
-- Check for jammable units near the given unit name and apply effects
--]]
minitrons.pollUnit = function(unitName,polledUnit, nonce)

    local unit = Unit.getByName(unitName)

    if (not unit) or (not unit:isExist()) then
        polledUnit.jammerActive = false
    end

    -- Handle cooldown and overheat
    local oldHeat = polledUnit.heat

    if oldHeat > minitrons.heat_cutout then
        -- TODO minitrons.handleOverheat(polledUnit)    
        --
        polledUnit.heat = minitrons.heat_cutout
        polledUnit.jammerActive = false
    else
        local newHeat = oldHeat - minitrons.heat_decay

        if newHeat > 0 then
            polledUnit.heat = newHeat
        elseif newHeat == 0 then
            -- TODO minitrons.handleCooldown(polledUnit)
        else
            polledUnit.heat = 0
        end        
    end

    -- Clear jammer count for jammed units
    if (not polledUnit.jammerActive) then
        minitrons.handleJammerOff(polledUnit)
        return
    end

    if (not unit) or (polledUnit.activeProfile == nil) then return end
    
    local profile = minitrons.jammerProfiles[polledUnit.activeProfile] 
    local jammedUnitTypes = profile.jammedUnitTypes

    if not jammedUnitTypes then return end

    -- Jammer active --

    -- Check for jammed units

    local zonePredJam = helms.predicate.makeCircZoneDescUnit(unit, minitrons.default_jam_range)
    --local zonePredAudio = helms.predicate.makeCircZoneDescUnit(unit, minitrons.default_audio_range)

    local pred = function(junit)
        return jammedUnitTypes[profile.junit:getTypeName()] ~= nil
    end
    
    local matchUnits = helms.predicate.filterObjects(minitrons.jammableUnits,zonePredJam,pred)

    if not matchUnits then return end

    for _, junit in pairs(matchUnits) do
        local junitName = junit:getName()
        minitrons.handleJammerOnUnit(polledUnit,junitName,nonce)
    end

    -- Check for jammed units no-longer in range
    for ujuName, nce in pairs(polledUnit.jammedUnits) do
        if nce ~= nonce then
            minitrons.handleJammerOffUnit(polledUnit,ujuName)
        end
    end
end

--[[
-- Poll loop counter to act as a nonce for checking if activity occurred this poll
--]]
minitrons.pollNonce = 0

--[[
Private: do poll of groups and pools
--]]
minitrons.doPoll_ = function()

	local now = timer.getTime()

    for k, v in pairs(minitrons.polledUnits) do
        helms.util.safeCall(minitrons.pollUnit,{k,v, minitrons.pollNonce},minitrons.catchError)
    end    

    minitrons.pollNonce = minitrons.pollNonce + 1

	--schedule next poll----------------------------------
	return now+minitrons.poll_interval
end

--INTERNAL METHODS----------------------------------------------------------------------------------------------------

--[[
-- Build minitrons.unitTypeFilter a list of typenames to check for jamming
--]]
minitrons.rebuildUnitTypeFilter = function()
    minitrons.unitTypeFilter = {}

    for _, v in pairs(minitrons.jammerProfiles) do
        if v.jammedUnitTypes then
            for typeName, _ in pairs(v.jammedUnitTypes) do
                minitrons.unitTypeFilter[typeName] = true
            end
        end
    end
end

--API----------------------------------------------------------------------------------------------------
minitrons.addJammerUnit = function(unitName,jammerProfiles)
    if jammerProfiles == nil then
        minitrons.log_e.log("jammerProfiles required")
        return
    end

    -- Replace profile options with valid options
    for k,v in pairs(jammerProfiles) do
        if minitrons.jammerProfiles[k] == nil then
            jammerProfiles[k] = nil
        end
    end

    if unitName == nil then
        minitrons.log_e.log("unitName required")
        return
    end

    -- get group name for unit
    local unit = Unit.getByName(unitName)
    local groupName = ""
    local groupSize = 0

    if unit then
        local group = unit:getGroup()

        if group then
            groupName = group:getName()
            groupSize = group:getInitialSize()
        end
    else
        local groupKeys = helms.mission.getMEGroupKeysForUnit(unitName)
        groupName = groupKeys.groupName
        groupSize = groupKeys.unitCount
    end

    if groupSize > 1 then
        minitrons.log_i.log("Warning: Minitrons may not work properly for groups with multiple units.")
        minitrons.log_i.log(groupName .. " contains " .. groupSize .. " units")
    end

    -- Add to polled units (or switch profiles)
    if minitrons.polledUnits[unitName] then
        minitrons.polledUnits[unitName].jammerProfiles = jammerProfiles
    else
        minitrons.polledUnits[unitName] = {jammerProfiles = jammerProfiles, heat = 0, jammerActive = false, jammedUnits={}}
    end


    -- TODO: add comms menu options for the unit (One On option per profile)
    -- When clicked, add an off option. After a delay, re-add the modes?

end


--[[
-- Minimal logic notes:
-- When search radar within range of aircraft, and cockpit switch in stated position, and not cooked off
-- - AI of the SAM's group off
-- When in range of the SAM (different range) and Jamming not in effect -> play SAM sound
-- Jamming switch cooks off -> Some time after switching it on
-- Cools down -> Is no-longer cooked-off when switched off for a set time
--
-- Jamming is for one SAM type at a time -> Unit can select from the comms menu
-- API:
--  minitrons.addSamType("KeyUnitTypeName","SoundFileName", sound range, jamrange, "DisplayName") -- DisplayName optionally create group of Radars to jam
--  minitrons.addJammerUnit("unit name", <Cockpit switch number>, <Cockpit Switch On>, <Cockpit switch off>)
--]]


--EVENTS----------------------------------------------------------------------------------------------------

minitrons.handleUnitSpawn = function(unit)
    if not unit then return end

    if minitrons.unitTypeFilter[unit:getTypeName()] then
        table.insert(minitrons.jammableUnits, unit)
        minitrons.jammableUnitsEx[unit:getName()] = {jammerCount = 0}
    end
end

minitrons.EventHandler = {
    onEvent = function(self, event)
        if (event.id == world.event.S_EVENT_BIRTH) then
            helms.util.safeCall(minitrons.handleUnitSpawn, { event.initiator }, minitrons.catchError)
        end
    end
}

--STARTUP----------------------------------------------------------------------------------------------------
minitrons.rebuildUnitTypeFilter()

world.addEventHandler(minitrons.EventHandler)
