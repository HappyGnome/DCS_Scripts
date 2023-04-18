--#######################################################################################################
-- mission_maker_tools (PART 1)
-- Run once at mission start after initializing HeLMS
--
-- Script by HappyGnome

--doFile returns single global instance, or creates one
if mission_maker_tools then
	return mission_maker_tools
end

if not helms then return end
if helms.version < 1.8 then 
	helms.log_e.log("Invalid HeLMS version for mission_maker_tools")
end

--NAMESPACES----------------------------------------------------------------------------------------------
mission_maker_tools={}

-- MODULE OPTIONS:----------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------

--[[
Loggers for this module
--]]
mission_maker_tools.log_i=helms.logger.new("mission_maker_tools","info")
mission_maker_tools.log_e=helms.logger.new("mission_maker_tools","error")

--error handler for xpcalls. wraps mission_maker_tools.log_e.log
mission_maker_tools.catchError=function(err)
	mission_maker_tools.log_e.log(err)
end 
-----------------------------------------------------------------------------------------------------------
-- Event handlers

-----------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
-- API

mission_maker_tools.logWaypoints = function(substring, seconds, precision, includeAlt)
	local groupNames= helms.mission.getNamesContaining(substring)

	for k,v in pairs(groupNames) do
		local points = helms.mission.getMEGroupPointsByName(v)
		local prevPoint = nil
		if #points > 1 then
			local logstring = v .. ':\nWpt, Lat, Lon, Track (°T), Dist (nm), MSL (ft)'
			for i,point in pairs(points) do
				local alt = point.alt * helms.maths.m2ft
				point = helms.maths.as3D(point) 
				logstring = string.format("%s\n%d,%s",logstring ,i,helms.ui.convert.pos2LL(point,seconds, precision,','))

				if prevPoint then
					logstring = string.format("%s,%0.0f,%0.1f",logstring,helms.maths.getHeading(prevPoint, point),helms.maths.get2DDist(prevPoint, point)*helms.maths.m2nm)
				end

				if includeAlt then
					logstring = string.format("%s,%d",logstring,alt)
				end

				prevPoint = point
			end			
			mission_maker_tools.log_i.log('\n'..logstring..'\n')
		end
	end
end

--#######################################################################################################
-- mission_maker_tools (PART 2)
--
return mission_maker_tools