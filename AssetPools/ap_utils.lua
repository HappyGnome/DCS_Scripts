-- AP_UTILS
-- misc Utilities for asset_pool scripts
--
-- Script by HappyGnome


--doFile returns single global instance, or creates one
if ap_utils then
	return ap_utils
end

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

return ap_utils