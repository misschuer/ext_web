MatchTRExpander = class('MatchTRExpander')

-- IMatchTRExpander instance = MatchTRExpander:new {matchExpandConfig = matchExpandConfig}
--¹¹Ôìº¯Êý
function MatchTRExpander:ctor(...)
	local _, args = ...
	self.matchExpandConfig = args.matchExpandConfig
end

function MatchTRExpander:isDifficutMatch(task)
	return #(task:getMatchRangeRecords()) <= self.matchExpandConfig:size()
end

function MatchTRExpander:expandMatchRange(task)
	local records = task:getMatchRangeRecords()
	table.insert(records, self.matchExpandConfig:get(#records))
end