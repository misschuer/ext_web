-----------------------------------------------------------------------------------
--world_3v3------------------------------------------------------------------------
-----------------------------------------------------------------------------------

local json = require 'cjson'
local json_encode = json.encode
local json_decode = json.decode

local config = require 'world_3v3.config'
local cache = require 'world_3v3.cache'

local _M = {}

--队伍请求匹配
function _M:match(group_guid, userList)
	-- 判断有效时间
	if not _M:is_valid_time() then
		return {ret = 1, msg = 'out of time'}
	end
	
	local userIdList = {}
	-- 已经取消的情况就把记录删掉
	for _, user in pairs(userList) do
		local player_guid = user:getId()
		local match_info = cache:GetMatchInfo(player_guid)
		if match_info and match_info.state == -1 then
			cache:SetMatchInfo(player_guid, nil)
		end
		table.insert(userIdList, player_guid)
	end
	
	-- 判断是否重复匹配(假如游戏服宕机导致web端还有匹配数据的 怎么办)
	if MatchController:IsInMatching(config.matchProcessor, userIdList) then
		return {ret = 2, msg = 'already matching'}
	end
	
	MatchController:submitMatchTask(config.matchProcessor, userList)
	return {ret = 0, msg = 'add match list'}
end

--队伍取消匹配
function _M:cancel_match(player_guid)
	-- ngx.log(ngx.ERR, player_guid, " begin to cancel")
	if not MatchController:IsInMatching(config.matchProcessor, {player_guid}) then
		return {ret = 2, msg = 'not in matching'}
	end
	MatchController:cancelMatch(config.matchProcessor, player_guid)
	return {ret = 0, msg = 'success'}
end

--检测队伍匹配情况
function _M:check_match(player_guid)
	local match_info = cache:GetMatchInfo(player_guid)
	-- 还没有匹配上
	if not match_info then
		if not MatchController:IsInMatching(config.matchProcessor, {player_guid}) then
			return {ret = 2, msg = 'cancel'}
		end
		return {ret = 1, msg = 'matching'}
	end
	
	-- 过期取消
	if match_info.state == -1 then
		cache:SetMatchInfo(player_guid, nil)
		return {ret = 2, msg = 'cancel'}
	end
	
	-- 别人取消了
	if match_info.state == 10 or match_info.state == 11 then
		cache:SetMatchInfo(player_guid, nil)
		return {ret = 3, msg = 'cancel'}
	end
	
	-- 匹配上并且所有人已经准备
	if match_info.state == 2 then
		cache:SetMatchInfo(player_guid, nil)
		return {ret = 0, msg = 'matched', enter_info = match_info.enter_info}
	end
	
	-- 匹配上并且所有人已经准备
	if match_info.state == 12 then
		match_info.state = 2
		local wait_info = {}
		self:GetMatchWaitInfo(wait_info,  match_info.all_player_guid)
		cache:SetMatchInfo(player_guid, json_encode(match_info))
		return {ret = 4, msg = 'wait', wait_info = wait_info}
	end
	
	-- 匹配上但是有人未准备好
	local wait_info = {}
	local canceled = self:GetMatchWaitInfo(wait_info,  match_info.all_player_guid)
	
	-- 如果有人取消了 把自己的状态置一下 等待下一帧回收
	if canceled then
		match_info.state = match_info.state + 10
		cache:SetMatchInfo(player_guid, json_encode(match_info))
	end
	
	-- 返回等待的情况
	return {ret = 4, msg = 'wait', wait_info = wait_info}
end

-- 获取等待准备列表
function _M:GetMatchWaitInfo(wait_info, all_player_guid)
	
	local canceled = false
	for _, other_player_guid in ipairs(all_player_guid) do
		local other_info = cache:GetMatchInfo(other_player_guid)
		-- 某个人由于各种原因取消了, 那这个匹配不管用
		if not other_info or other_info.state == -1 then
			canceled = true
		end
		
		local state = -1
		if other_info then
			state = other_info.state
		end
		table.insert(wait_info, {state, other_player_guid})
	end
	
	return canceled
end

-- 比赛奖励
function _M:match_result(result)
	-- {player_guid=details[1], score=tonumer(details[2]), honor=tonumer(details[3]), result=tonumer(details[4])}
	
	for _, matchInfo in pairs(result) do
		local player_guid = matchInfo.player_guid
		local data = {}
		data.score = matchInfo.score
		data.honor = matchInfo.honor
		data.result = matchInfo.result
		local value = json_encode(data)
		cache:SetMatchResult(player_guid, value, true)
	end
end

function _M:check_match_result(player_guid)
	-- ngx.log(ngx.ERR, player_guid, " check_match_result ")
	local ret = cache:GetMatchResult(player_guid)
	if ret then
		cache:SetMatchResult(player_guid, nil, true)
		return {ret = 0, msg = 'get', details = ret}
	end
	return {ret = 1, msg = 'no reward'}
end

-- 排名信息
function _M:rank(player_name, avatar, weapon, divine, score, player_guid, force, gender)
	local rank_info = cache:GetRankInfo()
	if rank_info and string.len(rank_info) > 0 then
		rank_info = json_decode(rank_info)
	else
		rank_info = {}
	end
	
	-- 删掉以前的
	for i = #rank_info, 1, -1 do
		local info = rank_info[ i ]
		if info[ 1 ] == player_name then
			table.remove(rank_info, i)
			break
		end
	end
	
	local pos = 1
	-- 添加新的
	for i = #rank_info, 1, -1 do
		local info = rank_info[ i ]
		if info[ 5 ] >= score then
			pos = i + 1
			break
		end
	end
	
	-- ngx.log(ngx.ERR, pos, " ===", config.rank_num)
	-- 在排名内的
	if pos < config.rank_num then
		table.insert(rank_info, pos, {player_name, avatar, weapon, divine, score, player_guid, force, gender})
	end
	-- 不在排名内
	if #rank_info > config.rank_num then
		table.remove(rank_info, #rank_info)
	end
	
	cache:SetRankInfo(json_encode(rank_info), true)
	
	return {}
end

function _M:check_rank()
	local rank_info = cache:GetRankInfo()
	return {ret = 0, msg = 'get', details = rank_info}
end

-- oper = 1 接受, oper = 0 拒绝
function _M:prepare_match(player_guid, oper)
	local match_info = cache:GetMatchInfo(player_guid)
	-- 错误 无法准备
	if not match_info or match_info.state ~= 0 and match_info.state ~= 10 then
		return {ret = 1, msg = 'error'}
	end
	
	if oper == 0 then
		cache:SetMatchInfo(player_guid, nil)
		return {ret = 2, msg = 'cancel'}
	end
	
	-- 先给自己设置准备状态
	match_info.state = 1
	-- TODO: 这里第二次设置时不能再设置过期时间了
	cache:SetMatchInfo(player_guid, json_encode(match_info))
	
	-- 判断是否全部准备好
	local wait_info = {}
	local cnt = 0
	local all_player_guid = match_info.all_player_guid
	for _, other_player_guid in ipairs(all_player_guid) do
		local other_info = cache:GetMatchInfo(other_player_guid)
		local state = -1
		if other_info then
			if other_info.state == 1 then
				cnt = cnt + 1
			end
			state = other_info.state
		end
		table.insert(wait_info, {state, other_player_guid})
	end
	
	-- 所有人都准备就绪
	if cnt == #match_info.all_player_guid then
		wait_info = {}
		local all_player_guid = match_info.all_player_guid
		for _, other_player_guid in ipairs(all_player_guid) do
			local other_info = cache:GetMatchInfo(other_player_guid)
			other_info.state = 12
			cache:SetMatchInfo(other_player_guid, json_encode(other_info))
			table.insert(wait_info, {2, other_player_guid})
		end
	end
	
	-- 返回等待的情况
	return {ret = 0, msg = 'wait', wait_info = wait_info}
end

--是否有效时间
function _M:is_valid_time()
	local hour = os.date('*t').hour
	return hour == 20 or true
end

return _M
