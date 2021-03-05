-- ASSET_POOLS
-- Run once at mission start after initializing MIST (Tested with Mist 4.4.90)
-- 
-- Adds functionality based on pools of groups, tracking availability
-- And allowing availability-dependent respawing based on various triggers
--
-- V1.0
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
--]]
asset_pools.RespawnGroupForPoll = function(pool,groupName)
	local group = Group.getByName(groupName)
	
	mist.respawnGroup(groupName,true) --respawn with original tasking
	group = Group.getByName(groupName)
	
	if group then
		trigger.action.activateGroup(group) --ensure group is active
	end
	
	asset_pools.addGroupToPoll_(pool,groupName)
end

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

	--schedule next poll
	mist.scheduleFunction(asset_pools.doPoll_,nil,now+asset_pools.poll_interval)
end

mist.scheduleFunction(asset_pools.doPoll_,nil,timer.getTime()+asset_pools.poll_interval)

return asset_pools