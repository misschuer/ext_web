-----------------------------------------------------------------------------------
--world_gbt------------------------------------------------------------------------
-----------------------------------------------------------------------------------

require 'util.functions'
local dbAccess = require 'util.db_access'
local json = require 'cjson'
local json_encode = json.encode
local json_decode = json.decode
local router_cls = require 'util.router_map'
local cache = ngx.shared.gold_battle_info



local _M = {}

--匹配列表
function _M:GetMatchList(fenqu, battle_type)
	local key = string.format('%s#%u#%u', 'matchlist', fenqu, battle_type)
	local match_list = cache:get(key)
	if match_list == nil then
		return {}
	else
		return json_decode(match_list)
	end
end
function _M:SetMatchList(fenqu, battle_type, list)
	local key = string.format('%s#%u#%u', 'matchlist', fenqu, battle_type)
	cache:set(key, list)
end

--匹配信息
function _M:GetMatchInfo(player_guid)
	local key = string.format('%s#%s', 'matchinfo', player_guid)
	local info = cache:get(key)
	if info then
		return json_decode(info)
	else
		return nil
	end
end
function _M:SetMatchInfo(player_guid, match_info)
	local key = string.format('%s#%s', 'matchinfo', player_guid)
	cache:set(key, match_info)
end

return _M