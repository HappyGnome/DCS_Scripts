
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

weatherman.parseMarkCommand = function(text,pos,side,idx)
    local regex = "^" .. weatherman.mark_prefix .. "%s*(%w+)"
	local mtchAt,_,name = string.find(text,regex)

    --weatherman.log_i.log({text,regex,name})

    if mtchAt == nil then return end
	
    if (weatherman.stations[side] == nil) then weatherman.stations[side] = {} end

	if name == nil then
		name = #weatherman.stations[side] + 1
	end
	
    weatherman.addStation(name,pos,side,idx)
    
end

weatherman.onMarkDel = function(idx,side)
    weatherman.deleteStation_ (side,idx)
end


weatherman.eventHandler = { 
	onEvent = function(self,event)
--		if(event.id == world.event.S_EVENT_MARK_ADDED) then
--			helms.util.safeCall(weatherman.parseMarkCommand, {event.text, event.pos, event.coalition},weatherman.catchError)
		if (event.id == world.event.S_EVENT_MARK_REMOVED) then
		    helms.util.safeCall(weatherman.onMarkDel, {event.idx, event.coalition},weatherman.catchError)
        elseif (event.id == world.event.S_EVENT_MARK_CHANGE) then
			helms.util.safeCall(weatherman.parseMarkCommand, {event.text, event.pos, event.coalition,event.idx},weatherman.catchError)
        end
	end
}
world.addEventHandler(weatherman.eventHandler)

----------------------------------------------------------------------------------------------------
weatherman.deleteStation_ = function(side,idx)
    if (weatherman.stations[side] == nil) then weatherman.stations[side] = {} end
    weatherman.clearStationComms_(side,idx)
    weatherman.stations[side][idx] = nil
end

weatherman.addStation = function (name,pos,side,idx)
    if (weatherman.stations[side] == nil) then weatherman.stations[side] = {} end

    local tbl = weatherman.stations[side]

    if tbl[idx] then
        weatherman.deleteStation_ (side,idx)
    end

    tbl[idx] =
    {
        pos = pos,
        name = name,
        commsMenuItems = {},
        commsMenuRoot = nil
    }

    weatherman.initComms_(side,idx)
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

weatherman.getStation_=function(side,idx)
    local stations = weatherman.stations[side]
    if stations == nil then 
        weatherman.log_e.log({"Stations not initialized",side})
        return nil
    end

    local station = stations[idx]
    if station == nil then 

        weatherman.log_e.log({"Station not initialized",idx})
        return nil
    end

    return station
end

weatherman.clearStationComms_ = function(side, idx)
    local station= weatherman.getStation_(side, idx)
    if station ==nil then return nil end

    helms.ui.removeItem(station.commsMenuRoot)
end

weatherman.createStationComms_ = function(side, idx)

    local parent = weatherman.commRoots[side]
    if parent == nil then
        weatherman.log_e.log({"No comms root for side",side})
        return nil
    end

    local station= weatherman.getStation_(side, idx)
    if station ==nil then return nil end


    station.commsMenuItems = {}

    weatherman.addFLCommStructureHun_(station,side,idx)

    station.commsMenuItems["surface"] = helms.ui.addCommand(station.commsMenuRoot, "Surface",helms.util.safeCallWrap(weatherman.surface_, weatherman.catchError),side,idx)
end

weatherman.addFLCommStructureHun_ = function(station,side,idx)
    
    local ls = {1,2,3,4,5,6,0}

    for _,i in ipairs (ls) do
       local parent = helms.ui.ensureSubmenu(station.commsMenuRoot,"FL" .. i .."__")
       table.insert(station.commsMenuItems,parent)
       weatherman.addFLCommStructureTen_(station,side,idx,parent,"FL"..i,i*100) 
    end
end
weatherman.addFLCommStructureTen_ = function(station,side,idx, parent,prefix,alt)

    local ls = {1,2,3,4,5,6,7,8,9,0}
    for _,i in ipairs (ls) do
        local parent0 = helms.ui.ensureSubmenu(parent,prefix .. i.."_")
       -- table.insert(station.commsMenuItems,parent0)
        weatherman.addFLCommStructureUnit_(station,side,idx,parent0,prefix..i,alt + i*10) 
    end
end
weatherman.addFLCommStructureUnit_ = function(station,side,idx,parent,prefix,alt)

    local ls = {1,2,3,4,5,6,7,8,9,0}
    for _,i in ipairs (ls) do
        local optName = prefix .. i
        station.commsMenuItems [optName] = helms.ui.addCommand(parent, optName,helms.util.safeCallWrap(weatherman.weatherAloft_,weatherman.catchError),side,idx,alt + i)

    end
end

weatherman.initComms_ = function(side, idx)
    weatherman.clearStationComms_(side,idx)
    weatherman.ensureStationCommsRoot_(side,idx)
    weatherman.createStationComms_(side,idx)			
end
		
weatherman.ensureStationCommsRoot_ = function(side, idx)

    local station= weatherman.getStation_(side, idx)
    if station ==nil then return nil end

    if station.commsMenuRoot == nil then
        local parent = weatherman.ensureCoalitionSubmenu_(side)
        station.commsMenuRoot =  helms.ui.ensureSubmenu(parent,"Station: " .. station.name)
    end
end
		
--weatherman.removeComms_ = function(self)
--    if self.commsMenuRoot ~= nil then
--        --remove menu options
--        helms.ui.removeItem(self.commsMenuRoot)
--        self.commsMenuRoot = nil
--    end
--end

weatherman.surface_ = function(side,idx)
    local station = weatherman.getStation_(side,idx)
       
    if station == nil then return nil end

    weatherman.doReport_(side,idx,(land.getHeight(helms.maths.as2D(station.pos))+1)*helms.maths.m2ft,"Surface")
end

weatherman.weatherAloft_ = function(side,idx,alt)

    weatherman.doReport_(side,idx,alt*100,(alt*100) .. "ft")
end

weatherman.doReport_ = function(side,idx,alt, altName)
    weatherman.log_i.log(string.format("Creating report for %d,%s,%d,%s", side,idx,alt,altName ))

    local station = weatherman.getStation_(side,idx)
       
    if station == nil then return nil end

    local name = station.name

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
