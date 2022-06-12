--#######################################################################################################
-- Steersman
-- Run once at mission start after initializing HeLMS
-- 
-- Adds functionality to move a carrier group to a downwind location so that it can move upwind when required
--
-- Script by HappyGnome

if not helms then return end
if helms.version < 1 then 
	helms.log_e.log("Invalid HeLMS version for Steersman")
end

--#######################################################################################################
-- STEERSMAN
steersman = {}

-- MODULE OPTIONS:----------------------------------------------------------------------------------------
steersman.poll_interval = 59 --seconds, time between updates of group availability
steersman.ops_radius = 93000 -- m switch to flight ops mode if player is inbound in this radius
steersman.pre_ops_radius_seconds = 240
steersman.update_rest_cooldown = 600 --seconds
steersman.ops_radius_inner = 65000 -- m switch to flight ops mode if player is within in this radius
steersman.teardrop_dist = 1800 -- (m) distance behind ship to put turning point for expedited turnaround
steersman.deck_height = 20 -- m height at which to measure wind
steersman.enable_messages = false
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
steersman.log_i=helms.logger.new("steersman","info")
steersman.log_e=helms.logger.new("steersman","error")

--error handler for xpcalls. wraps steersman.log_e:error
steersman.catchError=function(err)
	steersman.log_e:error(err)
end 

--POLL----------------------------------------------------------------------------------------------------

steersman.doPoll_=function()

	local now=timer.getTime()	
	local smInstance = nil
	local groupName = nil
	
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
	return now + steersman.poll_interval
end

----------------------------------------------------------------------------------------------------

steersman.instance_meta_ = {
	__index = {
	
		setDesiredHeadwindKts = function(self,kts)
			self.desiredHeadwindMps_ = math.max(0, kts * helms.maths.kts2mps)
			return self
		end,
		
		setDeckAngleCCWDeg = function(self,degrees)
			self.deckAngleCCWDeg_  = math.max(-89, math.min(89,degrees))
			return self
		end,
		
		setMinCruiseSpeedKts = function(self,kts)
			self.minBoatSpeed_  = math.max(0, kts * helms.maths.kts2mps)
			return self
		end,
		
		pollStep_ = function(self)
			
			local options = {pickUnit=true}
			
			local dist,playerUnit,closestUnit = helms.dynamic.getClosestLateralPlayer(self.groupName_,{self.side_}, options)	
			
			local wantOpsMode = false
			
			if dist ~= nil then 
				local playerToBoat = helms.maths.unitVector(playerUnit:getPoint(),			   closestUnit:getPoint() )
				local inbound = helms.maths.dot2D(playerUnit:getVelocity(),
					playerToBoat)
			
				wantOpsMode = dist < steersman.ops_radius_inner
					or (playerUnit:inAir() and steersman.pre_ops_radius_seconds * inbound > dist - steersman.ops_radius 
						and inbound > 0.01)
			end
			
			if not wantOpsMode and (self.opsMode_ 
									or self.lastUpdatedRestPos == nil
									or self.lastUpdatedRestPos + steersman.update_rest_cooldown < timer.getTime()) then
				local path = self:GetRepositionRoute_()
				self:GoOnPath_(path,100)
				self.currentDestPoint_ = path[-1]
				self.lastUpdatedRestPos = timer.getTime()
				if self.opsMode_ and steersman.enable_messages then
					trigger.action.outTextForCoalition(self.side_,string.format("%s ceasing flight ops",self.groupName_),10)
				end
				self.opsMode_ = false
				self.turnMode_ = false
			elseif wantOpsMode then
				if not self.opsMode_ then --switch to ops mode/ turn mode
					if self:NotUpwind_() then -- only if not in upwind half of zone already
						local pointSpeed = self:GetUpwind_()
						self:GoToPoint_(pointSpeed,100,false, self.activationTasks) -- Go at full speed to speed up the turns
						if steersman.enable_messages then
							trigger.action.outTextForCoalition(self.side_,string.format("%s commencing flight ops",self.groupName_),10)
						end
						self.opsMode_ = true
						self.turnMode_ = true
						self.currentDestPoint_ = pointSpeed
					elseif not self:NotUpwind_(self.currentDestPoint_) then -- we're upwind and so is destination!
						local path = self:GetRepositionRoute_()
						self:GoOnPath_(path,100)
						self.currentDestPoint_ = path[-1]
					end
				elseif self.turnMode_ and self.currentDestPoint_ ~= nil then -- check whether we're approximately on track to exit turn mode
					local position = closestUnit:getPosition()
					if math.abs(helms.maths.thetaToDest(position.x,position.p,self.currentDestPoint_)) < 0.35 then --~20 degrees
						local pointSpeed = self:GetUpwind_()
						self:GoToPoint_(pointSpeed,pointSpeed.speed,false, nil,helms.mission.stringsToScriptTasks({self:MakeEndOfOpsRunScript()}))
						self.turnMode_ = false
					end
				end
			end
			
			return true -- keep polling
		end,
		
		--give the tracked group a mission to head for pointTo , using position of unit as a starting point
		--add extra waypoint 1km towards the destination to improve angular accuracy
		-- if spTasks is provided these will be added to the unit tasking
		--point to is vec2
		--speed is in mps
		GoToPoint_ = function(self, pointTo, speed, expediteTurn, spTasks,dpTasks)		
			local group = Group.getByName(self.groupName_) 
			if group ~= nil then
				local unit = group:getUnits()[1]
				if unit ~= nil then
					local startPoint = unit:getPoint()
					if startPoint ~= nil then
						local dir = helms.maths.unitVector(startPoint, pointTo)
						local points = { }
						local wp1 = {
								   action = AI.Task.VehicleFormation.OFF_ROAD,
								   x = startPoint.x,
								   y = startPoint.z
								 }
						if spTasks ~= nil then
							wp1.task = { id = "ComboTask", params = {tasks = spTasks} }
						end
						table.insert(points,wp1)
						if expediteTurn then
							table.insert(points,{
								   action = AI.Task.VehicleFormation.OFF_ROAD,
								   x = startPoint.x + steersman.teardrop_dist * dir.x, 
								   y = startPoint.z + steersman.teardrop_dist * dir.y,
								   speed = 100
								 })
						end
						
						local wp2 = {
								   action = AI.Task.VehicleFormation.OFF_ROAD,
								   x = pointTo.x,
								   y = pointTo.y,
								   speed = speed
								 }
						if dpTasks ~= nil then
							wp2.task = { id = "ComboTask", params = {tasks = dpTasks} }
						end
						table.insert(points,wp2)
						local missionData = { 
						   id = 'Mission', 
						   params = { 
							 route = { 
							   points = points
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
		
		--give the tracked group a mission to head for pointTo , using position of unit as a starting point
		--add extra waypoint 1km towards the destination to improve angular accuracy
		--point to is vec2
		--speed is in mps
		GoOnPath_ = function(self, path, speed)		
			local group = Group.getByName(self.groupName_) 
			if group ~= nil then
				local unit = group:getUnits()[1]
				if unit ~= nil then
					local startPoint = unit:getPoint()
					if startPoint ~= nil then
						local points = { }
						table.insert(points,{
								   action = AI.Task.VehicleFormation.OFF_ROAD,
								   x = startPoint.x,
								   y = startPoint.z
								 })		
						for _,point in pairs(path) do
							table.insert(points,{
									   action = AI.Task.VehicleFormation.OFF_ROAD,
									   x = point.x, 
									   y = point.y,	
									   speed = speed
									 })
						end
						
						local missionData = { 
						   id = 'Mission', 
						   params = { 
							 route = { 
							   points = points
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
			
			local speed = math.sqrt(helms.maths.dot2D(wind,wind))

			local downwindTheta = math.atan2(wind.z,wind.x)
			
			return unpack({speed,downwindTheta})

		end,
		
		--[[
		Return S,Theta
			Theta = (radians CCW in x,z coordinates system) of the reciprocal of the required heading for optimal wind
			S = speed in upwind direction for optimal winds (mps)
		Windtheta =  'xz angle' in radians of downwind direction 
		windSpeed  (mps)
		--]]
		GetSpeedAndTheta = function (self, windSpeed, windTheta)
			local v = self.desiredHeadwindMps_
			local w = windSpeed 
			local alpha = self.deckAngleCCWDeg_ * helms.maths.deg2rad 
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

		-- Return true if winds are light or the boat is in the downwind part of the zone
		-- point = point to assess for being upwind, or nil to use unit position
		NotUpwind_ = function(self,point)
			local wind = atmosphere.getWind({x = self.zoneCentre_.x, y = steersman.deck_height ,z = self.zoneCentre_.y})
			
			if math.sqrt(helms.maths.dot2D(wind,wind)) < self.lightWindCuttoff then
				return true
			end
			
			local here
			if point ~= nil then
				here = helms.maths.as3D(point)
			else
				here = self:GetUnitPoint_()
			end
			 
			--unit from centre
			local u = { x = here.x - self.zoneCentre_.x, 
						y = here.z - self.zoneCentre_.y}

			return helms.maths.dot2D(wind,u) >= 0

		end,


		GetRepositionRoute_ = function (self)
			if self:NotUpwind_() then
				return self:GetDownwindZigZag_(nil)
			else
				local ret = self:GetDownwindZigZag_(helms.maths.as3D(self.zoneCentre_))
				table.insert(ret,0,self.zoneCentre_)
				return ret
			end	
		end,
		
		-- return coords of the downwind position from zone centre of the group at the edge of the zone, based on winds at zone centre,
		--accounts for angled deck
		--return list of points {x,y} zig-zagging to the downwind point
		-- Uses current unit position as start of the route unless startPoint (3D) is passed
		GetDownwindZigZag_ = function(self,startPoint)
			local windspeed, downwindTheta = self:GetWindsZoneCentre()
			local theta = 0 --theta for the downwind position, accounting for deck angle
			
			_,theta = self:GetSpeedAndTheta(windspeed,downwindTheta)
						
			if windspeed < self.lightWindCuttoff then --for light winds choose a random direction instead
				theta = math.random()*2*math.pi
				return { [1] = {x = self.zoneCentre_.x + math.cos(theta)*self.zoneRadius_, y = self.zoneCentre_.y + math.sin(theta)*self.zoneRadius_} }
			end
			
			local downwindDir = {x = math.cos(theta), y = math.sin(theta)}	
			local crosswindDir = {x = -downwindDir.y, y = downwindDir.x}	
			local downwindPoint = helms.maths.lin2D(self.zoneCentre_,1,downwindDir,self.zoneRadius_)
			
			local preRet = {[1] = downwindPoint} -- default return
			local unitPoint  = startPoint
			if unitPoint == nil then unitPoint = self:GetUnitPoint_() end
			if unitPoint == nil then return preRet end
			
			local unitToDownwind = helms.maths.lin2D(unitPoint,-1,downwindPoint,1)
			local zagQuot = math.floor(helms.maths.dot2D(unitToDownwind,downwindDir)/self.zagSize_)
			
			--steersman.log_i:info(zagQuot)--TODO
			local i=1
			local sign = 1
			while i<zagQuot do
				
				table.insert(preRet,helms.maths.lin2D(helms.maths.lin2D(downwindDir,i*self.zagSize_,crosswindDir,sign*self.zagSize_),-1,downwindPoint,1))
				
				sign = -1*sign
				i = i+2
			end
			
			local ret = {}
			for j=1,#preRet do
				table.insert(ret, preRet[#preRet - j + 1])
			end
			--steersman.log_i:info(#ret)--TODO
			return ret
		end,
		
		GetUnitPoint_ = function(self)
					
			local group = Group.getByName(self.groupName_) 
			
			if group == nil then return nil end
			local unit = group:getUnits()[1]		
			
			if unit == nil then return nil end
			return unit:getPoint()
		end,
		
		-- return coords of the upwind position at zone edge from the given unit , based on wind at zone centre
		-- also return speed (m/s) to travel upwind to get the desired headwind
		--accounts for angled deck
		-- return {x,y,speed}
		GetUpwind_ = function(self)
			
			local ret = {} -- default return
			local unitPoint  = self:GetUnitPoint_()
			if unitPoint == nil then return ret end
			
			--unit from centre
			local u = { x = unitPoint.x - self.zoneCentre_.x, 
						y = unitPoint.z - self.zoneCentre_.y}
			
			local windspeed, downwindTheta = self:GetWindsZoneCentre()
			local speed =0
			local theta = 0 --theta for the downwind position, accounting for deck angle
			
			speed,theta = self:GetSpeedAndTheta(windspeed,downwindTheta)
			
			if windspeed < self.lightWindCuttoff then --for calm winds default to crossing the zone
				theta = math.atan2(u.y, u.x)
			end			
			
			-- unit direction to travel for headwind
			local v = {x = -1 * math.cos(theta), y = -1 * math.sin(theta)}
			local vDotU = helms.maths.dot2D(v,u)
			--discriminant
			local D = vDotU * vDotU - helms.maths.dot2D(u,u) + self.zoneRadius_*self.zoneRadius_
			
			if D <= 0 then return ret end
			
			local t = math.sqrt(D) - vDotU
			
			ret = {x = unitPoint.x + t * v.x , y = unitPoint.z + t * v.y}
			
			ret.speed = speed
			
			return ret
		end,

		MakeEndOfOpsRunScript = function(self)
			return string.format("steersman.tracked_groups_[\"%s\"].opsMode_ = false\n if steersman.enable_messages then trigger.action.outTextForCoalition(%s,\"%s ceasing flight ops\",10) end",
			self.groupName_,
			self.side_,
			self.groupName_)
		end
		
	} --index
}
	
--API--------------------------------------------------------------------------------------

--spawn data overrrides obtaining data by group name
steersman.new = function (groupName, zoneName)

	local zone = trigger.misc.getZone(zoneName)
	local group = Group.getByName(groupName)
	
	if zone == nil or group == nil then return nil end
	
	local task = helms.mission.getMEGroupRouteByName(groupName);
	local activationTasks = nil
	if task ~= nil and task[1] ~= nil then
		if task[1].task.id == "ComboTask"  and task[1].task.params ~= nil then
			activationTasks = task[1].task.params.tasks
		else 
			activationTasks = {[1] = task[1].task}
		end
		
	end
	
	local instance = {
		groupName_ = groupName,
		side_ = group:getCoalition(),
		deckAngleCCWDeg_ = 10, -- -90 - +90
		desiredHeadwindMps_ = 16, -- >=0
		minBoatSpeed_ = 7, -- >=0
		zagSize_ = 1000,
		lightWindCuttoff = 0.4,--mps
		zoneCentre_ = {x = zone.point.x, y = zone.point.z},
		zoneRadius_ = zone.radius,
		lastUpdatedRestPos = nil,
		opsMode_ = false,
		turnMode_ = false,
		activationTasks = activationTasks,
		currentDestPoint_ = nil
	}	
	
	setmetatable(instance,steersman.instance_meta_)
	
	steersman.tracked_groups_[groupName] = instance
	
	return instance
end

--#######################################################################################################
-- STEERSMAN(PART 2)

helms.dynamic.scheduleFunction(steersman.doPoll_,nil,timer.getTime()+steersman.poll_interval)

return steersman