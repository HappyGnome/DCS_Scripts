--#######################################################################################################
-- Steersman
-- Run once at mission start after initializing MIST (Tested with Mist 4.4.90)
-- 
-- Adds functionality to move a carrier group to a downwind location so that it can move upwind when required
--
-- Script by HappyGnome

--#######################################################################################################
-- UTILS

sm_utils = {}

--[[
See ap_utils.getClosestLateralPlayer

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
sm_utils.getClosestLateralPlayer = function(groupName,sides, options)

	local playerUnits = {}
	if options == nil then
		options = {}
	end
	
	for _,side in pairs(sides) do
		for _,player in pairs (coalition.getPlayers(side)) do
			table.insert(playerUnits,player)
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
		
		if not unitFilter or unitFilter(unit) then
			positions[i]={location.x,location.z}
			if options.pickUnit then
				break
			end
		end
	end
	
	if options.useGroupStart then
		local points = mist.getGroupPoints(groupName)			
		if points[1] then positions[#units + 1] = {points[1].x,points[1].y} end
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
	
	return unpack(ret)
	
end

sm_utils.dot2D = function(u,v)
	local uy = u.z
	local vy = v.z
	if uy == nil then uy = u.y end
	if vy == nil then vy = v.y end
	return u.x*v.x + uy*vy
end

--return {x,y} unit vector in direction from a to b
sm_utils.unitVector = function(A,B)
	local Ay = A.z
	local By = A.z
	if Ay == nil then Ay = A.y end
	if By == nil then By = B.y end
	local C = {x = B.x - A.x, y = By - Ay}
	local r = math.sqrt(sm_utils.dot2D(C,C))
	
	if r < 0.001 then return {x=0, y=0} end
	return {x = C.x/r, y = C.y/r}
end

sm_utils.deg2rad = 0.01745329
sm_utils.kts2mps = 0.5144

sm_utils.shallow_copy = function(obj)
	local ret = obj	
	if type(obj) == 'table' then
		ret = {}
		for k,v in pairs(obj) do
			ret[k] = v
		end
	end	
	return ret
end

sm_utils.safeCall = function(func,args,errorHandler)
	local op = function()
		func(unpack(args))
	end
	xpcall(op,errorHandler)
end
--#######################################################################################################
-- STEERSMAN
steersman = {}

-- MODULE OPTIONS:----------------------------------------------------------------------------------------
steersman.poll_interval = 301 --seconds, time between updates of group availability
steersman.ops_radius = 140000 -- m switch to flight ops mode if players in this radius
steersman.deck_height = 20 -- m height at which to measure wind
----------------------------------------------------------------------------------------------------------

--[[
key = group name in mission
value = steersman
--]]
steersman.tracked_groups_={} 

--------------------------------------------------------------------------------------------------------

--[[
Loggers for this module
--]]
steersman.log_i=mist.Logger:new("steersman","info")
steersman.log_e=mist.Logger:new("steersman","error")

--error handler for xpcalls. wraps steersman.log_e:error
steersman.catchError=function(err)
	steersman.log_e:error(err)
end 

--POLL----------------------------------------------------------------------------------------------------

steersman.doPoll_=function()

	local now=timer.getTime()	
	local smInstance = nil
	
	--hitch_trooper.log_i:info("poll") --debug
	
	local pollGroup = function()
		if not smInstance:pollStep_() then 
			steersman.tracked_groups_[groupName] = nil
		end
	end
	
	--do group poll
	for k,v in pairs(steersman.tracked_groups_) do
		--parameters for the lambda
		groupName = k
		smInstance = v
		
		xpcall(pollGroup,steersman.catchError) --safely do work of polling the group
	end

	--schedule next poll----------------------------------
	mist.scheduleFunction(steersman.doPoll_,nil,now + steersman.poll_interval)
end

----------------------------------------------------------------------------------------------------

steersman.instance_meta_ = {
	__index = {
	
		setDesiredHeadwindKts = function(self,kts)
			self.desiredHeadwindMps_ = math.max(0, kts * sm_utils.kts2mps)
			return self
		end,
		
		setDeckAngleCCWDeg = function(self,degrees)
			self.deckAngleCCWDeg_  = math.max(-89, math.min(89,degrees))
			return self
		end,
		
		pollStep_ = function(self)
			
			local options = {pickUnit=true}
			
			local dist,playerUnit,closestUnit = sm_utils.getClosestLateralPlayer(self.groupName_,{self.side}, options)
			
			steersman.log_i:info(dist)
			steersman.log_i:info(playerUnit)
			steersman.log_i:info(closestUnit)--TODO debug		
			
			local wantOpsMode = dist ~= nil and dist < steersman.ops_radius
			
			if not wantOpsMode then	
				self:GoToPoint_(self:GetDownwind_(),100)
				self.opsMode_ = false
			elseif not self.opsMode_ and wantOpsMode then
				local pointSpeed = self:GetUpwind_()
				self:GoToPoint_(pointSpeed,pointSpeed.speed)
				self.opsMode_ = true
			end
			
			return true -- keep polling
		end,
		
		--give the tracked group a mission to head for pointTo , using position of unit as a starting point
		--add extra waypoint 1km towards the destination to improve angular accuracy
		--point to is vec2
		--speed is in mps
		GoToPoint_ = function(self, pointTo, speed)		
			local group = Group.getByName(self.groupName_) 
			if group ~= nil then
				local unit = group:getUnits()[1]
				if unit ~= nil then
					local startPoint = unit:getPoint()
					if startPoint ~= nil then
						local dir = sm_utils.unitVector(startPoint, pointTo)
						steersman.log_i:info(dir)--TODO debug
						local missionData = { 
						   id = 'Mission', 
						   params = { 
							 route = { 
							   points = { 
								[1] = {
								   action = AI.Task.VehicleFormation.OFF_ROAD,
								   x = startPoint.x,
								   y = startPoint.z
								 },
								 --[[[2] = {
								   action = AI.Task.VehicleFormation.OFF_ROAD,
								   x = startPoint.x + 1000 * dir.x, 
								   y = startPoint.z + 1000 * dir.y
								 },
								 [3] = {--]]
								 [2]={
								   action = AI.Task.VehicleFormation.OFF_ROAD,
								   x = pointTo.x, 
								   y = pointTo.y,	
								   speed = speed
								 }
							   } 
							 }
						   } 
						}
						local controller = group:getController()
						controller:setOnOff(true)			
						controller:setTask(missionData)
					end
				end
			end
		end,
		
		--[[
		Get windspeed and downwindTheta at zone centre at deck height
		--]]
		GetWindsZoneCentre = function(self)
			local wind = atmosphere.getWind({x = self.zoneCentre_.x, y = steersman.deck_height ,z = self.zoneCentre_.y})
			
			local speed = math.sqrt(sm_utils.dot2D(wind,wind))

			local downwindTheta = math.atan2(wind.z,wind.x)
			
			return unpack({speed,downwindTheta})

		end,
		
		--[[
		Return S,Theta
			Theta = (radians CCW in x,z coordinates system) of the reciprocal of the required heading for optimal wind
			S = speed in upwing direction for optimal winds (mps)
		Windtheta =  'xz angle' in radians of downwind direction 
		windSpeed  (mps)
		--]]
		GetSpeedAndTheta = function (self, windSpeed, windTheta)
			local v = self.desiredHeadwindMps_
			local w = windSpeed 
			local alpha = self.deckAngleCCWDeg_ * sm_utils.deg2rad 
			local sina = math.sin(alpha)
			local cosa = math.cos(alpha)
			
			local speed = 0
			local zeta = 0--angle between angled deck and the wind
			
			local D = w*w - v*v*sina*sina
			if D > 0 then
				speed = math.max(self.minBoatSpeed_,v*math.cos(alpha) - math.sqrt(D))
				zeta = math.asin(speed*sina / w)
			else --low windspeed
				speed = math.max(self.minBoatSpeed_,(v - w*sina)/cosa)
				zeta = math.pi/2 - math.abs(alpha)
				if alpha < 0 then
					zeta = -zeta
				end
			end
			
			return unpack({speed, windTheta + zeta + alpha})
		end,
		
		-- return coords of the downwind position from zone centre of the group at the edge of the zone, based on winds at zone centre,
		--accounts for angled deck
		--return {x,y}
		GetDownwind_ = function(self)
			
			local windspeed, downwindTheta = self:GetWindsZoneCentre()
			local speed =0
			local theta = 0 --theta for the downwind position, accounting for deck angle
			
			speed,theta = self:GetSpeedAndTheta(windspeed,downwindTheta)
			steersman.log_i:info("Down "..windspeed.." "..downwindTheta.." "..speed.." "..theta)
			
			if windspeed < 0.4 then --for light winds choose a random direction instead
				theta = math.random()*2*math.pi
			end
			
			return { x = self.zoneCentre_.x + math.cos(theta)*self.zoneRadius_, y = self.zoneCentre_.y + math.sin(theta)*self.zoneRadius_}
		end,
		
		-- return coords of the upwind position at zone edge from the given unit , based on wind at zone centre
		-- also return speed (m/s) to travel upwind to get the desired headwind
		--accounts for angled deck
		-- return {x,y,speed}
		GetUpwind_ = function(self)
			
			local ret = {} -- default return			
			local group = Group.getByName(self.groupName_) 
			
			if group == nil then return ret end
			local unit = group:getUnits()[1]			
			
			if unit == nil then return ret end
			local unitPoint = unit:getPoint()
			if unitPoint == nil then return ret end
			
			--unit from centre
			local u = { x = unitPoint.x - self.zoneCentre_.x, 
						y = unitPoint.z - self.zoneCentre_.y}
			
			local windspeed, downwindTheta = self:GetWindsZoneCentre()
			local speed =0
			local theta = 0 --theta for the downwind position, accounting for deck angle
			
			speed,theta = self:GetSpeedAndTheta(windspeed,downwindTheta)
			steersman.log_i:info("Up "..windspeed.." "..downwindTheta.." "..speed.." "..theta)
			
			if windspeed < 0.4 then --for calm winds default to crossing the zone
				theta = math.atan2(u.y, u.x)
			end			
			
			-- unit direction to travel for headwind
			local v = {x = -1 * math.cos(theta), y = -1 * math.sin(theta)}
			local vDotU = sm_utils.dot2D(v,u)
			--discriminant
			local D = vDotU * vDotU - sm_utils.dot2D(u,u) + self.zoneRadius_*self.zoneRadius_
			
			if D <= 0 then return ret end
			
			local t = math.sqrt(D) - vDotU
			
			ret = {x = unitPoint.x + t * v.x , y = unitPoint.z + t * v.y}
			
			ret.speed = speed
			
			return ret
		end
		
		
	} --index
}
	
--API--------------------------------------------------------------------------------------

--spawn data overrrides obtaining data by group name
steersman.new = function (groupName, zoneName)

	local zone = trigger.misc.getZone(zoneName)
	local group = Group.getByName(groupName)
	
	if zone == nil or group == nil then return nil end
	local instance = {
		groupName_ = groupName,
		side = group:getCoalition(),
		deckAngleCCWDeg_ = 10, -- -90 - +90
		desiredHeadwindMps_ = 15, -- >=0
		minBoatSpeed_ = 2, -- >=0
		zoneCentre_ = {x = zone.point.x, y = zone.point.z},
		zoneRadius_ = zone.radius,
		opsMode_ = true
	}	
	
	setmetatable(instance,steersman.instance_meta_)
	
	steersman.tracked_groups_[groupName] = instance
	
	return instance
end

--#######################################################################################################
-- STEERSMAN(PART 2)

mist.scheduleFunction(steersman.doPoll_,nil,timer.getTime()+steersman.poll_interval)

return steersman