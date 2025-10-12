
--#######################################################################################################
-- MINITRONS 
-- Run once at mission start after initializing HeLMS
-- 
-- Add some basic SAM jamming functionality
--
-- Script by HappyGnome

if not helms then return end
if helms.version < 1.15 then 
	helms.log_e.log("Invalid HeLMS version for MiniTrons")
end

minitrons = {}

-- MODULE OPTIONS:----------------------------------------------------------------------------------------
minitrons.poll_interval = 59.5 --seconds, time between updates of jamming effects
----------------------------------------------------------------------------------------------------------

--[[
    Key = Jammer name
    Value = Jammer config options
--]]
minitrons.jammerType = { Type1 = {noseGimbal = 60, tailGimbal = 60}}

--[[
    Key = SAM Unit Name
    Value = Table: Key = jammer type, Value = Sam-jammer interaction parameters (defines suppression effects)
--]]
minitrons.samConfig =
{
    ["SA-2"] = 
    { 
            config = 
            {
                --degradeMinCoef = 0.1, -- Minimum scale factor for performance (max engagement range) that can be applied due to jamming
                recoverySeconds = 30, -- seconds  
                -- recoveryScale -- Scale factor per tick (calculated from recoverySeconds)
                -- recoveryAdd -- Additive recovery per tick (calculated from recoverySeconds)

            }
            , byType = {Type1 = {} }}
}

--[[
    Key = Unit name
    Value = {active = ..., type = ...}
--]]
minitrons.jammerUnits = {}

--[[
    Key = unit name
    Value = { }
--]]
minitrons.jammedUnits = {}

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
--
--
