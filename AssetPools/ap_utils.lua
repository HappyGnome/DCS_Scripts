-- AP_UTILS
-- misc Utilities for asset_pool scripts
--
-- V1.0
-- Script by HappyGnome


--doFile returns single global instance, or creates one
if ap_utils then
	return ap_utils
end

--NAMESPACES---------------------------------------------------------------------------------------------- 
ap_utils={}

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



return ap_utils