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

-- Feature suggest: Damage to jammer while on, permanent destruction (until respawn)
-- Feature suggest: investigate LOS as condtion for the audio & jamming
-- Feature suggest: Just turn of radars, not AI

-- MODULE OPTIONS:----------------------------------------------------------------------------------------
minitrons.poll_interval = 2.7 --seconds, time between updates of jamming effects
--
minitrons.heat_decay = 120 -- per second up to 3600
minitrons.heat_growth = 120 -- per second up to 3600
minitrons.heat_maxstart = 240 -- Max heat at which jamming can be enabled
minitrons.heat_cutout = 3600
minitrons.damage_rate = 1
minitrons.max_damage = 300

minitrons.default_jam_range = 10000
minitrons.default_audio_range = 20000

minitrons.menu_jammer_label = "Minitrons Jammer"
minitrons.jammerUsMsg = "Jammer u/s (burnt out)"

minitrons.jammerProfiles =
{
--    ["SA-3"]={jammedUnitTypes = {--[[ TypeName = {} ]]}},
--    ["Blue AAA"]={jammedUnitTypes = {
--            ["HEMTT_C-RAM_Phalanx"] ={}
--    }},
--    ["Blue EWR"]={jammedUnitTypes = {
--        ["FPS-117"] = {}
--    }}
}

----------------------------------------------------------------------------------------------------------

minitrons.unitTypeDisplayNameCache =
{
    -- ["TypeName"] = "DisplayName"
}

minitrons.polledUnits =
{
    -- ["UnitName"] = {
    --          heat0 = 0, 
    --          time0=0, 
    --          jammerActive = false, 
    --          jammerProfiles = { [n] = "Profile" }, 
    --          jammedUnits={}, 
    --          audibleTypes={}, 
    --          activeProfile = "", 
    --          commsParent = nil, 
    --          groupName = ""
    --          unitName = "UnitName"
    -- }
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
-- Clear Jammer effects from a jamming unit
--]]
minitrons.handleJammerOff = function(polledUnit)

    for juName,_ in pairs(polledUnit.jammedUnits) do
        minitrons.unJamUnit(juName)
    end

    polledUnit.jammedUnits = {}
end

--[[
-- Apply Jammer effects of one jammer to one jammed unit, if not already jammed.
-- Requires a nonce for visibility of which units were jammed this round
--]]
minitrons.handleJammerOnUnit = function(polledUnit, jammedUnitName, nonce)
    
    
    -- If newly-jammed
    if not polledUnit.jammedUnits[jammedUnitName] then
        minitrons.jamUnit(jammedUnitName)    
    end
    
    polledUnit.jammedUnits[jammedUnitName]  = nonce

end

--[[
-- Comms option handler for switching off the jammer
--]]
minitrons.handleCommOff = function(polledUnit)

    if (not polledUnit) then
        minitrons.log_e.log("handleCommOff: polledUnit was null.")
    elseif not polledUnit.jammerActive then
        minitrons.log_e.log("Cannot de-activate jammer. It's already off")
    end

    polledUnit.jammerActive = false

    local now = timer.getTime()

    polledUnit.heat0 = math.min(minitrons.heat_cutout, polledUnit.heat0 + (now - polledUnit.time0) * minitrons.heat_growth)
    polledUnit.damage0 = polledUnit.damage0 + (now - polledUnit.time0) * minitrons.damage_rate
    polledUnit.time0 = now

    minitrons.handleJammerOff(polledUnit)

    -- Update comms menus after this handler completes
    helms.dynamic.scheduleFunction(minitrons.resetCommsMenus,{polledUnit},now+1,true)
end

--[[
-- Comms option handler for switching on the jammer
--]]
minitrons.handleCommOn = function(polledUnit, profile)

   -- local polledUnit = minitrons.polledUnits[unitName]

    if (not polledUnit) then
        minitrons.log_e.log("handleCommOn: polledUnit was null.")
    elseif polledUnit.jammerActive then
        minitrons.log_e.log("Cannot activate jammer. It's already on")
    end

    local now = timer.getTime()

    local unit = Unit.getByName(polledUnit.unitName)

    local heat1 =  polledUnit.heat0 - (now - polledUnit.time0) * minitrons.heat_decay

    if polledUnit.burntOut then
        if unit then

            trigger.action.outTextForUnit(unit:getID()  ,minitrons.jammerUsMsg,5,false)
        end
        return 

    elseif heat1 > minitrons.heat_maxstart then
        if unit then

            local availInMins = math.ceil ((heat1 - minitrons.heat_maxstart) / (60 * minitrons.heat_decay))

            trigger.action.outTextForUnit(unit:getID()  ,"Jammer is cooling down\nWait " .. availInMins ..  " mins",5,false)
        end
        return 
    end

    polledUnit.heat0 = math.max(0,heat1)
    -- polledUnit.damage0 = ... -- Jammer was off - no damage to add
    polledUnit.time0 = now

    polledUnit.activeProfile = profile
    polledUnit.jammerActive = true

    if unit then
        trigger.action.outTextForUnit(unit:getID()  ,"Jammer on. Mode: " .. profile,5,false)
    end

    -- Update comms menus after this handler completes
    helms.dynamic.scheduleFunction(minitrons.resetCommsMenus,{polledUnit},now+1,true)
end


--[[
-- Remove Jammer effects for a single unit
--]]
minitrons.handleJammerOffUnit = function(polledUnit, jammedUnitName)
    
    polledUnit.jammedUnits[jammedUnitName] = nil
    minitrons.unJamUnit(jammedUnitName)    
end

--[[
-- List currently audible radars
--]]
minitrons.repeatAudio = function(polledUnit)

    local unit = Unit.getByName(polledUnit.unitName)
    if (not unit) or (not polledUnit.audibleUnitTypes) then return end

    local msg = "Signals detected:"
    local found = false

    for k, nce in pairs(polledUnit.audibleUnitTypes) do
        if nce ~= minitrons.noNonce then
            found = true
            msg = msg .. "\n" .. minitrons.unitTypeDisplayNameCache[k]
        end
    end

    if not found then
        msg = "No signals detected"
    end

    trigger.action.outTextForUnit(unit:getID(),msg,10,false)
end

--[[
-- Set comms menus for the current jammer state
--]]
minitrons.resetCommsMenus = function(polledUnit)
    if polledUnit.commsParent then
        helms.ui.removeChildItems(polledUnit.commsParent)
    elseif polledUnit.groupName then
        polledUnit.commsParent = helms.ui.ensureSubmenuForGroup(polledUnit.groupName, minitrons.menu_jammer_label)
    end

    if not polledUnit.commsParent then
        minitrons.log_e.log("No comms parent for group")
        return
    end

    if polledUnit.jammerActive then
        helms.ui.addCommand(polledUnit.commsParent,"Audio",minitrons.repeatAudio, polledUnit)
        helms.ui.addCommand(polledUnit.commsParent,"Off",minitrons.handleCommOff, polledUnit)
    else

        helms.ui.addCommand(polledUnit.commsParent,"Audio",minitrons.repeatAudio, polledUnit)
        for _,v in pairs(polledUnit.jammerProfiles) do
    
            helms.ui.addCommand(polledUnit.commsParent,"On: "..v,minitrons.handleCommOn, polledUnit, v)
        end
    end

end

--[[
-- Check for jammable units within range of a given unit (given its active mode). Apply effects to those units
--]]
minitrons.conditionalJammingForPoll = function(unit,polledUnit,nonce)

    -- Clear jammer count for jammed units
    if (not polledUnit.jammerActive) or (polledUnit.burntOut) then
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

    local pred = function(junit)

        return jammedUnitTypes[junit:getTypeName()] ~= nil
    end
    
    local matchUnits = helms.predicate.filterObjects(minitrons.jammableUnits,zonePredJam,pred)

    if not matchUnits then matchUnits = {} end

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
-- Check for audible units within range of a given unit. Show messages / play audio to the jamming player if applicable
--]]
minitrons.updateAudioForPoll = function(unit,polledUnit,nonce)

    if (not unit) or (not polledUnit) or (not polledUnit.audibleUnitTypes) then return end

    local audibleUnitTypes = polledUnit.audibleUnitTypes
    local zonePredAudio = helms.predicate.makeCircZoneDescUnit(unit, minitrons.default_audio_range)

    local pred = function(junit)
        return audibleUnitTypes[junit:getTypeName()] ~= nil 
    end
    
    local matchUnits = helms.predicate.filterObjects(minitrons.jammableUnits,zonePredAudio,pred)

    if not matchUnits then matchUnits = {} end

    for _, junit in pairs(matchUnits) do

        local typeName = junit:getTypeName()

        if not minitrons.unitTypeDisplayNameCache[typeName] then
            minitrons.unitTypeDisplayNameCache[typeName] = junit:getDesc().displayName
        end

        if polledUnit.audibleUnitTypes[typeName] == minitrons.noNonce then
            local msg = "Signal detected: " .. minitrons.unitTypeDisplayNameCache[typeName]

            trigger.action.outTextForUnit(unit:getID(),msg,10,false)
        end

        polledUnit.audibleUnitTypes[typeName] = nonce

    end

    for typeName,nce in pairs (polledUnit.audibleUnitTypes) do
        if (nce ~= nonce) and (nce ~= minitrons.noNonce) then

            local msg = "Lost signal: " .. minitrons.unitTypeDisplayNameCache[typeName]

            trigger.action.outTextForUnit(unit:getID(),msg,10,false)

            polledUnit.audibleUnitTypes[typeName] = minitrons.noNonce
        end
    end

end

--[[
-- Check for jammable units near the given unit name and apply effects
--]]
minitrons.pollUnit = function(polledUnit, nonce, now)

    local unit = Unit.getByName(polledUnit.unitName)

    if (not unit) or (not unit:isExist()) then
        polledUnit.jammerActive = false
    end

    -- Check for audible units --

    minitrons.updateAudioForPoll(unit,polledUnit,nonce)

    -- Handle cooldown and overheat
    local heat1
    local damage1 = polledUnit.damage0

    if polledUnit.jammerActive then
        heat1 = polledUnit.heat0 + minitrons.heat_growth * (now - polledUnit.time0)
        damage1 = damage1 + minitrons.damage_rate * (now - polledUnit.time0)

    else
        heat1 = polledUnit.heat0 - minitrons.heat_decay * (now - polledUnit.time0)
    end

    -- If Jammer overheated or burnt out
    if damage1 > minitrons.max_damage  or heat1 > minitrons.heat_cutout then

        local msg = "Jammer overheated"

        if damage1 > minitrons.max_damage then
            msg = minitrons.jammerUsMsg

            polledUnit.burntOut = true
            damage1 = minitrons.max_damage -- do not trigger the burnt-out event next time

        end

        if unit then
            trigger.action.outTextForUnit(unit:getID()  , msg,5,false)
        end

        polledUnit.heat0 = minitrons.heat_cutout -- do not trigger the overheated event next time
        polledUnit.time0 = now
        polledUnit.damage0 = damage1 
        polledUnit.jammerActive = false

        minitrons.resetCommsMenus(polledUnit) --

--    elseif heat1 <= minitrons.heat_maxstart and polledUnit.heat0 > minitrons.heat_maxstart then -- Cooldown handling
--
--        polledUnit.heat0 = heat1
--        polledUnit.time0 = now
--        polledUnit.damage0 = damage1 
    end

    -- Jamming effects --
    minitrons.conditionalJammingForPoll(unit,polledUnit,nonce)
end

--[[
-- Poll loop counter to act as a nonce for checking if activity occurred this poll
--]]
minitrons.pollNonce = 0

--[[
-- non-nil Value not clashing with any nonce
--]]
minitrons.noNonce = false

--[[
Private: do poll of groups and pools
--]]
minitrons.doPoll_ = function()

	local now = timer.getTime()

    for _, v in pairs(minitrons.polledUnits) do
        helms.util.safeCall(minitrons.pollUnit,{v, minitrons.pollNonce, now},minitrons.catchError)
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

    --minitrons.log_i.log(minitrons.jammerProfiles)
    --minitrons.log_i.log(minitrons.unitTypeFilter)
end


--[[
-- Rebuild a list of audible type names for a jammer unit
--]]
minitrons.rebuildAudibleTypesForUnit = function(polledUnit)
    local types = {}

    if polledUnit == nil or polledUnit.jammerProfiles == nil then return end

    for _, profileKey in pairs(polledUnit.jammerProfiles) do
        local profile = minitrons.jammerProfiles[profileKey]

        local profileTypes

        if profile then profileTypes = profile.jammedUnitTypes end
        if not profileTypes then profileTypes = {} end

        for k,_ in pairs(profileTypes) do
            types[k] = minitrons.noNonce
        end
    end

    polledUnit.audibleUnitTypes = types
end
--API----------------------------------------------------------------------------------------------------
minitrons.addJammerUnit = function(unitName,jammerProfiles)
    if jammerProfiles == nil then
        minitrons.log_e.log("jammerProfiles required")
        return
    end

    if not minitrons.configurationReady then
        minitrons.log_e.log("rebuildConfig was not called before adding jammer unit")
    end

    -- Replace profile options with valid options
    for k,v in pairs(jammerProfiles) do
        if minitrons.jammerProfiles[v] == nil then
            jammerProfiles[k] = nil
            minitrons.log_e.log("jammerProfile not found: "..v)
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
        minitrons.polledUnits[unitName] = {
            jammerProfiles = jammerProfiles, 
            heat0 = 0, 
            time0 = 0, 
            jammerActive = false, 
            jammedUnits={}, 
            audibleTypes={}, 
            groupName = groupName,
            unitName = unitName,
            damage0 = 0
        }
    end

    minitrons.rebuildAudibleTypesForUnit(minitrons.polledUnits[unitName])
    minitrons.resetCommsMenus(minitrons.polledUnits[unitName])

end

--[[
-- Add the types of named unit(s) to the named profile 
--]]
minitrons.addUnitToProfile = function(profileName,...)

    if (not profileName) or (not arg) or (next(arg) == nil) then return end

--    ["SA-3"]={jammedUnitTypes = {--[[ TypeName = {} ]]}},
    local jammedUnitTypes = {}

    if not minitrons.jammerProfiles[profileName] then
        minitrons.jammerProfiles[profileName] = {}
    end
    
    if minitrons.jammerProfiles[profileName].jammedUnitTypes then
        jammedUnitTypes = minitrons.jammerProfiles[profileName].jammedUnitTypes
    end

    for _, unitName in ipairs(arg) do
        local unit = Unit.getByName(unitName)

        if unit then
            jammedUnitTypes[unit:getTypeName()] = {}
        else
            minitrons.log_i.log("Unit type " .. unitName .. " not found.")
        end
    end

    minitrons.configurationReady = false
    minitrons.jammerProfiles[profileName].jammedUnitTypes = jammedUnitTypes

    minitrons.log_i.log(minitrons.jammerProfiles)

--    -- rebuild comms and lookups for jammer units already added
--    for _,pu in pairs(minitrons.polledUnits) do
--        minitrons.rebuildAudibleTypesForUnit(pu)
--        minitrons.resetCommsMenus(pu)
--    end

end

--[[
-- To be called after changing profiles, before adding jammer units
--]]
minitrons.rebuildConfig = function()

    -- Rebuild list of unit types affected by minitrons
    minitrons.rebuildUnitTypeFilter()

    -- Simulate spawn event for all existing units
    for _,coa in pairs(coalition.side) do
        for _,gp in pairs(coalition.getGroups(coa)) do
            for _, unit in pairs(gp:getUnits()) do
                minitrons.handleUnitSpawn(unit)
            end
        end
    end

    minitrons.configurationReady = true
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

    local unitName = unit:getName()

    if minitrons.unitTypeFilter[unit:getTypeName()] then
        table.insert(minitrons.jammableUnits, unit)
        minitrons.jammableUnitsEx[unitName] = {jammerCount = 0}
    end

    -- Reset jammer on a new spawn of a player unit
    local existingPlayer = minitrons.polledUnits[unitName]
    if existingPlayer then
        existingPlayer.heat0 = 0
        existingPlayer.time0 = 0
        existingPlayer.damage0 = 0
        existingPlayer.jammerActive = false
        existingPlayer.burntOut = false
        existingPlayer.activeProfile = nil

        minitrons.resetCommsMenus(existingPlayer)
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
world.addEventHandler(minitrons.EventHandler)

minitrons.rebuildConfig()

helms.dynamic.scheduleFunction(minitrons.doPoll_,nil,timer.getTime()+minitrons.poll_interval)

minitrons.log_i.log("Minitrons initialised")
