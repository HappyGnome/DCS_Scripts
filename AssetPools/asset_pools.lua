--#######################################################################################################
-- ASSET_POOLS (PART 1)
-- Run once at mission start after initializing HeLMS
-- 
-- Adds functionality based on pools of groups, tracking availability
-- And allowing availability-dependent respawing based on various triggers
--
-- Script by HappyGnome

--doFile returns single global instance, or creates one
if asset_pools then
	return asset_pools
end

if not helms then return end
if helms.version < 1 then 
	helms.log_e.log("Invalid HeLMS version for Asset_Pools")
end

--NAMESPACES----------------------------------------------------------------------------------------------
asset_pools={}

-- MODULE OPTIONS:----------------------------------------------------------------------------------------
asset_pools.poll_interval=60 --seconds, time between updates of group availability
asset_pools.ai_bingo_fuel=0.2 --fraction of internal fuel for ending ai missions
asset_pools.ai_despawn_exclusion_air = 157000 -- 85 nm
asset_pools.ai_despawn_exclusion_ground = 60000 -- 60km
asset_pools.ai_despawn_exclusion_sea = 200000 --200km
----------------------------------------------------------------------------------------------------------
--TODO expose these options to mission makers

--[[
List of groups belonging to all pools. Lifecyclye state of all assets is updated at the same time

keys - groupName
value - key of associated pool in asset_pools.pools, or nil if state should not be updated

N.B. a group can only belong to one pool at a time. Adding it to multiple pools has undefined results
--]]
asset_pools.tracked_groups_={} 

--[[
key=group name, value = number of units at spawn
]]--
asset_pools.initial_group_sizes={} 

--[[
key=group name, value = SetFrequency command for unit at spawn
]]--
asset_pools.initial_group_freq_commands={} 


--[[
Table of pool objects. Each should be instances a class implementing:

poolId --> key of the pool in asset_pools.pools_

groupDead=function(self,groupName, now), --> called when group despawns or dies
												now == Mission time at death detection
											return true to keep polling this group, or false to stop

groupIdle=function(self,groupName, now, initialSize) --> called when group no-longer has a task
												now == Mission time at idle detection
											return true to keep polling this group, or false to stop

onTick=function(self, now) --> 	called during the poll step so that the pool can do update work
									now == Mission time at the tick
								return true to keep receiving tick events and polling associated groups
									or false to stop
--]]
asset_pools.pools_={}
asset_pools.next_pool_id_=0 --id of next item to add

--[[
Loggers for this module
--]]
asset_pools.log_i=helms.logger.new("asset_pools","info")
asset_pools.log_e=helms.logger.new("asset_pools","error")

--error handler for xpcalls. wraps asset_pools.log_e.log
asset_pools.catchError=function(err)
	asset_pools.log_e.log(err)
end 



--GLOBAL POLL---------------------------------------------------------------------------------------

--[[
Add a pool to poll list, assign it its index as an id
--]]
asset_pools.addPoolToPoll_ = function(pool)
	pool.poolId = asset_pools.next_pool_id_ 
	asset_pools.pools_[pool.poolId]=pool	
	asset_pools.next_pool_id_ = asset_pools.next_pool_id_ + 1
end

--[[
Add groupName to the poll list associated to a given pool
--]]
asset_pools.addGroupToPoll_ = function(pool,groupName)
	asset_pools.tracked_groups_[groupName]=pool.poolId
end

--[[
Remove groupName from the poll list
--]]
asset_pools.removeGroupFromPoll = function(groupName)
	asset_pools.tracked_groups_[groupName]=nil
end

--[[
respawn named group and add it to poll associated to given pool

@param groupName = name of group in ME to respawn (ignored if groupData set)
@param groupData = nil if named group exists in ME, or override named group with dynamic group Data
@return nil (no rescheduling)
--]]
asset_pools.RespawnGroupForPoll = function(pool,groupName, groupData)

	local op = function()
		local group
		
		if groupData and groupData.data and groupData.keys then
			groupName=groupData.data.name
			--asset_pools.log_i.log("data:"..helms.util.obj2str(groupData))--debug
			helms.dynamic.spawnGroup(helms.util.deep_copy(groupData.data),helms.util.deep_copy(groupData.keys))
		else		
			--asset_pools.log_i.log("name:"..groupName)--debug	
			helms.dynamic.respawnMEGroupByName(groupName) --respawn with original tasking
		end
		group = helms.dynamic.getGroupByName(groupName)
		
		if group then
			trigger.action.activateGroup(group) --ensure group is active
			asset_pools.initial_group_sizes[groupName] = group:getSize()
			local freqCommand = asset_pools.initial_group_freq_commands[groupName]
			
			if freqCommand == nil then
				local groupME_Data = helms.mission.getMEGroupDataByName(groupName)
				
				if groupME_Data ~= nil and groupME_Data.frequency ~= nil and 	groupME_Data.modulation ~= nil then
					freqCommand = {
						id = 'SetFrequency',
						params = {
							frequency = groupME_Data.frequency * 1000000,
							modulation = groupME_Data.modulation
						}
					}
					asset_pools.initial_group_freq_commands[groupName] = freqCommand
				end
			end
			
			local controller = group:getController()
			if controller ~= nil and freqCommand ~= nil then						
				controller:setCommand(freqCommand)
			end
		end
	end
	helms.util.safeCall(op,{},asset_pools.catchError)
	asset_pools.addGroupToPoll_(pool,groupName)	
end

--[[
Private: do poll of groups and pools
--]]
asset_pools.doPoll_ = function()
	
	local now = timer.getTime()

	--Update pools------------------------------------------------------
	local tickPool--parameter for the lambda - pool to update
	
	--lambda for onTick callbacks
	local function doTick()
		if not tickPool:onTick(now) then
		-- if pool requests to stop polling it and its groups
			asset_pools.pools_[tickPool.poolId]=nil
		end
	end
	
	--do misc state updates for each pool
	for k,pool in pairs(asset_pools.pools_) do
		tickPool=pool
		xpcall(doTick,asset_pools.catchError) --safely do work of dispatching tick events
	end
	
	--Update groups------------------------------------------------------
	local groupName=""--loop variables for use in the poll lambda (avoid making lambda in a loop)
	local poolAt=nil
	
	--Lambda that does the polling work
	--wrap the poll work in a function so we can run it in xpcall, without crashing the loop
	local function pollGroup()
		if not poolAt then return end -- group is not set up for polling
		
		local pool = asset_pools.pools_[poolAt]
		
		if not pool then -- associated pool disabled - prevent this group from polling for now
			asset_pools.tracked_groups_[groupName]=nil
			return
		end
		
		-- || group and associated pool now both alive for polling ||
		-- vv                                                      vv
		
		local unit = nil
		local group = helms.dynamic.getGroupByName(groupName)
		local units={}
		local groupController=nil
		
		if group then
			units = group:getUnits()
			groupController = group:getController()
		end	
		
		local isActive = false
		local isDead = true -- being dead takes precedence over being inactive 
							-- if the unit doesn't exist we also count it as dead
							
		
		local groupHasTask =  groupController and groupController:hasTask()
		
		for i,unit in pairs(units) do
			if unit:getLife()>1.0 then
				isDead=false
				
				--check whether group or unit have a controller with active task
				
				local controller=unit:getController()				
				
				--if controller then trigger.action.outText("DB2",5)end--DEBUG
				--if groupController then trigger.action.outText("DB3",5)end--DEBUG

				if unit:getFuel() < asset_pools.ai_bingo_fuel then
					groupController:popTask()
					controller:popTask()
				else
				
					if pool.exclude_despawn_near then 
						local d,_,u=helms.dynamic.getClosestLateralPlayer(groupName, pool.exclude_despawn_near)
						if d and u then
							local landType = landTypeUnderUnit(u);
							isActive = isActive or u:inAir() and d<asset_pools.ai_despawn_exclusion_air 
							isActive = isActive or (landType == land.SurfaceType.WATER
												or landType == land.SurfaceType.SHALLOW_WATER) and 
									d<asset_pools.ai_despawn_exclusion_water
							isActive = isActive or d<asset_pools.ai_despawn_exclusion_ground
						end
					end

					local unitHasTask = controller and controller:hasTask()
					--asset_pools.log_i.log({groupName,unitHasTask,groupHasTask})--debug
					isActive = isActive or unit:isActive() and (unitHasTask or groupHasTask)
		
				end
			end
			--trigger.action.outText("DB1",5)--DEBUG
		end
		
		if isDead then
			if not pool:groupDead(groupName,now) then -- if pool requests to stop polling this group
				asset_pools.tracked_groups_[groupName]=nil
			end 
		elseif not isActive then
			if not pool:groupIdle(groupName,now, asset_pools.initial_group_sizes[groupName]) then -- if pool requests to stop polling this group
				asset_pools.tracked_groups_[groupName]=nil
			end
		end
	
	end--pollGroup

	--do group poll
	for k,v in pairs(asset_pools.tracked_groups_) do
		--parameters for the lambda
		groupName=k
		poolAt=v
		
		xpcall(pollGroup,asset_pools.catchError) --safely do work of polling the group
	end

	--asset_pools.log_i.log("ap_poll") --debug

	--schedule next poll----------------------------------
	return now+asset_pools.poll_interval
end

--#######################################################################################################
-- AP_UTILS
-- misc Utilities for asset_pool scripts


--doFile returns single global instance, or creates one
--if ap_utils then
	--return ap_utils
--end

--NAMESPACES---------------------------------------------------------------------------------------------- 
ap_utils={}

--[[
Loggers for this module
--]]
ap_utils.log_i=helms.logger.new("ap_utils","info")
ap_utils.log_e=helms.logger.new("ap_utils","error")


--UTILS------------------------------------------------------------------------------------------------


--[[
	Create respawn-on-command asset pools for all groups whose name contains a certain substring.
	Add comms menu commands to trigger them

	Call this at mission start/when associated unit can first be requested
	for each respawnable resource

	spawnDelay ==
		int -> time between request and activation/respawn (s)
	delayWhenIdle ==
		int -> time (s) before respawn requests allowed when unit goes idle
	delayWhenDead ==
		int -> time (s) before respawn requests allowed when unit is dead
	coalitionName == "red", "blue","neutral" or "all" (anything else counts as "all")
		-> coalition name that can spawn group and receive updates about them
		-> Note that neutral players don't seem to have a dedicated comms menu 
		-> units added with "neutral" will not be spawnable!
	
	replaceSubstring = string to replace substring in generated groups in the mission. Default to "-".
--]]
ap_utils.makeRocIfNameContains = function(substring, spawnDelay, delayWhenIdle, delayWhenDead, coalitionName, replaceSubstring)
	local names = helms.mission.getNamesContaining(substring)
	if replaceSubstring == nil then replaceSubstring = "-" end
	for _,name in pairs(names) do
		helms.dynamic.createGroupAlias(name,string.gsub(name,substring,replaceSubstring,1))
		respawnable_on_call.new(name, spawnDelay, delayWhenIdle, delayWhenDead, coalitionName)		
	end
end

-- Wrapper for new Helms method, for backwards compatibility
ap_utils.getNamesContaining = function(substring)
	return helms.mission.getNamesContaining(substring)
end

-- Wrapper for new Helms method, for backwards compatibility
ap_utils.generateGroups = function(nameRoot,count,unitDonors,taskDonors)
	return helms.mission.generateGroups(nameRoot,count,unitDonors,taskDonors)
end


--#######################################################################################################
-- RESPAWNABLE_ON_CALL


--NAMESPACES----------------------------------------------------------------------------------------------
respawnable_on_call={}
----------------------------------------------------------------------------------------------------------

--[[
Loggers for this module
--]]
respawnable_on_call.log_i=helms.logger.new("respawnable_on_call","info")
respawnable_on_call.log_e=helms.logger.new("respawnable_on_call","error")

--RESPAWNABLE_ON_CALL-----------------------------------------------------------------------------------------
--[[
Pool class used for respawnable-on-call operation. Currently only designed for controlling a single group
--]]
respawnable_on_call.instance_meta_={

	__index={ --Metatable for this "class"
	
		--Public methods-------------------
		
		--[[
		Schedule removal of instance from poll, and remove comms menus
		
		return = self
		--]]
		delete=function(self)
			self.killSwitch=true
			self:deleteComms_()
			return self
		end,

		--Asset pool override
		groupDead=function(self, groupName, now)			
			self.canRequestAt
				= now + self.delayWhenDead
				
			--trigger.action.outText("Detected that asset "..groupName.." is dead",5)--DEBUG
			--asset_pools.log_i.log(self.groupName.." was detected dead.")
			
			if self.groupDeathCallback then
				self.groupDeathCallback(self.groupName, self.timesCalledIn)
			end
			
			--stop polling this group
			return false		
		end,

		--Asset pool override
		groupIdle=function(self, groupName, now, initialSize)			
			self.canRequestAt
				= now + self.delayWhenIdle
				
			--trigger.action.outText("Detected that asset "..groupName.." is idle",5)--DEBUG			
			asset_pools.log_i.log(groupName.." was detected idle.")
			
			if self.groupIdleCallback then
				self.groupIdleCallback(self.groupName, self.timesCalledIn)
			end
			
			--stop polling this group
			return false 
		end,

		--Asset pool override
		onTick=function(self, now)	
			return not self.killSwitch -- keep polling
		end,


		--Other methods
		
		
		--[[
			Set optional callback for when group dies/despawns
			param callback = function(groupName,timesCalledIn)
			return self
		--]]
		setGroupDeathCallback = function(self,callback)
			self.groupDeathCallback = callback
			return self
		end,
		
		--[[
			Set optional callback for when group is called in
			param callback = function(groupName,timesCalledIn)
			return self
		--]]
		setGroupCallInCallback = function(self,callback)
			self.groupCallInCallback = callback
			return self
		end,
		
		--[[
			Set optional callback for when group goes idle
			param callback = function(groupName,timesCalledIn)
			return self
		--]]
		setGroupIdleCallback = function(self,callback)
			self.groupIdleCallback = callback
			return self
		end,
		
		--[[
			reset spawn counter
			return self
		--]]
		resetSpawnCount = function(self)
			self.timesCalledIn=0
			return self
		end,
		

		--[[
		Private: Request to spawn new instance of template group if there's not already one
		--]]
		handleSpawnRequest_ = function(self)
			local now=timer.getTime()
			local cRA=self.canRequestAt
			local cRA_isnum = type(cRA)=="number"
			local groupAlias = helms.dynamic.getGroupAlias(self.groupName)
			
			if cRA==true or (cRA_isnum and cRA<now) then
				self.canRequestAt=false --try to prevent dual requests, schedule spawn
				helms.dynamic.scheduleFunction(asset_pools.RespawnGroupForPoll,{self,self.groupName,nil,nil},now+self.spawnDelay)
				
				self.timesCalledIn = self.timesCalledIn+1 --increment spawn count
				if self.groupCallInCallback then --post call-in callback
					self.groupCallInCallback(self.groupName, self.timesCalledIn)
				end
				
				helms.ui.messageForCoalitionOrAll(self.side,
					string.format("%s will be on-call in %ds",groupAlias,self.spawnDelay),5)
					
				respawnable_on_call.log_i.log(self.groupName.." was called in.")
			else
				helms.ui.messageForCoalitionOrAll(self.side,
					string.format("%s is not available or is already on-call",groupAlias),5)
				if cRA_isnum then
					local toWait= self.canRequestAt-now
					helms.ui.messageForCoalitionOrAll(self.side,
						string.format("%s will be available in %ds",groupAlias,toWait),5)
				end
			end
		end,

		--[[
		Set up comms menus needed to spawn this group
		--]]
		createComms_=function(self)
			local groupAlias = helms.dynamic.getGroupAlias(self.groupName)
			--add menu options
			if self.side then --coalition specific addition	
				self.subMenuName=respawnable_on_call.ensureCoalitionSubmenu_(self.side)
				
				self.commsPath=missionCommands.addCommandForCoalition(self.side,groupAlias,
				respawnable_on_call.commsMenus[self.subMenuName][2],
					self.handleSpawnRequest_,self)
			else --add for all	
				self.subMenuName=respawnable_on_call.ensureUniversalSubmenu_()
				
				self.commsPath=missionCommands.addCommand(groupAlias,
				respawnable_on_call.commsMenus[self.subMenuName][2],
					self.handleSpawnRequest_,self)
			end
			
			respawnable_on_call.commsMenus[self.subMenuName][1] 
					= respawnable_on_call.commsMenus[self.subMenuName][1] + 1
		end,
		
		--[[
		Remove comms menus for spawning this group
		--]]
		deleteComms_=function(self)
			if not self.commsPath then return end-- very important it's not nil, or whole comms menu will be emptied
			
			--remove menu options
			if self.side then --coalition specific removal				
				missionCommands.removeItemForCoalition(self.side,self.commsPath)
			else --remove for all					
				missionCommands.removeItem(self.commsPath)
			end
			
			--update submenu item count
			if self.subMenuName then
				respawnable_on_call.commsMenus[self.subMenuName][1] 
					= respawnable_on_call.commsMenus[self.subMenuName][1] - 1
			end
		end
	}----index
}--meta_	
	
--[[
Menu item counts for submenus
key = menu name
value = {item count,path}
--]]
respawnable_on_call.commsMenus = {}

--[[
Add comms submenu for red or blue (side == instance of coalition.side)
--]]
respawnable_on_call.ensureCoalitionSubmenu_=function(side)
	local coa_string=helms.ui.convert.sideToString(side)
	local menuNameRoot = coa_string.." Assets"
	local level = 1
	local menuName = menuNameRoot .. "_" .. level
	
	if respawnable_on_call.commsMenus[menuName]==nil then--create submenu
		respawnable_on_call.commsMenus[menuName] = {0, missionCommands.addSubMenuForCoalition(side, menuNameRoot ,nil)}
	else 
		
		while respawnable_on_call.commsMenus[menuName][1]>=9 do --create overflow if no space here
			level = level + 1
			local newMenuName = menuNameRoot .. "_"..level
			
			if respawnable_on_call.commsMenus[newMenuName]==nil then--create submenu of menu at menuName
				respawnable_on_call.commsMenus[newMenuName] = {0,
				missionCommands.addSubMenuForCoalition(side, "Next",respawnable_on_call.commsMenus[menuName][2])}
			end
			menuName = newMenuName
		end
	end	
	return menuName
end

--[[
Add comms submenu for assets available to any faction
return name of the submenu
--]]
respawnable_on_call.ensureUniversalSubmenu_=function()

	local menuNameRoot = "Other Assets"
	local level = 1
	local menuName = menuNameRoot .. "_" .. level
	
	if respawnable_on_call.commsMenus[menuName]==nil then--create submenu
		respawnable_on_call.commsMenus[menuName] = {0, missionCommands.addSubMenu(menuNameRoot ,nil)}
	else 		
		while respawnable_on_call.commsMenus[menuName][1]>=9 do --create overflow if no space here
			level = level + 1
			local newMenuName = menuNameRoot .. "_"..level
			
			if respawnable_on_call.commsMenus[newMenuName]==nil then--create submenu of menu at menuName
				respawnable_on_call.commsMenus[newMenuName] = {0,
				missionCommands.addSubMenu("Next",respawnable_on_call.commsMenus[menuName][2])}
			end
			menuName = newMenuName
		end
	end	
	return menuName
end

----------------------------------------------------------------------------------------------------

--API--------------------------------------------------------------------------------------------------

--[[
	Create a respawn-on-command asset pool. Add comms menu command to trigger it

	Call this at mission start/when associated unit can first be requested
	for each respawnable resource

	spawnDelay ==
		int -> time between request and activation/respawn (s)
	delayWhenIdle ==
		int -> time (s) before respawn requests allowed when unit goes idle
	delayWhenDead ==
		int -> time (s) before respawn requests allowed when unit is dead
	coalitionName == "red", "blue","neutral" or "all" (anything else counts as "all")
		-> coalition name that can spawn group and receive updates about them
		-> Note that neutral players don't seem to have a dedicated comms menu 
		-> units added with "neutral" will not be spawnable!
--]]
respawnable_on_call.new=function(groupName, spawnDelay, delayWhenIdle, delayWhenDead, coalitionName)
	
	local coa=helms.ui.convert.stringToSide (coalitionName)
	
	local instance={}
	
	--Properties
	
	--Asset pool override
	instance.poolId = nil
	
	-- function(groupName,timesCalledIn) -> nil
	-- will be called when group dies/despawns
	instance.groupDeathCallback = nil
	-- function(groupName,timesCalledIn) -> nil
	-- will be called when group (re)spawn is scheduled
	instance.groupCallInCallback = nil
	-- function(groupName,timesCalledIn) -> nil
	-- will be called when group (is detected as idle
	instance.groupIdleCallback = nil
	
	
	--[[
	Set the group tracked by this asset_pool
	--]]
	instance.groupName = groupName
	
	--[[
	Number of times this group has been scheduled to spawn
	--]]
	instance.timesCalledIn = 0
	
	--[[
	Setting this to true will de-activate the this instance at the next tick
	--]]
	instance.killSwitch=false
	
	--[[
		canRequestAt ==
		true -> request any time
		false -> not available to request
		int -> time that requests can next be made (s elapsed in mission)
	--]]
	instance.canRequestAt = not helms.dynamic.groupHasActiveUnit(groupName)
		--initially true, unless group already exists on the map
	
	--[[
		spawnDelay ==
		int -> time between request and activation/respawn (s)
	--]]
	instance.spawnDelay = spawnDelay
	
	--[[
		delayWhenIdle ==
		int -> time before respawn requests allowed when unit goes idle
	--]]
	instance.delayWhenIdle = delayWhenIdle
	
	--[[
		delayWhenDead ==
		int -> time before respawn requests allowed when unit is dead
	--]]
	instance.delayWhenDead = delayWhenDead
	
	--[[
		side == coalition.side, or nil for all
		-> coalition name that can spawn group and receive updates about them
	--]]
	instance.side = coa
	
	setmetatable(instance,respawnable_on_call.instance_meta_)	
	
	instance.exclude_despawn_near = helms.util.excludeValues(coalition.side,{coa})

	--add pool and add group to poll list, with an association to this group
	asset_pools.addPoolToPoll_(instance)
	
	instance:createComms_()
	
	return instance
			
end--new

--#######################################################################################################
-- CONSTANT_PRESSURE_SET
--
-- Asset pool functionality for keeping randomized steady presence of assets alive



--NAMESPACES----------------------------------------------------------------------------------------------
constant_pressure_set={}
----------------------------------------------------------------------------------------------------------

-- MODULE OPTIONS:----------------------------------------------------------------------------------------
constant_pressure_set.gc_delay_seconds=600 --seconds, time to wait before destroying idle groups
----------------------------------------------------------------------------------------------------------

--[[
Loggers for this module
--]]
constant_pressure_set.log_i=helms.logger.new("constant_pressure_set","info")
constant_pressure_set.log_e=helms.logger.new("constant_pressure_set","error")

--CONSTANT_PRESSURE_SET-----------------------------------------------------------------------------------------
--[[
Pool class used for managing a collection of groups, respawning them at random to keep up an approximately constant 
number in-mission
--]]
constant_pressure_set.instance_meta_={--Do metatable setup
	__index={ --Metatable for this "class"
	
		--Public methods---------------
		
		--[[
		remove this pool from polling
		return =self
		--]]
		delete=function(self)
			self.killSwitch=true
			return self
		end,
		

		--Asset pool override
		groupDead=function(self, groupName, now)						
			
			self:putGroupOnCooldown_(groupName,now)				
			
			--stop polling this group
			return false		
		end,

		--Asset pool override
		groupIdle=function(self, groupName, now, initialSize)
		
			--check optional predicate if set
			if self.idlePredicate_ and not self.idlePredicate_(groupName) then
				return true -- not idle if predicate returns false
			end
			
			if self.deathPredicate_ and self.deathPredicate_(groupName, initialSize) then
				return self:groupDead(groupName,now)
			end			

			self:putGroupOnCooldown_(groupName,now)		
			
			--stop polling this group
			return false 
		end,

		--Asset pool override
		onTick=function(self, now)	
			
			--update cooldowns 
			local pred=function(T)--predicate, remove all times in the past
				return T<now
			end				
			
			--remove a number of groups from cooldown equal to number of 
			--expired cooldown timers this tick
			--remove expired timers from list
			local toReactivate= helms.util.removeRandom(
				self.groupListCooldown_, 
				helms.util.eraseByPredicate(self.timeListCooldown_,pred))
				
			for k in pairs(toReactivate) do
				self:takeGroupOffCooldown_(k)
			end
			
			--schedule spawns
			
			--count active groups in excess of target
			local surplusSpawned=-self.targetActiveCount
			for _ in pairs(self.groupListActive_) do
				surplusSpawned=surplusSpawned+1
			end
			
			--pick random subset of ready groups to spawn
			for g in pairs(helms.util.removeRandom(self.groupListReady_,-surplusSpawned)) do
				self:doScheduleSpawn_(g,now)--activate group and schedule to spawn with random delay
			end

			local gc_cutoff = now - constant_pressure_set.gc_delay_seconds

			for k,v in pairs(self.groupListIdleTimes_) do
				if v < gc_cutoff and helms.dynamic.allUnitPredicate(k, function(unit) return not unit:inAir() end)then
					helms.dynamic.despawnGroupByName(k)
					self.groupListIdleTimes_[k] = nil
				end
			end
		
			return not self.killSwitch -- keep polling
		end,


		--Other methods
		
		--add group to current ready pool  or cooldown pool
		-- if named group already managed by this pool, nothing will change
		-- param groupName = group to add
		-- ready = is this group available as reinforcement immediately?
		addGroup_=function(self, groupName, ready)
			if (not self.groupListActive_[groupName]) 
				and (not self.groupListCooldown_[groupName]) 
				and (not self.groupListReady_[groupName])  then --don't add duplicates
				if ready then
					self.groupListReady_[groupName]=true--ready to spawn immediately
				else
					self.groupListCooldown_[groupName]=true--only spawn after a cooldown event puts it back to ready
				end
			end
		end,
		
		-- Move group to cooldown list and off of active list
		-- add cooldown clock time to cooldown list
		putGroupOnCooldown_=function(self,groupName,now)
			
			local cooldownTime=now+self.cooldownOnDeath
			self.groupListActive_[groupName]=nil
			self.groupListCooldown_[groupName]=true
			self.groupListIdleTimes_[groupName] = now

			if self.timeListCooldown_[cooldownTime] then
				self.timeListCooldown_[cooldownTime]
					=self.timeListCooldown_[cooldownTime]+1
			else
				self.timeListCooldown_[cooldownTime]=1
				--constant_pressure_set.log_i.log(self.timeListCooldown_[cooldownTime]..", "..cooldownTime)--DEBUG
			end	
		end,
		
		-- Move group to ready list and off cooldown list 
		takeGroupOffCooldown_=function(self,groupName)
		
			self.groupListReady_[groupName]=true
			self.groupListCooldown_[groupName]=nil
			constant_pressure_set.log_i.log(groupName.." cooled down")
		end,
		
		-- Schedule spawn of group at random future time
		doScheduleSpawn_=function(self,groupName,now)
		
			self.groupListReady_[groupName]=nil
			self.groupListIdleTimes_[groupName] = nil
			self.groupListActive_[groupName]=true
			
			local delay= math.random(self.minSpawnDelay,self.maxSpawnDelay)
			
			helms.dynamic.scheduleFunction(asset_pools.RespawnGroupForPoll,
				{self,groupName,self.groupDataLookup[groupName]},now+delay,true)
				
			constant_pressure_set.log_i.log(groupName.." called in with delay "..delay)
			--constant_pressure_set.log_i.log(helms.util.obj2str(self.groupDataLookup))--debug
			
		end,
		
		-- Set an idle predicate - an additional check before group goes idle
		-- predicate=function(groupName) -> Boolean
		-- predicate should return true if group allowed to go idle
		setIdlePredicate =function(self,predicate) 
			self.idlePredicate_ = predicate
			return self
		end,
		
		-- Set a predicate to downgrade from idle to dead
		-- predicate=function(groupName,initialSize) -> Boolean
		-- predicate should return true if idle group counts as dead
		setDeathPredicate =function(self,predicate) 
			self.deathPredicate_ = predicate
			return self
		end,
		
		-- Short for setDeathPredicate with life percentage predicate
		setDeathPctPredicate =function(self,percent) 
			local pred = function(groupName, initialSize)
				return helms.dynamic.getNormalisedGroupHealth(groupName,initialSize) < percent/100
			end
			self:setDeathPredicate(pred)
			return self
		end
		
	}--index
}--meta_,		
	
--[[ 
-- Return a new instance of a constant pressure object

-- params 
-- targetActive = number of groups to try to keep active
-- reinforceStrength = number of groups available to spawn at the start (excl first spawned groups) 
--		All other spawns will require a cooldown to complete first
-- idleCooldown = cooldown added when group goes idleCooldown
-- deathCooldown = cooldown added (s) when group dies/despawns
-- min/maxSpawnDelay = max/min  time(s) of random delay to add to respawn time of groups
-- ... - list of groupnames in the set
--]]
constant_pressure_set.new = function(targetActive, reinforceStrength,idleCooldown, deathCooldown, minSpawnDelay, maxSpawnDelay, ...)
	local instance={}
	--Properties
	
	--Asset pool override
	instance.poolId = nil
	
	--Other properties
	
	-- Names of groups that may be destroyed, along with the time the group became idle
	-- key=groupName
	-- values = time cooled down
	instance.groupListIdleTimes_={}

	--set (table) for active groups (those active or requested spawned)
	--key=groupNames
	--values = true
	instance.groupListActive_={}
	
	--set (table) for ready groups (those available to spawn)
	--key=groupNames
	--values = true
	instance.groupListReady_={}
	
	-- set (table) of groups cooling down
	-- key= groupName
	-- value = true
	instance.groupListCooldown_={}
	
	-- Optional predicate (groupName)->Boolean
	-- if set it must return true for group to go idle
	instance.idlePredicate_=nil
	
	-- Optional predicate (groupName)->Boolean
	-- An idle group satisfying this will count as dead for the cooldown
	instance.deathPredicate_=nil
	
	--List of times at which cooldowns will happen
	--key=time(s)
	--value == number of groups to cooldown at that time
	instance.timeListCooldown_={}
	
	--number of groups we're currently trying to keep alive
	instance.targetActiveCount=targetActive
	
	--NOTE: when a unit finishes cooldown, a random unit in cooldown queue is made available
	--for spawn - to stop a consistent spawn order developing
	
	--seconds of cooldown when group finishes its tasks
	instance.cooldownOnIdle=idleCooldown
	
	--seconds of cooldown when group dies/despawns
	instance.cooldownOnDeath=deathCooldown
	
	--max delay when a unit respawns
	instance.maxSpawnDelay=maxSpawnDelay
	
	--min delay when a unit respawns
	instance.minSpawnDelay=minSpawnDelay
	
	--[[
	Setting this to true will de-activate the this instance at the next tick
	--]]
	instance.killSwitch=false
	
	--Assign methods
	setmetatable(instance,constant_pressure_set.instance_meta_)

	instance.exclude_despawn_near = coalition.side -- all players
	--constant_pressure_set.log_i.log(instance.exclude_despawn_near) -- debug

	instance.groupDataLookup={} --lookup mapping groupName to group spawn data where available	
	local allGroups={}--all group names
	
	for _,v in pairs{...} do
		if type(v)=='string' then
			table.insert(allGroups,v)
		else --try to interpret as group data
			table.insert(allGroups,v.data.name)
			instance.groupDataLookup[v.data.name]=v
			--helms.log_i.log(v)--debug
		end
	end
	
	--select random groups to be initial spawns and ready retinforcements
	local initForce=helms.util.removeRandom(allGroups, reinforceStrength+targetActive)
	
	for _,g in pairs(initForce) do
		instance:addGroup_(g,true)
	end
	
	-- remaining groups are not available immediately
	for _,g in pairs(allGroups) do
		instance:addGroup_(g,false)
	end
	
	asset_pools.addPoolToPoll_(instance)
	
	return instance
end

--#######################################################################################################
-- UNIT_REPAIRMAN


--NAMESPACES----------------------------------------------------------------------------------------------
unit_repairman={}
----------------------------------------------------------------------------------------------------------

-- MODULE OPTIONS:----------------------------------------------------------------------------------------
unit_repairman.poll_interval = 67 --seconds, time between updates of group availability
----------------------------------------------------------------------------------------------------------doPoll_

--[[
Loggers for this module
--]]
unit_repairman.log_i = helms.logger.new("unit_repairman","info")
unit_repairman.log_e = helms.logger.new("unit_repairman","error")

--error handler for xpcalls. wraps unit_repairman.log_e.log
unit_repairman.catchError = function(err)
	unit_repairman.log_e.log(err)
end 

--UNIT REPAIRMAN---------------------------------------------------------------------------------------

--[[
key = group name in mission
value = {groupName, minDelaySeconds, maxDelaySeconds, options, lastDamagedAt, initialStrength, lastHealth}
--]]
unit_repairman.tracked_groups_={}


--POLL----------------------------------------------------------------------------------------------------

unit_repairman.doPoll_=function()
	local groupName = nil
	local urData = nil
	local repairedGroups = {}
	local now = timer.getTime()
	
	local pollGroup = function()
		local group,units = helms.dynamic.getLivingUnits(groupName) 
		local doRepair = false
		
		local health = helms.dynamic.getNormalisedGroupHealth(groupName)
		if urData.lastHealth == nil then urData.lastHealth = 1.0 end
		if health < urData.lastHealth then
			urData.lastDamagedAt = now
		end
		urData.lastHealth = health

		if health < 1.0
			and urData.lastDamagedAt ~= nil and urData.lastDamagedAt + (1.0 - health) * urData.options.perDamageRepairSeconds * urData.initialStrength + urData.options.baseRepairSeconds < now
			and not urData.awaitingActivation then

			doRepair = true
		end

		--unit_repairman.log_i.log(urData) -- debug
		if doRepair then
			table.insert(repairedGroups, groupName)
			--schedule next respawn----------------------------------
			helms.dynamic.scheduleFunction(unit_repairman.doPeriodicRespawn_,{urData.groupName,  urData.minDelaySeconds, urData.maxDelaySeconds,urData.options},
				now + math.random(urData.minDelaySeconds,urData.maxDelaySeconds),true)
		end

	end
	
	--do group poll
	for k,v in pairs(unit_repairman.tracked_groups_) do
		--parameters for the lambda
		groupName = k
		urData = v
		
		xpcall(pollGroup,unit_repairman.catchError) --safely do work of polling the group
	end
	
	--remove groups from further polling who have been scheduled to respawn
	for k,v in pairs(repairedGroups) do
		unit_repairman.tracked_groups_[v] = nil
	end

	--schedule next poll----------------------------------
	return now + unit_repairman.poll_interval
end

--[[
respawn named group and schedule a further respawn after random delay

@param groupName = name of group in ME to respawn
@param minDelaySeconds = minimum delay for subsequent respawn
@param maxDelaySeconds = maximum delay for subsequent respawn
@param options.remainingSpawns = when this reaches 0 the spawns will stop. Leave nil for no-limit
@param options.spawnUntil = latest value of timer.getTime() that spawns will occur. Leave nil for no-limit
@param options.delaySpawnIfPlayerWithin = lateral distance from the group within which red or blue players block spawn
@param options.retrySpawnDelay = (s) time after which to retry spawn if it's blocked (e.g. by players nearby). Default is 600 (10 minutes.)
@param options.perDamageRepairSeconds = (s) respawn delay per unit destroyed (or equivalent damage)
@param options.baseRepairSeconds = (s) minimum delay to schedule respawn after new damage occurs
--]]
unit_repairman.doPeriodicRespawn_ = function(groupName, minDelaySeconds, maxDelaySeconds, options)
	
	if options == nil then
		options = {}
	end
	local now = timer.getTime()

	local function action()		
		local group
		local newOptions = {perDamageRepairSeconds = 180, baseRepairSeconds = 60}--options for subsequent respawn
		
		
		if options.delaySpawnIfPlayerWithin then 
			--check for players nearby
			local gclpOptions={pickUnit=true, useGroupStart=true}
			local startPoint = helms.mission.getGroupStartPoint2D(groupName)
			local dist,_,_ = helms.dynamic.getClosestLateralPlayer(groupName,{coalition.side.RED,coalition.side.BLUE}, gclpOptions)
			
			if(dist ~= nil and dist < options.delaySpawnIfPlayerWithin) then --player too close
				local delay = 600 --seconds
				if options.retrySpawnDelay then
					delay = options.retrySpawnDelay
				end
				
				helms.dynamic.scheduleFunction(unit_repairman.doPeriodicRespawn_,{groupName,  minDelaySeconds, maxDelaySeconds,options}, now + delay, true) -- reschedule with the same options
				return
			end
		end
		
		for k,v in pairs(options) do
			newOptions[k] = v
		end
	
		if options.remainingSpawns then
			if options.remainingSpawns <= 0 then return end
			newOptions.remainingSpawns = options.remainingSpawns - 1
		end
		
		if options.spawnUntil then
			if now > options.spawnUntil then return end
		end
		
		helms.dynamic.respawnMEGroupByName(groupName) --respawn with original tasking
		
		group = helms.dynamic.getGroupByName(groupName)

		local initSize = 0
		if group then
			trigger.action.activateGroup(group) --ensure group is active
			initSize = group:getSize()
		end		
		
		unit_repairman.tracked_groups_[groupName]= {groupName = groupName,
			minDelaySeconds = minDelaySeconds,
			maxDelaySeconds = maxDelaySeconds,
			options = newOptions, 
			initialStrength = initSize,
			lastHealth = 1.0,
			awaitingActivation = false}
	end--action
	
	xpcall(action,unit_repairman.catchError) -- safely call the respawn action
end

unit_repairman.eventHandler = { 
	onEvent = function(self,event)
		if (event.id == world.event.S_EVENT_BIRTH) then
			helms.util.safeCall(unit_repairman.birthHandler,{event.initiator},unit_repairman.catchError)
		end

		if (event.id == world.event.S_EVENT_UNIT_LOST) then
			unit_repairman.log_i.log('dead event'.. helms.util.obj2str(event.initiator))--TODO
		end
	end
}

world.addEventHandler(unit_repairman.eventHandler)

unit_repairman.birthHandler = function(initiator)
	if initiator and initiator:getCategory() == Object.Category.UNIT then
		local group = initiator:getGroup()
		if group then
			local groupName = group:getName()
			local urData = unit_repairman.tracked_groups_[groupName]
			if urData and urData.awaitingActivation then
				urData.awaitingActivation = false
				
				helms.dynamic.scheduleFunction(helms.dynamic.respawnMEGroupByName,{groupName},timer.getTime() + 2,true) -- respawn after a short delay to prevent a crash
			end
		end
	end
end

--API UNIT_REPAIRMAN---------------------------------------------------------------------------------------

--[[
register group for periodic respawns random delay

@param groupName = name of group in ME to respawn (ignored if groupData set)
@param minDelaySeconds = minimum delay for subsequent respawn
@param maxDelaySeconds = maximum delay for subsequent respawn
@param options.remainingSpawns = when this reaches 0 the spawns will stop. Leave nil for no-limit
@param options.spawnUntil = latest value of timer.getTime() (mission elapsed time) that spawns will occur. Leave nil for no-limit
@param options.delaySpawnIfPlayerWithin = lateral distance from the group within which red or blue players block spawn
@param options.retrySpawnDelay = (s) time after which to retry spawn if it's blocked (e.g. by players nearby). Default is 600 (10 minutes.)
@param options.perDamageRepairSeconds = (s) respawn delay per unit destroyed (or equivalent damage accross the group)
@param options.baseRepairSeconds = (s) minimum delay to schedule respawn after new damage occurs
--]]
unit_repairman.register = function(groupName, minDelaySeconds, maxDelaySeconds, options)
	local group = helms.dynamic.getGroupByName(groupName)

	local initSize = 0
	if group then
		initSize = group:getSize()
	end		
	
	
	if options.perDamageRepairSeconds == nil then options.perDamageRepairSeconds = 3600 end
	if options.baseRepairSeconds == nil then options.baseRepairSeconds = 600 end
	
	unit_repairman.tracked_groups_[groupName] = {
		groupName = groupName,
		minDelaySeconds = minDelaySeconds,
		maxDelaySeconds = maxDelaySeconds,
		options = options,
		initialStrength = initSize,
		lastHealth = 1.0,
		awaitingActivation = helms.mission.groupAwaitingActivation(groupName)}
end

--[[
deregister group for periodic respawns random delay

@param groupName = name of group in ME to stop repairing, or a table containing ME names of groups to deregister
@param despawnNow = (default true) despawn the group now if it exists?
--]]
unit_repairman.deregister = function(groupName, despawn)
	if type(groupName) == 'string' then
		groupName = {groupName}
	end

	for _,v in pairs(groupName) do
		unit_repairman.tracked_groups_[v] = nil
		if despawn == nil or despawn == true then
			helms.dynamic.despawnGroupByName(v)
		end
	end
end

--[[
deregister group for periodic respawns random delay

@param substring = if a substring of a groupname, that group will cease being repaired, and may optionally be despawned
@param despawnNow = (default true) despawn the group now if it exists?
--]]
unit_repairman.deregisterRepairmanIfNameContains = function(substring, despawn)
	unit_repairman.deregister(helms.mission.getNamesContaining(substring),despawn)
end

--[[
	Register a unit_repairman for each group whose name contains a certain substring.
	
@param substring = if a substring of a groupname, that group will get a repair scheduled
@param minDelaySeconds = minimum random delay to subsequent respawn
@param maxDelaySeconds = maximum random delay to subsequent respawn
@param options.remainingSpawns = when this reaches 0 the spawns will stop. Leave nil for no-limit
@param options.spawnUntil = latest value of timer.getTime() (mission elapsed time) that spawns will occur. Leave nil for no-limit
@param options.delaySpawnIfPlayerWithin = lateral distance from the group within which red or blue players block spawn
@param options.retrySpawnDelay = (s) time after which to retry spawn if it's blocked (e.g. by players nearby). Default is 600 (10 minutes.)
@param options.perDamageRepairSeconds = (s) respawn delay per unit destroyed, or equivalent damage split between units. Default is 60 minutes
@param options.baseRepairSeconds = (s) minimum delay to schedule respawn after new damage occurs default is 10 minutes
@param replaceSubstring = string to replace substring in generated groups in the mission. Default to "-".
@param respawnNow = bool, default true. Respawn the group now to apply the alias group name.

@returns a table where values are the original names of groups registered
--]]
unit_repairman.registerRepairmanIfNameContains = function(substring,  minDelaySeconds, maxDelaySeconds, options, replaceSubstring, respawnNow)

	local names = helms.mission.getNamesContaining(substring)
	if replaceSubstring == nil then replaceSubstring = "-" end
	if respawnNow == nil then respawnNow = true end
	for k, name in pairs(names) do
		unit_repairman.register(name, minDelaySeconds, maxDelaySeconds, options)

		helms.dynamic.createGroupAlias(name,string.gsub(name,substring,replaceSubstring,1))

		if respawnNow and not unit_repairman.tracked_groups_[name].awaitingActivation then
			helms.dynamic.respawnMEGroupByName(name) 
		end -- respawn after applying alias
	end

	return names
end

helms.dynamic.scheduleFunction(unit_repairman.doPoll_,nil,timer.getTime() + unit_repairman.poll_interval)

--#######################################################################################################
-- ASSET_POOLS (PART 2)
helms.dynamic.scheduleFunction(asset_pools.doPoll_,nil,timer.getTime()+asset_pools.poll_interval)

return asset_pools