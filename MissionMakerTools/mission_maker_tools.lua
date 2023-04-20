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

mission_maker_tools.logWaypoints = function(substring, seconds, precision, includeAlt, sep, prefix,suffix)
	if not sep then sep =',' end
	if not prefix then prefix ='' end
	if not suffix then suffix ='' end

	local groupNames= helms.mission.getNamesContaining(substring)

	for k,v in pairs(groupNames) do
		local points = helms.mission.getMEGroupPointsByName(v)
		local prevPoint = nil
		if #points > 1 then
			local logstring = v .. ':\nWpt, Lat, Lon, Track (°T), Dist (nm), MSL (ft)'
			for i,point in pairs(points) do
				local alt = point.alt * helms.maths.m2ft
				point = helms.maths.as3D(point) 
				logstring = string.format("%s\n%s%d%s%s",logstring ,prefix,i,sep,helms.ui.convert.pos2LL(point,seconds, precision,sep))

				if prevPoint then
					logstring = string.format("%s%s%0.0f%s%0.1f",logstring,sep,helms.maths.getHeading(prevPoint, point),sep,helms.maths.get2DDist(prevPoint, point)*helms.maths.m2nm)
				end

				if includeAlt then
					logstring = string.format("%s%s%d",logstring,sep,alt)
				end
				logstring = string.format("%s%s",logstring,suffix)
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