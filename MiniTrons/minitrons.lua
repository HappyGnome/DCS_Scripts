
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
minitrons.rep_rcs = 10 -- m^2 representa
----------------------------------------------------------------------------------------------------------

--[[
    Key = Jammer name
    Value = Jammer config options
--]]
minitrons.jammerType = { Type1 = {nose = {gimbal = 60, effPwr = 10}, tail = { gimbal = 60, effPwr = 10} }}

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
                recoveryPerSecond = 10, -- pct per second  
                effPwr = 10000    -- effective power:  Watts, power x antenna gain
            }
            , typeFilterCoeff =
            {
                Type1 =  1 -- x => every watt of jamming masks x watts of reflected signal.
            }
            --, finalTypeCoeff = {Type1 = ...}
    }
}


--------------------------------------------------------------------------------------------------------
-- Precompute config

minitrons.preComputeCoeffs = function()

    local minFilterCoeff = 1e-12
    local rcsCoeff = (minitrons.rep_rcs / (4 * math.pi))

    -- detection range ^ 2 = jammer range * sqrt( rcsCoeff * effPwrTx / (effPwrJm * filterCoeff))
    -- Coeff should also convert this into a proportion of the SAM max range
    -- Get max jamming effect per tick on each transmitter
    -- Linearly reduce jamming effect per tick, take max of reducced effect and new effect this tick
    
end

--------------------------------------------------------------------------------------------------------


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
