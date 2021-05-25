--#######################################################################################################
-- ASSET_POOLS (PART 1)
-- Run once at mission start after initializing MIST (Tested with Mist 4.4.90)
-- 
-- Adds functionality based on pools of groups, tracking availability
-- And allowing availability-dependent respawing based on various triggers
--
-- Script by HappyGnome

--doFile returns single global instance, or creates one
if asset_pools then
	return asset_pools
end


--NAMESPACES----------------------------------------------------------------------------------------------
asset_pools={}

-- MODULE OPTIONS:----------------------------------------------------------------------------------------
asset_pools.poll_interval=60 --seconds, time between updates of group availability
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
Table of pool objects. Each should be instances a class implementing:

poolId --> key of the pool in asset_pools.pools_

groupDead=function(self,groupName, now), --> called when group despawns or dies
												now == Mission time at death detection
											return true to keep polling this group, or false to stop

groupIdle=function(self,groupName, now) --> called when group no-longer has a task
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
asset_pools.log_i=mist.Logger:new("asset_pools","info")
asset_pools.log_e=mist.Logger:new("asset_pools","error")

--error handler for xpcalls. wraps asset_pools.log_e:error
asset_pools.catchError=function(err)
	asset_pools.log_e:error(err)
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
		This is a table that will be accepted by mist.dynAdd
--]]
asset_pools.RespawnGroupForPoll = function(pool,groupName, groupData)
	local group 
	
	if groupData then
		groupName=groupData.groupName
		mist.dynAdd(groupData)
	else
		group = Group.getByName(groupName)
		
		mist.respawnGroup(groupName,true) --respawn with original tasking
	end
	group = Group.getByName(groupName)
	
	if group then
		trigger.action.activateGroup(group) --ensure group is active
	end
	
	asset_pools.addGroupToPoll_(pool,groupName)
end

--[[
Private: do poll of groups and pools
--]]
asset_pools.doPoll_=function()

	local now=timer.getTime()
	
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
		local group = Group.getByName(groupName)
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
				
				local unitHasTask = controller and controller:hasTask()
				
				
				isActive = isActive or (unit:isActive() and (unitHasTask or groupHasTask))					
			end
			--trigger.action.outText("DB1",5)--DEBUG
		end
		
		if isDead then
			if not pool:groupDead(groupName,now) then -- if pool requests to stop polling this group
				asset_pools.tracked_groups_[groupName]=nil
			end 
		elseif not isActive then
			if not pool:groupIdle(groupName,now) then -- if pool requests to stop polling this group
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

	--schedule next poll----------------------------------
	mist.scheduleFunction(asset_pools.doPoll_,nil,now+asset_pools.poll_interval)
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
ap_utils.log_i=mist.Logger:new("ap_utils","info")
ap_utils.log_e=mist.Logger:new("ap_utils","error")


--UTILS------------------------------------------------------------------------------------------------
--[[
Convert coalition name to coalition.side

return coalition.side, or nil if none recognised 
name is not case sensitive, but otherwise should be "red", "blue" or "neutral" to name a particular faction
--]]
ap_utils.stringToSide = function(name)
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
ap_utils.sideToString = function(side)
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
Print message to the given coalition.side, or to all players if side==nil
--]]
ap_utils.messageForCoalitionOrAll = function(side,message,delay)
	if side then
		trigger.action.outTextForCoalition(side,message,delay)
	else
		trigger.action.outText(message,5)
	end
end

--[[
Print message to the given coalition.side, or to all players if side==nil
--]]
ap_utils.messageForCoalitionOrAll = function(side,message,delay)
	if side then
		trigger.action.outTextForCoalition(side,message,delay)
	else
		trigger.action.outText(message,5)
	end
end

--[[
Randomly remove N elements from a table and return removed elements (key,value)
--]]
ap_utils.removeRandom=function(t,N)
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
ap_utils.eraseByPredicate=function(s,pred)
	local ret=0
	
	
	
	for k,v in pairs(s) do
		if pred(k) then
			ret=ret+v
			s[k]=nil
		end
	end
	
	return ret
end


--[[
Return = Boolean: Does named group have a living active unit in-play
--]]
ap_utils.groupHasActiveUnit=function(groupName)
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
Make random groups

param nameRoot = base group name e.g. "dread" generates "dread-1", "dread-2",...
param count = number of groups to generate
param unitDonors = array of group names specifying the unit combinations to use
param taskDonors = array of group names specifying routes/tasks to use

Return = unpacked array of groupData tables that can be passed to dynAdd to spawn a group
--]]
ap_utils.generateGroups = function(nameRoot,count,unitDonors,taskDonors)

	local groupNum =0 --index to go with name route to make group name
	local ret={}
	local logMessage="Generated groups: "
	
	while groupNum<count do
		groupNum = groupNum + 1
		
		local newGroupData = mist.getGroupData(unitDonors[math.random(#unitDonors)])
		
		--get route and task data from random task donor
		local taskDonorName=taskDonors[math.random(#taskDonors)]
		local taskDonorData = mist.getGroupData(taskDonorName)
		newGroupData.route  = mist.getGroupRoute(taskDonorName,true) --copying taskDonorData.route directly doesn't work...
																	  -- mist... 
		
		newGroupData.groupName=nameRoot.."-"..groupNum
		newGroupData.groupId=nil --mist generates a new id
		
		--null group position - get it from the route
		newGroupData.x=nil --taskDonorData.x
		newGroupData.y=nil --taskDonorData.y
		
		local unitInFront=taskDonorData.units[1] --unit in formation in front of the one being set. Initially the leader from the task donor
		--lateral offsets between group units
		--local xOff=100*math.sin(unitInFront.heading+math.rad(120))
		--local yOff=100*math.cos(unitInFront.heading+math.rad(120))
		
		--generate unit names and null ids
		--also copy initial locations and headings
		for i,unit in pairs(newGroupData.units) do
			unit.unitName=nameRoot.."-"..groupNum.."-"..(i+1)
			unit.unitId=nil
			
			--null unit locations - force them to be set by start of route
			unit.x=nil--taskDonorData.x
			unit.y=nil--taskDonorData.y
			unit.alt=nil--unitInFront.alt
			unit.alt_type=nil--unitInFront.alt_type
			unit.heading=nil--unitInFront.heading
			--unitInFront=unit
			
			--debug
			--ap_utils.log_i:info("unit data: "..unit.x..","..unit.y..","..unit.type)
			
		end
		
		newGroupData.lateActivation = true
		
		table.insert(ret,newGroupData)
		
		--[[local msgOK=" FAIL"
		if mist.groupTableCheck(newGroupData) then
			msgOK=" OK"
		end
		
		--debug
		p_utils.log_i:info("group data: "..newGroupData.category..","..newGroupData.country)
		
		logMessage=logMessage..newGroupData.groupName..msgOK..", "		--]]		
		
	end
	
	--ap_utils.log_i:info(logMessage)
	
	return unpack(ret)

end

--[[
Find the closest player to any living unit in named group
ignores altitude - only lateral coordinates considered
@param groupName - name of the group to check
@param side - coalition.side of players to check against
@param unitFilter - (unit)-> boolean returns true if unit should be considered
		(if this is nil then all units are considered)
@return dist,playerUnit, closestUnit OR nil,nil,nil if no players found or group empty
--]]
ap_utils.getClosestLateralPlayer = function(groupName,side, unitFilter)

	local playerUnits = coalition.getPlayers(side)
	local group = Group.getByName(groupName)
	
	local ret={nil,nil,nil} --default return
	
	
	
	local units=group:getUnits()
	
	local positions={} -- {x,z},.... Indices correspond to indices in units
	for i,unit in pairs(units) do
		local location=unit:getPoint()
		
		if not unitFilter or unitFilter(unit) then
			positions[i]={location.x,location.z}
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
	
	return unpack(ret)
	
end

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
--]]
ap_utils.makeRocIfNameContains = function(substring, spawnDelay, delayWhenIdle, delayWhenDead, coalitionName)
	for name,v in pairs(mist.DBs.groupsByName) do
		if string.find(name,substring) ~= nil then
			respawnable_on_call.new(name, spawnDelay, delayWhenIdle, delayWhenDead, coalitionName)	
		end
	end
end

--return ap_utils

--#######################################################################################################
-- RESPAWNABLE_ON_CALL

--REQUISITES----------------------------------------------------------------------------------------------
--local asset_pools=dofile('./Scripts/AssetPools/asset_pools.lua')
--local ap_utils=dofile('./Scripts/AssetPools/ap_utils.lua')


--NAMESPACES----------------------------------------------------------------------------------------------
respawnable_on_call={}
----------------------------------------------------------------------------------------------------------

--[[
Loggers for this module
--]]
respawnable_on_call.log_i=mist.Logger:new("respawnable_on_call","info")
respawnable_on_call.log_e=mist.Logger:new("respawnable_on_call","error")

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
			--asset_pools.log_i:info(self.groupName.." was detected dead.")
			
			if self.groupDeathCallback then
				self.groupDeathCallback(self.groupName, self.timesCalledIn)
			end
			
			--stop polling this group
			return false		
		end,

		--Asset pool override
		groupIdle=function(self, groupName, now)			
			self.canRequestAt
				= now + self.delayWhenIdle
				
			--trigger.action.outText("Detected that asset "..groupName.." is idle",5)--DEBUG			
			--asset_pools.log_i:info(groupName.." was detected idle.")
			
			if self.groupIdleCallback then
				self.groupIdleCallback(self.groupName, self.timesCalledIn)
			end
			
			--stop polling this group
			return false 
		end,

		--Asset pool override
		onTick=function(self, now)	
			return not killSwitch -- keep polling
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
			
			if cRA==true or (cRA_isnum and cRA<now) then
				self.canRequestAt=false --try to prevent dual requests, schedule spawn
				mist.scheduleFunction(asset_pools.RespawnGroupForPoll,{self,self.groupName,nil},now+self.spawnDelay)
				
				self.timesCalledIn = self.timesCalledIn+1 --increment spawn count
				if self.groupCallInCallback then --post call-in callback
					self.groupCallInCallback(self.groupName, self.timesCalledIn)
				end
				
				ap_utils.messageForCoalitionOrAll(self.side,
					string.format("%s will be on-call in %ds",self.groupName,self.spawnDelay),5)
					
				respawnable_on_call.log_i:info(self.groupName.." was called in.")
			else
				ap_utils.messageForCoalitionOrAll(self.side,
					string.format("%s is not available or is already on-call",self.groupName),5)
				if cRA_isnum then
					local toWait= self.canRequestAt-now
					ap_utils.messageForCoalitionOrAll(self.side,
						string.format("%s will be available in %ds",self.groupName,toWait),5)
				end
			end
		end,

		--[[
		Set up comms menus needed to spawn this group
		--]]
		createComms_=function(self)
			--add menu options
			if self.side then --coalition specific addition	
				local subMenuName=respawnable_on_call.ensureCoalitionSubmenu_(self.side)
				
				self.commsPath=missionCommands.addCommandForCoalition(self.side,self.groupName,respawnable_on_call[subMenuName],
					self.handleSpawnRequest_,self)
			else --add for all	
				local subMenuName=respawnable_on_call.ensureUniversalSubmenu_()
				
				self.commsPath=missionCommands.addCommand(self.groupName,respawnable_on_call[subMenuName],
					self.handleSpawnRequest_,self)
			end
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
		end
	}----index
}--meta_	
	
--[[
Add comms submenu for red or blue (side == instance of coalition.side)
--]]
respawnable_on_call.ensureCoalitionSubmenu_=function(side)
	local coa_string=ap_utils.sideToString(side)
	local subMenuName="subMenu_"..coa_string
	if respawnable_on_call[subMenuName]==nil then--create submenu
		respawnable_on_call[subMenuName] = 
			missionCommands.addSubMenuForCoalition(side, coa_string.." Assets",nil)
	end	
	return subMenuName
end

--[[
Add comms submenu for assets available to any faction
return name of the submenu
--]]
respawnable_on_call.ensureUniversalSubmenu_=function()
	local subMenuName="subMenu"
	if respawnable_on_call[subMenuName]==nil then--create submenu
		respawnable_on_call[subMenuName] = 
			missionCommands.addSubMenu("Other Assets",nil)
	end		
	return subMenuName
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
	
	local coa=ap_utils.stringToSide(coalitionName)
	
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
	instance.canRequestAt = not ap_utils.groupHasActiveUnit(groupName)
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
	
	
	--add pool and add group to poll list, with an association to this group
	asset_pools.addPoolToPoll_(instance)
	
	instance:createComms_()
	
	return instance
			
end--new

--#######################################################################################################
-- CONSTANT_PRESSURE_SET
--
-- Asset pool functionality for keeping randomized steady presence of assets alive

--REQUISITES----------------------------------------------------------------------------------------------
--local asset_pools=dofile('./Scripts/AssetPools/asset_pools.lua')
--local ap_utils=dofile('./Scripts/AssetPools/ap_utils.lua')


--NAMESPACES----------------------------------------------------------------------------------------------
constant_pressure_set={}
----------------------------------------------------------------------------------------------------------

--[[
Loggers for this module
--]]
constant_pressure_set.log_i=mist.Logger:new("constant_pressure_set","info")
constant_pressure_set.log_e=mist.Logger:new("constant_pressure_set","error")

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
			
			local cooldownTime=now+self.cooldownOnDeath
			self:putGroupOnCooldown_(groupName,cooldownTime)				
			
			--stop polling this group
			return false		
		end,

		--Asset pool override
		groupIdle=function(self, groupName, now)
		
			--check optional predicate if set
			if self.idlePredicate_ and not self.idlePredicate_(groupName) then
				return true -- not idle if predicate returns false
			end
			
			local cooldownTime=now+self.cooldownOnIdle
			self:putGroupOnCooldown_(groupName,cooldownTime)		
			
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
			local toReactivate= ap_utils.removeRandom(self.groupListCooldown_, 
				ap_utils.eraseByPredicate(self.timeListCooldown_,pred))
				
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
			for g in pairs(
				ap_utils.removeRandom(self.groupListReady_,-surplusSpawned)
				) do
				self:doScheduleSpawn_(g,now)--activate group and schedule to spawn with random delay
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
		putGroupOnCooldown_=function(self,groupName,cooldownTime)
		
			self.groupListActive_[groupName]=nil
			self.groupListCooldown_[groupName]=true
			
			if self.timeListCooldown_[cooldownTime] then
				self.timeListCooldown_[cooldownTime]
					=self.timeListCooldown_[cooldownTime]+1
			else
				self.timeListCooldown_[cooldownTime]=1
				--constant_pressure_set.log_i:info(self.timeListCooldown_[cooldownTime]..", "..cooldownTime)--DEBUG
			end	
		end,
		
		-- Move group to ready list and off cooldown list 
		takeGroupOffCooldown_=function(self,groupName)
		
			self.groupListReady_[groupName]=true
			self.groupListCooldown_[groupName]=nil
			constant_pressure_set.log_i:info(groupName.." cooled down")
		end,
		
		-- Schedule spawn of group at random future time
		doScheduleSpawn_=function(self,groupName,now)
		
			self.groupListReady_[groupName]=nil
			self.groupListActive_[groupName]=true
			
			local delay= math.random(self.minSpawnDelay,self.maxSpawnDelay)
			
			mist.scheduleFunction(asset_pools.RespawnGroupForPoll,
				{self,groupName,self.groupDataLookup[groupName]},now+delay)
				
			constant_pressure_set.log_i:info(groupName.." called in with delay "..delay)
			
		end,
		
		-- Set an idle predicate - an additional check before group goes idle
		-- predicate=function(groupName) -> Boolean
		-- predicate should return true if group allowed to go idle
		setIdlePredicate =function(self,predicate) 
			self.idlePredicate_=predicate
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
	
	
	instance.groupDataLookup={} --lookup mapping groupName to group spawn data where available	
	local allGroups={}--all group names
	
	for _,v in pairs{...} do
		if type(v)=='string' then
			table.insert(allGroups,v)
		else --try to interpret as group data
			table.insert(allGroups,v.groupName)
			instance.groupDataLookup[v.groupName]=v
		end
	end
	
	--select random groups to be initial spawns and ready retinforcements
	local initForce=ap_utils.removeRandom(allGroups, reinforceStrength+targetActive)
	
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
-- ASSET_POOLS (PART 2)
mist.scheduleFunction(asset_pools.doPoll_,nil,timer.getTime()+asset_pools.poll_interval)

return asset_pools