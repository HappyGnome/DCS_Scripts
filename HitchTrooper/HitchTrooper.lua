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
	
	return string.format("%s %d' %f",prefix,whole,minutes)
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
ht_utils.getLivingUnit = function (groupName)	
	local group = Group.getByName(groupName) 
	if group ~= nil and Group.isExist(group) then
		local units = group:getUnits()
		for i,unit in pairs(units) do
			if unit:getLife()>1.0 then
				return group,unit
			end
		end
	end
	return group,nil
end

--#######################################################################################################
-- HITCH_TROOPER 
hitch_trooper = {}

-- MODULE OPTIONS:----------------------------------------------------------------------------------------
hitch_trooper.poll_interval=61 --seconds, time between updates of group availability
----------------------------------------------------------------------------------------------------------

--[[
key = group name in mission
value = hitch_trooper
--]]
hitch_trooper.tracked_groups_={} 

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

	local now=timer.getTime()	
	local groupName = nil
	local htInstance = nil
	
	local pollGroup = function()
		local group,unit = ht_utils.getLivingUnit(groupName) 
		if unit == nil then
			htInstance:disbandGroup_()
			hitch_trooper.tracked_groups_[groupName] = nil
		end
	end
	
	--do group poll
	for k,v in ipairs(hitch_trooper.tracked_groups_) do
		--parameters for the lambda
		groupName = k
		htInstance = v
		
		xpcall(pollGroup,hitch_trooper.catchError) --safely do work of polling the group
	end

	--schedule next poll----------------------------------
	mist.scheduleFunction(hitch_trooper.doPoll_,nil,now+hitch_trooper.poll_interval)
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
		end
	end
end

hitch_trooper.eventHandler = { 
	onEvent = function(self,event)
		if(event.id == world.event.S_EVENT_MARK_ADDED) then
			xpcall(hitch_trooper.parseMarkCommand (event.text, event.pos, event.coalition),hitch_trooper.catchError)
		--[[elseif (event.id == world.event.S_EVENT_MARK_REMOVED) then
			ap_utils.markList[event.idx] = nil--]]
		elseif (event.id == world.event.S_EVENT_MARK_CHANGE) then
			xpcall(hitch_trooper.parseMarkCommand (event.text, event.pos, event.coalition),hitch_trooper.catchError)
		end
	end
}
world.addEventHandler(hitch_trooper.eventHandler)

----------------------------------------------------------------------------------------------------

--[[
Add comms submenu for red or blue (side == instance of coalition.side)
--]]
hitch_trooper.ensureCoalitionSubmenu_=function(side)
	local menuNameRoot = "Hitchtroopers"
	local level = 1
	local menuName = menuNameRoot .. "_" .. level
	
	if hitch_trooper.commsMenus[menuName] == nil then--create submenu
		hitch_trooper.commsMenus[menuName] = {0, missionCommands.addSubMenuForCoalition(side, menuNameRoot ,nil)}
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

hitch_trooper.digraphCounters_ = {[coalition.side.BLUE] = 27, [coalition.side.RED] = 27} --start at AA

hitch_trooper.makeDigraph_ = function(side)
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
		end,
		
		setCommsActiveMode_ = function(self)
			for k,v in pairs(self.commsMenuItems) do
				missionCommands.removeItemForCoalition(self.side,v)
			end
			self.commsMenuItems = {disband = missionCommands.addCommandForCoalition(self.side, "Disband",self.commsMenuRoot,self.disbandGroup_,self),
			evac = missionCommands.addCommandForCoalition(self.side, "Evac",self.commsMenuRoot,self.evacPoint_,self,nil,true),
			smoke= missionCommands.addCommandForCoalition(self.side, "Smoke",self.commsMenuRoot,self.smokePosition_,self)}
			
		end,
		
		initComms_ = function(self)
			self.commsMenusName = hitch_trooper.ensureCoalitionSubmenu_(self.side)
			self.commsMenuRoot =  missionCommands.addSubMenuForCoalition(self.side, self.digraph,hitch_trooper.commsMenus[self.commsMenusName][2])
			self:setCommsSpawnMode_()
		end,
		
		spawnGroup_ = function(self)
			local now = timer.getTime()
			if self.minRespawnTime >= 0 and self.minRespawnTime <= now then
				self.minRespawnTime = -1
				--delete group if it exists
				local group = Group.getByName(self.groupName) 
				if group ~= nil and Group.isExist(group) then
					Group.destroy(group)
				end
				--respawn with new name
				local spawnData = mist.getGroupData(self.groupName)
				self.activeGroupName = string.format("%s (%s)",self.groupName,self.digraph)
				spawnData.groupName = self.activeGroupName 	
				spawnData.route = mist.getGroupRoute(self.groupName,true)
				spawnData.clone = false
				mist.dynAdd(spawnData) --respawn with original tasking
				
				self:setCommsActiveMode_()
				hitch_trooper.tracked_groups_[self.activeGroupName] = self
			else
				trigger.action.outTextForCoalition(self.side,string.format("%s: unavaiable at this time",self.digraph),5)
			end
		end,
		
		disbandGroup_ = function(self)
			local group = Group.getByName(self.activeGroupName) 
			if group ~= nil and Group.isExist(group) then
				Group.destroy(group)
				self.minRespawnTime = timer.getTime() + 60--10800
				hitch_trooper.tracked_groups_[self.activeGroupName] = nil
				self:setCommsSpawnMode_()
			end
		end,
		
		attackPoint_ = function(self, pos)		
			local group, unit = ht_utils.getLivingUnit(self.activeGroupName) 
			if unit ~= nil then
				local startPoint = unit:getPoint()
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
			if self.evac_pos == nil then
				trigger.action.outTextForCoalition(self.side,string.format("%s: where to?",self.digraph),10)
				return
			elseif not triggerNow then
				return
			end
			local group, unit = ht_utils.getLivingUnit(self.activeGroupName) 
			if unit ~= nil then
				local startPoint = unit:getPoint()
				local arrivalString = string.format("trigger.action.outTextForCoalition(%d,\"%s: Awaiting evac at %s\",10)", self.side, self.digraph, ht_utils.pos2LL(self.evac_pos))
				
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
					trigger.action.outTextForCoalition(self.side,string.format("%s: will evac to %s",self.digraph,ht_utils.pos2LL(self.evac_pos)),10)
				end
			end
		end,
		
		smokePosition_ = function(self)
			local group, unit = ht_utils.getLivingUnit(self.activeGroupName) 
			if unit ~= nil then
				local point = unit:getPoint()
				point.x = point.x + 100.0 * (math.random() - 0.5)
				point.z = point.z + 100.0 * (math.random() - 0.5)
				trigger.action.smoke(point, trigger.smokeColor.Green)
				
				hitch_trooper.log_i:info(unit:getDesc())--debug
				hitch_trooper.log_i:info(group:getController())--debug
			end
			
		end,
		
		sitrep_ = function(self)
			--TODO. 
		end
	} --index
}
	
--API--------------------------------------------------------------------------------------

hitch_trooper.new = function (groupName)
	
	local group = Group.getByName(groupName)
	local coa = Group.getCoalition(group)	
	
	local instance = {
		groupName = groupName,
		statusMessage = "",
		minRespawnTime = 0,
		side = coa,
		digraph = hitch_trooper.makeDigraph_(coa),
		evac_pos = nil,
		commsMenuItems = {} -- key = item action type, value = path
	}
	
	setmetatable(instance,hitch_trooper.instance_meta_)
	
	instance:initComms_()
	
	return instance
end

--Search for groups with name containing
hitch_trooper.init = function(substring)

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
