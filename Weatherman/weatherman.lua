
--#######################################################################################################
-- WEATHERMAN 
-- Run once at mission start after initializing HeLMS
-- 
-- Adds helper functionality for getting the weather at points
--
-- Script by HappyGnome

--#######################################################################################################
-- WEATHERMAN 

if not helms then return end
if helms.version < 1.16 then 
	helms.log_e.log("Invalid HeLMS version for Weatherman")
end

weatherman = {}

-- MODULE OPTIONS:----------------------------------------------------------------------------------------
weatherman.report_display_time = 20
weatherman.mark_prefix = ":wm:"
weatherman.marks_enable = true -- Idea: Add non-mark mode (e.g. create points in mission editor only)
-- Ideas: Add METARS? Tie reports to the existence of a unit/side of a base? Periodic updates? Comms menu options to repeat info?
----------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------

--[[
Loggers for this module
--]]
weatherman.log_i=helms.logger.new("weatherman","info")
weatherman.log_e=helms.logger.new("weatherman","error")

--error handler for xpcalls. wraps weatherman.log_e:error
weatherman.catchError=function(err)
	weatherman.log_e.log(err)
end 

----------------------------------------------------------------------------------------------------

weatherman.stations = {}
weatherman.commRoots = {}


--EVENT HANDLER-------------------------------------------------------------------------------------

weatherman.parseMarkCommand = function(text,pos,side)
    local regex = weatherman.mark_prefix .. "(%w+)"
	_,_,name = string.find(text,regex)
	
    if (weatherman.stations[side] == nil) then weatherman.stations[side] = {} end

	if name == nil then
		name = #weatherman.stations[side] + 1
	end
	
    weatherman.addStation(name,pos,side)
    
end

weatherman.onMarkDel = function(markIdx)
    --TODO    
end


weatherman.eventHandler = { 
	onEvent = function(self,event)
		if(event.id == world.event.S_EVENT_MARK_ADDED) then
			helms.util.safeCall(weatherman.parseMarkCommand, {event.text, event.pos, event.coalition},weatherman.catchError)
		elseif (event.id == world.event.S_EVENT_MARK_REMOVED) then
		    helms.util.safeCall(weatherman.onMarkDel, {event.idx},weatherman.catchError)
--        elseif (event.id == world.event.S_EVENT_MARK_CHANGE) then
--			helms.util.safeCall(weatherman.parseMarkCommand, {event.text, event.pos, event.coalition},weatherman.catchError)
        end
	end
}
world.addEventHandler(weatherman.eventHandler)

----------------------------------------------------------------------------------------------------

weatherman.addStation = function (name,pos,side)
    if (weatherman.stations[side] == nil) then weatherman.stations[side] = {} end

    local tbl = weatherman.stations[side]

    tbl[name] =
    {
        pos = pos,
        commsMenuItems = {},
        commsMenuRoot = nil
    }

    weatherman.initComms_(side,name)
end

--[[
Add comms submenu for red or blue (side == instance of coalition.side)
--]]
weatherman.ensureCoalitionSubmenu_=function(side)
	local menuName, _, subMenuAdded = helms.ui.ensureSubmenu(side,"Weatherman")

	if subMenuAdded then
		helms.ui.addCommand(menuName, "Help", weatherman.help,side)
	end

    weatherman.commRoots[side] = menuName

	return menuName	

end

weatherman.help = function(side)
	local text = "WEATHERMAN HELP: Add Mark to the F10 map with text starting \"" .. weatherman.mark_prefix .. "\" to add a station."
	trigger.action.outTextForCoalition(side,text,10)
end

weatherman.getStation_=function(side,name)
    local stations = weatherman.stations[side]
    if stations == nil then 
        weatherman.log_e.log({"Stations not initialized",side})
        return nil
    end

    local station = stations[name]
    if station == nil then 

        weatherman.log_e.log({"Station not initialized",name})
        return nil
    end

    return station
end
		
weatherman.createStationComms_ = function(side, name)

    local parent = weatherman.commRoots[side]
    if parent == nil then
        weatherman.log_e.log({"No comms root for side",side})
        return nil
    end

    local station= weatherman.getStation_(side, name)
    if station ==nil then return nil end

    for k,v in pairs(station.commsMenuItems) do
        helms.ui.removeItem(station.commsMenuRoot,v)
    end

    station.commsMenuItems = 
    {	
        surface = helms.ui.addCommand(station.commsMenuRoot, "Surface",helms.util.safeCallWrap(weatherman.surface_, weatherman.catchError),side,name),
    }

    weatherman.addFLCommStructureHun_(station,side,name)
end

weatherman.addFLCommStructureHun_ = function(station,side,name)
    for i = 0,9 do
       local parent = helms.ui.ensureSubmenu(station.commsMenuRoot,"FL" .. i .."__")
       weatherman.addFLCommStructureTen_(station,side,name,parent,"FL"..i,i*100) 
    end
end
weatherman.addFLCommStructureTen_ = function(station,side,name, parent,prefix,alt)

    for i = 0,9 do
        local parent0 = helms.ui.ensureSubmenu(parent,prefix .. i.."_")
        weatherman.addFLCommStructureUnit_(station,side,name,parent0,prefix..i,alt + i*10) 
    end
end
weatherman.addFLCommStructureUnit_ = function(station,side,name,parent,prefix,alt)

    for i = 0,9 do
        local optName = prefix .. i
        station.commsMenuItems [optName] = helms.ui.addCommand(parent, optName,helms.util.safeCallWrap(weatherman.weatherAloft_,weatherman.catchError),side,name,alt + i)

    end
end

weatherman.initComms_ = function(side, name)
    weatherman.ensureStationCommsRoot_(side,name)
    weatherman.createStationComms_(side,name)			
end
		
weatherman.ensureStationCommsRoot_ = function(side, name)

    local station= weatherman.getStation_(side, name)
    if station ==nil then return nil end

    if station.commsMenuRoot == nil then
        local parent = weatherman.ensureCoalitionSubmenu_(side)
        station.commsMenuRoot =  helms.ui.ensureSubmenu(parent,"Station: " .. name)
    end
end
		
--weatherman.removeComms_ = function(self)
--    if self.commsMenuRoot ~= nil then
--        --remove menu options
--        helms.ui.removeItem(self.commsMenuRoot)
--        self.commsMenuRoot = nil
--    end
--end

weatherman.surface_ = function(side,name)
    local station = weatherman.getStation_(side,name)
       
    if station == nil then return nil end

    weatherman.doReport_(side,name,(land.getHeight(helms.maths.as2D(station.pos))+1)*helms.maths.m2ft,"Surface")
end

weatherman.weatherAloft_ = function(side,name,alt)

    weatherman.doReport_(side,name,alt*100,(alt*100) .. "ft")
end

weatherman.doReport_ = function(side,name,alt, altName)
    weatherman.log_i.log(string.format("Creating report for %d,%s,%d,%s", side,name,alt,altName ))

    local station = weatherman.getStation_(side,name)
       
    if station == nil then return nil end

    local point = helms.maths.as3D (station.pos) 
    point.y = alt / helms.maths.m2ft

    local pointMSL = helms.maths.as3D (station.pos) 
    pointMSL.y = 0

    local T, P1 = atmosphere.getTemperatureAndPressure(point) -- Kelvin,Pascal
    local T0, P0 = atmosphere.getTemperatureAndPressure(pointMSL) -- Kelvin,Pascal

    local windVec = atmosphere.getWind(point) -- Mps

    local celc = T + helms.maths.kelvin2celcius
    local qnh = helms.maths.round( helms.maths.pascal2hectopascal * P0)

    weatherman.log_i.log({"WindVec", windVec, point}) -- TODO
    weatherman.log_i.log({"P0", P0}) -- TODO
    weatherman.log_i.log({"P1", P1}) -- TODO
    local windTrue = helms.maths.getHeading(windVec,helms.maths.zero3)
    local windSpeed = helms.maths.get2DDist(helms.maths.zero2,windVec) / helms.maths.kts2mps

-- helms.maths.kts2mps

    weatherman.log_i.log({timer.getAbsTime(),helms.ui.convert.getNowString()}) -- TODO
    local message = string.format("__ STATION %s weather at time %s __","" .. name, helms.ui.convert.getNowString())

--    message = message..string.format("\nLat:")
--    message = message..string.format("\nLon:")
    message = message..string.format("\nQNH: %dhPa",qnh)
    message = message..string.format("\nWinds @%s: %d/%dT",altName, windSpeed,windTrue)
    message = message..string.format("\nTemp @%s: %dC",altName, celc)

    trigger.action.outTextForCoalition(side,message,weatherman.report_display_time)
end
		

return weatherman
