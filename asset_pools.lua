-- ASSET_POOLS
-- Run once at mission start after initializing MIST (Tested with Mist 4.4.90)
-- 
-- Adds functionality based on pools of groups, tracking availability
-- And allowing availability-dependent respawing based on various triggers
--
-- V1.0
-- Script by HappyGnome

--NAMESPACES----------------------------------------------------------------------------------------------
asset_pools={}
ap_utils={}

-- MODULE OPTIONS:----------------------------------------------------------------------------------------
asset_pools.poll_interval=60 --seconds, time between updates of group availability
----------------------------------------------------------------------------------------------------------

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


--RESPAWNABLE_ON_CALL-----------------------------------------------------------------------------------------
--[[
Pool class used for respawnable-on-call operation. Currently only designed for controlling a single group
--]]
asset_pools.RespawnableOnCall={

	meta_={},		
	
	-- Return a new instance of RespawnableOnCall
	-- param id = index of this pool in pools list
	new = function()
		local instance={}
		--Properties
		
		--Asset pool override
		instance.poolId = nil
		
		
		--[[
		Set the group tracked by this asset_pool
		--]]
		instance.groupName = ""
		
		--[[
			canRequestAt ==
			true -> request any time
			false -> not available to request
			int -> time that requests can next be made (s elapsed in mission)
		--]]
		instance.canRequestAt = true
		
		--[[
			spawnDelay ==
			int -> time between request and activation/respawn (s)
		--]]
		instance.spawnDelay = 60
		
		--[[
			delayWhenIdle ==
			int -> time before respawn requests allowed when unit goes idle
		--]]
		instance.delayWhenIdle = 300
		
		--[[
			delayWhenDead ==
			int -> time before respawn requests allowed when unit is dead
		--]]
		instance.delayWhenDead = 300
		
		--[[
			side == coalition.side, or nil for all
			-> coalition name that can spawn group and receive updates about them
		--]]
		instance.side = nil
		
		setmetatable(instance,asset_pools.RespawnableOnCall.meta_)
		
		return instance
	end,
	
	--[[
	Add comms submenu for red or blue (side == instance of coalition.side)
	--]]
	ensureCoalitionSubmenu_=function(side)
		local coa_string=ap_utils.sideToString(side)
		local subMenuName="subMenu_"..coa_string
		if asset_pools.RespawnableOnCall[subMenuName]==nil then--create submenu
			asset_pools.RespawnableOnCall[subMenuName] = 
				missionCommands.addSubMenuForCoalition(side, coa_string.." Assets",nil)
		end	
		return subMenuName
	end,
	
	--[[
	Add comms submenu for assets available to any faction
	return name of the submenu
	--]]
	ensureUniversalSubmenu_=function()
		local subMenuName="subMenu"
		if asset_pools.RespawnableOnCall[subMenuName]==nil then--create submenu
			asset_pools.RespawnableOnCall[subMenuName] = 
				missionCommands.addSubMenu("Other Assets",nil)
		end		
		return subMenuName
	end
}

--Do metatable setup
asset_pools.RespawnableOnCall.meta_.__index={ --Metatable for this "class"

	--Asset pool override
	groupDead=function(self, groupName, now)			
		self.canRequestAt
			= now + self.delayWhenDead
			
		--trigger.action.outText("Detected that asset "..groupName.." is dead",5)--DEBUG
		--asset_pools.log_i:info(self.groupName.." was detected dead.")
		
		--stop polling this group
		return false		
	end,

	--Asset pool override
	groupIdle=function(self, groupName, now)			
		self.canRequestAt
			= now + self.delayWhenIdle
			
		--trigger.action.outText("Detected that asset "..groupName.." is idle",5)--DEBUG			
		--asset_pools.log_i:info(groupName.." was detected idle.")
		
		--stop polling this group
		return false 
	end,

	--Asset pool override
	onTick=function(self, now)	
		return true -- keep polling
	end,


	--Other methods

	--[[
	Private: Request to spawn new instance of template group if there's not already one
	--]]
	handleSpawnRequest_ = function(self)
		local now=timer.getTime()
		local cRA=self.canRequestAt
		local cRA_isnum = type(cRA)=="number"
		
		if cRA==true or (cRA_isnum and cRA<now) then
			self.canRequestAt=false --try to prevent dual requests, schedule spawn
			mist.scheduleFunction(self.doReSpawn_,{self},now+self.spawnDelay)
			
			ap_utils.messageForCoalitionOrAll(self.side,
				string.format("%s will be on-call in %ds",self.groupName,self.spawnDelay),5)
				
			asset_pools.log_i:info(self.groupName.." was called in.")
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
	Private: respawn and activate the named group
	--]]
	doReSpawn_ = function(self)
		local group = Group.getByName(self.groupName)
		
		mist.respawnGroup(self.groupName,true) --respawn with original tasking
		group = Group.getByName(self.groupName)
		
		if group then
			trigger.action.activateGroup(group) --ensure group is active
		end
		
		asset_pools.addGroupToPoll(self,self.groupName)
	end,

	--[[
	Set up comms menus needed to spawn this group
	--]]
	createComms=function(self)
		--add menu options
		if self.side then --coalition specific addition	
			local subMenuName=asset_pools.RespawnableOnCall.ensureCoalitionSubmenu_(self.side)
			
			missionCommands.addCommandForCoalition(self.side,self.groupName,asset_pools.RespawnableOnCall[subMenuName],
				self.handleSpawnRequest_,self)
		else --add for all	
			local subMenuName=asset_pools.RespawnableOnCall.ensureUniversalSubmenu_()
			
			missionCommands.addCommand(self.groupName,asset_pools.RespawnableOnCall[subMenuName],
				self.handleSpawnRequest_,self)
		end
	end
}--meta_
----------------------------------------------------------------------------------------------------




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
asset_pools.createRespawnableGroup=function(groupName, spawnDelay, delayWhenIdle, delayWhenDead, coalitionName)
	
	local coa=ap_utils.stringToSide(coalitionName)
	
	local newPool=asset_pools.RespawnableOnCall.new()
	
	newPool.canRequestAt=true --allow immediate requests
	newPool.spawnDelay=spawnDelay
	newPool.delayWhenIdle=delayWhenIdle
	newPool.delayWhenDead=delayWhenDead
	newPool.side=coa
	newPool.groupName=groupName
	
	--add pool and add group to poll list, with an association to this group
	asset_pools.addPoolToPoll_(newPool)
	
	newPool:createComms()
	
end--asset_pools.createRespawnableGroup

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
asset_pools.addGroupToPoll = function(pool,groupName)
	asset_pools.tracked_groups_[groupName]=pool.poolId
end

--[[
Remove groupName from the poll list
--]]
asset_pools.removeGroupFromPoll = function(groupName)
	asset_pools.tracked_groups_[groupName]=nil
end

--GLOBAL POLL---------------------------------------------------------------------------------------

--[[
Private: do poll of first unit in each watched group
--]]
asset_pools.doPoll_=function()

	local now=timer.getTime()
	
	local groupName=""--loop variables for use in the poll lambda (avoid making lambda in a loop)
	local poolAt=nil
	
	--Lambda that does the polling work
	--wrap the poll work in a function so we can run it in xpcall, without crasghing the loop
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
		if group then
			local units = Group.getUnits(group)
			if units then
				unit=units[1]
			end				
		end	
		
		local isActive = false
		local isDead = true -- being dead takes precedence over being inactive 
							-- if the unit doesn't exist we also count it as dead
		
		if unit then
			if Unit.getLife(unit)>1.0 then
				isDead=false
				
				--check whether group or unit have a controller with active task
				
				local controller=Unit.getController(unit)
				local groupController=Group.getController(group)
				
				--if controller then trigger.action.outText("DB2",5)end--DEBUG
				--if groupController then trigger.action.outText("DB3",5)end--DEBUG
				
				local unitHasTask = controller and Controller.hasTask(controller)
				local groupHasTask =  groupController and Controller.hasTask(groupController)
				
				isActive= Unit.isActive(unit) and (unitHasTask or groupHasTask)					
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

	for k,v in pairs(asset_pools.tracked_groups_) do
		--parameters for the lambda
		groupName=k
		poolAt=v
		
		xpcall(pollGroup,asset_pools.catchError) --safely do work of polling the group
	end
	
	local tickPool--parameter for the lambda - pool to update
	
	--lambda for onTick callbacks
	local function doTick()
		if not tickPool:onTick(asset_pools.poll_interval) then
		-- if pool requests to stop polling it and its groups
			asset_pools.pools_[tickPool.poolId]=nil
		end
	end
	
	--do misc state updates for each pool
	for k,pool in ipairs(asset_pools.pools_) do
		tickPool=pool
		xpcall(doTick,asset_pools.catchError) --safely do work of dispatching tick events
	end

	--schedule next poll
	mist.scheduleFunction(asset_pools.doPoll_,nil,now+asset_pools.poll_interval)
end

mist.scheduleFunction(asset_pools.doPoll_,nil,timer.getTime()+asset_pools.poll_interval)