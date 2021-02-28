-- RESPAWNABLE_ON_CALL 
-- Run once at mission start after initializing MIST (Tested with Mist 4.4.90)
-- Call addGroup once for each unit that can be respawned from the comms menu
-- Respawnable groups should be inactive in the mission - they are not activated, but instead
-- used as templates for spawned groups
--
-- V1.0
-- Script by HappyGnome
 
 
respawn_on_call={} -- namespace/ global instance for this script

--[[
keys = groupName
values = {"canRequestAt":true, "spawnDelay":0, "delayWhenIdle":0, "delayWhenDead":0, "side":"both"}

canRequestAt ==
	true -> request any time
	false -> not available to request
	int -> time that requests can next be made (s elapsed in mission)
spawnDelay ==
	int -> time between request and activation/respawn (s)
delayWhenIdle ==
	int -> time before respawn requests allowed when unit goes idle
delayWhenDead ==
	int -> time before respawn requests allowed when unit is dead
side == coalition.side, or nil for all
	-> coalition name that can spawn group and receive updates about them
--]]
respawn_on_call.groupList={} 

--[[
List of group to poll to check they're still on-call
--]]
respawn_on_call.pollList={} 

respawn_on_call.log_i=mist.Logger:new("respawn_on_call.log_i","info")


--[[
Add group with given name to re-spawnable units list. Add comms menu command 

Call this at mission start/when associated unit can first be requested
for each respawnable resource

spawnDelay ==
	int -> time between request and activation/respawn (s)
delayWhenIdle ==
	int -> time (s) before respawn requests allowed when unit goes idle
delayWhenDead ==
	int -> time (s) before respawn requests allowed when unit is dead
coalitionName == "red", "blue", or "all" (anything else counts as "all")
	-> coalition name that can spawn group and receive updates about them
--]]
respawn_on_call.addGroup=function(groupName, spawnDelay, delayWhenIdle, delayWhenDead, coalitionName)
	
	local coa=respawn_on_call.stringToSide(coalitionName)
	
	local newGroup={}
	newGroup.canRequestAt=true --allow immediate requests
	newGroup.spawnDelay=spawnDelay
	newGroup.delayWhenIdle=delayWhenIdle
	newGroup.delayWhenDead=delayWhenDead
	newGroup.side=coa
	
	respawn_on_call.groupList[groupName]=newGroup
	
	--add menu options
	if coa then --coalition specific addition
		local subMenuName="subMenu_"..coa
		if respawn_on_call[subMenuName]==nil then--create submenu
			respawn_on_call[subMenuName] = 
				missionCommands.addSubMenuForCoalition(coa, "Respawnable Assets",nil)
		end		
	
		missionCommands.addCommandForCoalition(coa,groupName,respawn_on_call[subMenuName],
			respawn_on_call.handleSpawnRequest_,groupName)
	else --add for all
		local subMenuName="subMenu"
		if respawn_on_call[subMenuName]==nil then--create submenu
			respawn_on_call[subMenuName] = 
				missionCommands.addSubMenu("Respawnable Assets",nil)
		end		
	
		missionCommands.addCommand(groupName,respawn_on_call[subMenuName],
			respawn_on_call.handleSpawnRequest_,groupName)
	end
	
end

--[[
Private: Request to spawn new instance of template group if there's not already one
--]]
respawn_on_call.handleSpawnRequest_ = function(groupName)
	local groupInfo=respawn_on_call.groupList[groupName]
	local now=timer.getTime()
	if groupInfo then
	    local cRA=groupInfo.canRequestAt
		local cRA_isnum = type(cRA)=="number"
		
		if cRA==true or (cRA_isnum and cRA<now) then
			groupInfo.canRequestAt=false --try to prevent dual requests, schedule spawn
			mist.scheduleFunction(respawn_on_call.doReSpawn_,{groupName},now+groupInfo.spawnDelay)
			
			respawn_on_call.messageForCoalitionOrAll(groupInfo.side,
				string.format("%s will be on-call in %ds",groupName,groupInfo.spawnDelay),5)
				
			respawn_on_call.log_i:info(groupName.." was called in.")
		else
			respawn_on_call.messageForCoalitionOrAll(groupInfo.side,
				string.format("%s is not available or is already on-call",groupName),5)
			if cRA_isnum then
				local toWait= groupInfo.canRequestAt-now
				respawn_on_call.messageForCoalitionOrAll(groupInfo.side,
					string.format("%s will be available in %ds",groupName,toWait),5)
			end
		end
	end
end

--[[
Private: respawn and activate the named group
--]]
respawn_on_call.doReSpawn_ = function(groupName)
	local group = Group.getByName(groupName)
	
	mist.respawnGroup(groupName,true) --respawn with original tasking
	group = Group.getByName(groupName)
	
	if group then
		trigger.action.activateGroup(group) --ensure group is active
	end
	
	respawn_on_call.pollList[groupName]=true
end


--[[
Private: do poll of first unit in each watched group
--]]
respawn_on_call.doPoll_=function()

	local now=timer.getTime()
	for groupName,v in pairs(respawn_on_call.pollList) do
		if v==true then --groupName names a group that should be active
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
					
					if controller then trigger.action.outText("DB2",5)end--DEBUG
					if groupController then trigger.action.outText("DB3",5)end--DEBUG
					
					local unitHasTask = controller and Controller.hasTask(controller)
					local groupHasTask =  groupController and Controller.hasTask(groupController)
					
					isActive= Unit.isActive(unit) and (unitHasTask or groupHasTask)					
				end
				trigger.action.outText("DB1",5)--DEBUG
			end
			
			if isDead then
				respawn_on_call.pollList[groupName]=false
				respawn_on_call.groupList[groupName]["canRequestAt"]
					= now + respawn_on_call.groupList[groupName]["delayWhenDead"]
					
				trigger.action.outText("Detected that asset "..groupName.." is dead",5)--DEBUG
				respawn_on_call.log_i:info(groupName.." was detected dead.")
				
			elseif not isActive then
					respawn_on_call.pollList[groupName]=false
					respawn_on_call.groupList[groupName]["canRequestAt"]
						= now + respawn_on_call.groupList[groupName]["delayWhenIdle"]
					trigger.action.outText("Detected that asset "..groupName.." is idle",5)--DEBUG
					
					respawn_on_call.log_i:info(groupName.." was detected idle.")
			end
		end
	end

	--schedule next poll
	mist.scheduleFunction(respawn_on_call.doPoll_,nil,now+60)
end


--[[
Convert coalition name to coalition.side

return coalition.side, or nil if none recognised 
name is not case sensitive, but otherwise should be "red" or "blue" to name a particular faction
--]]
respawn_on_call.stringToSide = function(name)
	name=string.lower(name) --remove case sensitivity
	if name=="red" then
		return coalition.side.RED
	elseif name=="blue" then
		return coalition.side.BLUE
	end--else nil
end

--[[
Print message to the given coalition.side, or to all players if side==nil
--]]
respawn_on_call.messageForCoalitionOrAll = function(side,message,delay)
	if side then
		trigger.action.outTextForCoalition(side,message,delay)
	else
		trigger.action.outText(message,5)
	end
end

--start poll
mist.scheduleFunction(respawn_on_call.doPoll_,nil,timer.getTime()+60)