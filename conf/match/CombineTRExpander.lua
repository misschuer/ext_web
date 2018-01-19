CombineTRExpander = class('CombineTRExpander')

-- ICombineTRExpander instance = CombineTRExpander:new {combineExpandConfig = combineExpandConfig}
--¹¹Ôìº¯Êý
function CombineTRExpander:ctor(...)
	local _, args = ...
	self.combineExpandConfig = args.combineExpandConfig
end

function CombineTRExpander:isDifficutMatch(task)
	return #(task:getCombineRangeRecords()) <= self.combineExpandConfig:size()
end

function CombineTRExpander:expandMatchRange(task)
	local records = task:getCombineRangeRecords()
	table.insert(records, self.combineExpandConfig:get(#records))
end