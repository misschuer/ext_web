local json = require 'cjson'
local json_encode = json.encode
local json_decode = json.decode

MatchProcessor = class('MatchProcessor')
--[[IMatchProcessor instance = MatchProcessor:new {
	config = config,
}
--]]
--���캯��
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
	
	--�Ѻ���ƥ���������´�ɢ�ŵ���β
	local externalPlayerTasks = task:separate()
	for _, externalTask in pairs(externalPlayerTasks) do
		table.insert(self.taskQueue, externalTask)
	end
	self.notifier:cancel(task)
	
	self:encode()
end

--[[
     * �Ƶ�ĩβλ��
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
	-- �Ƿ���������Ӫ
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
				if campActive then --��������Ƕ�����Ӫ���ܳ�Ϊ���֣����ж�
                    baseCondition = baseCondition and not task:isSameCamp(position)
                end
				
				if (baseCondition) then
                    local cpr = position:compareTo(task)
                    if (math.abs(cpr) <= record) then --�ҵ����ʵĶ���
                        task:completed()
                        self.notifier:completed(task, position)
                        self.totalMatched = self.totalMatched + task:size() + position:size()
						table.remove(self.taskQueue, i) -- ��ɾ�����
						table.remove(self.taskQueue, 1) -- ƥ��ɹ����Ƴ�ͷ�����Ƴ�position
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
	���
--]]
function MatchProcessor:organizeTeam()	
	-- ngx.log(ngx.ERR, "organizeTeam ##############################")
	self:decode()
    local task = self.taskQueue[ 1 ]
            
    if (not task) then
		return
	end
            
    if (not task:isActive()) then -- �ж�task�Ƿ�ʧЧ
		table.remove(self.taskQueue, 1)
		self:timeout(task)
		self:encode()
		return
	end

	if (not task:isFull()) then -- ���δ���ˣ���Ѱ��ƽ��ֵ��Χ�ڵ������������
		self:expandCombineRange(task)
        self:combineTeam(task)
	end

    -- �������������δ������������飬��ƥ���������β��
	if (not task:isFull()) then --// �ڴ�ʱ�����̰߳�ȫ���⣬�����ȡ��ƥ��
        -- // һ��ȫ�ֱ����޷�����������飬��������
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
		-- // δƥ��ɹ�����ͷ�Ƶ�β��
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
	-- ѭ�������Ƚ�ƥ�䷶Χ����,��С�ķ�Χ����ķ�Χ��ʼ�Ƚ�
	local combineRangeRecords = task:getCombineRangeRecords()
			
	for _, record in pairs(combineRangeRecords) do --//��Χ���ż�¼��������С����ȡ����
		
		local i = 1
		while (i <= #self.taskQueue) do -- //ʣ������Task���������������������
			local position = self.taskQueue[ i ]
			
			if not position:isActive() then	--//�ж�position�Ƿ�ʧЧ
				self:timeout(position)
				table.remove(self.taskQueue, i)
			else
				local campActive = self.config:isCampActive() --//�Ƿ���Ҫ��Ӫ�ж�
				if (position ~= task and task:canCombine(position, campActive)) then --// �ж��Ƿ��ܹ��ϲ�������
					local cpr = position:compareTo(task)
					--����ƥ��Ҫ��
					if (math.abs(cpr) <= record) then
						task:combine(position, campActive) --// �ϲ�
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