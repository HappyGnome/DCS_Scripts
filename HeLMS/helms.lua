--#######################################################################################################
-- HeLMS v1.0 -  Helpful Library of Mission Scripts
--
-- Common utilities for scripts by HappyGnome. Lightweight replacement for some MIST features.
--
-- Script by HappyGnome
--#######################################################################################################

--NAMESPACES---------------------------------------------------------------------------------------------- 
helms={ version = 1}

----------------------------------------------------------------------------------------------------------
--LUA EXTENSIONS------------------------------------------------------------------------------------------
-- Table manipulation etc

helms.util = {}

helms.util.safeCall = function(func,args,errorHandler)
	local op = function()
		func(unpack(args))
	end
	xpcall(op,errorHandler)
end

helms.util.obj2str = function(obj)
    if obj == nil then 
        return 'nil'
    end
	local msg = ''
	local t = type(obj)
	if t == 'table' then
		msg = msg..'{'
		for k,v in pairs(obj) do
			msg = msg..k..':'..helms.util.obj2str(v)..', '
		end
		msg = msg..'}'
	elseif t == 'string' then
		msg = msg.."\""..obj.."\""
	elseif t == 'number' or t == 'boolean' then
		msg = msg..tostring(obj)
	elseif t then
		msg = msg..t
	end
	return msg
end

--[[
Randomly remove N elements from a table and return removed elements (key,value)
--]]
helms.util.removeRandom = function(t,N)
	local ret={}
	local count=0
	
	for k in pairs(t) do
		count=count+1
	end
	
	N=math.min(N,count)
	
	local n=0
	while(n<N) do
		local toRemove=math.random(count-n)
			
		local i=0

		for k,v in pairs(t) do
			i=i+1
			if i==toRemove then
				t[k]=nil
				ret[k]=v
			end
		end
		n=n+1
	end
	
	return ret
end

--[[
Given a set s with multiplicity (key = Any, value= multiplicity)
Remove any for which pred(key)==true
Return the number removed counting multiplicity
--]]
helms.util.eraseByPredicate=function(s,pred)
	local ret=0	
	
	for k,v in pairs(s) do
		if pred(k) then
			ret=ret+v
			s[k]=nil
		end
	end
	
	return ret
end

helms.util.transposeTable=function(set)
	local ret = {}
	for k,v in pairs(set) do
		ret[v] = k
	end	
	return ret
end

helms.util.excludeValues=function(set,exc)
	local ret = {}
	local excT = helms.util.transposeTable(exc)
	for k,v in pairs(set) do
		if not excT[v] then
			ret[k] = v
		end
	end	
	return ret
end

helms.util.shallow_copy = function(obj)
	local ret = obj	
	if type(obj) == 'table' then
		ret = {}
		for k,v in pairs(obj) do
			ret[k] = v
		end
	end	
	setmetatable(ret,getmetatable(obj))
	return ret
end

--See http://lua-users.org/wiki/CopyTable
helms.util.deep_copy = function(obj)
	local copies = {}
	local function _copy(obj)
		if obj == nil or type(obj) ~= 'table' then
			return obj
		elseif copies[obj] then
			return copies[obj]
		end
		local copy = {}
		copies[obj] = copy
		for k,v in next, obj do
			copy[_copy(k)] = _copy(v)
		end
		setmetatable(copy,getmetatable(obj))
		return copy
	end
	return _copy(obj)
end

----------------------------------------------------------------------------------------------------------
--LOGGING-------------------------------------------------------------------------------------------------
helms.logger = {
	new = function (tag,eventType)
		if not env[eventType] then eventType = "error" end
		return {
			["log"] = function(obj)
				env[eventType](tag .. '|' .. helms.util.obj2str(obj), false)
			end
		}
	end
}

--[[
Loggers for this module
--]]
helms.log_i = helms.logger.new("helms","info")
helms.log_e = helms.logger.new("helms","error")

----------------------------------------------------------------------------------------------------------
--MATHS---------------------------------------------------------------------------------------------------
-- General calculation tools and conversions

helms.maths = {}

helms.maths.deg2rad = 0.01745329
helms.maths.kts2mps = 0.5144

--[[
True heading point A to point B, in degrees
--]]
helms.maths.getTrueNorthTheta = function (pointA)	
	local lat, lon = coord.LOtoLL(pointA)
	local north = coord.LLtoLO(lat + 1, lon)
	return math.atan2(north.z - pointA.z, north.x - pointA.x)
end

--[[
True heading point A to point B, in degrees
--]]
helms.maths.getHeading = function (pointA,pointB)	
	local north = helms.maths.getTrueNorthTheta(pointA) -- atan2 for true north at pointA
	local theta = (math.atan2(pointB.z-pointA.z,pointB.x-pointA.x) - north) * 57.2957795 --degrees
	local hdg = math.fmod(theta,360)
	if hdg < 0 then
		hdg = hdg + 360
	end
	return hdg	
end

helms.maths.as2D = function(u)
	local uy = u.z
	if uy == nil then uy = u.y end
	return {x = u.x, y= uy}
end

helms.maths.as3D = function(u)
	local uz = u.z
	local uy = u.y
	if uz == nil then
		uz = u.y
		uy = 0
	end
	return {x = u.x, y= uy,z = uz}
end

helms.maths.get2DDist = function(pointA, pointB) 
	local p = helms.maths.as2D(pointA)
	local q = helms.maths.as2D(pointB)
	local off = {x= p.x - q.x, y = p.y - q.y}
	return math.sqrt((off.x * off.x) + (off.y * off.y))
end

helms.maths.get3DDist = function(pointA, pointB) 
	local p = helms.maths.as3D(pointA)
	local q = helms.maths.as3D(pointB)
	local off = {x= p.x - q.x, y= p.y - q.y, z = p.z - q.z}
	return math.sqrt((off.x * off.x) + (off.y * off.y) + (off.z * off.z))
end

helms.maths.dot2D = function(u,v)
	local uy = u.z
	local vy = v.z
	if uy == nil then uy = u.y end
	if vy == nil then vy = v.y end
	return u.x*v.x + uy*vy
end

helms.maths.wedge2D = function(u,v)
	local uy = u.z
	local vy = v.z
	if uy == nil then uy = u.y end
	if vy == nil then vy = v.y end
	return u.x*vy - uy*v.x
end

helms.maths.lin2D = function(u,a,v,b)
	local uy = u.z
	local vy = v.z
	if uy == nil then uy = u.y end
	if vy == nil then vy = v.y end
	return {x = a*u.x + b*v.x, y= a*uy+b*vy}
end

--return {x,y} unit vector in direction from a to b
helms.maths.unitVector = function(A,B)
	local Ay = A.z
	local By = A.z
	if Ay == nil then Ay = A.y end
	if By == nil then By = B.y end
	local C = {x = B.x - A.x, y = By - Ay}
	local r = math.sqrt(helms.maths.dot2D(C,C))
	
	if r < 0.001 then return {x=0, y=0} end
	return {x = C.x/r, y = C.y/r}
end

--[[
Return the angle between velocity/heading X and the line from points A to B
--]]
helms.maths.thetaToDest = function (X,A,B)
	local toDest = helms.maths.lin2D(B,1,A,-1)
	return math.atan2(helms.maths.wedge2D(X,toDest),helms.maths.dot2D(X,toDest))
end

----------------------------------------------------------------------------------------------------------
--ME UTILS------------------------------------------------------------------------------------------------
-- Convert/manage data from mission file

helms.mission = {}

helms.mission.stringsToScriptTasks = function(strings)
	local tasks = {};
	for _,string in pairs(strings) do
		table.insert(tasks,
			{
				id = "WrappedAction",
				params = {
					action = {
						id = "Script",
						params = {
							command = string
						}
					}
				}
			})
	end
	return tasks;
end

--[[
	Get list of group names containing a substring
	
	substring - substring to search for
--]]
helms.mission.getNamesContaining = function(substring)
	local ret = {}
	for name,_ in pairs(helms.mission._GroupLookup) do
		if string.find(name,substring) ~= nil then
			table.insert(ret, name)
		end
	end
	return ret
end

--[[
Make random groups

param nameRoot = base group name e.g. "dread" generates "dread-1", "dread-2",...
param count = number of groups to generate
param unitDonors = array of group names specifying the unit combinations to use
param taskDonors = array of group names specifying routes/tasks to use

Return = unpacked array of groupData tables that can be passed to dynAdd to spawn a group
--]]
helms.mission.generateGroups = function(nameRoot,count,unitDonors,taskDonors)

	local groupNum =0 --index to go with name route to make group name
	local ret={}
	local logMessage="Generated groups: "
	
	while groupNum<count do
		groupNum = groupNum + 1
		
		local newGroupData = helms.mission.getMEGroupDataByName(unitDonors[math.random(#unitDonors)])
		
		--get route and task data from random task donor
		local taskDonorName=taskDonors[math.random(#taskDonors)]
		local taskDonorData = helms.mission.getMEGroupDataByName(taskDonorName)
		local taskDonorSpawnKeys = helms.mission.getKeysByName(taskDonorName)
		if taskDonorData and newGroupData then 
			local unitInFront = taskDonorData.units[1]
			newGroupData.route = taskDonorData.route
			
			newGroupData.groupName=nameRoot.."-"..groupNum
			newGroupData.groupId=nil 
			
			--null group position - get it from the route
			newGroupData.x=taskDonorData.x
			newGroupData.y=taskDonorData.y
			
			--generate unit names and null ids
			--also copy initial locations and headings
			for i,unit in pairs(newGroupData.units) do
				unit.unitName=nameRoot.."-"..groupNum.."-"..(i+1)
				unit.unitId=nil
				
				--null unit locations - force them to be set by start of route
				unit.x=taskDonorData.x
				unit.y=taskDonorData.y
				unit.alt=unitInFront.alt
				unit.alt_type=unitInFront.alt_type
				unit.heading=unitInFront.heading
			end
			
			newGroupData.lateActivation = true
			
			table.insert(ret,{data = newGroupData,keys = taskDonorSpawnKeys})
			--helms.log_i.log(taskDonorSpawnKeys)--debug
		end
	end
	
	--helms.log_i:info(logMessage)
	
	return unpack(ret)

end

helms.mission.getGroupStartPoint2D = function(groupName)
	local spawnData = helms.mission.getMEGroupDataByName(groupName)
	if spawnData and spawnData.units and spawnData.units[1] then
		return {x = spawnData.units[1].x,y=0,z = spawnData.units[1].y}
	end
end

--[[
Get units offroad max speed in mps, or default if this is not available
--]]
helms.mission.getUnitSpeed = function(unit,default)
	if unit == nil then return default end
	local unitDesc = unit:getDesc()
	
	if unitDesc ~= nil and unitDesc["speedMaxOffRoad"] ~= nil then
		return unitDesc["speedMaxOffRoad"]	
	end
	
	return default
end

--[[
Get units offroad max speed in mps, or default if this is not available
--]]
helms.mission._buildMEGroupLookup = function()
	helms.mission._GroupLookup = {}
	--helms.log_i.log(helms.util.obj2str(env.mission.coalition))--debug

	for coaK, coaV in pairs (env.mission.coalition) do
		if type(coaV) == 'table' and coaV.country then
			for ctryK, ctryV in pairs (coaV.country) do
				if type(ctryV) == 'table' then
					for catK, catV in pairs(ctryV) do
						if (catK == "helicopter" 
							or catK == "ship" 
							or catK == "plane" 
							or catK == "vehicle")
							and type(catV) == 'table'
							and catV.group 
							and type(catV.group) == 'table' then
							for gpK, gpV in pairs(catV.group) do
								if type(gpV) == 'table' and gpV.name then
									helms.mission._GroupLookup[gpV.name] = {coa = coaK, ctry = ctryK, ctryId = ctryV.id, cat = catK, gp = gpK, catEnum = helms.mission._catNameToEnum(catK)}
								end
							end							
						end
					end
				end
			end
		end
	end	
end

helms.mission._catNameToEnum = function(name)
	if name == "helicopter" then return Unit.Category["HELICOPTER"] end
	if name == "ship" then return Unit.Category["SHIP"] end
	if name == "plane" then return Unit.Category["AIRPLANE"] end
	if name == "vehicle" then return Unit.Category["GROUND_UNIT"] end
end

helms.mission.getMEGroupDataByName = function(name)
	local keys = helms.mission._GroupLookup[name]
	--helms.log_i.log(helms.util.obj2str(keys))--debug
	--helms.log_i.log(helms.util.obj2str(env.mission.coalition))--debug
	--helms.log_i.log(helms.util.obj2str(env.mission.coalition[keys.coa].country[keys.ctry][keys.cat].group[keys.gp])) --debug
	if not keys then return nil end
	return helms.util.deep_copy(env.mission.coalition[keys.coa].country[keys.ctry][keys.cat].group[keys.gp])
end

helms.mission.getMEGroupRouteByName = function(name)
	local gpData = helms.mission.getMEGroupDataByName(name)
	if not gpData then return nil end
	return gpData.route
end

helms.mission.getMEGroupPointsByName = function(name)
	local routeData = helms.mission.getMEGroupRouteByName(name)
	if not routeData then return nil end
	return routeData.points
end

helms.mission.getKeysByName = function(name)
	return helms.util.deep_copy(helms.mission._GroupLookup[name])
end

----------------------------------------------------------------------------------------------------------
--DYNAMIC-------------------------------------------------------------------------------------------------
-- E.g. spawning units, setting tasking
helms.dynamic = {}

helms.dynamic.respawnMEGroupByName = function(name, activate)
	local gpData = helms.mission.getMEGroupDataByName(name)
	if not gpData then return end
	
	local keys = helms.mission._GroupLookup[name]
	if not keys then return end
	if activate == nil or activate == true then
		gpData.lateActivation = false
	end
	coalition.addGroup(keys.ctryId, keys.catEnum, gpData)

end

-- groupData = ME format as returned by getMEGroupDataByName
-- keys = {coat,cat,gp} as returned by getKeysByName
helms.dynamic.spawnGroup = function(groupData, keys, activate)
	if not groupData then return end
	--groupData.task="Nothing"--debug
	if not keys or not keys.ctry or not keys.cat then return end
	if activate == nil or activate == true then
		groupData.lateActivation = false
	end
	coalition.addGroup(keys.ctryId, keys.catEnum, groupData)
end

--[[
Return = Boolean: Does named group have a living active unit in-play
--]]
helms.dynamic.groupHasActiveUnit=function(groupName)
	local group=Group.getByName(groupName)	
	
	if group then
		local units = Group.getUnits(group)
		if units then
			local unit=units[1]
			if unit then
				return Unit.isActive(unit)
			end
		end				
	end	
	return false
end

--[[
Find the closest player to any living unit in named group
ignores altitude - only lateral coordinates considered
@param groupName - name of the group to check
@param sides - table of coalition.side of players to check against
@param options.unitFilter - (unit)-> boolean returns true if unit should be considered
		(if this is nil then all units are considered)
@param options.pickUnit - if true, only one unit in the group will be used for the calculation
@param options.useGroupStart - if true, the group's starting waypoint will be added as an abstract unit position
@return dist,playerUnit, closestUnit OR nil,nil,nil if no players found or group empty
--]]
helms.dynamic.getClosestLateralPlayer = function(groupName,sides, options)

	local playerUnits = {}
	if options == nil or type(options) ~= 'table' then
		options = {}
	end

	if type(sides) == 'number' then
		sides = {sides}
	end
	if type(sides) == 'table' then
		for _,side in pairs(sides) do
			for _,player in pairs (coalition.getPlayers(side)) do
				table.insert(playerUnits,player)
			end
		end	
	end
	
	local ret={nil,nil,nil} --default return	
	
	local group = Group.getByName(groupName)
	local units={}
	
	if group ~= nil then 
		units = group:getUnits() 
	end
	
	
	local positions={} -- {x,z},.... Indices correspond to indices in units
	for i,unit in ipairs(units) do
		local location=unit:getPoint()
		
		if not options.unitFilter or options.unitFilter(unit) then
			positions[i]={location.x,location.z}
			if options.pickUnit then
				break
			end
		end
	end
	
	if options.useGroupStart then
		local points = helms.mission.getMEGroupPointsByName(groupName)		
		--helms.log_i:info("group points: "..#points.." for "..groupName)--debug		
		if points and points[1] then
			positions[#units + 1] = {points[1].x,points[1].y} 
		end
	end
	
	local preRet=nil --{best dist,player index,unit index}
	for i,punit in pairs(playerUnits) do
		local location=punit:getPoint()
		
		for j,pos in pairs(positions) do
			local dist2 = (pos[1]-location.x)^2 + (pos[2]-location.z)^2
			if preRet then
				if dist2<preRet[1] then
					preRet={dist2,i,j}
				end
			else --initial pairs
				preRet={dist2,i,j}
			end
		end
		
	end
	
	if preRet then
		ret = {math.sqrt(preRet[1]),playerUnits[preRet[2]],units[preRet[3]]}
	end
	--helms.log_e.log(ret)--debug
	return unpack(ret)
	
end

--[[
return (group, unit) for living unit in group of given name
--]]
helms.dynamic.getLivingUnits = function (groupName)	
	local group = Group.getByName(groupName)
	local retUnits = {}
	if group ~= nil and Group.isExist(group) then
		local units = group:getUnits()
		for i,unit in pairs(units) do
			if unit:getLife()>1.0 then
				table.insert(retUnits, unit)
			end
		end
	end
	return group,retUnits
end


--[[
return a float between 0 and 1 representing groups strength vs initial strength
--]]
helms.dynamic.getNormalisedGroupHealth = function (groupName, initialSize)	
	local group = Group.getByName(groupName)	
	
	if group ~= nil and Group.isExist(group) then
	group:getSize()
		if initialSize == nil then  initialSize = group:getSize() end
		local accum = 0.0;
		local units = group:getUnits()
		for i,unit in pairs(units) do
			accum = accum + (unit:getLife()/math.max(1.0,unit:getLife0()))
		end
		--constant_pressure_set.log_i:info("Calc:".. accum .." " .. initialSize .. " "..groupName )--TODO debug
		return accum / math.max(1.0,initialSize)
	end
	return 0.0
end

--[[
return point,name,dist (m) of nearest airbase/farp etc (not ships), checks all permanent airbases and farps from side, if given 
set friendlyOnly = true to only consider friendly bases
--]]
helms.dynamic.getNearestAirbase = function (point, side, friendlyOnly)
	local bases = helms.dynamic.getBaseList(side,friendlyOnly,false)
	local closestKey, closestDist = helms.dynamic.getKeyOfNearest2D(bases,point)
	
	if closestKey == nil then return nil, nil, nil end
	
	local closestBase = bases[closestKey]
	
	return closestBase:getPoint(),closestBase:getName(), closestDist
end

--[[
Get the key of the nearest object in objList to another given point
return key,dist
--]]
helms.dynamic.getKeyOfNearest2D = function(objList,point)
	local closestDist = math.huge
	local closestKey = nil
	for k,v in pairs(objList) do		
		if math.abs(v:getPoint().x - point.x) < closestDist then --quick filter in just one direction to cut down distance calcs
			local newDist = helms.maths.get2DDist(v:getPoint(),point)
			if newDist < closestDist then
				closestDist = newDist
				closestKey = k
			end
		end
	end
	return closestKey,closestDist
end

--[[
Return a table of airbases and farps for the coalition farpSide. If friendlyOnly then farpSide also applies to the fixed airbases returned
--]]
helms.dynamic.getBaseList = function(farpSide,friendlyOnly, shipsAsFarps)
	local basesTemp = world.getAirbases()
	local bases = {}
	
	if farpSide == nil and not friendlyOnly then
		for k,v in pairs(basesTemp) do	
			if (shipsAsFarps or not v:getUnit()) then
				table.insert(bases,v)
			end
		end
	elseif farpSide ~= nil and friendlyOnly then
	
		for k,v in pairs(basesTemp) do	
			if (shipsAsFarps or not v:getUnit()) and v:getCoalition() == farpSide then
			
				table.insert(bases,v)
			end
		end
	elseif farpSide ~= nil then
		for k,v in pairs(basesTemp) do	
			--fixed airbases only (no associated unit), and only friendly farps 
			if (shipsAsFarps or not v:getUnit()) and (v:getCoalition() == farpSide or v:getDesc().category == Airbase.Category.AIRDROME) then
				table.insert(bases,v)
			end
		end
	end
	helms.log_i.log(bases) --debug
	return bases
end

helms.dynamic.landTypeUnderUnit = function (unit)
	return land.getSurfaceType(helms.maths.as2D(unit:getPoint()))
end

helms.dynamic._scheduleFunctionWrapper = function(pack,t)
	if pack and pack.f and type(pack.f) == 'function'
		and pack.args and type(pack.args) == 'table' then
			
		local ret
		if not next(pack.args) then
			ret = pack.f()
			--helms.log_e.log("no pack"..helms.util.obj2str(pack))--debug
		else
			ret = pack.f(unpack(pack.args))
			--helms.log_e.log("pack"..helms.util.obj2str(pack))--debug
		end
		
		if not pack.once and ret and type(ret) == 'number' then 
			--helms.log_e.log({"Reschedule ",ret})
			return ret
		end
		return nil
	end
	helms.log_e.log("Invalid scheduled function parameters")
end

helms.dynamic.scheduleFunction = function(f,argPack,t, once)
	if not argPack then argPack = {} end
	timer.scheduleFunction(helms.dynamic._scheduleFunctionWrapper, {f = f, args = argPack, once = once},t)
end

----------------------------------------------------------------------------------------------------------
--UI------------------------------------------------------------------------------------------------------
-- E.g. messages to users, comms management, string conversions etc.

helms.ui = {}

--[[
Print message to the given coalition.side, or to all players if side==nil
--]]
helms.ui.messageForCoalitionOrAll = function(side,message,delay)
	if side then
		trigger.action.outTextForCoalition(side,message,delay)
	else
		trigger.action.outText(message,5)
	end
end

-- String conversions-------------------------------------------------------------------------------------
helms.ui.convert = {}

helms.ui.convert.stringToSide = function(name)
	name=string.lower(name) --remove case sensitivity
	if name == "red" then
		return coalition.side.RED
	elseif name == "blue" then
		return coalition.side.BLUE
	elseif name == "neutral" then
		return coalition.side.NEUTRAL
	end--else nil
end

--[[
Convert coalition to "Red", "Blue", "Neutral", or "None"
--]]
helms.ui.convert.sideToString = function(side)
	if side == coalition.side.RED then
		return "Red"
	elseif side == coalition.side.BLUE then
		return "Blue"
	elseif side == coalition.side.NEUTRAL then
		return "Neutral"
	else
		return "None"
	end
end

helms.ui.convert.getNowString = function()
    local dhms = helms.ui.convert.getDHMS(timer.getAbsTime())
	return string.format("%02d%02dL",dhms["h"],dhms["m"])
end

helms.ui.convert.getDHMS = function(seconds)
	if seconds then
		return {d = math.floor(seconds/86400),h = seconds % 86400, m = seconds % 3600, s = seconds % 60}
	end
end
--[[
	Format decimal angle in tegrees to deg, decimal minutes format
--]]
helms.ui.convert.formatDegMinDec = function(degrees,posPrefix,negPrefix)
	local prefix = posPrefix
	if(degrees < 0) then prefix = negPrefix end
	degrees = math.abs(degrees)
	local whole = math.floor(degrees)
	local minutes = 60 *(degrees - whole)
	
	return string.format("%s %d°%.2f'",prefix,whole,minutes)
end

helms.ui.convert.pos2LL = function(pos)
	local lat,lon,_ = coord.LOtoLL(pos)
	return string.format("%s %s",helms.ui.convert.formatDegMinDec(lat,"N","S"),helms.ui.convert.formatDegMinDec(lon,"E","W"))
end

--[[
	positive int to "base 26" conversion
--]]
helms.ui.convert.toAlpha = function(n)
	local lookup = {"A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"}
	local ret = ""
	while (n > 0) do
		local digit = n%26
		if digit == 0 then
			digit = 26
		end
		ret = lookup[digit]..ret
		n = (n-digit)/26
	end
	return ret
end





--[[
convert heading to octant string e.g. "North", "Northeast" etc
hdg must be in the range  0 -360
--]]
helms.ui.convert.hdg2Octant = function (hdg)
	local ret = "North"	
	if hdg >= 22.5 then
		if hdg < 67.5 then
			ret = "Northeast"	
		elseif hdg < 112.5 then
			ret = "East"
		elseif hdg < 157.5 then
			ret = "Southeast"
		elseif hdg < 202.5 then
			ret = "South"
		elseif hdg < 247.5 then
			ret = "Southwest"
		elseif hdg < 292.5 then
			ret = "West"
		elseif hdg < 337.5 then
			ret = "Northwest"
		end
	end
	return ret
end




--[[
Describe point relative to airbase e.g. "8Km Northeast of Kutaisi"
side determines whether only one set of bases are used for reference points
--]]
helms.ui.convert.MakeAbToPointDescriptor = function (point, side)
	local abPoint,abName,meters = helms.dynamic.getNearestAirbase(point,side)
	if not abPoint then return "??" end
	return string.format("%s of %s",helms.ui.convert.MakePointToPointDescriptor(abPoint,point),abName)
end

--[[
Describe point b from point a with distance and octant e.g. "8km South"
distance defaults to true. Indicates whether to include distance info
--]]
helms.ui.convert.MakePointToPointDescriptor = function (pointA, pointB, distance)
	local octant = helms.ui.convert.hdg2Octant(helms.maths.getHeading(pointA,pointB))
	if distance or distance == nil then
		local meters = helms.maths.get2DDist(pointA,pointB)
		if meters >= 10000 then 
			return string.format("%.0fkm %s",meters/1000,octant)
		elseif meters >= 1000 then
			return string.format("%.1fkm %s",meters/1000,octant)
		else
			return string.format("%.0fm %s",meters,octant)
		end
	else
		return string.format("%s",octant)
	end
end


--[[
return ETA for following a straight path between two points at a given estimated speed
--]]
helms.ui.convert.getETAString = function (point1,point2, estMps)	
	if estMps == nil or estMps <= 0 then return "unknown" end
	
	local ttg = helms.maths.get3DDist(point1,point2)/ estMps
	local etaAbs = timer.getAbsTime() + ttg	
	local dhms = helms.ui.convert.getDHMS(etaAbs)
	return string.format("%02d%02dL",dhms["h"],dhms["m"])
end
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------

helms.mission._buildMEGroupLookup()

helms.log_i.log("HeLMS v"..helms.version.." loaded")