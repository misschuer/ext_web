MatchConfig = class('MatchConfig')

-- IMatchConfig instance = MatchConfig:new {userMax = userMax, matchExpandConfig = matchExpandConfig, combineExpandConfig = combineExpandConfig}

--¹¹Ôìº¯Êý
function MatchConfig:ctor(...)
	local _, args = ...
	self.userMax = args.userMax
	self.matchExpandConfig = args.matchExpandConfig
	self.combineExpandConfig = args.combineExpandConfig
end

function MatchConfig:getUserMax()
	return self.userMax
end

function MatchConfig:getMatchExpandConfig()
	return self.matchExpandConfig
end

function MatchConfig:getCombineExpandConfig()
	return self.combineExpandConfig
end

function MatchConfig:isCampActive()
	return false
end
