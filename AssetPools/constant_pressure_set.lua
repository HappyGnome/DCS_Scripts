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

--CONSTANT_PRESENCE_SET-----------------------------------------------------------------------------------------
--[[
Pool class used for managing a collection of groups, respawning them at random to keep up an approximately constant 
number in-mission
--]]
constant_pressure_set.ConstantPresenceSet={

	meta_={--Do metatable setup
		__index={ --Metatable for this "class"

			--Asset pool override
			groupDead=function(self, groupName, now)		

				self.groupList_[groupName]=now+self.cooldownOnDeath
				
				--stop polling this group
				return false		
			end,

			--Asset pool override
			groupIdle=function(self, groupName, now)	
					
				self.groupList_[groupName]=now+self.cooldownOnIdle
				
				--stop polling this group
				return false 
			end,

			--Asset pool override
			onTick=function(self, now)	
				
				--update cooldowns 
				
			
				return true -- keep polling
			end,


			--Other methods
			addGroup=function(self, groupName)
				if not self.groupList_[groupName] then
					self.groupList_[groupName]=0--ready to spawn immediately
				end
			end
			
			
		}--index
	},--meta_,		
	
	-- Return a new instance of RespawnableOnCall
	-- param id = index of this pool in pools list
	new = function()
		local instance={}
		--Properties
		
		--Asset pool override
		instance.poolId = nil
		
		--Other properties
		
		--Managed groups and their cooldown times 
		--key=groupNames
		--values = clock time of cooldown (>0 for cooling down, ==0 for spawnable, <0 for on-call)
		instance.groupList_={}
		
		--number of groups we're currently trying to keep alive
		instance.targetActiveCount=0
		
		--NOTE: when a unit finishes cooldown, a random unit in cooldown queue is made available
		--for spawn - to stop a consistent spawn order developing
		
		--seconds of cooldown when group finishes its tasks
		instance.cooldownOnIdle=300
		
		--seconds of cooldown when group dies/despawns
		instance.cooldownOnDeath=3600
		
		--max delay when a unit respawns
		instance.maxSpawnDelay=300
		
		--min delay when a unit respawns
		instance.minSpawnDelay=0
		
		--Assign methods
		setmetatable(instance,constant_pressure_set.ConstantPresenceSet.meta_)
		
		return instance
	end
}