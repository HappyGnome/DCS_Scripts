-- CONSTANT_PRESSURE_SET
--
-- Asset pool functionality for keeping randomized steady presence of assets alive
--
-- V1.0
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

		--Asset pool override
		groupDead=function(self, groupName, now)						
			
			local cooldownTime=now+self.cooldownOnDeath
			self:putGroupOnCooldown(groupName,cooldownTime)				
			
			--stop polling this group
			return false		
		end,

		--Asset pool override
		groupIdle=function(self, groupName, now)
			
			local cooldownTime=now+self.cooldownOnIdle
			self:putGroupOnCooldown(groupName,cooldownTime)		
			
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
				self:takeGroupOffCooldown(k)
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
				self:doScheduleSpawn(g,now)--activate group and schedule to spawn with random delay
			end
		
			return true -- keep polling
		end,


		--Other methods
		
		--add group assuming it's not already managed by this pool
		addGroup=function(self, groupName)
			if (not self.groupListActive_[groupName]) and (not self.groupListCooldown_[groupName]) then
				self.groupListReady_[groupName]=true--ready to spawn immediately
			end
		end,
		
		-- Move group to cooldown list and off of active list
		-- add cooldown clock time to cooldown list
		putGroupOnCooldown=function(self,groupName,cooldownTime)
		
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
		takeGroupOffCooldown=function(self,groupName)
		
			self.groupListReady_[groupName]=true
			self.groupListCooldown_[groupName]=nil
			constant_pressure_set.log_i:info(groupName.." cooled down")
		end,
		
		-- Schedule spawn of group at random future time
		doScheduleSpawn=function(self,groupName,now)
		
			self.groupListReady_[groupName]=nil
			self.groupListActive_[groupName]=true
			
			local delay= math.random(self.minSpawnDelay,self.maxSpawnDelay)
			
			mist.scheduleFunction(asset_pools.RespawnGroupForPoll,
				{self,groupName},now+delay)
				
			constant_pressure_set.log_i:info(groupName.." called in with delay "..delay)
			
		end
		
		
	}--index
}--meta_,		
	
--[[ 
-- Return a new instance of a constant pressure object

-- params 
-- targetActive = number of groups to try to keep active
-- idleCooldown = cooldown added when group goes idleCooldown
-- deathCooldown = cooldown added (s) when group dies/despawns
-- min/maxSpawnDelay = max/min  time(s) of random delay to add to respawn time of groups
-- ... - list of groupnames in the set
--]]
constant_pressure_set.new = function(targetActive,idleCooldown, deathCooldown, minSpawnDelay, maxSpawnDelay, ...)
	local instance={}
	--Properties
	
	--Asset pool override
	instance.poolId = nil
	
	--Other properties
	
	-- array of task forces
	-- entries are tables {"<groupName>"=true/false...} 
	-- where true indicates group is active
	instance.tfList_={}
	
	-- tf lookup by group
	-- key = group name
	-- value = index in tfList
	instance.tfLookup_={}
	
	--set (table) for active taskforces (those active or requested spawned)
	--key=tfKey
	--values = true
	instance.tfListActive_={}
	
	--set (table) for ready groups (those available to spawn)
	--key=tfKey
	--values = true
	instance.tfListReady_={}
	
	-- set (table) of groups cooling down
	-- key= groupName
	-- value = true
	instance.tfListCooldown_={}
	
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
	
	--Assign methods
	setmetatable(instance,constant_pressure_set.instance_meta_)
	
	--tfg = array of groups or single group
	for _,tfg in pairs{...} do
		--add new taskforce to list
		local tf={}
		table.insert(instance.tfList_, tf)
		local index=#instance.tfList_
			
		--initialize the taskforce based on this argument	
		if type(tfg)=="table" then -- taskforce of possibly multiple groups			
			for _,g in pairs tf do
				tf[g]=false -- group not initially spawned
				instance.tfLookup_[g]=index
			end			
		elseif 	 type(tf)=="string"	then --taskforce of one group of one
			tf[g]=false -- group not initially spawned
			instance.tfLookup_[g]=index
		end
	end
	
	asset_pools.addPoolToPoll_(instance)
	
	return instance
end
