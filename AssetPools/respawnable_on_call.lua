-- RESPAWNABLE_ON_CALL
--
-- Script by HappyGnome

--REQUISITES----------------------------------------------------------------------------------------------
local asset_pools=dofile('./Scripts/AssetPools/asset_pools.lua')
local ap_utils=dofile('./Scripts/AssetPools/ap_utils.lua')


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
			if self.commsPath then -- very important it's not il, or whole comms menu will be emptied
				missionCommands.removeItem(self.commsPath)
			end
			return self
		end,

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
			return not killSwitch -- keep polling
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
				mist.scheduleFunction(asset_pools.RespawnGroupForPoll,{self,self.groupName},now+self.spawnDelay)
				
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
		end
	}----index
},	--meta_	
	
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
end,

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
	
	
	--[[
	Set the group tracked by this asset_pool
	--]]
	instance.groupName = groupName
	
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



