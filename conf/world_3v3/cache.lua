-----------------------------------------------------------------------------------
--world_3v3------------------------------------------------------------------------
-----------------------------------------------------------------------------------

require 'util.functions'
local dbAccess = require 'util.db_access'
local json = require 'cjson'
local json_encode = json.encode
local json_decode = json.decode
local router_cls = require 'util.router_map'
local cache = ngx.shared.world_3v3_cache

local _M = {}

--匹配列表
function _M:GetMatchList()
	local key = string.format('%s#%s', os.date('%Y%m%d'), 'matchlist')
	local match_list = cache:get(key)
	if match_list then
		return match_list
	end
	
	return nil
end
function _M:SetMatchList(list)
	local key = string.format('%s#%s', os.date('%Y%m%d'), 'matchlist')
	
	cache:set(key, list, _M:GetMatchExpireTime())
end


--匹配信息
function _M:GetMatchInfo(player_guid)
	local key = string.format('%s#%s#%s', os.date('%Y%m%d'), 'matchinfo', player_guid)
	local info = cache:get(key)
	
	if info then
		return json_decode(info)
	end
	
	return nil
end
function _M:SetMatchInfo(player_guid, match_info, expire)
	expire = expire or _M:GetMatchExpireTime()
	local key = string.format('%s#%s#%s', os.date('%Y%m%d'), 'matchinfo', player_guid)

	cache:set(key, match_info, expire)
end


--奖励信息
function _M:GetMatchResult(player_guid)
	local key = string.format('%s#%s', 'matchresult', player_guid)
	local info = cache:get(key)
	
	--ngx.log(ngx.ERR, player_guid, "GetMatchResult ===== ", key, "##", tostring(info))
	
	if info then
		return info
	end
	
	return nil
end
function _M:SetMatchResult(player_guid, match_result, saveDB)
	saveDB = saveDB or false
	local key = string.format('%s#%s', 'matchresult', player_guid)
	--ngx.log(ngx.ERR, player_guid, "SetMatchResult ===== ", key, "##", match_result)
	cache:set(key, match_result, _M:GetMatchExpireTime())
	
	if saveDB then
		local db = dbAccess.getDBObj(conf.db_name)
		
		-- 先判断有没有记录
		local cursor = db.match_result_list:find({player_guid=player_guid})
		if cursor:hasNext() then
			if match_result then
				--更新排名信息
				db.match_result_list:update({player_guid = player_guid}, {['$set']={result_info=match_result,update_time = os.time()}},true)
			else
				-- 如果是置空的就清掉好了
				db.match_result_list:delete({player_guid = player_guid})
			end
		else
			-- 插入信息
			db.match_result_list:insert({player_guid=player_guid, result_info=match_result, update_time = os.time()})
		end
	end
end


--排行信息
function _M:GetRankInfo()
	local key = string.format('%s', 'matchrank')
	local info = cache:get(key)
	
	if info then
		return info
	end
	
	return nil
end
function _M:SetRankInfo(match_rank_info, saveDB)
	saveDB = saveDB or false
	local key = string.format('%s', 'matchrank')
	cache:set(key, match_rank_info, _M:GetMatchExpireTime())
	
	--ngx.log(ngx.ERR, "SetRankInfo > ", match_rank_info)
	
	if saveDB then
		local db = dbAccess.getDBObj(conf.db_name)
		match_rank_info = match_rank_info or ''
		--更新排名信息
		db.match_rank_list:update({indx = 1}, {['$set']={rank_info=match_rank_info,update_time = os.time()}},true)
	end
end

function _M:GetMatchExpireTime()
	local cur_date = os.date('*t', os.time())
	cur_date.hour = 0
	cur_date.sec = 0
	cur_date.min = 0
	local due_time = os.time(cur_date) + 86400 + 60 - os.time()
	
	return due_time
end

return _M