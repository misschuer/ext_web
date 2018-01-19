-----------------------------------------------------------------------------------
--world_gbt------------------------------------------------------------------------
-----------------------------------------------------------------------------------

local dbAccess = require 'util.db_access'
local json = require 'cjson'
local json_encode = json.encode
local json_decode = json.decode

local router_cls = require 'util.router_map'
local vaildArgs = router_cls.vaildArgs
local cache = require 'world_gbt.cache'
local manager = require 'world_gbt.manager'
local config = require 'world_gbt.config'

local _M = {}
--玩家请求匹配
function _M:match()
	local args = vaildArgs({'player_guid', 'open_time', 'battle_type'},{'open_time', 'battle_type'}) 
	if not args then
		return
	end

	local fenqu = config:get_fenqu(args.open_time)
	local locks = string.format('match_list#fenqu%u#battle_type%u', fenqu, args.battle_type)
	local ret_tab = router_cls.opdata_with_lock(locks, function() 
		return manager:match(fenqu, args.player_guid, args.battle_type)
	end)	
	return ngx.print(json_encode(ret_tab))
end

--队伍取消匹配
function _M:cancel_match()
	local args = vaildArgs({'player_guid', 'open_time', 'battle_type'},{'open_time', 'battle_type'}) 
	if not args then
		return
	end	
	
	local fenqu = config:get_fenqu(args.open_time)
	local locks = string.format('match_list#fenqu%u#battle_type%u', fenqu, args.battle_type)
	local ret_tab = router_cls.opdata_with_lock(locks, function() 
		return manager:cancel_match(fenqu, args.player_guid, args.battle_type)
	end)	
	return ngx.print(json_encode(ret_tab))	
end


function _M:extend(hanlder)
	hanlder['/world_gbt/match'] = self.match --玩家请求匹配
	hanlder['/world_gbt/cancel_match'] = self.cancel_match --玩家取消匹配
end

return _M
