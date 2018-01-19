MatchTask = class('MatchTask')

-- IMatchTask instance = MatchTask:new {partList = partList}
--构造函数
function MatchTask:ctor(...)
	local _, args = ...
	self.partList = args.partList
	
	self.maxUser = 0
	self.startTime = 0
	self.matchCount = 0
	
	self.matchRangeRecords = {0}
	self.combineRangeRecords = {0}
end

function MatchTask:getMaxUser()
	return self.maxUser
end

function MatchTask:setMaxUser(maxUser)
	self.maxUser = maxUser
end

function MatchTask:getStartTime()
	return self.startTime
end

function MatchTask:setStartTime(startTime)
	self.startTime = startTime
end

function MatchTask:isActive()
	return self.startTime + 120 > os.time()
end

function MatchTask:isFull()
	return self:size() == self.maxUser
end

function MatchTask:size()
	local cnt = 0
	for _, teamPart in pairs(self.partList) do
		cnt = cnt + teamPart:size()
	end
	return cnt
end

function MatchTask:getMatchRangeRecords()
	return self.matchRangeRecords
end
	
function MatchTask:getCombineRangeRecords()
	return self.combineRangeRecords
end

function MatchTask:isSameCamp(task)
	return false
end

function MatchTask:playersSizeEquals(task)
	return self:size() == task:size()
end

function MatchTask:incrementMatchCount()
	self.matchCount = self.matchCount + 1
end

function MatchTask:compareTo(task)
	local aver1 = self:getAverageScore()
	local aver2 = task:getAverageScore()
	return aver1 - aver2
end

function MatchTask:getAverageScore()
	local scores = 0

	for _, teamPart in pairs(self.partList) do
		scores = scores + teamPart:getScores()
	end

	return math.floor(scores / self:size())
end

--[[
做某些事
--]]
function MatchTask:completed()
		
end

function MatchTask:canCombine(position, campActive)
	return self:size() + position:size() <= self.maxUser
end

function MatchTask:combine(position, campActive)
	table.foreach(position.partList, function(i, v)
		table.insert(self.partList, v)
	end)
end

--[[
	 * 分离除自己以外的
	 **/
--]]
function MatchTask:separate()
	local taskList = {}
	
	for i = #self.partList, 2, -1 do
		local teamPart = self.partList[ i ]
		local task = MatchTask:new {partList = {teamPart}}
		task:setMaxUser(self:getMaxUser())
		task:setStartTime(self:getStartTime())
		table.insert(taskList, task)
		self.partList[ i ] = nil
	end

	return taskList
end

function MatchTask:getPartList()
	return self.partList
end

function MatchTask:getCaptain()
	return self.partList[ 1 ]:getCaptain()
end

function MatchTask:containsUser(id)
	for _, teamPart in pairs(self.partList) do
		if teamPart:contaisId(id) then
			return true
		end
	end
	return false
end

function MatchTask.encode(obj)
	local datastrs = {}
	for _, teamPart in ipairs(obj.partList) do
		table.insert(datastrs, TeamPart.encode(teamPart))
	end
	
	-- ngx.log(ngx.ERR, "MatchTask.encode = ", obj.maxUser, " ", obj.startTime, " ", obj.matchCount)
	return string.format("{\"partList\":[%s], \"maxUser\":%d, \"startTime\":%d, \"matchCount\":%d, \"matchRangeRecords\":[%s], \"combineRangeRecords\":[%s]}", 
			string.join(",", datastrs), obj.maxUser, obj.startTime, obj.matchCount, string.join(",", obj.matchRangeRecords), string.join(",", obj.combineRangeRecords))
end

function MatchTask.decode(obj)
	local objs = obj.partList
	local partList = {}
	for _, team_part_info in ipairs(objs) do
		local teamPart = TeamPart.decode(team_part_info)
		table.insert(partList, teamPart)
	end
	local task = MatchTask:new {partList = partList}
	
	task.maxUser = obj.maxUser
	task.startTime = obj.startTime
	task.matchCount = obj.matchCount
	task.matchRangeRecords = obj.matchRangeRecords
	task.combineRangeRecords = obj.combineRangeRecords
	
	return task
end