--#######################################################################################################
-- HITCH_TROOPER 
-- Run once at mission start after initializing HeLMS
-- 
-- Adds functionality to spawn squads to transport and command around the map using markpoints
--
-- Script by HappyGnome

--#######################################################################################################
-- UTILS

ht_utils = {}


if not helms then return end
if helms.version < 1 then 
	helms.log_e.log("Invalid HeLMS version for Hitch_Trooper")
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

--[[
Add unit info to the groupInfo structure and return groupInfo. If groupInfo is nil, a new groupInfo object is created
--]]
ht_utils.addUnitToGroupInfo = function(unit,groupInfo, knowType)
	if not unit then return groupInfo end
	
	if groupInfo == nil then
		groupInfo = {counts = {}}
	end
	
	
	local category = ht_utils.getUnitCategoryDesc(unit, knowType)

	
	if knowType then
		if unit:hasAttribute("SAM related") then
			groupInfo.suspectSAMs = true
		elseif unit:hasAttribute("Air Defence") then
			groupInfo.otherAD = true
		end
	end
	 
	if not groupInfo.counts[category] then 
		groupInfo.counts[category] = 1
	else
		groupInfo.counts[category] = groupInfo.counts[category] + 1
	end
	
	return groupInfo
end

ht_utils.getUnitCategoryDesc = function(unit, knowType)
	local category = "Unknown"
	if not unit then return category end
	
	if unit:hasAttribute("Planes") then
		category = "Aircraft"
	elseif unit:hasAttribute("Helicopters") then
		category = "Helos"
	elseif knowType and unit:hasAttribute("Heavy armed ships") then
		category = "Warships"
	elseif unit:hasAttribute("Ships") then
		category = "Vessels"
	elseif unit:hasAttribute("Infantry") then
		category = "Infantry"
	elseif knowType and unit:hasAttribute("Armored vehicles") then
		category = "Armour"
	elseif unit:hasAttribute("Vehicles") then
		category = "Vehicles"
	end
	return category
end

--[[
Create string for intel report on group info as created by addUnitToGroupInfo
--]]
ht_utils.describeGroupInfo = function(groupInfo)
	if not groupInfo then return "??" end
	
	local desc = ""
	local sep = ""
	
	for cat,count in pairs(groupInfo.counts) do
		desc = desc .. sep .. cat .. " x ".. count
		sep = "\n"
	end
	
	if groupInfo.suspectSAMs then
		desc = desc .. sep .. "Caution SAMs"
	elseif groupInfo.otherAD then
		desc = desc .. sep .. "Caution AD"
	end
	
	return desc
end
--#######################################################################################################
-- HITCH_TROOPER 
hitch_trooper = {}

-- MODULE OPTIONS:----------------------------------------------------------------------------------------
hitch_trooper.poll_interval = 61 --seconds, time between updates of group availability
hitch_trooper.respawn_delay = 28800 --seconds, time between disbanding and respawn becoming available
hitch_trooper.init_smoke_ammo = 3 --smokes available per group
hitch_trooper.recovery_radius = 1500 --distance from friendly base to allow despawn/resupply
hitch_trooper.next_mark_id = 1000
hitch_trooper.allow_map_marks = true
hitch_trooper.triggeredDetectCooldown = 60 -- Min time between impromptu target intel updates
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
key = group name in mission
value = hitch_trooper
--]]
hitch_trooper.author_spawnable_groups_={} 

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
hitch_trooper.log_i=helms.logger.new("hitch_trooper","info")
hitch_trooper.log_e=helms.logger.new("hitch_trooper","error")

--error handler for xpcalls. wraps hitch_trooper.log_e:error
hitch_trooper.catchError=function(err)
	hitch_trooper.log_e:error(err)
end 

--POLL----------------------------------------------------------------------------------------------------

hitch_trooper.doPoll_=function()

	local now=timer.getTime()	
	local nowString = helms.ui.convert.getNowString()
	
	local groupName = nil
	local htInstance = nil
	local airbasePoints = {[coalition.side.BLUE] = nil, [coalition.side.RED] = nil}
	
	--hitch_trooper.log_i:info("poll") --debug
	
	local pollGroup = function()
		local group,units = helms.dynamic.getLivingUnits(groupName) 
		if units[1] == nil then
			htInstance:disbandGroup_()
		else
			
			htInstance:updateDetectedList_(units[1],nowString,false)
			htInstance:onTick_(group)
			
			--check for resupply
			if airbasePoints[htInstance.side] == nil then
				airbasePoints[htInstance.side] = helms.dynamic.getBaseList(htInstance.side,true,true)
			end
			local _,dist = helms.dynamic.getKeyOfNearest2D(airbasePoints[htInstance.side], units[1]:getPoint())	
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
	return now + hitch_trooper.poll_interval
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

hitch_trooper.birthHandler = function(initiator)
	if initiator and initiator:getCategory() == Object.Category.UNIT then
		local group = initiator:getGroup()
		if group then
			local groupName = group:getName()
			local ht = hitch_trooper.author_spawnable_groups_[groupName]
			if ht then
				hitch_trooper.author_spawnable_groups_[groupName] = nil
				group:destroy()--prevent spawn of raw group
				helms.dynamic.scheduleFunction(ht.spawnGroup_,{ht},timer.getTime() + 2,true)	--spawn the hitchtroopers after small delay (else it crashes!)	
			end
		end
	end
end

hitch_trooper.eventHandler = { 
	onEvent = function(self,event)
		if(event.id == world.event.S_EVENT_MARK_ADDED) then
			helms.util.safeCall(hitch_trooper.parseMarkCommand, {event.text, event.pos, event.coalition},hitch_trooper.catchError)
		--[[elseif (event.id == world.event.S_EVENT_MARK_REMOVED) then
			ap_utils.markList[event.idx] = nil--]]
		elseif (event.id == world.event.S_EVENT_MARK_CHANGE) then
			helms.util.safeCall(hitch_trooper.parseMarkCommand, {event.text, event.pos, event.coalition},hitch_trooper.catchError)
		elseif (event.id == world.event.S_EVENT_HIT) then
			helms.util.safeCall(hitch_trooper.hitHandler,{event.target,event.initiator},hitch_trooper.catchError)
		elseif (event.id == world.event.S_EVENT_SHOT or event.id == world.event.S_EVENT_SHOOTING_START) then
			helms.util.safeCall(hitch_trooper.shotHandler,{event.target,event.initiator},hitch_trooper.catchError)
		elseif (event.id == world.event.S_EVENT_BASE_CAPTURED) then
			helms.util.safeCall(hitch_trooper.capHandler,{event.initiator,event.place},hitch_trooper.catchError)
		--[[elseif (event.id == world.event.S_EVENT_WEAPON_ADD) then --experimental
			hitch_trooper.log_i:info(event)	--]]	
		elseif (event.id == world.event.S_EVENT_BIRTH) then --experimental
			helms.util.safeCall(hitch_trooper.birthHandler,{event.initiator},hitch_trooper.catchError)
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
		hitch_trooper.commsMenus[menuName] = {2, missionCommands.addSubMenuForCoalition(side,rootMenuText,nil)}
		missionCommands.addCommandForCoalition(side, "Available", hitch_trooper.commsMenus[menuName][2], hitch_trooper.listForSide,side)
		missionCommands.addCommandForCoalition(side, "Help", hitch_trooper.commsMenus[menuName][2], hitch_trooper.help,side)
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
			if v.spawnData and v.spawnData.groupData 
				and v.spawnData.groupData.units 
				and v.spawnData.groupData.units[1] then
				point = helms.ui.convert.MakeAbToPointDescriptor({x = v.spawnData.groupData.units[1].x,y=0,z = v.spawnData.groupData.units[1].y}, side)
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

hitch_trooper.help = function(side)
	local text = "HITCHTROOPER F10 MAP MARKER HELP\nFor hitchtroopers with symbol \"AA\" use mark label:\n\"aa evac\" - sets extraction point\n\"aa rec\" - start recon towards point\n\"aa atk\" - start attack towards point"
	trigger.action.outTextForCoalition(side,text,10)
end

hitch_trooper.digraphCounters_ = {[coalition.side.BLUE] = 27, [coalition.side.RED] = 27} --start at AA

hitch_trooper.makeDigraph_ = function(side)
	if not hitch_trooper.digraphCounters_[side] then return "??" end
	local ret = helms.ui.convert.toAlpha(hitch_trooper.digraphCounters_[side])
	hitch_trooper.digraphCounters_[side] = hitch_trooper.digraphCounters_[side] + 1
	return ret
end

hitch_trooper.instance_meta_ = {
	__index = {
		
		--Misc poll updates
		onTick_ = function (self, group)
			-- Update alarm state
			if self.alarmStateNextPoll ~= nil then
				local controller = group:getController()
				controller:setOption(AI.Option.Ground.id.ALARM_STATE, self.alarmStateNextPoll)
			end		
			if self.reconAlarmState == true then -- keep alternating
				if self.alarmStateNextPoll == AI.Option.Ground.val.ALARM_STATE.GREEN then
					self.alarmStateNextPoll = AI.Option.Ground.val.ALARM_STATE.AUTO
				else 
					self.alarmStateNextPoll = AI.Option.Ground.val.ALARM_STATE.GREEN
				end
			else	-- stop alternating
				self.alarmStateNextPoll = nil
			end	
		end,
		
		setCommsSpawnMode_ = function(self)
			for k,v in pairs(self.commsMenuItems) do
				missionCommands.removeItemForCoalition(self.side,v)
			end
			self:ensureGroupCommsRoot_()
			self.commsMenuItems = {spawn = missionCommands.addCommandForCoalition(self.side, "Call in",self.commsMenuRoot,self.spawnGroup_,self)}
			hitch_trooper.spawnable_groups_[self.activeGroupName] = self
		end,
		
		recordHit_ = function(self,initiator)
			if self.retreatFromFire and initiator ~= nil then
				self:retreatFromPoint_(initiator:getPoint())
				self:updateDetectedList_(nil,nil,true)
			end
			if self.morale >= 0 then
				self.morale = self.morale - 1
				if self.morale < 0 then
					trigger.action.outTextForCoalition(self.side,string.format("%s: Request immediate medevac!",self.digraph),5)
					if self.evac_pos ~= nil then
						self:evacPoint_(nil,true)
						self:updateDetectedList_(nil,nil,true)
					end
				end
			end
		end,
		recordShot_ = function(self,initiator)
			if self.retreatFromFire and initiator ~= nil then
				self:retreatFromPoint_(initiator:getPoint())
				self:updateDetectedList_(nil,nil,true)
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
			self:ensureGroupCommsRoot_()
			self.commsMenuItems = {	evac = missionCommands.addCommandForCoalition(self.side, "Evac",self.commsMenuRoot,self.evacPoint_,self,nil,true),
			smoke= missionCommands.addCommandForCoalition(self.side, "Smoke",self.commsMenuRoot,self.smokePosition_,self),
			sitrep = missionCommands.addCommandForCoalition(self.side, "Sitrep",self.commsMenuRoot,self.sitrep_,self),
			recover = missionCommands.addCommandForCoalition(self.side, "Stand down",self.commsMenuRoot,self.recover_,self)}
			hitch_trooper.spawnable_groups_[self.activeGroupName] = nil			
		end,
		
		initComms_ = function(self)
			self:ensureGroupCommsRoot_()
			self:setCommsSpawnMode_()			
		end,
		
		ensureGroupCommsRoot_ = function(self)
			if self.commsMenuRoot == nil then
				self.htCommsPage = hitch_trooper.ensureCoalitionSubmenu_(self.side)
				self.commsMenuRoot =  
					missionCommands.addSubMenuForCoalition(self.side, self.digraph,hitch_trooper.commsMenus[self.htCommsPage][2])
				hitch_trooper.commsMenus[self.htCommsPage][1] = hitch_trooper.commsMenus[self.htCommsPage][1] + 1
			end
		end,
		
		removeComms_ = function(self)
			if self.commsMenuRoot ~= nil then
				--remove menu options
				missionCommands.removeItemForCoalition(self.side,self.commsMenuRoot)
				self.commsMenuRoot = nil
				
				--update submenu item count
				if self.htCommsPage then
					hitch_trooper.commsMenus[self.htCommsPage][1] = hitch_trooper.commsMenus[self.htCommsPage][1] - 1
				end
			end
		end,
		
		recover_ = function(self)
			local _, units = helms.dynamic.getLivingUnits(self.activeGroupName) 
			local unitsNotHome = false
			if units ~= nil then
				for k,v in pairs(units) do 
					_,_,dist = helms.dynamic.getNearestAirbase(v:getPoint(),self.side,true)
					--hitch_trooper.log_i.log(helms.dynamic.getNearestAirbase(v:getPoint(),self.side,true))--debug
					if dist == nil or dist > hitch_trooper.recovery_radius then
						unitsNotHome = true
						break
					end
				end
				if unitsNotHome then
					trigger.action.outTextForCoalition(self.side,string.format("%s: get us back to base first.",self.digraph),5)	
				else
					trigger.action.outTextForCoalition(self.side,string.format("%s: standing down. See ya!",self.digraph),5)
					helms.dynamic.scheduleFunction(self.disbandGroup_,{self}, timer.getTime() + 300,true)
					self:removeComms_()
					helms.dynamic.scheduleFunction(hitch_trooper.new,{self.groupName, self.playersCanSpawn, self.spawnData,self.gpNameRoot}, timer.getTime() + 300, true)
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
				local group = helms.dynamic.getGroupByName(self.groupName) 
				if group ~= nil and Group.isExist(group) then
					Group.destroy(group)
				end
				--respawn with new name
				local spawnData = helms.util.shallow_copy(self.spawnData)
				spawnData.groupData.name = self.activeGroupName
				--hitch_trooper.log_i.log(spawnData.groupData)--debug
				--hitch_trooper.log_i.log(spawnData.keys)--debug
				helms.dynamic.spawnGroup(spawnData.groupData,spawnData.keys)
				
				self:setCommsActiveMode_()
				hitch_trooper.tracked_groups_[self.activeGroupName] = self
				
				self.morale = math.ceil(#spawnData.groupData.units/3.0)
			else
				trigger.action.outTextForCoalition(self.side,string.format("%s: unavaiable at this time",self.digraph),5)
			end
		end,
		
		disbandGroup_ = function(self)
			local group = helms.dynamic.getGroupByName(self.activeGroupName) 
			if group ~= nil and Group.isExist(group) then
				Group.destroy(group)
				self.minRespawnTime = timer.getTime() + hitch_trooper.respawn_delay
			end
			hitch_trooper.tracked_groups_[self.activeGroupName] = nil
			self:removeComms_()
		end,
		
		attackPoint_ = function(self, pos)		
			local group, units = helms.dynamic.getLivingUnits(self.activeGroupName) 
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
					controller:setOption(AI.Option.Ground.id.ALARM_STATE, AI.Option.Ground.val.ALARM_STATE.AUTO)						
					controller:setTask(missionData)
					
					self.alarmStateNextPoll = nil
					
					-- default evac point
					if self.evac_pos == nil then
						self.evac_pos = startPoint
					end
					self.retreatFromFire = false
					
					self.current_destination = pos	
					self.taskMessage = string.format("Attacking %s",helms.ui.convert.pos2LL(pos))
					trigger.action.outTextForCoalition(self.side,string.format("%s: attacking %s",self.digraph,helms.ui.convert.pos2LL(pos)),10)
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
			if not triggerNow then
					return
			end					
			local group, units = helms.dynamic.getLivingUnits(self.activeGroupName) 	
			if units[1] ~= nil then
				local startPoint = units[1]:getPoint()				
				
				if self.evac_pos == nil then
					--trigger.action.outTextForCoalition(self.side,string.format("%s: where to?",self.digraph),10)
					self.evac_pos = startPoint
				end
				
				local arrivalString = 
				string.format("trigger.action.outTextForCoalition(%d,\"%s: Awaiting evac at %s\",10)", self.side, self.digraph, helms.ui.convert.pos2LL(self.evac_pos))
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
					controller:setOption(AI.Option.Ground.id.ALARM_STATE, AI.Option.Ground.val.ALARM_STATE.GREEN)						
					controller:setTask(missionData)
					
					self.alarmStateNextPoll = nil
					
					self.current_destination = self.evac_pos
					self.retreatFromFire = true					
					
					--hitch_trooper.log_i:info(eta)--debug
					
					self.taskMessage = string.format("Evac'ing to %s.",helms.ui.convert.pos2LL(self.evac_pos))
					trigger.action.outTextForCoalition(self.side,string.format("%s: will evac to %s",self.digraph,helms.ui.convert.pos2LL(self.evac_pos)),10)
				end
			end
		end,
		
		--[[
		Set evac destination if pos not nil. 
		--]]
		reconPoint_ = function(self, pos)
			local group, units = helms.dynamic.getLivingUnits(self.activeGroupName) 	
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
					controller:setOption(AI.Option.Ground.id.ALARM_STATE, AI.Option.Ground.val.ALARM_STATE.GREEN)						
					controller:setTask(missionData)
					
					self.reconAlarmState = true
					self.alarmStateNextPoll = AI.Option.Ground.val.ALARM_STATE.AUTO
					
					-- default evac point
					if self.evac_pos == nil then
						self.evac_pos = startPoint
					end
					self.current_destination = pos	
					self.retreatFromFire = true
					
					--hitch_trooper.log_i:info(eta)--debug
					
					self.taskMessage = string.format("Reconnoitring %s.",helms.ui.convert.pos2LL(pos))
					trigger.action.outTextForCoalition(self.side,string.format("%s: will recon %s",self.digraph,helms.ui.convert.pos2LL(pos)),10)
				end
			end
		end,
		
		--[[
		retreat a short way from a given 3D point
		--]]
		retreatFromPoint_ = function(self, pos)
			local group, units = helms.dynamic.getLivingUnits(self.activeGroupName) 	
			if units[1] ~= nil then
				local startPoint = units[1]:getPoint()					
				local dist = helms.maths.get2DDist(startPoint,pos)
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
					controller:setOption(AI.Option.Ground.id.ALARM_STATE, AI.Option.Ground.val.ALARM_STATE.GREEN)
					self.alarmStateNextPoll = AI.Option.Ground.val.ALARM_STATE.AUTO -- switch to auto after retreating a little
					
					self.current_destination = endPoint		
					self.evac_pos = endPoint			
					
					--hitch_trooper.log_i:info(eta)--debug
					
					self.taskMessage = string.format("Retreating to %s.",helms.ui.convert.pos2LL(endPoint))
				end
			end
		end,
		
		smokePosition_ = function(self)
			local group, units = helms.dynamic.getLivingUnits(self.activeGroupName) 
			if units[1] ~= nil then
				if self.smoke_ammo <= 0 then
					trigger.action.outTextForCoalition(self.side,string.format("%s: We're out of smoke!",self.digraph),10)
					return
				end
				local point = units[1]:getPoint()
				point.x = point.x + 200.0 * (math.random() - 0.5)
				point.z = point.z + 200.0 * (math.random() - 0.5)
				helms.dynamic.scheduleFunction(trigger.action.smoke,{point, trigger.smokeColor.Green},timer.getTime() + 30 + math.random() * 60,true)
				self.smoke_ammo = self.smoke_ammo - 1
			end
			
		end,
		
		sitrep_ = function(self)
			local group, units = helms.dynamic.getLivingUnits(self.activeGroupName) 
			if units[1] ~= nil then
				local message = string.format("__SITREP__ %s",self.digraph)
				message = message.."\nWe're "..helms.ui.convert.MakeAbToPointDescriptor(units[1]:getPoint(),self.side)
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
						tgtDesc = tgtDesc .. ht_utils.getUnitCategoryDesc (v.object,v.type)
						tgtDesc = tgtDesc .." ".. helms.ui.convert.MakeAbToPointDescriptor(units[1]:getPoint(), v.object:getPoint(), v.distance)						
					end
				end
				if hasTargets then 
					message = message..tgtDesc
				end
				
				self:updateDetectedList_(units[1],nil,false)
				if self:printMapMarks_() == true then
					message = message.."\nMap updated"
				end
				
				trigger.action.outTextForCoalition(self.side,message,10)
			end
		end,
		
		--{timestamp = now, point = obj:getPoint(),distKnown = target.distance,comment = tgtDesc,uncertaintyDist = 100}
		printMapMarks_ = function(self)
			if not hitch_trooper.allow_map_marks then 
				return false
			end
			
			local ret = false			
			for k,v in pairs(self.detectedTargets) do
				if v.point and v.distKnown then 
					if v.rectId ~= nil then
						trigger.action.removeMark(v.rectId)					
					end
					v.rectId = hitch_trooper.next_mark_id
					
					--local point1 = {x = v.point.x - (v.uncertaintyDist * math.random()/2), y = v.point.y, z = v.point.z - (v.uncertaintyDist * math.random() / 2)}
					--local point2 = {x = point1.x + v.uncertaintyDist, y = point1.y, z = point1.z + v.uncertaintyDist}
					
					local point = {x = v.point.x - (v.uncertaintyDist * (math.random() -0.5)), y = v.point.y, z = v.point.z - (v.uncertaintyDist * (math.random() -0.5))}
					
					--trigger.action.rectToAll(self.side , v.rectId , point2 , point1 , {r=1, g=0, b=0, a=0.5}, {r=1, g=0, b=0, a=0.5} , 1)
					trigger.action.markToCoalition(v.rectId , v.comment, point,self.side )
					
					hitch_trooper.next_mark_id = hitch_trooper.next_mark_id + 1
					ret = true
				end
			end
			return ret
		end,
		
		currentEta_ = function(self)
			local group, units = helms.dynamic.getLivingUnits(self.activeGroupName) 	
			if units[1] ~= nil and self.current_destination ~= nil then
				local startPoint = units[1]:getPoint()	
				if startPoint ~= nil then 
					return helms.ui.convert.getETAString(self.current_destination, startPoint, helms.mission.getUnitSpeed(units[1],4)*0.8)
				end
			end
			return nil
		end,
		
		--[[
		unit should be a unit from this instance
		If unit == nil or nowString == nil, a living unit form this group and the current time will be used, respectively
		--]]
		updateDetectedList_ = function(self,unit, nowString, triggered)
			if nowString == nil then
				nowString = helms.ui.convert.getNowString()
			end
			if unit == nil then
				local group, units = helms.dynamic.getLivingUnits(self.activeGroupName)
				if units == nil or units[1] == nil then return end
				unit = units[1]
			end
			
			if triggered then
				local now = timer.getTime()
				if self.triggeredDetectCooldown ~= nil and self.triggeredDetectCooldown > now then return
				else
					self.triggeredDetectCooldown = now + hitch_trooper.triggeredDetectCooldown
				end
			end
			
			--check detection
			local targets = unit:getController():getDetectedTargets()
			local groupsUpdated = {} -- unit category counts for detected groups
			--{timestamp:..., point3D:..., comment:..., rectId:..., uncertaintyDist:...}
			for _,target in pairs(targets) do
				local obj = target.object
				if target.visible and obj ~= nil and obj:getCategory() == Object.Category.UNIT then	
					local groupName = obj:getGroup():getName()
					
					if not groupsUpdated[groupName] then
						local tgtDesc
						groupsUpdated[groupName] = ht_utils.addUnitToGroupInfo(obj,nil,target.type)	
						local rectId
						if self.detectedTargets[groupName] ~= nil then 
							rectId = self.detectedTargets[groupName].rectId 
						end 
						self.detectedTargets[groupName] = {timestamp = now, point = obj:getPoint(),distKnown = target.distance,comment = "Contact" ,uncertaintyDist = 100, rectId = rectId}
					else
						groupsUpdated[groupName] = ht_utils.addUnitToGroupInfo(obj,groupsUpdated[groupName],target.type)
					end
				end
				
			end
			
			-- create group descriptions
			for groupName,groupInfo in pairs(groupsUpdated) do				
				self.detectedTargets[groupName].comment = ht_utils.describeGroupInfo(groupInfo) .. " at " .. nowString
			end
		end
	} --index
}
	
--API--------------------------------------------------------------------------------------

--spawn data overrrides obtaining data by group name
hitch_trooper.new = function (groupName, playersCanSpawn, spawnData, displayGpName)
	
	if spawnData == nil then
		spawnData = {groupData = helms.mission.getMEGroupDataByName(groupName),
		keys = helms.mission.getKeysByName(groupName)}
	end
	
	if playersCanSpawn == nil then
		playersCanSpawn = true
	end

	if displayGpName == nil then displayGpName = groupName end
	
	--local countryId = spawnData.country
	--if type(countryId) == "string" then
		--countryId = country.id[string.upper(countryId)]
	--end	
	--hitch_trooper.log_i:info(countryId) --debug
	--hitch_trooper.log_i.log(spawnData.keys.ctryId) --debug
	local coa = coalition.getCountryCoalition(spawnData.keys.ctryId)
	local group = helms.dynamic.getGroupByName(groupName)
	local unit = nil
	if group ~= nil then
		unit = group:getUnits()[1]
	end
	
	local instance = {
		groupName = groupName,
		gpNameRoot = displayGpName,
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
		morale = 0, -- when this hits zero, cannot attack
		detectedTargets = {}, --index = object name, value ={timestamp:..., point:..., comment:..., rectId:..., uncertaintyDist:...}
		playersCanSpawn = playersCanSpawn,
		alarmStateNextPoll = nil, -- for switching/alternating alarm state
		reconAlarmState = false, -- set true to alternate alarm state
		triggeredDetectCooldown = nil
	}
	instance.activeGroupName = string.format("%s (%s)",displayGpName,instance.digraph)
	
	setmetatable(instance,hitch_trooper.instance_meta_)
	
	if playersCanSpawn == true then
		instance:initComms_()
	end
	
	if unit ~= nil and unit:isActive() == true then --activate at mission start/spawn
		instance:spawnGroup_()
	elseif playersCanSpawn == false then --if inactive and mission author controlling spawn mark to listen for activation
		hitch_trooper.author_spawnable_groups_[groupName] = instance
	end
	
	trigger.action.outTextForCoalition(instance.side,string.format("%s: Now available for call in",instance.digraph),5)
	
	return instance
end

--Search for groups with name containing
hitch_trooper.newIfNameContains = function(substring, playersCanSpawn, replaceSubstring)
	local names = helms.mission.getNamesContaining(substring)
	if replaceSubstring == nil then replaceSubstring = "-" end
	for k,name in pairs(names) do			
		hitch_trooper.new(name, playersCanSpawn,nil,string.gsub(name,substring,replaceSubstring,1))
	end
end

--#######################################################################################################
-- HITCH TROOPER(PART 2)

helms.dynamic.scheduleFunction(hitch_trooper.doPoll_,nil,timer.getTime()+hitch_trooper.poll_interval)

return hitch_trooper
