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
--minitrons.rep_rcs = 10 -- m^2 representa
minitrons.default_on_time = 30 -- seconds
minitrons.default_range_nm = 20 
minitrons.default_cooldown_time = 30 --seconds

minitrons.unit_type_switch
{
    ["F/A-18C"] = 123
}

minitrons.polled_units = 
{
    -- ["UnitName"] = {jammedUnitTypes = {["typeName"] = {}}}, onTime = 0, offTIme = 0}
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

	--schedule next poll----------------------------------
	return now+minitrons.poll_interval
end


--API----------------------------------------------------------------------------------------------------
minitrons.addJammerUnit = function(unitName,jammedUnitType)
    if jammedUnitType == nil then
        return
    end

    if unitName == nil then
        return
    end

    if minitrons.polled_units[unitName] == nil then
        minitrons.polled_units[unitName] = {jammedUnitTypes = {}, onTime = 0, offTIme = 0}
    end

    table.insert(minitrons.polled_units[unitName].jammedUnitTypes,{[jammedUnitType] = {}})

end
