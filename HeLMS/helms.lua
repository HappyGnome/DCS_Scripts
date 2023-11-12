--#######################################################################################################
-- HeLMS v1.0 -  Helpful Library of Mission Scripts
--
-- Common utilities for scripts by HappyGnome. Lightweight replacement for some MIST features.
--
-- Script by HappyGnome
--#######################################################################################################

--NAMESPACES---------------------------------------------------------------------------------------------- 
helms={ version = 1.9}

----------------------------------------------------------------------------------------------------------
--LUA EXTENSIONS------------------------------------------------------------------------------------------
-- Table manipulation etc

helms.util = {}

helms.util.safeCall = function(func,args,errorHandler)
	--helms.log_i.log("sc1")
	local op = function()
		--helms.log_i.log(args)
		return func(unpack(args))
	end
	local ok,result = xpcall(op,errorHandler)
	--helms.log_i.log(result)
	return result
end

helms.util.safeCallWrap = function(func,errorHandler)
	return function(...) return helms.util.safeCall(func,arg,errorHandler) end
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
If predicate(k, v) is specified, only entries satisfying the predicate are returned
--]]
helms.util.removeRandom = function(t,N, predicate)
	local ret={}
	local count=0
	local s ={}
	for k, v in pairs(t) do
		if predicate == nil or predicate(k,v) == true then
			count=count+1
			s[k] = v
		end
	end
	
	N=math.min(N,count)
	
	local n=0
	while(n<N) do
		local toRemove=math.random(count-n)
			
		local i=0

		for k,v in pairs(s) do
			i=i+1
			if i==toRemove then
				t[k]=nil
				s[k] = nil
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

-- return a unpacked then b unpacked. (Avoids the issue {unpack(a),unpack(b)}=={a[1],unpack(b)})
helms.util.multiunpack = function(...)
	local ret = {}
	for k,v in pairs{...} do
		for i,w in ipairs(v) do
			ret[#ret+1] = w
		end
	end
	return unpack(ret)
end

helms.util.hexToRgba = function(hexStr)
	local rawNum = tonumber(hexStr)

	local res = {[1]=0.0,[2]=0.0,[3]=0.0,[4]=1.0}

	if rawNum == nil then 
		return res 
	end
	res[4] = (rawNum % 256)/256.0
	rawNum = rawNum / 256
	res[3] = (rawNum % 256)/256.0
	rawNum = rawNum / 256
	res[2] = (rawNum % 256)/256.0
	rawNum = rawNum / 256
	res[1] = (rawNum % 256)/256.0
	return res
end

helms.util.reverse = function(tbl)
	local res = {}

	for i,v in ipairs(tbl) do
		res[#tbl - i + 1] = v
	end
	
	return res
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

--error handler for xpcalls. wraps helms.log_e.log
helms.catchError=function(err)
	helms.log_e.log(err)
end 

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

helms.maths.applyMat2D = function(u,M)
	local v = {}
	v.x = helms.maths.dot2D(u,M[1])
	v.y = helms.maths.dot2D(u,M[2])
	return v
end

helms.maths.makeRotMat2D = function(theta)
	local M = {{},{}}
	M[1] = {x = math.cos(theta), y = -math.sin(theta)}
	M[2] = {x = math.sin(theta), y = math.cos(theta)}
	return M
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

helms.maths.lin3D = function(u,a,v,b)
	local U= helms.maths.as3D(u)
	local V= helms.maths.as3D(v)
	return {x = a*U.x + b*V.x, y= a*U.y+b*V.y, z= a*U.z+b*V.z}
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

helms.maths.randomInCircle = function (r,centre)
	centre = helms.maths.as2D(centre)

	local theta = math.random() * 2 * math.pi
	r = r * math.sqrt(math.random())

	return { x = centre.x + math.cos(theta) * r, y = centre.y + math.sin(theta) * r}
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

helms.mission.getNamesContainingUpk = function(substring)
	return unpack(helms.mission.getNamesContaining(substring))
end
--[[
	Return true if group activation is pending
--]]
helms.mission.groupAwaitingActivation = function(name)

	local group=helms.dynamic.getGroupByName(name)
	if not group or not group:isExist() then return false end -- group not spawned, or destroyed implies not awaiting activation

	local units = Group.getUnits(group)
	if units then
		local unit=units[1]
		if unit then
			return not Unit.isActive(unit)
		end
	end	
	return false -- no existing units
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
			
			newGroupData.name = nameRoot.."-"..groupNum
			newGroupData.groupId = nil 
			
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
									helms.mission._GroupLookup[gpV.name] = {coa = coaK, ctry = ctryK, ctryId = ctryV.id, cat = catK, gp = gpK, catEnum = helms.mission._catNameToEnum(catK), startPoint = {x = gpV.x, y = gpV.y}}
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

helms.mission.getMEGroupNamesInZone = function(zoneName, coalition)

	local ret = {}
	local zone = trigger.misc.getZone(zoneName)

	if zone == nil then return ret end

	local centre = {x = zone.point.x, y = zone.point.z}
	local radius = zone.radius

	local quickBounds = {xMax = centre.x + radius, xMin = centre.x - radius, yMax = centre.y + radius, yMin = centre.y - radius}

	if coalition ~= nil then
		coalition = string.lower(coalition)
	end

	for name,gpData in pairs(helms.mission._GroupLookup) do
		if  (gpData.coa == coalition or coalition == nil) and
			gpData.startPoint.x >= quickBounds.xMin and
			gpData.startPoint.x <= quickBounds.xMax and
			gpData.startPoint.y >= quickBounds.yMin and
			gpData.startPoint.y <= quickBounds.yMax and
			helms.maths.get2DDist(centre,gpData.startPoint) <= radius then

			ret[#ret + 1] = name

		end
	end

	return ret
end

helms.mission.getMEGroupSize = function(name)
	local keys = helms.mission._GroupLookup[name]
	if not keys then return nil end
	local gp = env.mission.coalition[keys.coa].country[keys.ctry][keys.cat].group[keys.gp]
	if gp == nil then return 0 end	
	return #gp.units
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

--[[
	Get list of drawing names containing a substring
	
	substring - substring to search for
--]]
helms.mission.getDrawingNamesContaining = function(substring)
	local ret = {}
	for name,_ in pairs(helms.mission._getDrawingList) do
		if string.find(name,substring) ~= nil then
			table.insert(ret, name)
		end
	end
	return ret
end

helms.mission._drawingSideKeys = { ['Common'] = -1, ['Neutral'] = 0, ['Blue'] = 2, ['Red'] = 1 }
helms.mission._meDrawingList = nil

helms.mission._getDrawingList = function()
	if helms.mission._meDrawingList == nil then
		helms.mission._meDrawingList = helms.mission._buildDrawingList()
	end
	return helms.mission._meDrawingList
end

helms.mission._buildDrawingList = function()
	local drawings = {} -- key = name, value = {shapeId,coalition,colour, fillColour, lineType, points}

	if env.mission.drawings == nil or env.mission.drawings.layers == nil then 
		return drawings
	end

	for layerKey,layer in pairs(env.mission.drawings.layers) do
		local side = helms.mission._drawingSideKeys[layer.name] -- nil for author
		
		if layer.objects ~= nil then
			for objKey,obj in pairs(layer.objects) do
				local drawing = nil

				if obj.primitiveType == "Line" then
					drawing = helms.mission._convertMeDrawingLine(obj)
				elseif obj.primitiveType == "Polygon" then
					if obj.polygonMode == 'circle'then
						drawing = helms.mission._convertMeDrawingCircle(obj)
					elseif obj.polygonMode == 'oval' then
						drawing = helms.mission._convertMeDrawingOval(obj)
					else
						drawing = helms.mission._convertMeDrawingPoly(obj)
					end
				elseif obj.primitiveType == "TextBox" then
					drawing = helms.mission._convertMeDrawingText(obj)
				end

				if drawing ~=nil then
					drawing.colour = helms.util.hexToRgba(obj.colorString)
					drawing.fillColour = helms.util.hexToRgba(obj.fillColorString)
					drawing.coalition = side

					drawing.lineType = 1 -- Line types don't match between ME and scripting
										-- for now, make this binary simplification
					if obj.thickness == 0 then
						drawing.lineType = 0
					end

					drawings[obj.name] = drawing
				end
			end
		end
	end

	return drawings
end

helms.mission._convertMeDrawingLine = function(meDrawing)
	local basePoint = helms.maths.as3D({x = meDrawing.mapX, y= meDrawing.mapY})
	local points = {}
	local ret = {shapeId = 1, points = points}

	if meDrawing.points == nil or #meDrawing.points<1 then
		return ret
	end

	for i = 1, #meDrawing.points do
		points[#points + 1] = helms.maths.lin3D(basePoint,1,meDrawing.points[i],1)
	end

	if meDrawing.closed == true then
		points[#points + 1] = points[1]
	end

	ret.points = points
	return ret
end

helms.mission._convertMeDrawingPoly = function(meDrawing)
	local basePoint = helms.maths.as3D({x = meDrawing.mapX, y= meDrawing.mapY})
	local points = {}
	local ret = {shapeId = 7, points = points}

	-- Rect
	if meDrawing.polygonMode == 'rect' then

		local wBy2 = meDrawing.width/2
		local hBy2 = meDrawing.height/2
		points[1] = {x = -wBy2, y = -hBy2}
		points[2] = {x = wBy2, y = -hBy2}
		points[3] = {x = wBy2, y = hBy2}
		points[4] = {x = -wBy2, y = hBy2}
	else --Free, arrow etc
		if meDrawing.points == nil or #meDrawing.points<1 then
			return nil
		end

		for i = 1, #meDrawing.points do
			points[i] = meDrawing.points[i]
		end
	end

	local theta = 0
	if meDrawing.angle ~= nil then
		theta = meDrawing.angle * helms.maths.deg2rad
	end
	local M = helms.maths.makeRotMat2D(theta)
	for i = 1, #points do
		points[i] = helms.maths.lin3D(basePoint,1,helms.maths.applyMat2D(points[i],M),1)
	end

	ret.points = points
	return ret
end

helms.mission._convertMeDrawingCircle = function(meDrawing)
	local basePoint = helms.maths.as3D({x = meDrawing.mapX, y= meDrawing.mapY})
	local points = {basePoint}
	local ret = {shapeId = 2,  points = points}

	ret.shapeId = 2
	ret.radius = meDrawing.radius
	return ret
end

helms.mission._convertMeDrawingOval = function(meDrawing)
	local basePoint = helms.maths.as3D({x = meDrawing.mapX, y= meDrawing.mapY})
	local points = {basePoint }
	local ret = {shapeId = 2, startPos = basePoint, points = points}

	ret.shapeId = 2
	ret.radius = ( meDrawing.r1 + meDrawing.r1 )/2

	return ret
end

helms.mission._convertMeDrawingText = function(meDrawing)
	local basePoint = helms.maths.as3D({x = meDrawing.mapX, y= meDrawing.mapY})
	local ret = {shapeId = 5, points = {basePoint}, text = meDrawing.text, fontSize = meDrawing.fontSize}
	return ret
end
----------------------------------------------------------------------------------------------------------
--DYNAMIC-------------------------------------------------------------------------------------------------
-- E.g. spawning units, setting tasking
helms.dynamic = {
	groupNameMap = {}, -- key = ME group name/ group name in spawn data, value = Name to use to spawn/respawn group
	groupNameMapReverse = {} --reverse lookup for groupNameMap
}

helms.dynamic.getGroupByName = function(name)
	local group = Group.getByName(name)	
	if group ~= nil then return group end
	return Group.getByName(helms.dynamic.getGroupAlias(name))
end

helms.dynamic.createGroupAlias = function(meGroupName, aliasRoot)
	local index = 0
	if meGroupName == aliasRoot then return end
	while true do
		local name = aliasRoot
		if index > 0 then name = name .. "-" .. index end
		if helms.mission._GroupLookup[name] == nil and helms.dynamic.groupNameMapReverse[name] == nil and Group.getByName(name) == nil then
			helms.dynamic.groupNameMap[meGroupName] = name
			helms.dynamic.groupNameMapReverse[name] = meGroupName
			break
		end
		index = index + 1
	end
end

helms.dynamic.getGroupAlias = function(meGroupName)
	local name = helms.dynamic.groupNameMap[meGroupName]
	if name == nil then
		return meGroupName
	end
	return name
end

helms.dynamic.normalizeUnitNames = function(gpData)
	if not gpData or not gpData.units or not gpData.name then return end
	local gpName = gpData.name
	local index = 1
	for _,u in ipairs(gpData.units) do
		
		while true do
			local name = gpName .. "-" .. index
			index = index + 1
			local unit = Unit.getByName(name)
			if unit == nil or unit:getGroup():getName() == gpName then
				u.name = name
				break
			end			
		end
	end
end

helms.dynamic.despawnGroupByName = function(groupName)
	local group = helms.dynamic.getGroupByName(groupName)
	--helms.log_i.log("Deleting " .. groupName) --Debug
	if group then
		group:destroy()
	end
end

helms.dynamic.allUnitPredicate = function(groupName, func)
	local group = helms.dynamic.getGroupByName(groupName)
	if group ==nil then return true end
	
	local units = Group.getUnits(group)
	if units == nil then return true end

	for k,v in pairs(units) do
		if not func(v) then return false end
	end
	return true
end

helms.dynamic.respawnMEGroupByName = function(name, activate)
	local gpData = helms.mission.getMEGroupDataByName(name)
	if not gpData then return end

	local keys = helms.mission._GroupLookup[name]
	if not keys then return end
	if activate == nil or activate == true then
		gpData.lateActivation = false
	end

	local alias = helms.dynamic.groupNameMap[name]
	if alias ~= nil then
		local existingGp = Group.getByName(name)
		if existingGp ~= nil then
			existingGp:destroy()
		end
		gpData.name = alias
	end
	helms.dynamic.normalizeUnitNames(gpData)
	coalition.addGroup(keys.ctryId, keys.catEnum, gpData)
end

helms.dynamic.respawnMEGroupsInZone = function(zoneName, activate, coalition)
	local names = helms.mission.getMEGroupNamesInZone(zoneName, coalition)
	if not names or #names == 0 then return end

	for k,name in pairs(names) do
		helms.dynamic.respawnMEGroupByName(name,activate)
	end
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

	local alias = helms.dynamic.groupNameMap[groupData.name]
	if alias ~= nil then
		local existingGp = Group.getByName(groupData.name)
		if existingGp ~= nil then
			existingGp:destroy()
		end
		groupData.name = alias
	end
	helms.dynamic.normalizeUnitNames(groupData)
	coalition.addGroup(keys.ctryId, keys.catEnum, groupData)
end

--[[
Return = Boolean: Does named group have a living active unit in-play
--]]
helms.dynamic.groupHasActiveUnit=function(groupName)
	local group=helms.dynamic.getGroupByName(groupName)	
	
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
	
	local group = helms.dynamic.getGroupByName(groupName)
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
	local group = helms.dynamic.getGroupByName(groupName)
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
	local group = helms.dynamic.getGroupByName(groupName)
	
	if group ~= nil and Group.isExist(group) then
		if initialSize == nil then  initialSize = group:getSize() end
		local accum = 0.0;
		local units = group:getUnits()
		for i,unit in pairs(units) do
			accum = accum + (unit:getLife()/math.max(1.0,unit:getLife0()))
		end
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
Get the key of an object within a given distance laterally from a given point. For speed the L^\infinity metric is used.
Optional predicate can be specified.
Returns first example found, even if multiple exist
if no object is found, nil is returned, otherwise the key of the object is returned
--]]
helms.dynamic.getKeyOfObjWithin2D = function(objList,point, dist, predicate)
	point = helms.maths.as3D(point)
	for k,v in pairs(objList) do	
		local point2 = v:getPoint()
		if math.abs(point.x - point2.x) < dist 
			and math.abs(point.z - point2.z) < dist 
			and (predicate == nil or predicate(v)) then 
			return k
		end
		--helms.log_i.log({point,point2,dist,predicate(v)})
	end
	return nil
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
	--helms.log_i.log(bases) --debug
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
			--helms.log_e.log({"Reschedule ",ret})--debug
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

helms.dynamic.scheduleFunctionSafe = function(f,argPack,t, once, errorHandler)
	if not argPack then argPack = {} end
	timer.scheduleFunction(helms.util.safeCallWrap(helms.dynamic._scheduleFunctionWrapper,errorHandler), {f = f, args = argPack, once = once},t)
end

helms.dynamic.isAirGroup = function(groupName)
	local group = helms.dynamic.getGroupByName(groupName)
	local retUnits = {}
	if group ~= nil then
		local units = group:getUnits()
		local unit = units[1]
		if unit then
			local desc = unit:getDesc()
			return desc.category == Unit.Category["HELICOPTER"] or desc.category == Unit.Category["AIRPLANE"]
		end
	end
	return false
end

helms.dynamic.clearTasks = function(groupName)
	local group = helms.dynamic.getGroupByName(groupName)
	if group ~= nil then
		local controller = group:getController()
		if controller ~= nil then
			controller:setTask({id = 'NoTask',params = {}})
		end
	end
end

--[[

--]]
helms.dynamic.setRandomFlags=function(N, toVal, ...)
	local selection = helms.util.removeRandom(arg,N)

	for k,v in pairs (selection) do
		trigger.action.setUserFlag(v,toVal)
	end
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
	if name ~= nil then
		name=string.lower(name) --remove case sensitivity
	end
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
		return {d = math.floor(seconds/86400),h = math.floor(seconds/3600), m = math.floor(seconds/60), s = seconds % 60}
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

--[[
keys: name
values: {
	[1] = #items
	[2] = path for DCS commands
	[3] = {item paths, or nested object for submenus}
	[4] = coalition (side) or nil
}

--]]
helms.ui.commsMenus_ = {}

helms.ui.ensureDefaultSubmenu=function(side)
	if side and side ~= coalition.side.NEUTRAL then --coalition specific addition	
		return helms.ui.ensureSubmenu(side,"Assets",true)
	else --add for all	
		return helms.ui.ensureSubmenu(nil,"Other Assets")
	end
end

--[[
Get page with space in comms submenu with given text label, relative to parent path or side
parentMenuPath = coalition.side, nil for neutral, or object returned by previous call or nil. If included specifies the submenu to add the new menu to, side is inferred from parent.
label = radio item text
prependCoa (bool) = if true, add coalition name to label text
--]]
helms.ui.ensureSubmenu=function(parentMenuPath, label, prependCoa)
	local retPath = {}
	if type(parentMenuPath) == "table" then
		retPath = helms.util.shallow_copy(parentMenuPath)
	end

	local parentCommsMenusBase, side, dcsParentPath, _ = helms.ui.unpackCommsPath_ (parentMenuPath)
	local parentCommsMenus
	if parentCommsMenusBase then
		parentCommsMenus = parentCommsMenusBase[3]
	else
		parentCommsMenus = helms.ui.commsMenus_ 
	end

	local menuNameRootText = label
	local menuNameRoot = label .. helms.ui.convert.sideToString(side)
	if prependCoa then
		menuNameRootText = helms.ui.convert.sideToString(side).." ".. menuNameRootText
	end
	local menuName = menuNameRoot
	local subMenuAdded = false
	
	local menu
	if parentCommsMenus[menuName]==nil then--create submenu
		menu,_,dcsParentPath= helms.ui.getPageWithSpace_(parentCommsMenusBase,retPath)
		local menuItems = parentCommsMenus

		if menu then menuItems = menu[3] end
		if side then
			menuItems[menuName] = {0, missionCommands.addSubMenuForCoalition(side, menuNameRootText ,dcsParentPath),{},side}
		else 
			menuItems[menuName] = {0, missionCommands.addSubMenu(menuNameRootText ,dcsParentPath),{},nil}
		end
		if menu then
			menu[1] = menu[1] + 1
		end		
		subMenuAdded = true
		retPath[#retPath+1] = menuName
	else
		retPath[#retPath+1] = menuName
		menu,_,_ = helms.ui.getPageWithSpace_(parentCommsMenus[menuName],retPath)
	end
	
	return retPath, nil, subMenuAdded
end

helms.ui.getPageWithSpace_ = function(commsMenus,pathBuilder)
	if commsMenus == nil then
		return nil, {},nil
	end
	if pathBuilder == nil then pathBuilder = {} end
	while commsMenus[1]>=9 do --create overflow if no space here
		local newMenuName = "__NEXT__"
		local side = commsMenus[4]
		if commsMenus[3][newMenuName] ==nil then--create submenu of menu at menuName
			if side then
				commsMenus[3][newMenuName] = {0,missionCommands.addSubMenuForCoalition(side, "Next",commsMenus[2]),{},side}
			else
				commsMenus[3][newMenuName] = {0,missionCommands.addSubMenu("Next",commsMenus[2]),{},nil}
			end
		end
		commsMenus = commsMenus[3][newMenuName]
		pathBuilder[#pathBuilder+1] = newMenuName
	end
	return commsMenus, pathBuilder, commsMenus[2]
end

helms.ui.unpackCommsPath_ = function(parentMenuPath,upLevels)
	local dcsParentPath = nil
	local parentCommsMenus = nil
	local side = nil
	local nextItemKey = nil

	if parentMenuPath ~= nil and type(parentMenuPath) == "table" then
		local maxKey = #parentMenuPath
		if upLevels ~= nil then
			maxKey = maxKey - upLevels
		end
		
		for k,v in ipairs(parentMenuPath) do
			if k>maxKey then
				nextItemKey = v
				break 
			elseif k > 1 then
				if parentCommsMenus[3] and parentCommsMenus[3][v] then
					parentCommsMenus = parentCommsMenus[3][v]
				end
			else -- parentCommsMenus = helms.ui.commsMenus_
				parentCommsMenus = helms.ui.commsMenus_[v] 
			end
		end
		if parentCommsMenus then 
			dcsParentPath = parentCommsMenus[2]
			side = parentCommsMenus[4]
		end
	elseif parentMenuPath ~= nil then
		side = parentMenuPath
	end

	return parentCommsMenus, side, dcsParentPath, nextItemKey
end 

--[[
Add comms submenu for red or blue (side == instance of coalition.side)
parentMenuPath = coalition.side, nil for neutral, or object returned by previous call or nil. If included specifies the submenu to add the new menu to, side is inferred from parent.
label = radio item text
handler = handler method,
args = args for handler
--]]
helms.ui.addCommand = function (parentMenuPath, label, handler, ...)
	local parentCommsMenus, side, dcsParentPath, _ = helms.ui.unpackCommsPath_ (parentMenuPath)
	parentCommsMenus,_,dcsParentPath  = helms.ui.getPageWithSpace_(parentCommsMenus)

	if parentCommsMenus == nil then 
		helms.log_e.log("Could not add comms menu "..label)
		return
	end

	local newDcsPath
	if side then
		newDcsPath = missionCommands.addCommandForCoalition(side,label,
					dcsParentPath,
					handler,unpack(arg))
	else 
		newDcsPath = missionCommands.addCommand(label,
					dcsParentPath,
					handler,unpack(arg))
	end
	
	local newIndex = parentCommsMenus[1] + 1
	parentCommsMenus[1] = newIndex
	parentCommsMenus[3][newIndex] = newDcsPath
	return newIndex
end

helms.ui.removeItem = function (parentMenuPath, itemIndex)
	local parentCommsMenus, side, dcsParentPath, _ = helms.ui.unpackCommsPath_ (parentMenuPath)

	if parentCommsMenus~= nil then
		local path
		if itemIndex ~= nil then
			path = parentCommsMenus[3][itemIndex]
			if path ~= nil then
				parentCommsMenus[3][itemIndex] = nil
				parentCommsMenus[1] = parentCommsMenus[1] - 1				
			end
		else -- remove parent menu
			path = dcsParentPath
			local parent2CommsMenus, _, _, nextKey = helms.ui.unpackCommsPath_ (parentMenuPath,1)
			if parent2CommsMenus ~= nil then
				parent2CommsMenus[3][nextKey] = nil
				parent2CommsMenus[1] = parent2CommsMenus[1] - 1
			end			    
		end

		if path ~= nil and side == nil then
			missionCommands.removeItem(path)
		elseif path ~= nil then
			missionCommands.removeItemForCoalition(side,path)
		end	
	end
end

helms.ui._renderedDrawingIds = {} -- key = name, value = {id = ,active = }
helms.ui._nextRenderedDrawingId = nil

helms.ui.showDrawing = function (drawingName,coalition)
	local current = helms.ui._renderedDrawingIds[drawingName] 
	if current ~= nil and current.active == true then return end

	local drawings = helms.mission._getDrawingList()
	local meDrawing = drawings[drawingName]

	if helms.ui._nextRenderedDrawingId == nil then 
		helms.ui._nextRenderedDrawingId = 2 * #drawings + 1
	end
	local id = helms.ui._nextRenderedDrawingId 
	local idAlt = id

	if coalition == nil then coalition = meDrawing.coalition end

	if meDrawing == nil then return end

	if meDrawing.shapeId == 1 then --Line
		trigger.action.markupToAll(helms.util.multiunpack({meDrawing.shapeId, coalition, id }, meDrawing.points, {meDrawing.colour , meDrawing.fillColour , meDrawing.lineType}))
	elseif meDrawing.shapeId == 2 then -- Circle
		--helms.log_i.log({helms.util.multiunpack({meDrawing.shapeId, coalition, id} , meDrawing.points, {meDrawing.radius, meDrawing.colour , meDrawing.fillColour , meDrawing.lineType})})
		trigger.action.circleToAll(helms.util.multiunpack({coalition, id} , meDrawing.points, {meDrawing.radius, meDrawing.colour , meDrawing.fillColour , meDrawing.lineType}))
	elseif meDrawing.shapeId == 5 then -- Text
		trigger.action.markupToAll(helms.util.multiunpack({meDrawing.shapeId, coalition, id }, meDrawing.points, {meDrawing.colour , meDrawing.fillColour , meDrawing.fontSize, true, meDrawing.text}))
	elseif meDrawing.shapeId == 7 then -- Polygon
		--helms.log_i.log({helms.util.multiunpack({meDrawing.shapeId, coalition, id} , meDrawing.points, {meDrawing.colour , meDrawing.fillColour , meDrawing.lineType})})
		trigger.action.markupToAll(helms.util.multiunpack({meDrawing.shapeId, coalition, id} , meDrawing.points, {meDrawing.colour , meDrawing.fillColour , meDrawing.lineType}))

		idAlt = id + 1
		trigger.action.markupToAll(helms.util.multiunpack({meDrawing.shapeId, coalition, idAlt} , helms.util.reverse(meDrawing.points), {meDrawing.colour , meDrawing.fillColour , meDrawing.lineType}))
	end

	helms.ui._renderedDrawingIds[drawingName] = {id = id, idAlt = idAlt, active = true}
	helms.ui._nextRenderedDrawingId = idAlt + 1
end

helms.ui.removeDrawing = function (drawingName)
	local current = helms.ui._renderedDrawingIds[drawingName]

	if current ~= nil and current.active == true and  current.id ~= nil then
		trigger.action.removeMark(current.id)

		if current.idAlt ~= current.id then
			trigger.action.removeMark(current.idAlt)
		end

		current.active = false
	end
end

-- shortcuts for easier use in ME scripts
helms.ui.combo = {}

helms.ui.combo.commsCallback = function (side,menuLabel,optionLabel, callback, ...)
	local parentMenuPath, _ = helms.ui.ensureSubmenu(side,menuLabel)

	if menuLabel ~= nil and optionLabel ~= nil and callback ~= nil and type(callback) == "function" then
    	return helms.ui.addCommand(parentMenuPath,optionLabel,helms.util.safeCallWrap(callback,helms.catchError),unpack(arg))
	else
		helms.log_e.log("Invalid arguments for helms.ui.combo.commsCallback")
	end
end
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
-- Events

helms.events = {
	hitLoggingEnabled_ = false,
	lastHitBy_ = {} -- key = unit name, value = {time = time last hit, initiatorName = name of unit that initiated the hit}, friendly fire not counted
}

helms.events.getLastHitBy = function(unitHitName)
	return helms.events.lastHitBy_[unitHitName]
end

helms.events.hitHandler_ = function(target, initiator,time)
	if not target or not initiator then return end
    local tgtName = target:getName()
    local initName = initiator:getName()

    if target:getCoalition() == initiator:getCoalition() then return end

    helms.events.lastHitBy_[tgtName]={time = time, initiatorName = initName}
end

helms.events.enableHitLogging = function()
	if helms.events.hitLoggingEnabled_ then return end

	local eventHandler = { 
		onEvent = function(self,event)
			if (event.id == world.event.S_EVENT_HIT) then
				helms.util.safeCall(helms.events.hitHandler_,{event.target,event.initiator,event.time},helms.catchError)
			end
		end
	}
	world.addEventHandler(eventHandler)

	helms.events.hitLoggingEnabled_ = true
end
---------------------------------------------------------------------------------------------------
helms.mission._buildMEGroupLookup()

helms.log_i.log("HeLMS v"..helms.version.." loaded")
---------------------------------------------------------------------------------------------------
helms.test ={}
helms.test.explodeUnitIfNameContains = function(substring, power)
	local names = helms.mission.getNamesContaining(substring)

	for k, name in pairs(names) do
		helms.test.explodeUnits(name,power)
		helms.dynamic.getGroupByName(name)
	end

	return names
end

helms.test.explodeUnits = function(groupName, power)
	local gp = helms.dynamic.getGroupByName(groupName)
	if gp then
		local units = gp:getUnits()
		if units then
			for _,v in pairs(units) do
				trigger.action.explosion(helms.maths.lin3D(v:getPoint(),1,{x = 10,y=0,z=0},1),power)
			end				
		end
	end
end