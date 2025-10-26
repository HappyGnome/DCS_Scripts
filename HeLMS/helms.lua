--#######################################################################################################
-- HeLMS v1.15 -  Helpful Library of Mission Scripts
--
-- Common utilities for scripts by HappyGnome. Lightweight replacement for some MIST features.
--
-- Script by HappyGnome
--#######################################################################################################

--NAMESPACES----------------------------------------------------------------------------------------------
helms = { version = 1.16 }

----------------------------------------------------------------------------------------------------------
--helms.util - LUA EXTENSIONS-----------------------------------------------------------------------------
--
-- Table manipulation etc

helms.util = {}

--[[
Call a function, unpacking args table as its arguments.
Args:
    func: function to call
    args: table containing arguments for func
    errorHandler: function(err) (see xpcall)
--]]
helms.util.safeCall = function(func, args, errorHandler)
    --helms.log_i.log("sc1")
    local op = function()
        --helms.log_i.log(args)
        return func(unpack(args))
    end
    local ok, result = xpcall(op, errorHandler)
    --helms.log_i.log(result)
    return result
end

--[[
Wrap a function, returning a function of the same signature,
but where errors are caught and passed to errorHandler.
--]]
helms.util.safeCallWrap = function(func, errorHandler)
    return function(...) return helms.util.safeCall(func, arg, errorHandler) end
end

--[[
Basic recursive Lua serializer
(serializeable values are strings, numbers, or tables containing serializeable values)
--]]
helms.util.obj2str = function(obj)
    if obj == nil then
        return 'nil'
    end
    local msg = ''
    local t = type(obj)
    if t == 'table' then
        msg = msg .. '{'
        for k, v in pairs(obj) do
            msg = msg .. k .. ':' .. helms.util.obj2str(v) .. ', '
        end
        msg = msg .. '}'
    elseif t == 'string' then
        msg = msg .. "\"" .. obj .. "\""
    elseif t == 'number' or t == 'boolean' then
        msg = msg .. tostring(obj)
    elseif t then
        msg = msg .. t
    end
    return msg
end

--[[
Randomly remove N elements from a table and return removed elements (key,value)
If predicate(k, v) is specified, only entries satisfying the predicate are returned
--]]
helms.util.removeRandom = function(t, N, predicate)
    local ret = {}
    local count = 0
    local s = {}
    for k, v in pairs(t) do
        if predicate == nil or predicate(k, v) == true then
            count = count + 1
            s[k] = v
        end
    end

    N = math.min(N, count)

    local n = 0
    while (n < N) do
        local toRemove = math.random(count - n)

        local i = 0

        for k, v in pairs(s) do
            i = i + 1
            if i == toRemove then
                t[k] = nil
                s[k] = nil
                ret[k] = v
            end
        end
        n = n + 1
    end

    return ret
end

--[[
Given a set s with multiplicity (key = Any, value= multiplicity)
Remove any for which pred(key)==true
Return the number removed counting multiplicity
--]]
helms.util.eraseByPredicate = function(s, pred)
    local ret = 0

    for k, v in pairs(s) do
        if pred(k) then
            ret = ret + v
            s[k] = nil
        end
    end

    return ret
end

--[[
Exchange keys and values:
Return a table whose keys are the values from the original table,
and values are corresponding keys.
--]]
helms.util.transposeTable = function(set)
    local ret = {}
    for k, v in pairs(set) do
        ret[v] = k
    end
    return ret
end

--[[
Return table `set` without any key-value pairs where the value
is also present in table `exc`
--]]
helms.util.excludeValues = function(set, exc)
    local ret = {}
    local excT = helms.util.transposeTable(exc)
    for k, v in pairs(set) do
        if not excT[v] then
            ret[k] = v
        end
    end
    return ret
end

--[[
Return a table containing the same values as `obj`
and with the same metatable.
--]]
helms.util.shallow_copy = function(obj)
    local ret = obj
    if type(obj) == 'table' then
        ret = {}
        for k, v in pairs(obj) do
            ret[k] = v
        end
    end
    setmetatable(ret, getmetatable(obj))
    return ret
end

--[[
Return a copy of `obj`, creating copied of nested tables (appearing as keys or values),
rather than just using references.

See http://lua-users.org/wiki/CopyTable
--]]
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
        for k, v in next, obj do
            copy[_copy(k)] = _copy(v)
        end
        setmetatable(copy, getmetatable(obj))
        return copy
    end
    return _copy(obj)
end

-- return a unpacked then b unpacked. (Avoids the issue {unpack(a),unpack(b)}=={a[1],unpack(b)})
helms.util.multiunpack = function(...)
    local ret = {}
    for k, v in pairs { ... } do
        for i, w in ipairs(v) do
            ret[#ret + 1] = w
        end
    end
    return unpack(ret)
end

helms.util.hexToRgba = function(hexStr)
    local rawNum = tonumber(hexStr)

    local res = { [1] = 0.0, [2] = 0.0, [3] = 0.0, [4] = 1.0 }

    if rawNum == nil then
        return res
    end
    res[4] = (rawNum % 256) / 256.0
    rawNum = rawNum / 256
    res[3] = (rawNum % 256) / 256.0
    rawNum = rawNum / 256
    res[2] = (rawNum % 256) / 256.0
    rawNum = rawNum / 256
    res[1] = (rawNum % 256) / 256.0
    return res
end

helms.util.reverse = function(tbl)
    local res = {}

    for i, v in ipairs(tbl) do
        res[#tbl - i + 1] = v
    end

    return res
end

helms.util.kvflip = function(tbl)
    local res = {}

    for k, v in pairs(tbl) do
        res[v] = k
    end

    return res
end

helms.util.uuid = function()
    local N16 = 65535 -- 2^16 - 1
    local N12 = 4095  -- 2^12 - 1 (byte 7 starts 0100(base 2) for UUID variant 4.x)
    local N14 = 16383 -- 2^14 - 1
    local K = 32768   -- 2^15   (byte 9 starts 10(base 2) for UUID variant 4.1 )
    return string.format("%04x%04x-%04x-4%03x-%04x-%04x%04x%04x", math.random(0, N16), math.random(0, N16),
        math.random(0, N16), math.random(0, N12), math.random(0, N14) + K, math.random(0, N16), math.random(0, N16),
        math.random(0, N16))
end

helms.util.strJoin = function(delim, tbl)
    local ret = ""

    if not tbl or not tbl[1] then return ret end

    ret = tbl[1]

    for i = 2, #tbl do
        ret = ret .. delim .. tbl[i]
    end

    return ret
end

helms.util.fmap = function(tbl, f)

    if tbl == nil then return nil end
    
    local result = {}

    for k,v in pairs(tbl) do
        result[k] = f(v)
    end

    return result
end
----------------------------------------------------------------------------------------------------------
--LOGGING-------------------------------------------------------------------------------------------------
helms.logger = {
    new = function(tag, eventType)
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
helms.log_i = helms.logger.new("helms", "info")
helms.log_e = helms.logger.new("helms", "error")

--error handler for xpcalls. wraps helms.log_e.log
helms.catchError = function(err)
    helms.log_e.log(err)
end

----------------------------------------------------------------------------------------------------------
--MATHS---------------------------------------------------------------------------------------------------
-- General calculation tools and conversions

helms.maths = {}

helms.maths.deg2rad = 0.01745329
helms.maths.kts2mps = 0.514444
helms.maths.m2ft = 3.281
helms.maths.m2nm = 0.000539957

--[[
True heading point A to point B, in degrees
--]]
helms.maths.getTrueNorthTheta = function(pointA)
    local lat, lon = coord.LOtoLL(pointA)
    local north = coord.LLtoLO(lat + 1, lon)
    return math.atan2(north.z - pointA.z, north.x - pointA.x)
end

--[[
True heading point A to point B, in degrees
--]]
helms.maths.getHeading = function(pointA, pointB)
    local north = helms.maths.getTrueNorthTheta(pointA)                                       -- atan2 for true north at pointA
    local theta = (math.atan2(pointB.z - pointA.z, pointB.x - pointA.x) - north) * 57.2957795 --degrees
    local hdg = math.fmod(theta, 360)
    if hdg < 0 then
        hdg = hdg + 360
    end
    return hdg
end

--[[
True heading point A to point B, in degrees
--]]
helms.maths.getPitch = function(vel)
    if not vel then return 0 end

    vel = helms.maths.as3D(vel)

    return math.atan2(vel.y, math.sqrt(helms.maths.dot2D(vel, vel)))
end

helms.maths.as2D = function(u)
    local uy = u.z
    if uy == nil then uy = u.y end
    return { x = u.x, y = uy }
end

helms.maths.as3D = function(u)
    local uz = u.z
    local uy = u.y
    if uz == nil then
        uz = u.y
        uy = 0
    end
    return { x = u.x, y = uy, z = uz }
end

helms.maths.as3DHeight = function(u, h)
    local uz = u.z
    local uy = u.y
    if uz == nil then
        uz = u.y
        uy = h + land.getHeight(u)
    end
    return { x = u.x, y = uy, z = uz }
end

-- Estimate slant range to ground from point p in direction x
helms.maths.quickSlantRange = function(p,x)

    if (x.y == 0) then return nil end -- Ray parallel to ground

   local h1 = land.getHeight(helms.maths.as2D(p))
   if (h1 < 0) then h1 = 0 end -- DCS terrain cannot currently go below sea level

   local dh1 = p.y - h1

   if (dh1 * x.y > 0) then return nil end -- ray must go towards from ground

   local slantX = (dh1/x.y)
   
   return math.sqrt(slantX * slantX + dh1*dh1)

end

helms.maths.get2DDist = function(pointA, pointB)
    local p = helms.maths.as2D(pointA)
    local q = helms.maths.as2D(pointB)
    local off = { x = p.x - q.x, y = p.y - q.y }
    return math.sqrt((off.x * off.x) + (off.y * off.y))
end

helms.maths.get3DDist = function(pointA, pointB)
    local p = helms.maths.as3D(pointA)
    local q = helms.maths.as3D(pointB)
    local off = { x = p.x - q.x, y = p.y - q.y, z = p.z - q.z }
    return math.sqrt((off.x * off.x) + (off.y * off.y) + (off.z * off.z))
end

helms.maths.dot2D = function(u, v)
    local uy = u.z
    local vy = v.z
    if uy == nil then uy = u.y end
    if vy == nil then vy = v.y end
    return u.x * v.x + uy * vy
end

helms.maths.dot3D = function(u, v)
    local u3 = helms.maths.as3D(u)
    local v3 = helms.maths.as3D(v)

    return u3.x * v3.x + u3.y * v3.y + u3.z * v3.z
end

helms.maths.applyMat2D = function(u, M)
    local v = {}
    v.x = helms.maths.dot2D(u, M[1])
    v.y = helms.maths.dot2D(u, M[2])
    return v
end

--helms.maths.positionToMat3D = function(pos)
--    return {
--        [1] = {x = pos.x.x, y = pos.y.x, z = pos.z.x},
--        [2] = {x = pos.x.y, y = pos.y.y, z = pos.z.y},
--        [3] = {x = pos.x.z, y = pos.y.z, z = pos.z.z}
--    }
--end

helms.maths.objLocalToGlobal = function(u, M)
    local v = {}
    v.x = u.x * M.x.x + u.y * M.y.x + u.z * M.z.x + M.p.x
    v.y = u.x * M.x.y + u.y * M.y.y + u.z * M.z.y + M.p.y
    v.z = u.x * M.x.z + u.y * M.y.z + u.z * M.z.z + M.p.z
    return v
end

helms.maths.makeRotMat2D = function(theta)
    local M = { {}, {} }
    M[1] = { x = math.cos(theta), y = -math.sin(theta) }
    M[2] = { x = math.sin(theta), y = math.cos(theta) }
    return M
end

helms.maths.wedge2D = function(u, v)
    local uy = u.z
    local vy = v.z
    if uy == nil then uy = u.y end
    if vy == nil then vy = v.y end
    return u.x * vy - uy * v.x
end

helms.maths.lin2D = function(u, a, v, b)
    local uy = u.z
    local vy = v.z
    if uy == nil then uy = u.y end
    if vy == nil then vy = v.y end
    return { x = a * u.x + b * v.x, y = a * uy + b * vy }
end

helms.maths.lin3D = function(u, a, v, b)
    local U = helms.maths.as3D(u)
    local V = helms.maths.as3D(v)
    return { x = a * U.x + b * V.x, y = a * U.y + b * V.y, z = a * U.z + b * V.z }
end

--return {x,y} unit vector in direction from a to b
helms.maths.unitVector = function(A, B)
    local Ay = A.z
    local By = A.z
    if Ay == nil then Ay = A.y end
    if By == nil then By = B.y end
    local C = { x = B.x - A.x, y = By - Ay }
    local r = math.sqrt(helms.maths.dot2D(C, C))

    if r < 0.001 then return { x = 0, y = 0 } end
    return { x = C.x / r, y = C.y / r }
end

--[[
Return the angle between velocity/heading X and the line from points A to B
--]]
helms.maths.thetaToDest = function(X, A, B)
    local toDest = helms.maths.lin2D(B, 1, A, -1)
    return math.atan2(helms.maths.wedge2D(X, toDest), helms.maths.dot2D(X, toDest))
end

helms.maths.randomInCircle = function(r, centre)
    centre = helms.maths.as2D(centre)

    local theta = math.random() * 2 * math.pi
    r = r * math.sqrt(math.random())

    return { x = centre.x + math.cos(theta) * r, y = centre.y + math.sin(theta) * r }
end

helms.maths.pointsCircleBorder = function(r, centre, count)
    centre = helms.maths.as2D(centre)

    local ret = {}

    if count <= 0 then
        return ret
    end

    local theta = 2 * math.pi / count

    local i

    for i = 1, count do
        ret[#ret + 1] = { x = centre.x + math.cos(i * theta) * r, y = centre.y + math.sin(i * theta) * r }
    end

    return ret
end

helms.maths.isPointInPoly = function(point, verts)
    if (not point) or (not verts) or (#verts < 3) then
        return false
    end

    local ytol = 0.01 -- added to verts lying on same y value as point

    local winding = 0

    local p1 = helms.maths.lin2D(verts[#verts], 1, point, -1)
    local p2 = helms.maths.lin2D(verts[1], 1, point, -1)

    for i = 1, #verts do
        if (p1.y > -ytol and p1.y < ytol) then
            p1.y = ytol
        end

        if (p2.y > -ytol and p2.y < ytol) then
            p2.y = ytol
        end

        if (p1.y * p2.y < 0) then
            if p1.x * p2.y < p2.x * p1.y then
                winding = winding - 0.5
            else
                winding = winding + 0.5
            end
        end

        if i < #verts then
            p1 = p2
            p2 = helms.maths.lin2D(verts[i + 1], 1, point, -1)
        end
    end

    return winding ~= 0
end

----------------------------------------------------------------------------------------------------------
--PHYSICS---------------------------------------------------------------------------------------------------
-- Physics-based calculation tools and conversions

helms.physics = {}

helms.physics.specGrav = 9.81
helms.physics.mach2Coeff = 401.88 -- Estimate of coefficient T/c^2

-- Get specific energy (relative to the surface of the map, in wind's frame of reference)
helms.physics.getSpecificEnergyWindRel = function(obj)
    if not obj then return 0 end

    local p = obj:getPoint()
    local v = obj:getVelocity()
    local vrel = helms.physics.getWindRelativeVel(v, p)

    return helms.physics.getSpecificKE(vrel) + helms.physics.getSpecificGPE(p)
end

helms.physics.getSpecificKE = function(vel)
    return 0.5 * helms.maths.dot3D(vel, vel)
end

-- Get specific gravitational potential (relative to the surface of the map)
helms.physics.getSpecificGPE = function(point)
    return helms.physics.specGrav * helms.maths.as3D(point).y
end

helms.physics.estimateMach = function(obj)
    if not obj then return 0 end

    local p = obj:getPoint()
    local v = obj:getVelocity()

    local vrel = helms.physics.getWindRelativeVel(v, p)
    local c2 = helms.physics.estimateC2(p)

    if c2 > 0 then
        return math.sqrt(helms.maths.dot3D(vrel, vrel) / c2)
    else
        return math.huge
    end
end

helms.physics.estimateC2 = function(point)
    local T, P = atmosphere.getTemperatureAndPressure(helms.maths.as3D(point))
    return T * helms.physics.mach2Coeff
end

helms.physics.getWindRelativeVel = function(vel, point)
    return helms.maths.lin3D(vel, 1, atmosphere.getWind(helms.maths.as3D(point)), -1)
end

helms.physics.TasKts = function(obj)
    if not obj then return 0 end

    local p = obj:getPoint()
    local v = obj:getVelocity()

    local vrel = helms.physics.getWindRelativeVel(v, p)

    return math.sqrt(helms.maths.dot3D(vrel, vrel)) / helms.maths.kts2mps
end

----------------------------------------------------------------------------------------------------------
--CONST------------------------------------------------------------------------------------------------
helms.const = {}

helms.const.GroupCatRev = helms.util.kvflip(Group.Category)
helms.const.CoalitionSideRev = helms.util.kvflip(coalition.side)

----------------------------------------------------------------------------------------------------------
--ME UTILS------------------------------------------------------------------------------------------------
-- Convert/manage data from mission file

helms.mission = {}

helms.mission.stringsToScriptTasks = function(strings)
    local tasks = {};
    for _, string in pairs(strings) do
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
    for name, _ in pairs(helms.mission._GroupLookup) do
        if string.find(name, substring) ~= nil then
            table.insert(ret, name)
        end
    end
    return ret
end

helms.mission.getNamesContainingUpk = function(substring)
    return unpack(helms.mission.getNamesContaining(substring))
end

--[[
	Execute a function for all groups with name containing a substring
	
	func signature: func(groupName,...)

	Additional parameters are passed to func
--]]
helms.mission.execForGroupNamesContaining = function(func, substring, ...)
    if func == nil or substring == nil then
        return
    end

    local names = helms.mission.getNamesContaining(substring)
    local safeFunc = helms.util.safeCallWrap(func)

    for _, name in pairs(names) do
        safeFunc(name, unpack(arg))
    end
end

--[[
	Return true if group activation is pending
--]]
helms.mission.groupAwaitingActivation = function(name)
    local group = helms.dynamic.getGroupByName(name)
    if not group or not group:isExist() then return false end -- group not spawned, or destroyed implies not awaiting activation

    local units = Group.getUnits(group)
    if units then
        local unit = units[1]
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
helms.mission.generateGroups = function(nameRoot, count, unitDonors, taskDonors)
    local groupNum = 0 --index to go with name route to make group name
    local ret = {}
    local logMessage = "Generated groups: "

    while groupNum < count do
        groupNum = groupNum + 1

        local newGroupData = helms.mission.getMEGroupDataByName(unitDonors[math.random(#unitDonors)])

        --get route and task data from random task donor
        local taskDonorName = taskDonors[math.random(#taskDonors)]
        local taskDonorData = helms.mission.getMEGroupDataByName(taskDonorName)
        local taskDonorSpawnKeys = helms.mission.getKeysByName(taskDonorName)
        if taskDonorData and newGroupData then
            local unitInFront = taskDonorData.units[1]
            newGroupData.route = taskDonorData.route

            newGroupData.name = nameRoot .. "-" .. groupNum
            newGroupData.groupId = nil

            --null group position - get it from the route
            newGroupData.x = taskDonorData.x
            newGroupData.y = taskDonorData.y

            --generate unit names and null ids
            --also copy initial locations and headings
            for i, unit in pairs(newGroupData.units) do
                unit.unitName = nameRoot .. "-" .. groupNum .. "-" .. (i + 1)
                unit.unitId = nil

                --null unit locations - force them to be set by start of route
                unit.x = taskDonorData.x
                unit.y = taskDonorData.y
                unit.alt = unitInFront.alt
                unit.alt_type = unitInFront.alt_type
                unit.heading = unitInFront.heading
                unit.psi = unitInFront.psi
            end

            newGroupData.lateActivation = true

            table.insert(ret, { data = newGroupData, keys = taskDonorSpawnKeys })
            --helms.log_i.log(taskDonorSpawnKeys)--debug
        end
    end

    --helms.log_i:info(logMessage)

    return unpack(ret)
end

helms.mission.getGroupStartPoint2D = function(groupName)
    local spawnData = helms.mission.getMEGroupDataByName(groupName)
    if spawnData and spawnData.units and spawnData.units[1] then
        return { x = spawnData.units[1].x, y = 0, z = spawnData.units[1].y }
    end
end

--[[
Get units offroad max speed in mps, or default if this is not available
--]]
helms.mission.getUnitSpeed = function(unit, default)
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

    for coaK, coaV in pairs(env.mission.coalition) do
        if type(coaV) == 'table' and coaV.country then
            for ctryK, ctryV in pairs(coaV.country) do
                if type(ctryV) == 'table' then
                    for catK, catV in pairs(ctryV) do
                        if (catK == "helicopter"
                                or catK == "ship"
                                or catK == "plane"
                                or catK == "vehicle"
                                or catK == "static")
                            and type(catV) == 'table'
                            and catV.group
                            and type(catV.group) == 'table' then
                            for gpK, gpV in pairs(catV.group) do
                                if type(gpV) == 'table' and gpV.name then
                                    helms.mission._GroupLookup[gpV.name] = {
                                        coa = coaK,
                                        ctry = ctryK,
                                        ctryId = ctryV.id,
                                        cat =
                                            catK,
                                        gp = gpK,
                                        catEnum = helms.mission._catNameToEnum(catK),
                                        startPoint = { x = gpV.x, y = gpV.y },
                                        isStatic = (catK == "static")
                                    }
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

helms.mission.getMEGroupNamesInZone = function(zoneName, side, includeStatic)
    local ret = {}

    if includeStatic == nil then includeStatic = true end

    local sideKey = nil
    if side ~= nil then
        sideKey = helms.mission.sideToString(side)
    end

    local zoneDesc = helms.predicate.makeZoneDesc_(zoneName)

    for name, gpData in pairs(helms.mission._GroupLookup) do
        if (gpData.coa == sideKey or sideKey == nil) and
            (includeStatic or gpData.isStatic ~= true) and
            helms.predicate.pointInZone_(gpData.startPoint, zoneDesc) then
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

helms.mission.groupContainsClient_ = function(gpData)
    if not gpData or not gpData.units then return false end

    for k, v in pairs(gpData.units) do
        if v.skill == "Client" then
            return true
        end
    end

    return false
end


--[[
	Get list of drawing names containing a substring
	
	substring - substring to search for
--]]
helms.mission.getDrawingNamesContaining = function(substring)
    local ret = {}
    for name, _ in pairs(helms.mission._getDrawingList) do
        if string.find(name, substring) ~= nil then
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

    for layerKey, layer in pairs(env.mission.drawings.layers) do
        local side = helms.mission._drawingSideKeys[layer.name] -- nil for author

        if layer.objects ~= nil then
            for objKey, obj in pairs(layer.objects) do
                local drawing = nil

                if obj.primitiveType == "Line" then
                    drawing = helms.mission._convertMeDrawingLine(obj)
                elseif obj.primitiveType == "Polygon" then
                    if obj.polygonMode == 'circle' then
                        drawing = helms.mission._convertMeDrawingCircle(obj)
                    elseif obj.polygonMode == 'oval' then
                        drawing = helms.mission._convertMeDrawingOval(obj)
                    else
                        drawing = helms.mission._convertMeDrawingPoly(obj)
                    end
                elseif obj.primitiveType == "TextBox" then
                    drawing = helms.mission._convertMeDrawingText(obj)
                end

                if drawing ~= nil then
                    drawing.colour = helms.util.hexToRgba(obj.colorString)
                    drawing.fillColour = helms.util.hexToRgba(obj.fillColorString)
                    drawing.coalition = side

                    drawing.lineType = helms.ui.drawingLineType.solid
                    -- Line types don't match between ME and scripting
                    -- for now, make this binary simplification
                    if obj.thickness == 0 then
                        drawing.lineType = helms.ui.drawingLineType.none
                    end

                    drawings[obj.name] = drawing
                end
            end
        end
    end

    return drawings
end

helms.mission.zoneTypes = { ['Circle'] = 0, ['Quad'] = 2 }
helms.mission._meZoneNameLookup = nil -- key = zone name, value = id

helms.mission.getMeZoneData = function(zoneName)
    if helms.mission._meZoneNameLookup == nil then
        helms.mission._meZoneNameLookup = helms.mission._buildZoneNameLookup()
    end
    local ZoneId = helms.mission._meZoneNameLookup[zoneName]

    if ZoneId == nil or env.mission.triggers == nil or env.mission.triggers.zones == nil then
        return nil
    end

    return env.mission.triggers.zones[ZoneId]
end

helms.mission._buildZoneNameLookup = function()
    local zones = {}

    if env.mission.triggers == nil or env.mission.triggers.zones == nil then
        return zones
    end

    for k, v in pairs(env.mission.triggers.zones) do
        zones[v.name] = k
    end

    return zones
end

helms.mission._convertMeDrawingLine = function(meDrawing)
    local basePoint = helms.maths.as3D({ x = meDrawing.mapX, y = meDrawing.mapY })
    local points = {}
    local ret = { shapeId = helms.ui.drawingShapeType.line, points = points }

    if meDrawing.points == nil or #meDrawing.points < 1 then
        return ret
    end

    for i = 1, #meDrawing.points do
        points[#points + 1] = helms.maths.lin3D(basePoint, 1, meDrawing.points[i], 1)
    end

    if meDrawing.closed == true then
        points[#points + 1] = points[1]
    end

    ret.points = points
    return ret
end

helms.mission._convertMeDrawingPoly = function(meDrawing)
    local basePoint = helms.maths.as3D({ x = meDrawing.mapX, y = meDrawing.mapY })
    local points = {}
    local ret = { shapeId = helms.ui.drawingShapeType.polygon, points = points }

    -- Rect
    if meDrawing.polygonMode == 'rect' then
        local wBy2 = meDrawing.width / 2
        local hBy2 = meDrawing.height / 2
        points[1] = { x = -wBy2, y = -hBy2 }
        points[2] = { x = wBy2, y = -hBy2 }
        points[3] = { x = wBy2, y = hBy2 }
        points[4] = { x = -wBy2, y = hBy2 }
    else --Free, arrow etc
        if meDrawing.points == nil or #meDrawing.points < 1 then
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
        points[i] = helms.maths.lin3D(basePoint, 1, helms.maths.applyMat2D(points[i], M), 1)
    end

    ret.points = points
    return ret
end

helms.mission._convertMeDrawingCircle = function(meDrawing)
    local basePoint = helms.maths.as3D({ x = meDrawing.mapX, y = meDrawing.mapY })
    local points = { basePoint }
    local ret = { shapeId = helms.ui.drawingShapeType.circle, points = points }

    ret.radius = meDrawing.radius
    return ret
end

helms.mission._convertMeDrawingOval = function(meDrawing)
    local basePoint = helms.maths.as3D({ x = meDrawing.mapX, y = meDrawing.mapY })
    local points = { basePoint }
    local ret = { shapeId = helms.ui.drawingShapeType.circle, startPos = basePoint, points = points }

    ret.radius = (meDrawing.r1 + meDrawing.r1) / 2

    return ret
end

helms.mission._convertMeDrawingText = function(meDrawing)
    local basePoint = helms.maths.as3D({ x = meDrawing.mapX, y = meDrawing.mapY })
    local ret = { shapeId = helms.ui.drawingShapeType.text,
        points = { basePoint }, text = meDrawing.text, fontSize = meDrawing.fontSize }

    return ret
end

--[[
Convert coalition to "red", "blue", "neutral", or nil if not matched
Following mission (.miz) coalition keys
--]]
helms.mission.sideToString = function(side)
    if side == coalition.side.RED then
        return "red"
    elseif side == coalition.side.BLUE then
        return "blue"
    elseif side == coalition.side.NEUTRAL then
        return "neutrals"
    else
        return nil
    end
end

----------------------------------------------------------------------------------------------------------
--PREDICATE-------------------------------------------------------------------------------------------------

helms.predicate = {}

-- Circular zones only at the moment (zone can be nil to check all units)
-- set coa == nil to check BLUE and RED units
helms.predicate.unitExists = function(coa, cat, zoneName, ...)
    -- Validate enums
    if cat and not helms.const.GroupCatRev[cat] then return false end
    if coa and not helms.const.CoalitionSideRev[coa] then return false end

    local searchGroups = function(groups, zoneName, ...)
        if groups == nil then
            return false
        end

        local zoneDesc = helms.predicate.makeZoneDesc_(zoneName)

        for k, group in pairs(groups) do
            units = group:getUnits()

            if helms.predicate.hasObjectMatch(units, zoneDesc, unpack(arg)) then
                return true
            end
        end

        return false
    end

    if coa then
        return searchGroups(coalition.getGroups(coa, cat), zoneName, unpack(arg))
    else
        return searchGroups(coalition.getGroups(coalition.side.BLUE, cat), zoneName, unpack(arg))
            or searchGroups(coalition.getGroups(coalition.side.RED, cat), zoneName, unpack(arg))
    end
end


helms.predicate.staticExists = function(coa, zoneName, ...)
    -- Validate enums
    if coa and not helms.const.CoalitionSideRev[coa] then return false end

    local searchObjs = function(objs, zoneName, ...)
        if objs == nil then
            return false
        end

        local zoneDesc = helms.predicate.makeZoneDesc_(zoneName)

        return helms.predicate.hasObjectMatch(units, zoneDesc, unpack(arg))
    end

    if coa then
        return searchObjs(coalition.getStaticObjects(coa), zoneName, unpack(arg))
    else
        return searchObjs(coalition.getStaticObjects(coalition.side.BLUE), zoneName, unpack(arg))
            or searchObjs(coalition.getStaticObjects(coalition.side.RED), zoneName, unpack(arg))
    end
end

helms.predicate.pointInZone_ = function(point, zoneDesc)
    point = helms.maths.as2D(point)

    if (not zoneDesc) or
        (not zoneDesc.quickBounds) or
        point.x < zoneDesc.quickBounds.xMin or
        point.x > zoneDesc.quickBounds.xMax or
        point.y < zoneDesc.quickBounds.yMin or
        point.y > zoneDesc.quickBounds.yMax then
        return false
    end

    if (not zoneDesc.vertices) and ((not zoneDesc.centre) or (not zoneDesc.radius)) then
        return false
    end

    return ((not zoneDesc.vertices) and helms.maths.get2DDist(zoneDesc.centre, point) <= zoneDesc.radius)
        or helms.maths.isPointInPoly(point, zoneDesc.vertices)
end

helms.predicate.makeZoneDesc_ = function(zoneName)
    local result = {}

    local quickBounds = {}
    local centre = { x = 0, y = 0 }
    local radius = 0
    local vertices = nil

    local meZoneData = helms.mission.getMeZoneData(zoneName)

    if meZoneData == nil then return result end

    if meZoneData.type == helms.mission.zoneTypes.Quad and meZoneData.verticies then
        vertices = meZoneData.verticies

        for k, v in pairs(vertices) do
            if quickBounds.xMax == nil or quickBounds.xMax < v.x then
                quickBounds.xMax = v.x
            end

            if quickBounds.xMin == nil or quickBounds.xMin > v.x then
                quickBounds.xMin = v.x
            end

            if quickBounds.yMax == nil or quickBounds.yMax < v.y then
                quickBounds.yMax = v.y
            end

            if quickBounds.yMin == nil or quickBounds.yMin > v.y then
                quickBounds.yMin = v.y
            end
        end

        result = { quickBounds = quickBounds, vertices = vertices }
    else
        local zone = trigger.misc.getZone(zoneName)

        if zone == nil then return result end

        centre = { x = zone.point.x, y = zone.point.z }
        radius = zone.radius

        quickBounds = {
            xMax = centre.x + radius,
            xMin = centre.x - radius,
            yMax = centre.y + radius,
            yMin = centre.y -
                radius
        }

        result = { centre = centre, radius = radius, quickBounds = quickBounds }
    end

    return result
end

helms.predicate.hasObjectMatch = function(objs, zoneDesc, ...)
    if objs == nil then
        return false
    end

    for k, obj in pairs(objs) do
        local fail = not helms.predicate.pointInZone_(obj:getPoint(), zoneDesc)

        if (not fail) and arg then
            for kp, pred in pairs(arg) do
                if (not fail) then
                    if type(pred) == 'function' and (not pred(obj)) then
                        fail = true
                    elseif type(pred) == 'table' and (not pred.eval(obj)) then
                        fail = true
                    end
                end
            end
        end

        if not fail then -- obj found
            if type(pred) == 'table' then
                pred.triggered(obj)
            end
            return true
        end
    end

    return false
end

helms.predicate.limitUnitRecount = function(maxCount, resetOnSpawn)
    if maxCount == nil then maxCount = 1 end
    if resetOnSpawn == nil then resetOnSpawn = false end

    local predTbl = { counted = {} }

    predTbl.triggered = function(unit)
        local unitKey = unit:getName()
        local curCount = predTbl.counted[unitKey]
        if curCount == nil then
            predTbl.counted[unitKey] = 1
        else
            predTbl.counted[unitKey] = curCount + 1
        end
    end

    pretTbl.pred = function(unit)
        local count = predTbl.counted[unit:getName()]
        return count == nil or count < maxCount
    end

    if resetOnSpawn then
        local resetCount = function(unitKey)
            predTbl.counted[unitKey] = nil
        end
        local eventHandler = {
            onEvent = function(self, event)
                if (event.id == world.event.S_EVENT_BIRTH) then
                    helms.util.safeCall(resetCount, { event.initiator:getName() }, helms.catchError)
                end
            end
        }
        world.addEventHandler(eventHandler)
    end

    return predTbl
end

helms.predicate.makeSpeedRange = function(minKt, maxKt)
    return function(unit)
        local v = unit:getVelocity()

        local kt = math.sqrt(helms.maths.dot2D(v, v)) / helms.maths.kts2mps

        return kt >= minKt and kt <= maxKt
    end
end

helms.predicate.makeAltRange = function(minFt, maxFt)
    return function(unit)
        local point = unit:getPoint()

        local alt = point.y * helms.maths.m2ft

        return alt >= minFt and alt <= maxFt
    end
end

helms.predicate.pnot = function(pred)
    return function(unit)
        return not pred(unit)
    end
end

helms.predicate.pand = function(...)
    return function(unit)
        for _, pred in pairs(arg) do
            if not pred(unit) then
                return false
            end
        end

        return true
    end
end

helms.predicate.por = function(...)
    return function(unit)
        for _, pred in pairs(arg) do
            if pred(unit) then
                return true
            end
        end

        return false
    end
end
----------------------------------------------------------------------------------------------------------
--DYNAMIC-------------------------------------------------------------------------------------------------
-- E.g. spawning units, setting tasking
helms.dynamic = {
    groupNameMap = {},       -- key = ME group name/ group name in spawn data, value = Name to use to spawn/respawn group
    groupNameMapReverse = {} --reverse lookup for groupNameMap
}

helms.dynamic.getGroupByName = function(name)
    local group = Group.getByName(name)
    if group ~= nil then return group end
    return Group.getByName(helms.dynamic.getGroupAlias(name))
end

helms.dynamic.getStaticByName = function(name)
    local group = StaticObject.getByName(name)
    if group ~= nil then return group end
    return StaticObject.getByName(helms.dynamic.getGroupAlias(name))
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
    for _, u in ipairs(gpData.units) do
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

--[[
Despawn group using its original name in the mission, supports despawning static groups.
--]]
helms.dynamic.despawnMEGroupByName = function(groupName)
    local gpData = helms.mission._GroupLookup[groupName]

    if not gpData then return end

    if not gpData.isStatic then
        helms.dynamic.despawnGroupByName(groupName)
    else
        local gpMeData = helms.mission.getMEGroupDataByName(groupName)

        if gpMeData.units then
            for k, v in pairs(gpMeData.units) do
                local group = helms.dynamic.getStaticByName(v.name)

                if group then group:destroy() end
            end
        end
    end
end

--[[
Despawn group using its name in-game (or alias, if spawned using HeLMS with an alias ). No support for despawning static groups.
--]]
helms.dynamic.despawnGroupByName = function(groupName)
    local group = helms.dynamic.getGroupByName(groupName)
    if group then group:destroy() end
end

helms.dynamic.allUnitPredicate = function(groupName, func)
    local group = helms.dynamic.getGroupByName(groupName)
    if group == nil then return true end

    local units = Group.getUnits(group)
    if units == nil then return true end

    for k, v in pairs(units) do
        if not func(v) then return false end
    end
    return true
end

helms.dynamic.respawnMEGroupByName = function(name, activate)
    local gpData = helms.mission.getMEGroupDataByName(name)
    if not gpData then return end

    if helms.mission.groupContainsClient_(gpData) then
        helms.log_e.log("Cannot respawn client group " .. name)
        return
    end

    local keys = helms.mission._GroupLookup[name]
    if not keys then return end
    if activate == nil or activate == true then
        gpData.lateActivation = false
    end

    local alias = helms.dynamic.getGroupAlias(name)
    if alias ~= nil then
        local existingGp = Group.getByName(name)
        if existingGp ~= nil then
            existingGp:destroy()
        end
        gpData.name = alias
    end

    if not keys.isStatic then
        helms.dynamic.normalizeUnitNames(gpData)
        coalition.addGroup(keys.ctryId, keys.catEnum, gpData)
    else
        if gpData.units then
            for k, v in pairs(gpData.units) do
                coalition.addStaticObject(keys.ctryId, v)
            end
        end
    end
end

helms.dynamic.respawnMEGroupsInZone = function(zoneName, activate, side, includeStatic)
    local names = helms.mission.getMEGroupNamesInZone(zoneName, side, includeStatic)
    if not names or #names == 0 then return end

    for k, name in pairs(names) do
        helms.dynamic.respawnMEGroupByName(name, activate)
    end
end

helms.dynamic.despawnMEGroupsInZone = function(zoneName, side, removeJunk, includeStatic)
    local names = helms.mission.getMEGroupNamesInZone(zoneName, side, includeStatic)
    if not names or #names == 0 then return end

    for k, name in pairs(names) do
        helms.dynamic.despawnMEGroupByName(name)
    end

    if removeJunk == nil or removeJunk then
        local zone = trigger.misc.getZone(zoneName)

        if zone then
            zone.point.y = land.getHeight(helms.maths.as2D(zone.point))
            world.removeJunk({
                id = world.VolumeType.SPHERE,
                params = zone
            })
        end
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
    --helms.log_i.log(groupData)
    local alias = helms.dynamic.getGroupAlias(groupData.name)
    if alias ~= nil then
        local existingGp = Group.getByName(groupData.name)
        if existingGp ~= nil then
            existingGp:destroy()
        end
        groupData.name = alias
    end

    if not keys.isStatic then
        helms.dynamic.normalizeUnitNames(groupData)
        coalition.addGroup(keys.ctryId, keys.catEnum, groupData)
    else
        coalition.addStaticObject(keys.ctryId, groupData)
    end
end

--[[
Return = Boolean: Does named group have a living active unit in-play
--]]
helms.dynamic.groupHasActiveUnit = function(groupName)
    local group = helms.dynamic.getGroupByName(groupName)

    if group then
        local units = Group.getUnits(group)
        if units then
            local unit = units[1]
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
helms.dynamic.getClosestLateralPlayer = function(groupName, sides, options)
    local playerUnits = {}
    if options == nil or type(options) ~= 'table' then
        options = {}
    end

    if type(sides) == 'number' then
        sides = { sides }
    end
    if type(sides) == 'table' then
        for _, side in pairs(sides) do
            for _, player in pairs(coalition.getPlayers(side)) do
                table.insert(playerUnits, player)
            end
        end
    end

    local ret = { nil, nil, nil } --default return	

    local group = helms.dynamic.getGroupByName(groupName)
    local units = {}

    if group ~= nil then
        units = group:getUnits()
    end


    local positions = {} -- {x,z},.... Indices correspond to indices in units
    for i, unit in ipairs(units) do
        local location = unit:getPoint()

        if not options.unitFilter or options.unitFilter(unit) then
            positions[i] = { location.x, location.z }
            if options.pickUnit then
                break
            end
        end
    end

    if options.useGroupStart then
        local points = helms.mission.getMEGroupPointsByName(groupName)
        --helms.log_i:info("group points: "..#points.." for "..groupName)--debug		
        if points and points[1] then
            positions[#units + 1] = { points[1].x, points[1].y }
        end
    end

    local preRet = nil --{best dist,player index,unit index}
    for i, punit in pairs(playerUnits) do
        local location = punit:getPoint()

        for j, pos in pairs(positions) do
            local dist2 = (pos[1] - location.x) ^ 2 + (pos[2] - location.z) ^ 2
            if preRet then
                if dist2 < preRet[1] then
                    preRet = { dist2, i, j }
                end
            else --initial pairs
                preRet = { dist2, i, j }
            end
        end
    end

    if preRet then
        ret = { math.sqrt(preRet[1]), playerUnits[preRet[2]], units[preRet[3]] }
    end
    --helms.log_e.log(ret)--debug
    return unpack(ret)
end

--[[
return (group, unit) for living unit in group of given name
--]]
helms.dynamic.getLivingUnits = function(groupName)
    local group = helms.dynamic.getGroupByName(groupName)
    local retUnits = {}
    if group ~= nil and Group.isExist(group) then
        local units = group:getUnits()
        for i, unit in pairs(units) do
            if unit:getLife() > 1.0 then
                table.insert(retUnits, unit)
            end
        end
    end
    return group, retUnits
end


--[[
return a float between 0 and 1 representing groups strength vs initial strength
--]]
helms.dynamic.getNormalisedGroupHealth = function(groupName, initialSize)
    local group = helms.dynamic.getGroupByName(groupName)

    if group ~= nil and Group.isExist(group) then
        if initialSize == nil then initialSize = group:getSize() end
        local accum = 0.0;
        local units = group:getUnits()
        for i, unit in pairs(units) do
            accum = accum + (unit:getLife() / math.max(1.0, unit:getLife0()))
        end
        return accum / math.max(1.0, initialSize)
    end
    return 0.0
end

--[[
return point,name,dist (m) of nearest airbase/farp etc (not ships), checks all permanent airbases and farps from side, if given
set friendlyOnly = true to only consider friendly bases
--]]
helms.dynamic.getNearestAirbase = function(point, side, friendlyOnly)
    local bases = helms.dynamic.getBaseList(side, friendlyOnly, false)
    local closestKey, closestDist = helms.dynamic.getKeyOfNearest2D(bases, point)

    if closestKey == nil then return nil, nil, nil end

    local closestBase = bases[closestKey]

    return closestBase:getPoint(), closestBase:getName(), closestDist
end

--[[
Get the key of the nearest object in objList to another given point
return key,dist
--]]
helms.dynamic.getKeyOfNearest2D = function(objList, point)
    local closestDist = math.huge
    local closestKey = nil
    for k, v in pairs(objList) do
        if math.abs(v:getPoint().x - point.x) < closestDist then --quick filter in just one direction to cut down distance calcs
            local newDist = helms.maths.get2DDist(v:getPoint(), point)
            if newDist < closestDist then
                closestDist = newDist
                closestKey = k
            end
        end
    end
    return closestKey, closestDist
end

--[[
Get the key of an object within a given distance laterally from a given point. For speed the L^\infinity metric is used.
Optional predicate can be specified.
Returns first example found, even if multiple exist
if no object is found, nil is returned, otherwise the key of the object is returned
--]]
helms.dynamic.getKeyOfObjWithin2D = function(objList, point, dist, predicate)
    point = helms.maths.as3D(point)
    for k, v in pairs(objList) do
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
helms.dynamic.getBaseList = function(farpSide, friendlyOnly, shipsAsFarps)
    local basesTemp = world.getAirbases()
    local bases = {}

    if farpSide == nil and not friendlyOnly then
        for k, v in pairs(basesTemp) do
            if (shipsAsFarps or not v:getUnit()) then
                table.insert(bases, v)
            end
        end
    elseif farpSide ~= nil and friendlyOnly then
        for k, v in pairs(basesTemp) do
            if (shipsAsFarps or not v:getUnit()) and v:getCoalition() == farpSide then
                table.insert(bases, v)
            end
        end
    elseif farpSide ~= nil then
        for k, v in pairs(basesTemp) do
            --fixed airbases only (no associated unit), and only friendly farps
            if (shipsAsFarps or not v:getUnit()) and (v:getCoalition() == farpSide or v:getDesc().category == Airbase.Category.AIRDROME) then
                table.insert(bases, v)
            end
        end
    end
    --helms.log_i.log(bases) --debug
    return bases
end

helms.dynamic.landTypeUnderUnit = function(unit)
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

helms.dynamic.scheduleFunction = function(f, argPack, t, once)
    if not argPack then argPack = {} end
    timer.scheduleFunction(helms.dynamic._scheduleFunctionWrapper, { f = f, args = argPack, once = once }, t)
end

helms.dynamic.scheduleFunctionSafe = function(f, argPack, t, once, errorHandler)
    if not argPack then argPack = {} end
    timer.scheduleFunction(helms.util.safeCallWrap(helms.dynamic._scheduleFunctionWrapper, errorHandler),
        { f = f, args = argPack, once = once }, t)
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

--[[
	Wrapper for helms.ai.clearTasks for backwards compatibility
--]]
helms.dynamic.clearTasks = function(groupName)
    helms.ai.clearTasks(groupName)
end

--[[

--]]
helms.dynamic.setRandomFlags = function(N, toVal, ...)
    local selection = helms.util.removeRandom(arg, N)

    for k, v in pairs(selection) do
        trigger.action.setUserFlag(v, toVal)
    end
end

----------------------------------------------------------------------------------------------------------
-- AI ----------------------------------------------------------------------------------------------------

helms.ai = {}

helms.ai._getController = function(groupName)
    local group = helms.dynamic.getGroupByName(groupName)
    local controller = nil

    if group ~= nil then
        controller = group:getController()
    end
    return controller, group
end

--[[
	Clear tasks for a named group
--]]
helms.ai.clearTasks = function(groupName)
    local controller = helms.ai._getController(groupName)

    if controller ~= nil then
        controller:setTask({ id = 'NoTask', params = {} })
    end
end

--[[
	Set alarm state for named group

	alarm state should be an AI.Option.Ground.val.ALARM_STATE value, e.g. AI.Option.Ground.val.ALARM_STATE.RED
--]]
helms.ai.setAlarmState = function(groupName, alarmState)
    local controller = helms.ai._getController(groupName)

    if controller ~= nil then
        controller:setOption(AI.Option.Ground.id.ALARM_STATE, alarmState)
    end
end

--[[
	Set alarm state for groups with name containing a substring

	alarm state should be an AI.Option.Ground.val.ALARM_STATE value, e.g. AI.Option.Ground.val.ALARM_STATE.RED
--]]
helms.ai.setAlarmStateIfNameContains = function(groupNameContains, alarmState)
    helms.mission.execForGroupNamesContaining(helms.ai.setAlarmState, groupNameContains, alarmState)
end

--[[
	Set immortal flag for named group
--]]
helms.ai.setImmortal = function(groupName, immortal)
    local controller = helms.ai._getController(groupName)

    if controller ~= nil then
        controller:setCommand({
            id = 'SetImmortal',
            params = {
                value = immortal
            }
        })
    end
end

----------------------------------------------------------------------------------------------------------
-- EFFECTS ----------------------------------------------------------------------------------------------------
helms.effect = {}

helms.effect._smokes = {} -- keys: integer for non-zone linked effects, string (zone name) for zone-linked effects
helms.effect._smokeRefreshSeconds = 300
helms.effect._minimumBorderSmokes = 4
helms.effect._defaultBorderSmokes = 8
helms.effect._minStrobeTime = 0.2

--[[
Create smoke with auto-refresh at a given point and colour ("red","green","blue","white", or "orange")
If replaceHandle is specified, the smoke replaces an existing smoke effect

Returns a handle to use with startSmoke or stopSmoke. (This is replaceHandle, if specified)
]]
helms.effect.startSmoke = function(point, colour, replaceHandle)
    return helms.effect.startSmokePoints_({ { point = point, colour = colour } }, replaceHandle)
end


helms.effect.startSmokePoints_ = function(pointcolours, replaceHandle)
    if replaceHandle == nil then
        replaceHandle = #helms.effect._smokes + 1
    end

    local pcRefined = {}

    for k, p in pairs(pointcolours) do
        local colour = helms.effect._stringToSmokeColour(p.colour)

        if not colour then
            helms.log_e.log("Smoke colour " .. p.colour .. " invalid")
            return nil
        end

        local p3 = helms.maths.as3DHeight(p.point, 0)

        pcRefined[k] = { point = p3, colour = colour }
    end

    if not helms.effect._smokes[replaceHandle] then
        helms.dynamic.scheduleFunctionSafe(
            helms.effect._refreshSmoke,
            { replaceHandle },
            timer.getTime() + 1,
            false,
            helms.catchError)
    else
        helms.log_i.log("Smoke " .. replaceHandle .. " updated")
    end

    helms.effect._smokes[replaceHandle] = pcRefined

    return replaceHandle
end

helms.effect.startSmokeOnZone = function(zoneName, colour, borderColour, borderSmokes)
    if not zoneName then return end

    local zone = trigger.misc.getZone(zoneName)

    if not zone then
        helms.log_e.log("Zone " .. zoneName .. " not valid")
        return nil
    end

    local zoneCtr = zone.point
    local zoneRad = zone.radius

    local pointcolours = {}

    if borderColour ~= nil then
        if borderSmokes == nil then
            borderSmokes = helms.effect._defaultBorderSmokes
        elseif borderSmokes < helms.effect._minimumBorderSmokes then
            borderSmokes = helms.effect._minimumBorderSmokes
        end

        for _, p in pairs(helms.maths.pointsCircleBorder(zoneRad, zoneCtr, borderSmokes)) do
            pointcolours[#pointcolours + 1] = { point = p, colour = borderColour }
        end
    end

    if colour ~= nil then
        pointcolours[#pointcolours + 1] = { point = zoneCtr, colour = colour }
    end

    if pointcolours then
        helms.effect.startSmokePoints_(pointcolours, zoneName)
        return zoneName
    end

    return nil
end

--[[
Use replaceHandle = zone name to stop refreshing smoke added on a zone
]]
helms.effect.stopSmoke = function(replaceHandle)
    if helms.effect._smokes[replaceHandle] then
        helms.effect._smokes[replaceHandle] = nil
        helms.log_i.log("Smoke " .. replaceHandle .. " stopped")
    else
        helms.log_i.log("Zone " .. replaceHandle .. " not valid, or already stopped")
    end
end

helms.effect.stopSmokeOnZone = function(zoneName)
    helms.effect.stopSmoke(zoneName)
end

helms.effect._refreshSmoke = function(handle)
    if handle == nil or not helms.effect._smokes[handle] then
        return
    end

    local smokeData = helms.effect._smokes[handle]

    for _, pc in pairs(smokeData) do
        trigger.action.smoke(pc.point, pc.colour)
    end

    helms.log_i.log("Smoke " .. handle .. " (re)started")

    return timer.getTime() + helms.effect._smokeRefreshSeconds
end

helms.effect._stringToSmokeColour = function(str)
    local lookup =
    {
        ["blue"] = trigger.smokeColor.Blue,
        ["green"] = trigger.smokeColor.Green,
        ["red"] = trigger.smokeColor.Red,
        ["white"] = trigger.smokeColor.White,
        ["orange"] = trigger.smokeColor.Orange,
    }

    return lookup[string.lower(str)]
end
------------------------
-- IR strobes
helms.effect._IrStrobes = {} -- key = object name,val = {displace, onTimeS,offTimeS, strobeObj, startTime} 
helms.effect._IrStrobeNextID = 0
helms.effect._StrobePosUpdateTimeMinS = 0.15
helms.effect._StrobePosUpdateDistM = 20

-- Start IR strobe on an object
helms.effect._startIrStrobeOnObject = function(obj, displace, onTimeS, offTimeS, spotUpdateTimeS)
    if obj == nil then
        return
    end

    local name = Object.getName(obj)
    local now = timer.getTime()
    local newID = helms.effect._IrStrobeNextID

    if helms.effect._IrStrobes[name] ~= nil then
        helms.effect._stopIrStrobeOnObject(name)
    end

    if displace == nil then
         displace = {x = 0, y = 0, z = 0}
    else
        displace = helms.maths.as3D(displace) -- fail at this point if format invalid
    end
    displace.y = displace.y + obj:getDesc().box.max.y

    if onTimeS == nil or onTimeS < helms.effect._minStrobeTime then
        onTimeS = helms.effect._minStrobeTime
    end

    if offTimeS == nil or offTimeS < 0 then
        offTimeS = 0
    elseif offTimeS < helms.effect._minStrobeTime then
        offTimeS = helms.effect._minStrobeTime
    end

    helms.effect._IrStrobes[name] = {displace = displace, onTimeS = onTimeS, offTimeS = offTimeS, irStrobeID = newID, objHost = obj}
    helms.effect._IrStrobeNextID = newID + 1

    helms.dynamic.scheduleFunction(helms.effect._pollIrStrobe, {name, newID}, now + 1, false)
    if type(spotUpdateTimeS) == 'number'  then

        if (spotUpdateTimeS < helms.effect._StrobePosUpdateTimeMinS) then 
            spotUpdateTimeS = helms.effect._StrobePosUpdateTimeMinS 
        end
        
        helms.effect._IrStrobes[name].spotUpdateTimeS = spotUpdateTimeS

        helms.dynamic.scheduleFunction(
            helms.effect._pollIrStrobeUpdateUnitPos, {name, newID}, now + spotUpdateTimeS , false)
    end

end

-- Stop IR strobe on a named object
helms.effect._stopIrStrobeOnObject = function(name)

    local irs = helms.effect._IrStrobes[name] 
    if irs ~= nil and irs.strobeObj ~= nil then
        irs.strobeObj:destroy()
    end

    helms.effect._IrStrobes[name] = nil
end

-- Poll IR strobe (either enabling the strobe, or called repeatedly to flash it)
helms.effect._pollIrStrobe= function(name, strobeId)
    if name == nil then
        return nil
    end

    local irs = helms.effect._IrStrobes[name] 

    if irs == nil or irs.irStrobeID ~= strobeId then
        return nil
    end

    local nextPollInS  = nil

    if (irs.strobeObj ~= nil) then

        irs.strobeObj:destroy()
        irs.strobeObj = nil
        nextPollInS = irs.offTimeS
    else

        local obj = irs.objHost

        local objPos = obj:getPosition()

        local spotPoint = helms.maths.objLocalToGlobal(irs.displace,objPos)

        irs.strobeObj = Spot.createInfraRed(obj, irs.displace, spotPoint)--helms.maths.lin3D(objPos.p,-1,spotPoint,1), spotPoint)
        nextPollInS = irs.onTimeS
    end

    if irs.offTimeS > 0 and nextPollInS > 0 then
        return timer.getTime() + nextPollInS
    else
        return nil
    end
end

-- Poll IR strobe (either enabling the strobe, or called repeatedly to flash it)
helms.effect._pollIrStrobeUpdateUnitPos= function(name, strobeId)
    if name == nil then
        return nil
    end

    local irs = helms.effect._IrStrobes[name] 

    if irs == nil or irs.irStrobeID ~= strobeId then
        return nil
    end

    if irs.strobeObj ~= nil then

        local obj = irs.objHost

        local objPos = obj:getPosition()

        local spotPoint = helms.maths.objLocalToGlobal(irs.displace,objPos)

        irs.strobeObj:setPoint(spotPoint)
    end

    return timer.getTime() + irs.spotUpdateTimeS
end

--[[
-- Start IR strobe effect on a static object
-- @staticName = name of the static unit (not group name)
-- @displace = Vec3 - displacement of the strobe from the top-centre of the object's collision box (optional)
-- onTimeS  = time of the "on" duty cycle of the flashing strobe (optional - strobe fixed on if omitted)
-- offTimeS = tiem of "off" duty cycle (optional - strobe fixed on if omitted)
--]]
helms.effect.startIrStrobeOnStatic = function(staticName, displace, onTimeS, offTimeS)

    local obj = StaticObject.getByName(staticName)
    if obj == nil then 
        helms.log_i.log("Static " .. staticName .." not found for placing IR strobe")
        return
    end

    helms.effect._startIrStrobeOnObject(obj, displace, onTimeS, offTimeS)

end

--[[
-- Stop existing IR strobe effect on named static unit
-- @staticName = object/unit name
--]]
helms.effect.stopIrStrobeOnStatic = function(staticName)

    local obj = StaticObject.getByName(staticName)
    if obj == nil then 
        helms.log_i.log("Static " .. staticName .." not found for stopping IR strobe")
        return
    end

    local name = Object.getName(obj)

    helms.effect._stopIrStrobeOnObject(name)

end

--[[
-- Start IR strobe effect on a unit
-- @unitName = name of the unit (not group name)
-- @displace = Vec3 - displacement of the strobe from the top-centre of the object's collision box (optional)
-- onTimeS  = time of the "on" duty cycle of the flashing strobe (optional - strobe fixed on if omitted)
-- offTimeS = tiem of "off" duty cycle (optional - strobe fixed on if omitted)
--]]
helms.effect.startIrStrobeOnUnit = function(unitName, displace, onTimeS, offTimeS, movingUnit)

    local obj = Unit.getByName(unitName)
    if obj == nil then 
        helms.log_i.log("Unit " .. unitName .." not found for placing IR strobe")
        return
    end

    local posTime =  nil

    if movingUnit then
        posTime = helms.mission.getUnitSpeed(obj,100)
    end

    if posTime ~= nil then
        posTime = helms.effect._StrobePosUpdateDistM / posTime
    end

    helms.effect._startIrStrobeOnObject(obj, displace, onTimeS, offTimeS, posTime)

end

--[[
-- Stop existing IR strobe effect on named unit
-- @unitName = object/unit name
--]]
helms.effect.stopIrStrobeOnUnit = function(unitName)

    local obj = Unit.getByName(unitName)
    if obj == nil then 
        helms.log_i.log("Unit " .. unitName .." not found for stopping IR strobe")
        return
    end

    local name = Object.getName(obj)

    helms.effect._stopIrStrobeOnObject(name)

end
----------------------------------------------------------------------------------------------------------
--UI------------------------------------------------------------------------------------------------------
-- E.g. messages to users, comms management, string conversions etc.

helms.ui = {}

--[[
Print message to the given coalition.side, or to all players if side==nil
cls is optional - if true, the screen is cleared
--]]
helms.ui.messageForCoalitionOrAll = function(side, message, delay, cls)
    if side then
        trigger.action.outTextForCoalition(side, message, delay, cls)
    else
        trigger.action.outText(message, delay, cls)
    end
end

-- String conversions-------------------------------------------------------------------------------------
helms.ui.convert = {}

helms.ui.convert.stringToSide = function(name)
    if name ~= nil then
        name = string.lower(name) --remove case sensitivity
    end
    if name == "red" then
        return coalition.side.RED
    elseif name == "blue" then
        return coalition.side.BLUE
    elseif name == "neutral" then
        return coalition.side.NEUTRAL
    end --else nil
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
    return string.format("%02d%02dL", dhms["h"], dhms["m"])
end

helms.ui.convert.getDHMS = function(seconds)
    if seconds then
        return {
            d = math.floor(seconds / 86400),
            h = math.floor(seconds / 3600),
            m = math.floor(seconds / 60),
            s =
                seconds % 60
        }
    end
end
--[[
	Format decimal angle in tegrees to deg, decimal minutes format
--]]
helms.ui.convert.formatDegMinDec = function(degrees, posPrefix, negPrefix)
    local prefix = posPrefix
    if (degrees < 0) then prefix = negPrefix end
    degrees = math.abs(degrees)
    local whole = math.floor(degrees)
    local minutes = 60 * (degrees - whole)

    return string.format("%s %d°%.2f'", prefix, whole, minutes)
end

helms.ui.convert.pos2LL = function(pos)
    local lat, lon, _ = coord.LOtoLL(pos)
    return string.format("%s %s", helms.ui.convert.formatDegMinDec(lat, "N", "S"),
        helms.ui.convert.formatDegMinDec(lon, "E", "W"))
end

--[[
	positive int to "base 26" conversion
--]]
helms.ui.convert.toAlpha = function(n)
    local lookup = { "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T",
        "U", "V", "W", "X", "Y", "Z" }
    local ret = ""
    while (n > 0) do
        local digit = n % 26
        if digit == 0 then
            digit = 26
        end
        ret = lookup[digit] .. ret
        n = (n - digit) / 26
    end
    return ret
end

--[[
convert heading to octant string e.g. "North", "Northeast" etc
hdg must be in the range  0 -360
--]]
helms.ui.convert.hdg2Octant = function(hdg)
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
helms.ui.convert.MakeAbToPointDescriptor = function(point, side)
    local abPoint, abName, meters = helms.dynamic.getNearestAirbase(point, side)
    if not abPoint then return "??" end
    return string.format("%s of %s", helms.ui.convert.MakePointToPointDescriptor(abPoint, point), abName)
end

--[[
Describe point b from point a with distance and octant e.g. "8km South"
distance defaults to true. Indicates whether to include distance info
--]]
helms.ui.convert.MakePointToPointDescriptor = function(pointA, pointB, distance)
    local octant = helms.ui.convert.hdg2Octant(helms.maths.getHeading(pointA, pointB))
    if distance or distance == nil then
        local meters = helms.maths.get2DDist(pointA, pointB)
        if meters >= 10000 then
            return string.format("%.0fkm %s", meters / 1000, octant)
        elseif meters >= 1000 then
            return string.format("%.1fkm %s", meters / 1000, octant)
        else
            return string.format("%.0fm %s", meters, octant)
        end
    else
        return string.format("%s", octant)
    end
end

--[[
return ETA for following a straight path between two points at a given estimated speed
--]]
helms.ui.convert.getETAString = function(point1, point2, estMps)
    if estMps == nil or estMps <= 0 then return "unknown" end

    local ttg = helms.maths.get3DDist(point1, point2) / estMps
    local etaAbs = timer.getAbsTime() + ttg
    local dhms = helms.ui.convert.getDHMS(etaAbs)
    return string.format("%02d%02dL", dhms["h"], dhms["m"])
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

helms.ui.ensureDefaultSubmenu = function(side)
    if side and side ~= coalition.side.NEUTRAL then --coalition specific addition	
        return helms.ui.ensureSubmenu(side, "Assets", true)
    else                                            --add for all	
        return helms.ui.ensureSubmenu(nil, "Other Assets")
    end
end

--[[
Get page with space in comms submenu with given text label, relative to parent path or side
parentMenuPath = coalition.side, nil for neutral, or object returned by previous call or nil. If included specifies the submenu to add the new menu to, side is inferred from parent.
label = radio item text
prependCoa (bool) = if true, add coalition name to label text

returns: path - a path table for future calls to ensureSubmenu, addCommand, etc.
		 <unused>
		 subMenuAdded - indicates if a new menu option was added. I.e. this submenu did not already exist.
--]]
helms.ui.ensureSubmenu = function(parentMenuPath, label, prependCoa)
    local retPath = {}
    if type(parentMenuPath) == "table" then
        retPath = helms.util.shallow_copy(parentMenuPath)
    end

    local parentCommsMenusBase, side, dcsParentPath, _ = helms.ui.unpackCommsPath_(parentMenuPath)
    local parentCommsMenus
    if parentCommsMenusBase then
        parentCommsMenus = parentCommsMenusBase.childItems
    else
        parentCommsMenus = helms.ui.commsMenus_
    end

    local menuNameRootText = label
    local menuNameRoot = label .. helms.ui.convert.sideToString(side)
    if prependCoa then
        menuNameRootText = helms.ui.convert.sideToString(side) .. " " .. menuNameRootText
    end
    local menuName = menuNameRoot
    local subMenuAdded = false

    local menu
    if parentCommsMenus[menuName] == nil then --create submenu
        menu, _, dcsParentPath = helms.ui.getPageWithSpace_(parentCommsMenusBase, retPath)
        local menuItems = parentCommsMenus

        if menu then menuItems = menu.childItems end
        if side then
            menuItems[menuName] = {
                itemCount = 0,
                dcsPath = missionCommands.addSubMenuForCoalition(side, menuNameRootText, dcsParentPath),
                childItems = {},
                coa = side
            }
        else
            menuItems[menuName] = {
                itemCount = 0,
                dcsPath = missionCommands.addSubMenu(menuNameRootText, dcsParentPath),
                childItems = {},
                coa = nil
            }
        end
        if menu then
            menu.itemCount = menu.itemCount + 1
        end
        subMenuAdded = true
        retPath[#retPath + 1] = menuName
    else
        retPath[#retPath + 1] = menuName
        menu, _, _ = helms.ui.getPageWithSpace_(parentCommsMenus[menuName], retPath)
    end

    return retPath, nil, subMenuAdded
end

helms.ui.getPageWithSpace_ = function(commsMenus, pathBuilder)
    if commsMenus == nil then
        return nil, {}, nil
    end
    if pathBuilder == nil then pathBuilder = {} end
    while commsMenus.itemCount >= 9 do --create overflow if no space here
        local newMenuName = "__NEXT__"
        local side = commsMenus.coa
        if commsMenus.childItems[newMenuName] == nil then --create submenu of menu at menuName
            if side then
                commsMenus.childItems[newMenuName] = {
                    itemCount = 0,
                    dcsPath = missionCommands.addSubMenuForCoalition(side, "Next", commsMenus.dcsPath),
                    childItems = {},
                    coa = side
                }
            else
                commsMenus.childItems[newMenuName] = {
                    itemCount = 0,
                    dcsPath = missionCommands.addSubMenu("Next", commsMenus.dcsPath),
                    childItems = {},
                    coa = nil
                }
            end
        end
        commsMenus = commsMenus.childItems[newMenuName]
        pathBuilder[#pathBuilder + 1] = newMenuName
    end
    return commsMenus, pathBuilder, commsMenus.dcsPath
end

helms.ui.unpackCommsPath_ = function(parentMenuPath, upLevels)
    local dcsParentPath = nil
    local parentCommsMenus = nil
    local side = nil
    local nextItemKey = nil

    if parentMenuPath ~= nil and type(parentMenuPath) == "table" then
        local maxKey = #parentMenuPath
        if upLevels ~= nil then
            maxKey = maxKey - upLevels
        end

        for k, v in ipairs(parentMenuPath) do
            if k > maxKey then
                nextItemKey = v
                break
            elseif k > 1 then
                if parentCommsMenus.childItems and parentCommsMenus.childItems[v] then
                    parentCommsMenus = parentCommsMenus.childItems[v]
                end
            else -- parentCommsMenus = helms.ui.commsMenus_
                parentCommsMenus = helms.ui.commsMenus_[v]
            end
        end
        if parentCommsMenus then
            dcsParentPath = parentCommsMenus.dcsPath
            side = parentCommsMenus.coa
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
helms.ui.addCommand = function(parentMenuPath, label, handler, ...)
    local parentCommsMenus, side, dcsParentPath, _ = helms.ui.unpackCommsPath_(parentMenuPath)
    parentCommsMenus, _, dcsParentPath             = helms.ui.getPageWithSpace_(parentCommsMenus)

    if parentCommsMenus == nil then
        helms.log_e.log("Could not add comms menu " .. label)
        return
    end

    local newDcsPath
    if side then
        newDcsPath = missionCommands.addCommandForCoalition(side, label,
            dcsParentPath,
            handler, unpack(arg))
    else
        newDcsPath = missionCommands.addCommand(label,
            dcsParentPath,
            handler, unpack(arg))
    end

    local newIndex = parentCommsMenus.itemCount + 1
    parentCommsMenus.itemCount = newIndex
    parentCommsMenus.childItems[newIndex] = newDcsPath
    return newIndex
end

helms.ui.removeItem = function(parentMenuPath, itemIndex)
    local parentCommsMenus, side, dcsParentPath, _ = helms.ui.unpackCommsPath_(parentMenuPath)

    if parentCommsMenus ~= nil then
        local path
        if itemIndex ~= nil then
            path = parentCommsMenus.childItems[itemIndex]
            if path ~= nil then
                parentCommsMenus.childItems[itemIndex] = nil
                parentCommsMenus.itemCount = parentCommsMenus.itemCount - 1
            end
        else -- remove parent menu
            path = dcsParentPath
            local parent2CommsMenus, _, _, nextKey = helms.ui.unpackCommsPath_(parentMenuPath, 1)
            if parent2CommsMenus ~= nil and nextKey ~= nil then
                parent2CommsMenus.childItems[nextKey] = nil
                parent2CommsMenus.itemCount = parent2CommsMenus.itemCount - 1
            end
        end

        if path ~= nil and side == nil then
            missionCommands.removeItem(path)
        elseif path ~= nil then
            missionCommands.removeItemForCoalition(side, path)
        end
    end
end

helms.ui._renderedDrawingIds = {}     -- key = name, value = {id = ,active = }
helms.ui._renderedZoneDrawingIds = {} -- key = zoneName, value = {id = ,active = } (matches _renderedDrawingIds)

helms.ui._nextRenderedDrawingId = nil

helms.ui.drawingShapeType = 
{
    line = 1,
    circle = 2,
    text = 5,
    polygon = 7
}

helms.ui.drawingLineType = 
{
    none = 0,
    solid = 1,
    dashed = 2,
    dotted = 3,
    dotdash = 4,
    longdash = 5,
    twodash = 6
}

--[[
Show named ME drawing for coalition
--]]
helms.ui.showDrawing = function(drawingName, coalition)
    local current = helms.ui._renderedDrawingIds[drawingName]
    if current ~= nil and current.active == true then return end

    local drawings = helms.mission._getDrawingList()
    local meDrawing = drawings[drawingName]

    helms.ui._renderedDrawingIds[drawingName] = helms.ui._doShowDrawing(meDrawing,coalition)
end

--[[
Show named zone as drawing for coalition.
`opts` = {lineHexRgba = ..., fillHexRgba = ..., lineType = ...} or nil
--]]
helms.ui.showZoneAsDrawing = function(zoneName, coalition, opts)
    local current = helms.ui._renderedZoneDrawingIds[zoneName]
    if current ~= nil and current.active == true then return end

    local meZoneData = helms.mission.getMeZoneData(zoneName)
    if not meZoneData then
        helms.log_i.log({"No mission data for zone",zoneName, meZoneData})
        return
    end

    -- default opts
    if not opts then
        opts = {}
    end

    if not opts.lineHexRgba then 
        opts.lineType = helms.ui.drawingLineType.none 
    elseif not opts.lineType then
        opts.lineType = helms.ui.drawingLineType.solid 
    end

    local drawData = {
        colour = helms.util.hexToRgba(opts.lineHexRgba), 
        lineType = opts.lineType
    }

    -- Use ME zone colour, if not overridden in opts
    if (opts.fillHexRgba == nil) and (meZoneData.color) then
        drawData.fillColour = meZoneData.color
    else
        drawData.fillColour = helms.util.hexToRgba(opts.fillHexRgba)
    end

    if meZoneData.type == helms.mission.zoneTypes['Quad'] and meZoneData.verticies then
        drawData.shapeId = helms.ui.drawingShapeType.polygon
        drawData.points = helms.util.fmap(meZoneData.verticies, helms.maths.as3D) -- Zone centre is 2d format, drawings use x-z
    elseif meZoneData.x and meZoneData.y and meZoneData.radius then
        drawData.shapeId = helms.ui.drawingShapeType.circle
        drawData.points = {helms.maths.as3D(meZoneData)}
        drawData.radius = meZoneData.radius
    else
        helms.log_i.log({"Mission data invalid for zone",zoneName, meZoneData})
        return
    end

    -- Moving zones not yet supported - initial position always used
    -- helms.log_i.log({"Showing Zone",zoneName,coalition, drawData, meZoneData})
    helms.ui._renderedZoneDrawingIds[zoneName] = helms.ui._doShowDrawing(drawData,coalition)
end

helms.ui._doShowDrawing = function(drawingData, coalition)

    if helms.ui._nextRenderedDrawingId == nil then
        -- Needs to be deconflicted from F10 map marks and other drawings
        -- But there may be ways to improve this
        helms.ui._nextRenderedDrawingId = 2 * #(helms.mission._getDrawingList()) + 1
    end

    local id = helms.ui._nextRenderedDrawingId
    local idAlt = id

    if drawingData == nil then return end

    if coalition == nil then coalition = drawingData.coalition end
    if coalition == nil then coalition = -1 end --final fallback - all

    if drawingData.shapeId == helms.ui.drawingShapeType.line then --Line
        trigger.action.markupToAll(
            helms.util.multiunpack(
                { drawingData.shapeId, coalition, id }, drawingData.points,
                { drawingData.colour, drawingData.fillColour, drawingData.lineType }))
    elseif drawingData.shapeId == helms.ui.drawingShapeType.circle then -- Circle
        trigger.action.circleToAll(
            helms.util.multiunpack(
                { coalition, id }, drawingData.points,
                { drawingData.radius, drawingData.colour, drawingData.fillColour, drawingData.lineType }))
    elseif drawingData.shapeId == helms.ui.drawingShapeType.text then -- Text
        trigger.action.markupToAll(
            helms.util.multiunpack(
                { drawingData.shapeId, coalition, id }, drawingData.points,
                { drawingData.colour, drawingData.fillColour, drawingData.fontSize, true, drawingData.text }))
    elseif drawingData.shapeId == helms.ui.drawingShapeType.polygon then -- Polygon
        -- Draw forward and reverse vertex order, reducing artefacts caused by backface culling
        trigger.action.markupToAll(
            helms.util.multiunpack(
                { drawingData.shapeId, coalition, id }, drawingData.points,
                { drawingData.colour, drawingData.fillColour, drawingData.lineType }))

        idAlt = id + 1
        trigger.action.markupToAll(
            helms.util.multiunpack(
                { drawingData.shapeId, coalition, idAlt }, helms.util.reverse(drawingData.points),
                { drawingData.colour, drawingData.fillColour, drawingData.lineType }))
    end

    helms.ui._nextRenderedDrawingId = idAlt + 1
    return { id = id, idAlt = idAlt, active = true }
end

helms.ui.removeDrawing = function(drawingName)
    local current = helms.ui._renderedDrawingIds[drawingName]

    helms.ui._removeDrawingObj(current)
end

helms.ui.removeZoneDrawing = function(zoneName)
    local current = helms.ui._renderedZoneDrawingIds[zoneName]

    helms.ui._removeDrawingObj(current)
end

--[[
Private: Hide a drawing, given its entry from _renderedDrawingIds
--]]
helms.ui._removeDrawingObj = function(obj)
    if obj ~= nil and obj.active == true and obj.id ~= nil then
        trigger.action.removeMark(obj.id)

        if obj.idAlt ~= obj.id then
            trigger.action.removeMark(obj.idAlt)
        end

        obj.active = false
    end
end

-- shortcuts for easier use in ME scripts
helms.ui.combo = { registered = {} }

helms.ui.combo.commsCallback = function(side, menuLabel, optionLabel, callback, ...)
    local parentMenuPath, _ = helms.ui.ensureSubmenu(side, menuLabel)

    if menuLabel ~= nil and optionLabel ~= nil and callback ~= nil and type(callback) == "function" then
        local sideKey = side
        if sideKey == nil then sideKey = "nil" end
        if not helms.ui.combo.registered[sideKey] then helms.ui.combo.registered[sideKey] = {} end
        if not helms.ui.combo.registered[sideKey][menuLabel] then helms.ui.combo.registered[sideKey][menuLabel] = {} end

        if helms.ui.combo.registered[sideKey][menuLabel][optionLabel] ~= nil then
            helms.ui.combo.removeCommsCallback(side, menuLabel, optionLabel)
        end

        local handle = { parentMenuPath, helms.ui.addCommand(parentMenuPath, optionLabel,
            helms.util.safeCallWrap(callback, helms.catchError), unpack(arg)) }

        helms.ui.combo.registered[sideKey][menuLabel][optionLabel] = handle

        return handle
    else
        helms.log_e.log("Invalid arguments for helms.ui.combo.commsCallback")
    end
end

helms.ui.combo.removeCommsCallback = function(side, menuLabel, optionLabel)
    local handlePack = nil

    local sideKey = side
    if sideKey == nil then sideKey = "nil" end

    if helms.ui.combo.registered[sideKey]
        and helms.ui.combo.registered[sideKey][menuLabel] then
        handlePack = helms.ui.combo.registered[sideKey][menuLabel][optionLabel]
    end

    if not handlePack or #handlePack < 2 then
        helms.log_e.log("Invalid comms handle pack")
    end

    return helms.ui.removeItem(unpack(handlePack))
end

-- UI.SCOREBOARD
helms.ui.scoreboard = {
    nextPrintTime = 0
    ,
    scoreboardLooping = false
    ,
    gameCount = 0
}

helms.ui.scoreboard.printIntervalSeconds = 60
helms.ui.scoreboard.messageDisplaySeconds = 10
helms.ui.scoreboard.clearScreen = false

helms.ui.scoreboard.games = {} -- handle = {name= string, scoreCallback = function, tagCallback, hintCallback}

-- Start a scoreboard that is periodically displayed until helms.ui.scoreboard.endGame is called
-- handle - used to refer to this game later (in endGame)
-- name - Display name of this game (displayed if multiple scoreboards are active)
-- scoreCallback = function() - returns {["TeamName"] = Score/string}
-- tagCallback (optional) = function() - returns  a tag for the end opf the score line
-- hintCallback (optional) = function() - returns hint line to print after the score
helms.ui.scoreboard.startGame = function(handle, name, scoreCallback, tagCallback, hintCallback)
    if helms.ui.scoreboard.games[handle] then
        return
    end

    helms.ui.scoreboard.gameCount = helms.ui.scoreboard.gameCount + 1
    helms.ui.scoreboard.games[handle] = {
        name = name,
        scoreCallback = scoreCallback,
        tagCallback = tagCallback,
        hintCallback =
            hintCallback
    }

    if not helms.ui.scoreboard.scoreboardLooping then
        helms.ui.scoreboard.scoreboardLooping = true

        helms.dynamic.scheduleFunction(helms.ui.scoreboard.printLoop, nil, timer.getTime() + 1, false)
    end
end

helms.ui.scoreboard.endGame = function(handle, message)
    if not helms.ui.scoreboard.games[handle] then
        return
    end

    if message then
        helms.ui.messageForCoalitionOrAll(nil, message, helms.ui.scoreboard.messageDisplaySeconds)
    end

    helms.ui.scoreboard.gameCount = helms.ui.scoreboard.gameCount - 1
    helms.ui.scoreboard.games[handle] = nil
end

helms.ui.scoreboard.printLoop = function()
    if not helms.ui.scoreboard.games then
        helms.ui.scoreboard.scoreboardLooping = false
        return
    end

    local printScoreLine = function(game)
        if not game.scoreCallback then
            return
        end

        local segs = {}

        local teamScores = game.scoreCallback()
        for k, v in pairs(teamScores) do
            segs[#segs + 1] = k .. ": " .. v
        end

        if game.tagCallback then
            local tag = game.tagCallback()
            if tag then
                segs[#segs + 1] = tag
            end
        end

        game.msgLines[#game.msgLines + 1] = helms.util.strJoin(" | ", segs)
    end

    local printHintLine = function(game)
        if not game.hintCallback then
            return
        end
        game.msgLines[#game.msgLines + 1] = game.hintCallback()
    end

    local now = timer.getTime()

    local showGameNames = helms.ui.scoreboard.gameCount > 1
    local clearScreen = helms.ui.scoreboard.clearScreen

    for _, game in pairs(helms.ui.scoreboard.games) do
        game.msgLines = {}

        if showGameNames then
            game.msgLines = { game.name }
        end

        helms.util.safeCall(printScoreLine, { game }, helms.catchError)
        helms.util.safeCall(printHintLine, { game }, helms.catchError)

        if game.msgLines then
            helms.ui.messageForCoalitionOrAll(nil, helms.util.strJoin("\n", game.msgLines),
                helms.ui.scoreboard.messageDisplaySeconds, clearScreen)
            clearScreen = false
        end
    end

    helms.ui.nextPrintTime = now + helms.ui.scoreboard.printIntervalSeconds

    return helms.ui.nextPrintTime
end

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
-- Events

helms.events = {
    hitLoggingEnabled_ = false,
    lastHitBy_ = {}, -- key = unit name, value = {time = time last hit, initiatorName = name of unit that initiated the hit, spawnCount = ...}
                                --, friendly fire not counted
    lastSpawn_ = {}, -- key = unit name, value = {time = .., playerName = ..., spawnCount = ...}
    unitDeathTracked_ = {}, -- key == unit Name, value = bool (death notified)
    unitDeathCallbacks_ = {},
    unitDeathTickS = nil,
    unitDeathTrackHitUnits = false,
}

helms.events.getLastHitBy = function(unitHitName)
    return helms.events.lastHitBy_[unitHitName]
end

helms.events.getLastSpawn = function(unitName)
    return helms.events.lastSpawn_[unitName]
end

helms.events.hitHandler_ = function(target, initiator, time)
    if not target or not initiator then return end
    local tgtName = target:getName()
    local initName = initiator:getName()

    if target:getCoalition() == initiator:getCoalition() then return end

    local tgtSpawnCount = 0
    if helms.events.lastSpawn_[tgtName] then
        tgtSpawnCount = helms.events.lastSpawn_[tgtName].spawnCount
    end

    helms.events.lastHitBy_[tgtName] = 
    {
        time = time, 
        initiatorName = initName,
        spawnCount = tgtSpawnCount
    }

    if helms.events.unitDeathTrackHitUnits then
        helms.events.unitDeathTracked_[tgtName] = false
    end
end

helms.events.spawnHandler_ = function(initiator, time)
    if not initiator or time == nil then return end
    if not initiator.Category == Object.Category.UNIT then return end

    local initName = initiator:getName()

    local newStats = { time = time, playerName = initiator:getPlayerName(), spawnCount = 1}

    if helms.events.lastSpawn_[initName] then
        newStats.spawnCount = helms.events.lastSpawn_[initName].spawnCount + 1
    end

    helms.events.lastSpawn_[initName] = newStats

    if helms.events.unitDeathTracked_[initName] == false then
        helms.events.unitDied_(initName,time,newStats.spawnCount - 1 )
    end
    helms.events.unitDeathTracked_[initName] = nil

end

--[[
--  Hit logs contain spawn counts only if spawn logging is enabled
--]]
helms.events.enableHitLogging = function()
    if helms.events.hitLoggingEnabled_ then return end

    local eventHandler = {
        onEvent = function(self, event)
            if (event.id == world.event.S_EVENT_HIT) then
                helms.util.safeCall(helms.events.hitHandler_, { event.target, event.initiator, event.time },
                    helms.catchError)
            end
        end
    }
    world.addEventHandler(eventHandler)

    helms.events.hitLoggingEnabled_ = true
end

helms.events.enableSpawnLogging = function()
    if helms.events.spawnLoggingEnabled_ then return end

    local eventHandler = {
        onEvent = function(self, event)
            if (event.id == world.event.S_EVENT_BIRTH) then
                helms.util.safeCall(helms.events.spawnHandler_, { event.initiator, event.time }, helms.catchError)
            end
        end
    }
    world.addEventHandler(eventHandler)

    helms.events.spawnLoggingEnabled_ = true
end

--[[
-- Callback when unit death/disappearance detected during death polling
-- spawnCount is the number of spawns then unit had (if tracked) at time of death. Not including the respawn in progeress, if death detected on respawn
--]]
helms.events.unitDied_=function(name,time, spawnCount)

    for k,v in pairs(helms.events.unitDeathCallbacks_) do
        if v(name,time,spawnCount) == false then
            helms.events.unitDeathCallbacks_[k] = nil
        end
    end
    helms.events.unitDeathTracked_[name] =true
end

--[[
    Register a unit so that it will be monitored via the dead unit poll for its current life
--]]
helms.events.registerUnitForDeathPoll = function(unitName)
    local unit = Unit.getByName(unitName)
    if unit ~= nil then
        if helms.events.unitDeathTrackHitUnits then
            helms.events.unitDeathTracked_[unitName] = false
        end
    else
        helms.log_i.log("Warning: unit " .. unitName .. " does not exist and will not generate death event.")
    end
end

--[[
    deathPollInterval - seconds, 
    deadHandler = function(name,objectID, deathTime) - return false to remove the callback

    enables hit logging and spawn logging
--]]
helms.events.enableDeathPolling = function(deathPollInterval, deadHandler, trackAllUnitsHit)

    if type(deadHandler) ~= 'function' then return end

    if trackAllUnitsHit==true then 
        helms.events.enableHitLogging()
        helms.events.unitDeathTrackHitUnits = true
    end

    helms.events.enableSpawnLogging()

    local firstCall = helms.events.unitDeathTickS == nil 

    if firstCall or helms.events.unitDeathTickS < deathPollInterval then
        helms.events.unitDeathTickS = deathPollInterval
    end

    helms.events.unitDeathCallbacks_[#helms.events.unitDeathCallbacks_+1] =
        helms.util.safeCallWrap(deadHandler, helms.catchError)
    
    if firstCall then
        local callback = function()

            local now = timer.getTime()
             
            for name,v in pairs(helms.events.unitDeathTracked_) do
                local unit = Unit.getByName(name)
                if unit == nil and v == false then 
                    local lastSpawn = helms.events.lastSpawn_[name]
                    local spawnCount = 0
                    if lastSpawn then
                        spawnCount = lastSpawn.spawnCount
                    end
                    helms.events.unitDied_(name,now, spawnCount)
                end
            end

            return now + helms.events.unitDeathTickS
        end

        helms.dynamic.scheduleFunctionSafe(callback,nil,timer.getTime() + helms.events.unitDeathTickS,nil, helms.catchError)
    end
end
---------------------------------------------------------------------------------------------------
helms.mission._buildMEGroupLookup()

helms.log_i.log("HeLMS v" .. helms.version .. " loaded")
---------------------------------------------------------------------------------------------------
helms.test = {}
helms.test.explodeUnitIfNameContains = function(substring, power)
    local names = helms.mission.getNamesContaining(substring)

    for k, name in pairs(names) do
        helms.test.explodeUnits(name, power)
        helms.dynamic.getGroupByName(name)
    end

    return names
end

helms.test.explodeUnits = function(groupName, power)
    local gp = helms.dynamic.getGroupByName(groupName)
    if gp then
        local units = gp:getUnits()
        if units then
            for _, v in pairs(units) do
                trigger.action.explosion(helms.maths.lin3D(v:getPoint(), 1, { x = 10, y = 0, z = 0 }, 1), power)
            end
        end
    end
end

helms.test.explodeStatic = function(groupName, power)
    local gp = helms.dynamic.getStaticByName(groupName)
    if gp then
        trigger.action.explosion(helms.maths.lin3D(gp:getPoint(), 1, { x = 10, y = 0, z = 0 }, 1), power)
    end
end

-----------------------------------------------------------------------------------------
--[[
S_EVENT_SHOT:1
S_EVENT_UNIT_TASK_COMPLETE:49
S_EVENT_SHOOTING_END:24
S_EVENT_REFUELING_STOP:14
S_EVENT_WEAPON_REARM:47
S_EVENT_DETAILED_FAILURE:17
S_EVENT_HUMAN_FAILURE:16
S_EVENT_RUNWAY_TOUCH:55
S_EVENT_UNIT_CREATE_TASK:44
S_EVENT_EJECTION:6
S_EVENT_UNIT_LOST:30
S_EVENT_INVALID:0
S_EVENT_EMERGENCY_LANDING:43
S_EVENT_CRASH:5
S_EVENT_WEAPON_DROP:48
S_EVENT_FLIGHT_TIME:40
S_EVENT_SCORE:29
S_EVENT_HUMAN_AIRCRAFT_REPAIR_FINISH:60
S_EVENT_MAC_LMS_RESTART:56
S_EVENT_SIMULATION_UNFREEZE:58
S_EVENT_SIMULATION_FREEZE:57
S_EVENT_HUMAN_AIRCRAFT_REPAIR_START:59
S_EVENT_RUNWAY_TAKEOFF:54
S_EVENT_DAYNIGHT:39
S_EVENT_MISSION_WINNER:53
S_EVENT_MISSION_RESTART:52
S_EVENT_KILL:2
S_EVENT_MAC_EXTRA_SCORE:51
S_EVENT_UNIT_TASK_STAGE:50
S_EVENT_SIMULATION_START:46
S_EVENT_UNIT_DELETE_TASK:45
S_EVENT_PLAYER_CAPTURE_AIRFIELD:42
S_EVENT_PLAYER_SELF_KILL_PILOT:41
S_EVENT_DEAD:8
S_EVENT_TRIGGER_ZONE:35
S_EVENT_AI_ABORT_MISSION:38
S_EVENT_LANDING_QUALITY_MARK:36
S_EVENT_WEAPON_ADD:34, UNIT_TASK:13
S_EVENT_DISCARD_CHAIR_AFTER_EJECTION:33
S_EVENT_PLAYER_ENTER_UNIT:20
S_EVENT_PARATROOPER_LENDING:32
S_EVENT_MAX:61
S_EVENT_LANDING_AFTER_EJECTION:31
S_EVENT_MARK_CHANGE:26
S_EVENT_MARK_ADDED:25
S_EVENT_PLAYER_COMMENT:2
S_EVENT_PLAYER_LEAVE_UNIT:21
S_EVENT_ENGINE_SHUTDOWN:19
S_EVENT_ENGINE_STARTUP:18
S_EVENT_TOOK_CONTROL:13
S_EVENT_MISSION_END:12
S_EVENT_TAKEOFF:3
S_EVENT_BASE_CAPTURED:10
S_EVENT_REFUELING:7
S_EVENT_LAND:4
S_EVENT_MISSION_START:11
S_EVENT_HIT:2
S_EVENT_BDA:37
S_EVENT_SHOOTING_START:23
S_EVENT_PILOT_DEAD:9
S_EVENT_BIRTH:15
S_EVENT_MARK_REMOVED:27
]]
