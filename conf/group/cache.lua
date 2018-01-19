-----------------------------------------------------------------------------------
--group----------------------------------------------------------------------------
-----------------------------------------------------------------------------------

require 'util.functions'
local dbAccess = require 'util.db_access'
local json = require 'cjson'
local json_encode = json.encode
local json_decode = json.decode
local router_cls = require 'util.router_map'
local cache = ngx.shared.group_match_cache

local _M = {}

--匹配列表
function _M:GetMatchList(fenqu)
	local key = string.format('%s#%s#%u', os.date('%Y%m%d'), 'matchlist', fenqu)
	local match_list = cache:get(key)
	if match_list == nil then
		return {}
	else
		return json_decode(match_list)
	end
end

function _M:SetMatchList(fenqu, list)
	local key = string.format('%s#%s#%u', os.date('%Y%m%d'), 'matchlist', fenqu)
	local cur_date = os.date('*t', os.time())
	cur_date.hour = 0
	cur_date.sec = 0
	cur_date.min = 0
	local due_time = os.time(cur_date) + 86400 + 60 - os.time()
	
	cache:set(key, list, due_time)
end

--匹配信息
function _M:GetMatchInfo(group_guid)
	local key = string.format('%s#%s#%s', os.date('%Y%m%d'), 'matchinfo', group_guid)
	local info = cache:get(key)
	if info then
		return json_decode(info)
	else
		return nil
	end
end

function _M:SetMatchInfo(group_guid, match_info)
	local key = string.format('%s#%s#%s', os.date('%Y%m%d'), 'matchinfo', group_guid)
	local cur_date = os.date('*t', os.time())
	cur_date.hour = 0
	cur_date.sec = 0
	cur_date.min = 0
	local due_time = os.time(cur_date) + 86400 + 60 - os.time()

	cache:set(key, match_info, due_time)
end

return _M