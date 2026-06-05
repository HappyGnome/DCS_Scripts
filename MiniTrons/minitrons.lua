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

minitrons.jammerProfiles = 
{
    ["SA-3"]={jammedUnitTypes = {}}
}

minitrons.polledUnits =
{
    -- ["UnitName"] = {heat = 0, jammerActive = false, jammerProfiles = {}}
}

----------------------------------------------------------------------------------------------------------

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
Private: do poll of groups and pools
--]]
minitrons.doPoll_ = function()

	local now = timer.getTime()

    xpcall(pollUnit,minitrons.catchError)
    
    -- helms.predicate.makeCircZoneDescUnit = function(unit, radius)

	--schedule next poll----------------------------------
	return now+minitrons.poll_interval
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

    minitrons.polledUnits[unitName] = {jammerProfiles = jammerProfiles, heat = 0, jammerActive = false}

    -- TODO: support multiple profiles (e.g. array of jammerProfiless, suitably validated)
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
