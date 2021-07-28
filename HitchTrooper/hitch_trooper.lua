--#######################################################################################################
-- HITCH_TROOPER 
-- Run once at mission start after initializing MIST (Tested with Mist 4.4.90)
-- 
-- Adds functionality to spawn squads to transport and command around the map using markpoints
--
-- Script by HappyGnome

--#######################################################################################################
-- UTILS

ht_utils = {}

--[[
	Format decimal angle in tegrees to deg, decimal minutes format
--]]
ht_utils.formatDegMinDec = function(degrees,posPrefix,negPrefix)
	local prefix = posPrefix
	if(degrees < 0) then prefix = negPrefix end
	degrees = math.abs(degrees)
	local whole = math.floor(degrees)
	local minutes = 60 *(degrees - whole)
	
	return string.format("%s %d°%.2f'",prefix,whole,minutes)
end

ht_utils.pos2LL = function(pos)
	local lat,lon,_ = coord.LOtoLL(pos)
	return string.format("%s %s",ht_utils.formatDegMinDec(lat,"N","S"),ht_utils.formatDegMinDec(lon,"E","W"))
end

--[[
	positive int to "base 26" conversion
--]]
ht_utils.toAlpha = function(n)
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
Convert coalition to "Red", "Blue", "Neutral", or "None"
--]]
ht_utils.sideToString = function(side)
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

--[[
return (group, unit) for living unit in group of given name
--]]
ht_utils.getLivingUnits = function (groupName)	
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
True heading point A to point B, in degrees
--]]
ht_utils.getHeading = function (pointA,pointB)	
	local north = mist.getNorthCorrection(pointA) -- atan2 for true north at pointA
	local theta = (math.atan2(pointB.z-pointA.z,pointB.x-pointA.x) - north) * 57.2957795 --degrees
	local hdg = math.fmod(theta,360)
	if hdg < 0 then
		hdg = hdg + 360
	end
	return hdg	
end

--[[
convert heading to octant string e.g. "North", "Northeast" etc
hdg must be in the range  0 -360
--]]
ht_utils.hdg2Octant = function (hdg)
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
Get the key of the nearest object in objList to another given point
return key,dist
--]]
ht_utils.getKeyOfNearest2D = function(objList,point)
	local closestDist = math.huge
	local closestKey = nil
	for k,v in pairs(objList) do		
		if math.abs(v:getPoint().x - point.x) < closestDist then --quick filter in just one direction to cut down distance calcs
			local newDist = mist.utils.get2DDist(v:getPoint(),point)
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
ht_utils.getBaseList = function(farpSide,friendlyOnly, shipsAsFarps)
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
	
	return bases
end


--[[
return point,name,dist (m) of nearest airbase/farp etc (not ships), checks all permanent airbases and farps from side, if given 
set friendlyOnly = true to only consider friendly bases
--]]
ht_utils.getNearestAirbase = function (point, side, friendlyOnly)
	local bases = ht_utils.getBaseList(side,friendlyOnly,false)
	local closestKey, closestDist = ht_utils.getKeyOfNearest2D(bases,point)
	
	if closestKey == nil then return nil, nil, nil end
	
	local closestBase = bases[closestKey]
	
	return closestBase:getPoint(),closestBase:getName(), closestDist
end

--[[
Describe point relative to airbase e.g. "8Km Northeast of Kutaisi"
side determines whether only one set of bases are used for reference points
--]]
ht_utils.MakeAbToPointDescriptor = function (point, side)
	local abPoint,abName,meters = ht_utils.getNearestAirbase(point,side)
	if not abPoint then return "??" end
	return string.format("%s of %s",ht_utils.MakePointToPointDescriptor(abPoint,point),abName)
end

--[[
Describe point b from point a with distance and octant e.g. "8km South"
distance defaults to true. Indicates whether to include distance info
--]]
ht_utils.MakePointToPointDescriptor = function (pointA, pointB, distance)
	local octant = ht_utils.hdg2Octant(ht_utils.getHeading(pointA,pointB))
	if distance or distance == nil then
		return string.format("%.0fkm %s",mist.utils.get2DDist(pointA,pointB)/1000,octant)
	else
		return string.format("%s",octant)
	end
end


--[[
return ETA for following a straight path between two points at a given estimated speed
--]]
ht_utils.getETAString = function (point1,point2, estMps)	
	if estMps == nil or estMps <= 0 then return "unknown" end
	
	local ttg = mist.utils.get3DDist(point1,point2)/ estMps
	local etaAbs = timer.getAbsTime() + ttg	
	local dhms = mist.time.getDHMS(etaAbs)
	return string.format("%02d%02dL",dhms["h"],dhms["m"])
end

--[[
Get units offroad max speed in mps, or default if this is not available
--]]
ht_utils.getUnitSpeed = function(unit,default)
	if unit == nil then return default end
	local unitDesc = unit:getDesc()
	
	if unitDesc ~= nil and unitDesc["speedMaxOffRoad"] ~= nil then
		return unitDesc["speedMaxOffRoad"]	
	end
	
	return default
end

--[[
Return: {Rounds,Missiles, Rockets, Bombs}
--]]
ht_utils.sumAmmo= function(units)
	local ret = {}
	local othertotal = 0
	for _,unit in pairs(units) do
		local ammos = unit:getAmmo()
		if ammos then
			for _,ammo in pairs(ammos) do
				if ammo.count > 0 then
					if ammo.desc.displayName == nil then
						othertotal = othertotal + ammo.count
					elseif ret[ammo.desc.displayName] == nil then
						ret[ammo.desc.displayName] = ammo.count
					else
						ret[ammo.desc.displayName] = ret[ammo.desc.displayName] + ammo.count
					end
				end
			end
		end
	end
	
	if othertotal > 0 then
		ret["other"] = othertotal
	end
	
	return ret
end

ht_utils.shallow_copy = function(obj)
	local ret = obj	
	if type(obj) == 'table' then
		ret = {}
		for k,v in pairs(obj) do
			ret[k] = v
		end
	end	
	return ret
end

ht_utils.safeCall = function(func,args,errorHandler)
	local op = function()
		func(unpack(args))
	end
	xpcall(op,errorHandler)
end
--#######################################################################################################
-- HITCH_TROOPER 
hitch_trooper = {}

-- MODULE OPTIONS:----------------------------------------------------------------------------------------
hitch_trooper.poll_interval = 61 --seconds, time between updates of group availability
hitch_trooper.respawn_delay = 28800 --seconds, time between disbanding and respawn becoming available
hitch_trooper.init_smoke_ammo = 3 --smokes available per group
hitch_trooper.recovery_radius = 1500 --distance from friendly base to allow despawn/resupply
----------------------------------------------------------------------------------------------------------

--[[
key = group name in mission
value = hitch_trooper
--]]
hitch_trooper.tracked_groups_={} 

--[[
key = group name in mission
value = hitch_trooper
--]]
hitch_trooper.spawnable_groups_={} 

--[[
Menu item counts for submenus
key = menu name
value = {item count,path}
--]]
hitch_trooper.commsMenus = {}

--------------------------------------------------------------------------------------------------------

--[[
Loggers for this module
--]]
hitch_trooper.log_i=mist.Logger:new("hitch_trooper","info")
hitch_trooper.log_e=mist.Logger:new("hitch_trooper","error")

--error handler for xpcalls. wraps hitch_trooper.log_e:error
hitch_trooper.catchError=function(err)
	hitch_trooper.log_e:error(err)
end 

--POLL----------------------------------------------------------------------------------------------------

hitch_trooper.doPoll_=function()
--TODO - Fix this!
	local now=timer.getTime()	
	local groupName = nil
	local htInstance = nil
	local airbasePoints = {[coalition.side.BLUE] = nil, [coalition.side.RED] = nil}
	
	--hitch_trooper.log_i:info("poll") --debug
	
	local pollGroup = function()
		local group,units = ht_utils.getLivingUnits(groupName) 
		if units[1] == nil then
			htInstance:disbandGroup_()
		else
			
			--check for resupply
			if airbasePoints[htInstance.side] == nil then
				airbasePoints[htInstance.side] = ht_utils.getBaseList(htInstance.side,true,true)
			end
			local _,dist = ht_utils.getKeyOfNearest2D(airbasePoints[htInstance.side], units[1]:getPoint())	
			if dist < hitch_trooper.recovery_radius then		
				htInstance.smoke_ammo = math.max(math.min(htInstance.smoke_ammo + 1,hitch_trooper.init_smoke_ammo), htInstance.smoke_ammo)
			end
		end
	end
	
	--do group poll
	for k,v in pairs(hitch_trooper.tracked_groups_) do
		--parameters for the lambda
		groupName = k
		htInstance = v
		
		xpcall(pollGroup,hitch_trooper.catchError) --safely do work of polling the group
	end

	--schedule next poll----------------------------------
	mist.scheduleFunction(hitch_trooper.doPoll_,nil,now + hitch_trooper.poll_interval)
end

--EVENT HANDLER-------------------------------------------------------------------------------------

hitch_trooper.parseMarkCommand = function(text,pos,side)
	_,_,digraph,cmd = string.find(text,"(%a+) (%w+)")
	
	if digraph == nil or cmd == nil then
		return
	end
	
	local htInstance = nil
	for k,v in pairs(hitch_trooper.tracked_groups_) do
		if v.digraph == string.upper(digraph) and v.side == side then
			htInstance = v
			break
		end
	end
	
	
	
	if htInstance ~= nil then
		if string.lower(cmd) == "atk" then
			htInstance:attackPoint_(pos)
		elseif string.lower(cmd) == "evac" then
			htInstance:evacPoint_(pos,false)
		elseif string.lower(cmd) == "rec" then
			htInstance:reconPoint_(pos)
		end
	end
end

hitch_trooper.hitHandler = function(obj,initiator)
	if obj and obj:getCategory() == Object.Category.UNIT then
		local groupName = obj:getGroup():getName()
		for _,ht in pairs(hitch_trooper.tracked_groups_) do
			if ht.activeGroupName == groupName then
				ht:recordHit_(initiator)
				break
			end
		end
	end
end

hitch_trooper.shotHandler = function(obj,initiator)
	if obj and obj:getCategory() == Object.Category.UNIT then
		local groupName = obj:getGroup():getName()
		for _,ht in pairs(hitch_trooper.tracked_groups_) do
			if ht.activeGroupName == groupName then
				ht:recordShot_(initiator)
				break
			end
		end
	end
end

hitch_trooper.capHandler = function(initiator,place)
	if initiator and initiator:getCategory() == Object.Category.UNIT then
		local groupName = initiator:getGroup():getName()
		for _,ht in pairs(hitch_trooper.tracked_groups_) do
			if ht.activeGroupName == groupName then
				ht:recordBaseCap_(place)
				break
			end
		end
	end
end

hitch_trooper.eventHandler = { 
	onEvent = function(self,event)
		if(event.id == world.event.S_EVENT_MARK_ADDED) then
			ht_utils.safeCall(hitch_trooper.parseMarkCommand, {event.text, event.pos, event.coalition},hitch_trooper.catchError)
		--[[elseif (event.id == world.event.S_EVENT_MARK_REMOVED) then
			ap_utils.markList[event.idx] = nil--]]
		elseif (event.id == world.event.S_EVENT_MARK_CHANGE) then
			ht_utils.safeCall(hitch_trooper.parseMarkCommand, {event.text, event.pos, event.coalition},hitch_trooper.catchError)
		elseif (event.id == world.event.S_EVENT_HIT) then
			ht_utils.safeCall(hitch_trooper.hitHandler,{event.target,event.initiator},hitch_trooper.catchError)
		elseif (event.id == world.event.S_EVENT_SHOT or event.id == world.event.S_EVENT_SHOOTING_START) then
			ht_utils.safeCall(hitch_trooper.shotHandler,{event.target,event.initiator},hitch_trooper.catchError)
		elseif (event.id == world.event.S_EVENT_BASE_CAPTURED) then
			ht_utils.safeCall(hitch_trooper.capHandler,{event.initiator,event.place},hitch_trooper.catchError)
		--[[elseif (event.id == world.event.S_EVENT_WEAPON_ADD) then --experimental
			hitch_trooper.log_i:info(event)	--]]		
		end
	end
}
world.addEventHandler(hitch_trooper.eventHandler)

----------------------------------------------------------------------------------------------------

--[[
Add comms submenu for red or blue (side == instance of coalition.side)
--]]
hitch_trooper.ensureCoalitionSubmenu_=function(side)
	local rootMenuText = "Hitchtroopers"
	local menuNameRoot = rootMenuText..side
	local level = 1
	local menuName = menuNameRoot .. "_" .. level
	
	if hitch_trooper.commsMenus[menuName] == nil then--create submenu
		hitch_trooper.commsMenus[menuName] = {1, missionCommands.addSubMenuForCoalition(side,rootMenuText,nil)}
		missionCommands.addCommandForCoalition(side, "Available", hitch_trooper.commsMenus[menuName][2], hitch_trooper.listForSide,side)
	else  
		
		while hitch_trooper.commsMenus[menuName][1] >= 9 do --create overflow if no space here
			level = level + 1
			local newMenuName = menuNameRoot .. "_"..level
			
			if hitch_trooper.commsMenus[newMenuName] == nil then--create submenu of menu at menuName
				hitch_trooper.commsMenus[newMenuName] = {0,
				missionCommands.addSubMenuForCoalition(side, "Next",hitch_trooper.commsMenus[menuName][2])}
			end
			menuName = newMenuName
		end
	end	
	return menuName
end

hitch_trooper.listForSide = function(side)
	local text = ""
	for k,v in pairs(hitch_trooper.spawnable_groups_) do
		if v.side == side then
			local point = ""
			if v.spawnData and v.spawnData.units and v.spawnData.units[1] then
				point = ht_utils.MakeAbToPointDescriptor({x = v.spawnData.units[1].x,y=0,z = v.spawnData.units[1].y}, side)
			end
			text = text .. string.format("%s %s\n",v.digraph,point)
		end
	end
	
	if text ~= "" then
		trigger.action.outTextForCoalition(side,text,10)
	else
		trigger.action.outTextForCoalition(side,"None available",5)
	end
end

hitch_trooper.digraphCounters_ = {[coalition.side.BLUE] = 27, [coalition.side.RED] = 27} --start at AA

hitch_trooper.makeDigraph_ = function(side)
	if not hitch_trooper.digraphCounters_[side] then return "??" end
	local ret = ht_utils.toAlpha(hitch_trooper.digraphCounters_[side])
	hitch_trooper.digraphCounters_[side] = hitch_trooper.digraphCounters_[side] + 1
	return ret
end

hitch_trooper.instance_meta_ = {
	__index = {
	
		setCommsSpawnMode_ = function(self)
			for k,v in pairs(self.commsMenuItems) do
				missionCommands.removeItemForCoalition(self.side,v)
			end
			self.commsMenuItems = {spawn = missionCommands.addCommandForCoalition(self.side, "Call in",self.commsMenuRoot,self.spawnGroup_,self)}
			hitch_trooper.spawnable_groups_[self.activeGroupName] = self
		end,
		
		recordHit_ = function(self,initiator)
		hitch_trooper.log_i:info("hit")
			if self.retreatFromFire and initiator ~= nil then
				self:retreatFromPoint_(initiator:getPoint())
			end
			if self.morale >= 0 then
				self.morale = self.morale - 1
				if self.morale < 0 then
					trigger.action.outTextForCoalition(self.side,string.format("%s: Request immediate medevac!",self.digraph),5)
					if self.evac_pos ~= nil then
						self:evacPoint_(nil,true)
					end
				end
			end
		end,
		recordShot_ = function(self,initiator)
		hitch_trooper.log_i:info("shot")
			if self.retreatFromFire and initiator ~= nil then
				self:retreatFromPoint_(initiator:getPoint())
			end
		end,
		recordBaseCap_ = function(self,place)
			local baseName = place:getName()
			if baseName == nil then
				baseName = "a base"
			end
			trigger.action.outTextForCoalition(self.side,string.format("%s: We captured %s. Huzzah!",self.digraph,baseName),5)
		end,
		
		setCommsActiveMode_ = function(self)
			for k,v in pairs(self.commsMenuItems) do
				missionCommands.removeItemForCoalition(self.side,v)
			end
			self.commsMenuItems = {	evac = missionCommands.addCommandForCoalition(self.side, "Evac",self.commsMenuRoot,self.evacPoint_,self,nil,true),
			smoke= missionCommands.addCommandForCoalition(self.side, "Smoke",self.commsMenuRoot,self.smokePosition_,self),
			sitrep = missionCommands.addCommandForCoalition(self.side, "Sitrep",self.commsMenuRoot,self.sitrep_,self),
			recover = missionCommands.addCommandForCoalition(self.side, "Stand down",self.commsMenuRoot,self.recover_,self)}
			hitch_trooper.spawnable_groups_[self.activeGroupName] = nil			
		end,
		
		initComms_ = function(self)
			self.htCommsPage = hitch_trooper.ensureCoalitionSubmenu_(self.side)
			self.commsMenuRoot =  
				missionCommands.addSubMenuForCoalition(self.side, self.digraph,hitch_trooper.commsMenus[self.htCommsPage][2])
			hitch_trooper.commsMenus[self.htCommsPage][1] = hitch_trooper.commsMenus[self.htCommsPage][1] + 1
			self:setCommsSpawnMode_()			
		end,
		
		removeComms_ = function(self)
			--remove menu options
			missionCommands.removeItemForCoalition(self.side,self.commsMenuRoot)
			
			--update submenu item count
			if self.htCommsPage then
				hitch_trooper.commsMenus[self.htCommsPage][1] = hitch_trooper.commsMenus[self.htCommsPage][1] - 1
			end
		end,
		
		recover_ = function(self)
			local _, units = ht_utils.getLivingUnits(self.activeGroupName) 
			local unitsNotHome = false
			if units ~= nil then
				for k,v in pairs(units) do 
					_,_,dist = ht_utils.getNearestAirbase(v:getPoint(),self.side,true)
					if dist ~= nil and dist > hitch_trooper.recovery_radius then
						unitsNotHome = true
						break
					end
				end
				if unitsNotHome then
					trigger.action.outTextForCoalition(self.side,string.format("%s: get us back to base first.",self.digraph),5)	
				else
					trigger.action.outTextForCoalition(self.side,string.format("%s: standing down. See ya!",self.digraph),5)
					mist.scheduleFunction(self.disbandGroup_,{self},timer.getTime() + 300)
					self:removeComms_()
					mist.scheduleFunction(hitch_trooper.new,{self.groupName, self.spawnData}, 300)
				end
			end
		end,
		
		spawnGroup_ = function(self)
			local now = timer.getTime()
			if self.minRespawnTime >= 0 and self.minRespawnTime <= now then
				self.minRespawnTime = -1
				self.evac_pos = nil --reset per-instance settings
				self.current_destination = nil
				self.taskMessage = ""
				
				--delete group if it exists
				local group = Group.getByName(self.groupName) 
				if group ~= nil and Group.isExist(group) then
					Group.destroy(group)
				end
				--respawn with new name
				local spawnData = ht_utils.shallow_copy(self.spawnData)
				spawnData.groupName = self.activeGroupName 	
				spawnData.route = mist.getGroupRoute(self.groupName,true)
				spawnData.clone = false
				mist.dynAdd(spawnData) --respawn with original tasking
				
				self:setCommsActiveMode_()
				hitch_trooper.tracked_groups_[self.activeGroupName] = self
				
				self.morale = math.ceil(#spawnData.units/3.0)
			else
				trigger.action.outTextForCoalition(self.side,string.format("%s: unavaiable at this time",self.digraph),5)
			end
		end,
		
		disbandGroup_ = function(self)
			local group = Group.getByName(self.activeGroupName) 
			if group ~= nil and Group.isExist(group) then
				Group.destroy(group)
				self.minRespawnTime = timer.getTime() + hitch_trooper.respawn_delay
			end
			hitch_trooper.tracked_groups_[self.activeGroupName] = nil
			self:removeComms_()
		end,
		
		attackPoint_ = function(self, pos)		
			local group, units = ht_utils.getLivingUnits(self.activeGroupName) 
			if units[1] ~= nil then
				if self.morale < 0 then
					trigger.action.outTextForCoalition(self.side,string.format("%s: Unable",self.digraph),10)
					return
				end
				local startPoint = units[1]:getPoint()
				if startPoint ~= nil then
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
							 [2] = {
							   action = AI.Task.VehicleFormation.OFF_ROAD,
							   x = pos.x, 
							   y = pos.z,	
							   speed = 100
							 }
						   } 
						 }
					   } 
					}
					local controller = group:getController()
					controller:setOnOff(true)
					controller:setOption(AI.Option.Ground.id.ROE, AI.Option.Ground.val.ROE.OPEN_FIRE)				
					controller:setTask(missionData)
					
					-- default evac point
					if self.evac_pos == nil then
						self.evac_pos = startPoint
					end
					self.retreatFromFire = false
					
					self.current_destination = pos	
					self.taskMessage = string.format("Attacking %s",ht_utils.pos2LL(pos))
					trigger.action.outTextForCoalition(self.side,string.format("%s: attacking %s",self.digraph,ht_utils.pos2LL(pos)),10)
				end
			end
		end,
		
		--[[
		Set evac destination if pos not nil. 
		trigger evac to that or preset point if triggerNow == true
		--]]
		evacPoint_ = function(self, pos, triggerNow)
			if pos ~= nil then
				self.evac_pos = pos
			end
			local group, units = ht_utils.getLivingUnits(self.activeGroupName) 	
			if units[1] ~= nil then
				local startPoint = units[1]:getPoint()		
							
				if self.evac_pos == nil then
					trigger.action.outTextForCoalition(self.side,string.format("%s: where to?",self.digraph),10)
					return
				elseif not triggerNow then
					return
				end
				
				local arrivalString = 
				string.format("trigger.action.outTextForCoalition(%d,\"%s: Awaiting evac at %s\",10)", self.side, self.digraph, ht_utils.pos2LL(self.evac_pos))
			    ..string.format("\nhitch_trooper.tracked_groups_[\"%s\"].taskMessage = nil",self.activeGroupName)
				if startPoint ~= nil then
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
							 [2] = {
							   action = AI.Task.VehicleFormation.OFF_ROAD,
							   x = self.evac_pos.x, 
							   y = self.evac_pos.z,	
							   speed = 100,
							   task = {
									id = "ComboTask",
									params = {
										tasks = {
											[1] = {
												id = "WrappedAction",
												params = {
													action = {
														id = "Script",
														params = {
															command = arrivalString
														}
													}
												}
											},--wrapped action
											[2] = {
												id = "EmbarkToTransport",
												params = {
													x = self.evac_pos.x,
													y = self.evac_pos.z,
													zoneRadius = 100											
												}									
											}--embark
										}
									}
							   }--combotask
							 }
						   } 
						 }
					   } 
					}
					local controller = group:getController()
					controller:setOnOff(true)
					controller:setOption(AI.Option.Ground.id.ROE, AI.Option.Ground.val.ROE.RETURN_FIRE)				
					controller:setTask(missionData)
					
					self.current_destination = self.evac_pos
					self.retreatFromFire = true					
					
					--hitch_trooper.log_i:info(eta)--debug
					
					self.taskMessage = string.format("Evac'ing to %s.",ht_utils.pos2LL(self.evac_pos))
					trigger.action.outTextForCoalition(self.side,string.format("%s: will evac to %s",self.digraph,ht_utils.pos2LL(self.evac_pos)),10)
				end
			end
		end,
		
		--[[
		Set evac destination if pos not nil. 
		--]]
		reconPoint_ = function(self, pos)
			local group, units = ht_utils.getLivingUnits(self.activeGroupName) 	
			if units[1] ~= nil then
				local startPoint = units[1]:getPoint()		
				
				if startPoint ~= nil then
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
							 [2] = {
							   action = AI.Task.VehicleFormation.OFF_ROAD,
							   x = pos.x, 
							   y = pos.z,	
							   speed = 100
							 }
						   } 
						 }
					   } 
					}
					local controller = group:getController()
					controller:setOnOff(true)
					controller:setOption(AI.Option.Ground.id.ROE, AI.Option.Ground.val.ROE.RETURN_FIRE)				
					controller:setTask(missionData)
					
					-- default evac point
					if self.evac_pos == nil then
						self.evac_pos = startPoint
					end
					self.current_destination = pos	
					self.retreatFromFire = true
					
					--hitch_trooper.log_i:info(eta)--debug
					
					self.taskMessage = string.format("Reconnoitring %s.",ht_utils.pos2LL(pos))
					trigger.action.outTextForCoalition(self.side,string.format("%s: will recon %s",self.digraph,ht_utils.pos2LL(pos)),10)
				end
			end
		end,
		
		--[[
		retreat a short way from a given 3D point
		--]]
		retreatFromPoint_ = function(self, pos)
			local group, units = ht_utils.getLivingUnits(self.activeGroupName) 	
			if units[1] ~= nil then
				local startPoint = units[1]:getPoint()					
				local dist = mist.utils.get2DDist(startPoint,pos)
				local retreatDist = 1000
				if math.abs(dist) < 1.0 then return end
				
				local endPoint = {} --3D point
				endPoint["x"] = startPoint.x + retreatDist*(startPoint.x - pos.x)/dist
				endPoint["y"] = startPoint.y
				endPoint["z"] = startPoint.z + retreatDist*(startPoint.z - pos.z)/dist

				if startPoint ~= nil then
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
							 [2] = {
							   action = AI.Task.VehicleFormation.OFF_ROAD,
							   x = endPoint.x, 
							   y = endPoint.z,	
							   speed = 100
							 }
						   } 
						 }
					   } 
					}
					local controller = group:getController()
					controller:setOnOff(true)				
					controller:setTask(missionData)	

					self.current_destination = endPoint		
					self.evac_pos = endPoint
					
					--hitch_trooper.log_i:info(eta)--debug
					
					self.taskMessage = string.format("Retreating to %s.",ht_utils.pos2LL(endPoint))
				end
			end
		end,
		
		smokePosition_ = function(self)
			local group, units = ht_utils.getLivingUnits(self.activeGroupName) 
			if units[1] ~= nil then
				if self.smoke_ammo <= 0 then
					trigger.action.outTextForCoalition(self.side,string.format("%s: We're out of smoke!",self.digraph),10)
					return
				end
				local point = units[1]:getPoint()
				point.x = point.x + 200.0 * (math.random() - 0.5)
				point.z = point.z + 200.0 * (math.random() - 0.5)
				mist.scheduleFunction(trigger.action.smoke,{point, trigger.smokeColor.Green},timer.getTime() + 30 + math.random() * 60)
				self.smoke_ammo = self.smoke_ammo - 1
			end
			
		end,
		
		sitrep_ = function(self)
			local group, units = ht_utils.getLivingUnits(self.activeGroupName) 
			if units[1] ~= nil then
				local message = string.format("__SITREP__ %s",self.digraph)
				message = message.."\nWe're "..ht_utils.MakeAbToPointDescriptor(units[1]:getPoint(),self.side)
				if self.taskMessage ~= nil and self.taskMessage ~= "" then
					message = message.."\n"..self.taskMessage
					local ETA = self:currentEta_()
					if ETA ~= nil then 
						message = message.."\nETA "..ETA
					end
				else	
					message = message.."\nStanding by"
				end
				local ammoCounts = ht_utils.sumAmmo(units)
				local linestart= true
				for k,v in pairs(ammoCounts) do
						if linestart then message = message.."\nAmmo: " end
						
						linestart = false
						message = message..v.."*"..k..", "
				end
				message = message.."Smoke*"..self.smoke_ammo
				
				local targets = units[1]:getController():getDetectedTargets()
				local priorityCountdown = 3 -- max number of targets to show
				local tgtDesc = "\nIn contact with: "
				local hasTargets = false
				for k,v in pairs(targets) do					
					if v.visible and v.object then
						hasTargets = true
						tgtDesc = tgtDesc .."\n"
						if priorityCountdown < 1 then 
							tgtDesc = tgtDesc .. "...plus company!"
							break 
						end
						priorityCountdown = priorityCountdown - 1
						if v.type then
							tgtDesc = tgtDesc .. v.object:getTypeName()
						else
							tgtDesc = tgtDesc .. "Unknown"
						end
						tgtDesc = tgtDesc .." ".. ht_utils.MakePointToPointDescriptor(units[1]:getPoint(), v.object:getPoint(), v.distance)						
					end
				end
				if hasTargets then 
					message = message..tgtDesc
				end
				trigger.action.outTextForCoalition(self.side,message,10)
			end
		end,
		
		currentEta_ = function(self)
			local group, units = ht_utils.getLivingUnits(self.activeGroupName) 	
			if units[1] ~= nil and self.current_destination ~= nil then
				local startPoint = units[1]:getPoint()	
				if startPoint ~= nil then 
					return ht_utils.getETAString(self.current_destination, startPoint, ht_utils.getUnitSpeed(units[1],4)*0.8)
				end
			end
			return nil
		end
	} --index
}
	
--API--------------------------------------------------------------------------------------

--spawn data overrrides obtaining data by group name
hitch_trooper.new = function (groupName,spawnData)
	
	if spawnData == nil then
		spawnData = mist.getGroupData(groupName)
	end
	--local countryId = spawnData.country
	--if type(countryId) == "string" then
		--countryId = country.id[string.upper(countryId)]
	--end	
	--hitch_trooper.log_i:info(countryId) --debug
	--hitch_trooper.log_i:info(country.id) --debug
	local coa = coalition.getCountryCoalition(spawnData.countryId)
	
	local instance = {
		groupName = groupName,
		taskMessage = "",
		minRespawnTime = 0,
		side = coa,
		digraph = hitch_trooper.makeDigraph_(coa),
		evac_pos = nil,
		retreatFromFire = true,
		spawnData = spawnData,
		current_destination = nil,
		smoke_ammo = hitch_trooper.init_smoke_ammo,
		commsMenuItems = {}, -- key = item action type, value = path
		morale = 0 -- when this hits zero, cannot attack
	}
	instance.activeGroupName = string.format("%s (%s)",instance.groupName,instance.digraph)
	
	setmetatable(instance,hitch_trooper.instance_meta_)
	
	instance:initComms_()
	
	trigger.action.outTextForCoalition(instance.side,string.format("%s: Now available for call in",instance.digraph),5)
	
	return instance
end

--Search for groups with name containing
hitch_trooper.newIfNameContains = function(substring)

	for name,v in pairs(mist.DBs.groupsByName) do
		if string.find(name,substring) ~= nil then					
			hitch_trooper.new(name)
		end
	end
end

--#######################################################################################################
-- HITCH TROOPER(PART 2)

mist.scheduleFunction(hitch_trooper.doPoll_,nil,timer.getTime()+hitch_trooper.poll_interval)

return hitch_trooper
