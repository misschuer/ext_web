-----------------------------------------------------------------------------------
--world_boss-----------------------------------------------------------------------
-----------------------------------------------------------------------------------

local dbAccess = require 'util.db_access'
local json = require 'cjson'
local json_encode = json.encode
local json_decode = json.decode

local router_cls = require 'util.router_map'
local vaildArgs = router_cls.vaildArgs
local cache = require 'world_boss.cache'
local manager = require 'world_boss.manager'
local config = require 'world_boss.config'

local _M = {}
function _M:init()
	local db = dbAccess.getDBObj(conf.db_name )
	if not db then
		return
	end

	--跨服分组信息
	local cursor = db.world_boss_group:find()
	while cursor:hasNext() do
		local data = cursor:next()
		if data.server_name and data.gid then
			cache:SetGroup(data.server_name, data.gid)
		end
	end	
	
	--分组房间信息
	local cursor = db.world_boss_room_info:find()
	while cursor:hasNext() do
		local data = cursor:next()
		if data.date == os.date('%Y%m%d') then
			cache:SetRoomInfo(data.gid, data.room_info)
		end
	end	
end

--设置跨服分组
function _M:set_group()
	local args = vaildArgs({'server_name','gid'},{'gid'}) -- server_name = "id, id, id..."
	if not args then
		return
	end	

	local ret_tab = manager:set_group(args.server_name, args.gid)
	return ngx.print(json_encode(ret_tab))	
end

--进入分组跨服
function _M:enter()
	local args = vaildArgs({'server_name'},{})
	if not args then
		return
	end

	local ret_tab = manager:enter(args.server_name)
	return ngx.print(json_encode(ret_tab))	
end

--同步玩家人数
function _M:sync_player_count()
	local args = vaildArgs({'war_id', 'player_count'}, {'player_count'}) 
	if not args then
		return
	end	

	local gid = tonumber(string.match(args.war_id, '%d+')) or 0
	local locks = string.format(config.gid_lock_str, gid)
	local ret_tab = router_cls.opdata_with_lock(locks, function()
		return manager:sync_player_count(gid, args.player_count)
	end)		
	
	return ngx.print(json_encode(ret_tab))		
end

--请求掉落数量
function _M:get_drop_count()
	local args = vaildArgs({'server_name'},{})
	if not args then
		return
	end

	local ret_tab = manager:get_drop_count(args.server_name)
	return ngx.print(json_encode(ret_tab))	
end

--请求掉落物品
function _M:apply_for_drop()
	local args = vaildArgs({'war_id'}) 
	if not args then
		return
	end	

	local gid = tonumber(string.match(args.war_id, '%d+')) or 0
	local locks = string.format(config.gid_lock_str, gid)
	local ret_tab = router_cls.opdata_with_lock(locks, function()
		return manager:apply_for_drop(gid)
	end)		
	
	return ngx.print(json_encode(ret_tab))		
end

--同步怪物状态
function _M:set_boss_state()
	local args = vaildArgs({'war_id', 'boss_state'}) 
	if not args then
		return
	end	

	local gid = tonumber(string.match(args.war_id, '%d+')) or 0
	local locks = args.war_id
	local ret_tab = router_cls.opdata_with_lock(locks, function()
		return manager:set_boss_state(gid, args.boss_state)
	end)

	return ngx.print(json_encode(ret_tab))
end

--获取怪物状态
function _M:get_boss_state()
	local args = vaildArgs({'server_name'}) 
	if not args then
		return
	end	

	local ret_tab = manager:get_boss_state(args.server_name)
	return ngx.print(json_encode(ret_tab))
end

--增加拾取信息
function _M:add_pick_info()
	local args = vaildArgs({'war_id', 'pick_data'}) 
	if not args then
		return
	end	

	local gid = tonumber(string.match(args.war_id, '%d+')) or 0
	local locks = args.war_id
	local ret_tab = router_cls.opdata_with_lock(locks, function()
		return manager:add_pick_info(gid, args.pick_data)
	end)

	return ngx.print(json_encode(ret_tab))
end

--获取拾取信息
function _M:get_pick_info()
	local args = vaildArgs({'server_name'}) 
	if not args then
		return
	end	

	local ret_tab = manager:get_pick_info(args.server_name)
	return ngx.print(json_encode(ret_tab))
end


function _M:extend(hanlder)
	hanlder['/world_boss/set_group'] = self.set_group --设置分组编号
	hanlder['/world_boss/enter'] = self.enter --进入分组房间
	hanlder['/world_boss/sync_player_count'] = self.sync_player_count --同步玩家人数
	hanlder['/world_boss/get_drop_count'] = self.get_drop_count --请求掉落数量
	hanlder['/world_boss/apply_for_drop'] = self.apply_for_drop --请求掉落物品
	hanlder['/world_boss/set_boss_state'] = self.set_boss_state --同步怪物状态
	hanlder['/world_boss/get_boss_state'] = self.get_boss_state --获取怪物状态
	hanlder['/world_boss/add_pick_info'] = self.add_pick_info --增加拾取信息
	hanlder['/world_boss/get_pick_info'] = self.get_pick_info --获取拾取信息
end

return _M
