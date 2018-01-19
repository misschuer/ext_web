-----------------------------------------------------------------------------------
--kuafu_plunder------------------------------------------------------------------------
-----------------------------------------------------------------------------------
local dbAccess = require 'util.db_access'
local json = require 'cjson'
local json_encode = json.encode
local json_decode = json.decode

local config = require 'kuafu_plunder.config'
local cache = require 'kuafu_plunder.cache'

local _M = {}

--队伍请求匹配
function _M:match(player_guid, indx)
	-- 判断有效时间
	if not _M:is_valid_time() then
		return {ret = 1, msg = 'out of time'}
	end
	
	-- 判断是不是重复匹配
	local match_list = cache:GetMatchList(indx)
	for _, guid in pairs(match_list) do
		if guid == player_guid then
			return {ret = 2, msg = 'repeat match'}
		end
	end
	
	-- 加入等待队列
	table.insert(match_list, player_guid)
	
	-- 匹配上了
	if #match_list == config.max_user then
		local war_id = string.format('%u#%s',os.time(), player_guid)
		local battle_server = _M.choose_battle_server()
			-- 通知匹配完成
		local enter_info = {}
		enter_info.war_id = war_id
		enter_info.battle_server = battle_server
		
		local match_info = {}
		match_info.enter_info = enter_info
		match_info.match_time = os.time()
		
		for _, guid in pairs(match_list) do
			cache:SetMatchInfo(guid, json_encode(match_info))
		end
		ngx.log(ngx.ERR, "guids = ", string.join(",", match_list), " ward_id = ", war_id)
		cache:SetMatchList(indx, nil)
		return {ret = 4, msg = 'matched'}
	end
	
	-- 存回去
	cache:SetMatchList(indx, json_encode(match_list))
	
	return {ret = 0, msg = 'add match list'}
end

--取消匹配
function _M:cancel_match(player_guid, indx)
	local match_list = cache:GetMatchList(indx)
	local existIndx = nil
	for k, guid in pairs(match_list) do
		if guid == player_guid then
			existIndx = k
			break
		end
	end
	
	if not existIndx then
		return {ret = 1, msg = 'not in matching'}
	end
	
	table.remove(match_list, existIndx)
	cache:SetMatchList(indx, json_encode(match_list))
	return {ret = 0, msg = 'success'}
end

-- 获得在匹配队列中的位置
function _M:GetMatchListIndx(player_guid, indx)
	local match_list = cache:GetMatchList(indx)
	local existIndx = nil
	for k, guid in pairs(match_list) do
		if guid == player_guid then
			existIndx = k
			break
		end
	end
	
	return existIndx
end

--检测队伍匹配情况
function _M:check_match(player_guid, indx)
	local match_info = cache:GetMatchInfo(player_guid)
	-- 还没有匹配上
	if not match_info then
		if not _M:GetMatchListIndx(player_guid, indx) then
			return {ret = 2, msg = 'cancel'}
		end
		local match_list = cache:GetMatchList(indx)
		local count = #match_list
		return {ret = 1, msg = 'matching', target = config.max_user, count = count}
	end

	cache:SetMatchInfo(player_guid, nil)
	return {ret = 0, msg = 'matched', enter_info = match_info.enter_info}
end

function _M:check_match_result(player_guid)
	local ret = cache:GetMatchResult(player_guid)
	--ngx.log(ngx.ERR, "check_match_result ", player_guid, " $$$ ", ret)
	if ret then
		cache:SetMatchResult(player_guid, nil, true)
		return {ret = 0, msg = 'get', details = ret}
	end
	return {ret = 1, msg = 'no reward'}
end

-- 传送钱数据
function _M:save_money(player_guid, gold)
	cache:SetGold(player_guid, gold)
end



return _M
