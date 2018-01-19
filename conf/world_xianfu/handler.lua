-----------------------------------------------------------------------------------
--world_xianfu------------------------------------------------------------------------
-----------------------------------------------------------------------------------

local dbAccess = require 'util.db_access'
local json = require 'cjson'
local json_encode = json.encode
local json_decode = json.decode

local router_cls = require 'util.router_map'
local vaildArgs = router_cls.vaildArgs
local cache = require 'world_xianfu.cache'
local manager = require 'world_xianfu.manager'
local config = require 'world_xianfu.config'

local _M = {}
function _M:init()
	-- 读数据库
	local db = dbAccess.getDBObj(conf.db_name )
	if not db then
		return
	end
	
	cursor = db.xianfu_match_result_list:find()
	while cursor:hasNext() do
		local data = cursor:next()
		cache:SetMatchResult(data.player_guid, data.result_info)
	end
end

--队伍请求匹配
function _M:match()
	local args = vaildArgs({'player_guid', 'indx', 'open_time'},{'indx', 'open_time'}) 
	if not args then
		return
	end

	--ngx.log(ngx.ERR, "on match", args.player_guid, args.indx)
	
	-- 获得匹配列表信息
	local ret_tab = router_cls.opdata_with_lock(config.match_list, function() 
		return manager:match(args.player_guid, args.indx)
	end)	
	return ngx.print(json_encode(ret_tab))
end

--队伍中某个人取消匹配
function _M:cancel_match()
	local args = vaildArgs({'player_guid', 'indx', 'open_time'},{'indx', 'open_time'}) 
	if not args then
		return
	end
	
	--ngx.log(ngx.ERR, "on cancel_match", args.player_guid, args.indx)
	
	local ret_tab = router_cls.opdata_with_lock(config.match_list, function() 
		return manager:cancel_match(args.player_guid, args.indx)
	end)	
	return ngx.print(json_encode(ret_tab))	
end

-- 检测是否匹配到, 或者已经过期
function _M:check_match()
	local args = vaildArgs({'player_guid', 'indx', 'open_time'},{'indx', 'open_time'}) 
	if not args then
		return
	end
	
	--ngx.log(ngx.ERR, args.player_guid, " $$$$$$$$ ",  args.indx)
	
	local ret_tab = router_cls.opdata_with_lock(config.match_list, function() 
		return manager:check_match(args.player_guid, args.indx)
	end)
	return ngx.print(json_encode(ret_tab))
end

-- 结果
function _M:match_result()
	local args = vaildArgs({'ret', 'open_time'},{'open_time'}) 
	if not args then
		return
	end
	
	ngx.log(ngx.ERR, "match_result = ", args.ret)
	
	local ret = {}
	local infos = string.split(args.ret, ";")
	for _, info in pairs(infos) do
		local details = string.split(info, "|")
		local player_guid = details[1]
		ngx.log(ngx.ERR, player_guid, " => ", details[2])
		table.insert(ret, {player_guid=player_guid, info=details[2]})
	end
	
	--ngx.log(ngx.ERR, "match_result ret length = ", #ret)
	
	local ret_tab = router_cls.opdata_with_lock(config.match_result, function() 
		return manager:match_result(ret)
	end)
	return ngx.print(json_encode(ret_tab))
end

-- 结果
function _M:check_match_result()
	local args = vaildArgs({'player_guid', 'open_time'},{'open_time'}) 
	if not args then
		return
	end
	
	local ret_tab = router_cls.opdata_with_lock(config.match_result, function() 
		return manager:check_match_result(args.player_guid)
	end)
	return ngx.print(json_encode(ret_tab))
end

--传送钱数据
function _M:save_money()
	local args = vaildArgs({'player_guid', 'gold'},{'gold'}) 
	if not args then
		return
	end
	
	local ret_tab = router_cls.opdata_with_lock(config.match_money, function() 
		return manager:save_money(args.player_guid, args.gold)
	end)
	return ngx.print(json_encode(ret_tab))
end

--同步钱数据
function _M:sync_money()
	local args = vaildArgs({'player_guid', 'isPk'}, {'isPk'}) 
	if not args then
		return
	end
	
	local ret_tab = router_cls.opdata_with_lock(config.match_money, function() 
		return manager:sync_money(args.player_guid, args.isPk)
	end)
	return ngx.print(json_encode(ret_tab))
end

function _M:kuafu_restore()
	local args = vaildArgs({'player_guid', 'changed'}, {'changed'}) 
	if not args then
		return
	end
	
	local ret_tab = router_cls.opdata_with_lock(config.match_money, function() 
		return manager:kuafu_restore(args.player_guid, args.changed)
	end)
	return ngx.print(json_encode(ret_tab))
end


-- 参数选择
function _M:extend(hanlder)
	hanlder['/world_xianfu/match'] = self.match --队伍请求匹配
	hanlder['/world_xianfu/cancel_match'] = self.cancel_match --队伍取消匹配
	hanlder['/world_xianfu/check_match'] = self.check_match --检查匹配
	hanlder['/world_xianfu/match_result'] = self.match_result --比赛结束, 存储奖励
	hanlder['/world_xianfu/check_match_result'] = self.check_match_result --检查奖励
	hanlder['/world_xianfu/save_money'] = self.save_money --传送钱数据
	hanlder['/world_xianfu/sync_money'] = self.sync_money --同步钱数据
	hanlder['/world_xianfu/kuafu_restore'] = self.kuafu_restore --跨服回来钱数量的改变
end

return _M
