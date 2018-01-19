local json = require 'cjson'
local json_encode = json.encode
local json_decode = json.decode

MatchProcessor = class('MatchProcessor')
--[[IMatchProcessor instance = MatchProcessor:new {
	config = config,
}
--]]
--构造函数
function MatchProcessor:ctor(...)
	local _, args = ...
	self.config = args.config
	self.cache = args.cache
		
	if self.config:getMatchExpandConfig() then
		self.matchRangeExpander = MatchTRExpander:new {
			matchExpandConfig = self.config:getMatchExpandConfig()
		}
	end
	
	if self.config:getCombineExpandConfig() then
		self.combineRangeExpander = CombineTRExpander:new {
			combineExpandConfig = self.config:getCombineExpandConfig()
		}
	end
	
	self.totalMatched = 0
	
	self.taskQueue = {}
end

function MatchProcessor:getMatchTask(id)
	for _, task in pairs(self.taskQueue) do
		if task:containsUser(id) then
			return task
		end
	end
	return nil
end

function MatchProcessor:submitMatch(task)
	self:decode()
	
	task:setMaxUser(self.config:getUserMax())
	task:setStartTime(os.time())
	table.insert(self.taskQueue, task)
	
	self:encode()
end

function MatchProcessor:cancelMatch(player_guid)
	self:decode()
	
	local task = self:getMatchTask(player_guid)
	table.removeItem(self.taskQueue, task)
	
	--把后来匹配的玩家重新打散排到队尾
	local externalPlayerTasks = task:separate()
	for _, externalTask in pairs(externalPlayerTasks) do
		table.insert(self.taskQueue, externalTask)
	end
	self.notifier:cancel(task)
	
	self:encode()
end

--[[
     * 移到末尾位置
     */
--]]
function MatchProcessor:headToTail()
	local t = self.taskQueue[ 1 ];
	table.remove(self.taskQueue, 1)
	table.insert(self.taskQueue, t)
end

function MatchProcessor:expandMatchRange(task)
	if self.matchRangeExpander then
		if self.matchRangeExpander:isDifficutMatch(task) then
            self.matchRangeExpander:expandMatchRange(task)
		end
	end
end

function MatchProcessor:expandCombineRange(task)
	if self.combineRangeExpander then
		if self.combineRangeExpander:isDifficutMatch(task) then
            self.combineRangeExpander:expandMatchRange(task)
		end
	end
end

function MatchProcessor:matchTask(task)
	task:incrementMatchCount()
    self:expandMatchRange(task)
    
	local matchRangeRecords = task:getMatchRangeRecords()
	-- 是否必须对立阵营
	local campActive = self.config:isCampActive()
	
	for _, record in pairs(matchRangeRecords) do
		local i = 1
		while (i <= #self.taskQueue) do
			local position = self.taskQueue[ i ]
			if not position:isActive() then
				self:timeout(position)
				table.remove(self.taskQueue, i)
			else
				local baseCondition = (position ~= task and task:playersSizeEquals(position))
				if campActive then --如果必须是对立阵营才能成为对手，则判断
                    baseCondition = baseCondition and not task:isSameCamp(position)
                end
				
				if (baseCondition) then
                    local cpr = position:compareTo(task)
                    if (math.abs(cpr) <= record) then --找到合适的队伍
                        task:completed()
                        self.notifier:completed(task, position)
                        self.totalMatched = self.totalMatched + task:size() + position:size()
						table.remove(self.taskQueue, i) -- 先删除这个
						table.remove(self.taskQueue, 1) -- 匹配成功则移除头并且移除position
                        return position
                    end
				end
				i = i + 1
			end
		end
	end
	
	return nil
end

--[[
	组队
--]]
function MatchProcessor:organizeTeam()	
	-- ngx.log(ngx.ERR, "organizeTeam ##############################")
	self:decode()
    local task = self.taskQueue[ 1 ]
            
    if (not task) then
		return
	end
            
    if (not task:isActive()) then -- 判断task是否失效
		table.remove(self.taskQueue, 1)
		self:timeout(task)
		self:encode()
		return
	end

	if (not task:isFull()) then -- 组队未满人，先寻找平均值范围内的组成完整队伍
		self:expandCombineRange(task)
        self:combineTeam(task)
	end

    -- 遍历所有组合仍未能组成完整队伍，则将匹配请求放入尾部
	if (not task:isFull()) then --// 在此时出现线程安全问题，如玩家取消匹配
        -- // 一次全局遍历无法组成完整队伍，则分离队伍
		local externalPlayerTasks = task:separate()
		
		for _, externalTask in pairs(externalPlayerTasks) do
			table.insert(self.taskQueue, externalTask)
		end
		self:headToTail()
		self:encode()
		return
    end

	local result = self:matchTask(task)
	if (not result) then
		-- // 未匹配成功，则将头移到尾部
		self:headToTail()
	else
		local remain = 0
		for _, t in pairs(self.taskQueue) do
			remain = remain + t:size()
		end
		ngx.log(ngx.ERR, "Complete a team match (remain = ", remain, ", totalMatched = ", self.totalMatched,")\n");
	end
    self:encode()
end

function MatchProcessor:combineTeam(task)
	-- 循环遍历比较匹配范围集合,从小的范围到大的范围开始比较
	local combineRangeRecords = task:getCombineRangeRecords()
			
	for _, record in pairs(combineRangeRecords) do --//范围扩张记录遍历，由小到大取最优
		
		local i = 1
		while (i <= #self.taskQueue) do -- //剩余所有Task遍历，用于组合完整队伍
			local position = self.taskQueue[ i ]
			
			if not position:isActive() then	--//判断position是否失效
				self:timeout(position)
				table.remove(self.taskQueue, i)
			else
				local campActive = self.config:isCampActive() --//是否需要阵营判断
				if (position ~= task and task:canCombine(position, campActive)) then --// 判断是否能够合并两个组
					local cpr = position:compareTo(task)
					--符合匹配要求
					if (math.abs(cpr) <= record) then
						task:combine(position, campActive) --// 合并
						table.remove(self.taskQueue, i)
					end
					if (task:isFull()) then
						return
					end
				end
				i = i + 1
			end
		end
	end
end

function MatchProcessor:timeout(task)
	self.notifier:cancel(task)
end

function MatchProcessor:getNotifier()
	return self.notifier
end

function MatchProcessor:setNotifier(notifier)
	self.notifier = notifier
end

function MatchProcessor:encode()
	local datastrs = {}
	for _, task in ipairs(self.taskQueue) do
		local taskEncode = MatchTask.encode(task)
		table.insert(datastrs, taskEncode)
	end
	
	local match_list = nil
	if #datastrs > 0 then
		match_list = string.format("[%s]", string.join(",", datastrs))
	end
	--ngx.log(ngx.ERR, "encode = ", match_list)
	self.cache:SetMatchList(match_list)
end

function MatchProcessor:decode()
	local match_list = self.cache:GetMatchList()
	self.taskQueue = {}
	if match_list then
		--ngx.log(ngx.ERR, "decode = ", match_list)
		
		local objs = json_decode(match_list)
		
		for _, obj in ipairs(objs) do
			local task = MatchTask.decode(obj)
			table.insert(self.taskQueue, task)
		end
	end
end