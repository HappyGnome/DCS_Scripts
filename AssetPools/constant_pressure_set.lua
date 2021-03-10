-- CONSTANT_PRESSURE_SET
--
-- Asset pool functionality for keeping randomized steady presence of assets alive
--
-- Script by HappyGnome

--REQUISITES----------------------------------------------------------------------------------------------
local asset_pools=dofile('./Scripts/AssetPools/asset_pools.lua')
local ap_utils=dofile('./Scripts/AssetPools/ap_utils.lua')


--NAMESPACES----------------------------------------------------------------------------------------------
constant_pressure_set={}
----------------------------------------------------------------------------------------------------------

--[[
Loggers for this module
--]]
constant_pressure_set.log_i=mist.Logger:new("constant_pressure_set","info")
constant_pressure_set.log_e=mist.Logger:new("constant_pressure_set","error")

--CONSTANT_PRESENCE_SET-----------------------------------------------------------------------------------------
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
