-----------------------------------------------------------------------------------
--kuafu_plunder------------------------------------------------------------------------
-----------------------------------------------------------------------------------

local dbAccess = require 'util.db_access'
local json = require 'cjson'
local json_encode = json.encode
local json_decode = json.decode

local router_cls = require 'util.router_map'
local vaildArgs = router_cls.vaildArgs
local cache = require 'kuafu_plunder.cache'
local manager = require 'kuafu_plunder.manager'
local config = require 'kuafu_plunder.config'

local _M = {}
function _M:init()
	-- 读数据库
	local db = dbAccess.getDBObj(conf.db_name )
	if not db then
		return
	end
	
	--[[
	cursor = db.xianfu_match_result_list:find()
	while cursor:hasNext() do
		local data = cursor:next()
		cache:SetMatchResult(data.player_guid, data.result_info)
	end
	--]]
end

--队伍请求匹配
function _M:match()
	local args = vaildArgs({'faction_guid', 'open_time'},{})
	if not args then
		return
	end

	-- 获得匹配列表信息
	local ret_tab = router_cls.opdata_with_lock(config.match_list, function() 
		return manager:match(args.faction_guid)
	end)	
	return ngx.print(json_encode(ret_tab))
end

--队伍中某个人取消匹配
function _M:cancel_match()
	local args = vaildArgs({'faction_guid'},{}) 
	if not args then
		return
	end
	
	--ngx.log(ngx.ERR, "on cancel_match", args.player_guid, args.indx)
	
	local ret_tab = router_cls.opdata_with_lock(config.match_list, function() 
		return manager:cancel_match(args.faction_guid)
	end)
	return ngx.print(json_encode(ret_tab))	
end

--传送钱数据
function _M:save_money()
	local args = vaildArgs({'faction_guid', 'gold'},{'gold'}) 
	if not args then
		return
	end
	
	local ret_tab = router_cls.opdata_with_lock(config.match_money, function()
		return manager:save_money(args.faction_guid, args.gold)
	end)
	return ngx.print(json_encode(ret_tab))
end

-- 询问操作
function _M:call_operate()
	local args = vaildArgs({'server_id'},{}) 
	if not args then
		return
	end
	
	local ret_tab = router_cls.opdata_with_lock(config.match_money, function()
		return manager:call_operate(args.server_id)
	end)
	return ngx.print(json_encode(ret_tab))
end

-- 同步战斗信息
function _M:sync_data()
	local args = vaildArgs({'faction_guid', 'fightString'},{})
	if not args then
		return
	end
	
	local ret_tab = router_cls.opdata_with_lock(config.match_money, function()
		return manager:call_operate(args.server_id)
	end)
	return ngx.print(json_encode(ret_tab))
end

--同步简单信息
function _M:sync_simple_data()
	local args = vaildArgs({'faction_guid', 'simpleString'},{})
	if not args then
		return
	end
	
	local ret_tab = router_cls.opdata_with_lock(config.match_money, function()
		return manager:call_operate(args.server_id)
	end)
	return ngx.print(json_encode(ret_tab))
end

-- 参数选择
function _M:extend(hanlder)
	hanlder['/kuafu_plunder/match'] 			= self.match 			--请求匹配
	hanlder['/kuafu_plunder/cancel_match']		= self.cancel_match 	--队伍取消匹配
	hanlder['/kuafu_plunder/save_money']		= self.save_money		--传送钱数据
	hanlder['/kuafu_plunder/call_operate']		= self.call_operate		--询问操作
	hanlder['/kuafu_plunder/sync_data']			= self.sync_data		--同步战斗信息
	hanlder['/kuafu_plunder/sync_simple_data']	= self.sync_simple_data	--同步简单信息
end

return _M
