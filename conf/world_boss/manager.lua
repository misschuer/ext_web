-----------------------------------------------------------------------------------
--world_boss-----------------------------------------------------------------------
-----------------------------------------------------------------------------------

local dbAccess = require 'util.db_access'
local json = require 'cjson'
local json_encode = json.encode
local json_decode = json.decode

local router_cls = require 'util.router_map'
local cache = require 'world_boss.cache'
local config = require 'world_boss.config'

local _M = {}

--设置跨服分组
function _M:set_group(server_strs, gid)
	local server_tabs = string.split(server_strs, ',')
	if #server_tabs == 0 then
		return {ret = 1, msg = 'server_name is empty'}
	end

	local db = dbAccess.getDBObj(conf.db_name)
	if not db then
		return {ret = 2, msg = 'db error'}
	end	
	
	for _, server_name in ipairs(server_tabs) do
		if server_name ~= '' then
			local wheres = {}
			wheres._id = server_name
			
			local value = {}
			value.server_name = server_name
			value.gid = gid
			db.world_boss_group:update(wheres, {["$set"] = value}, true, false)			
			cache:SetGroup(server_name, gid)
		end
	end
	
	return {ret = 0, msg = 'success'}
end

--进入分组跨服
function _M:enter(server_name)	
	--获取服务器所在的分组
	local gid = cache:GetGroup(server_name)
	if gid == nil then
		return {ret = 2, msg = 'gid not found'}
	end
	
	local room_info = cache:GetRoomInfo(gid)
	--房间进入信息已经生成
	if room_info then
		--房间已满不准进入
		if room_info.player_count >= config.max_player_count then
			return {ret = 3, msg = 'room is full'}
		
		--房间不满允许进入
		else
			room_info.player_count = room_info.player_count + 1	
		end
	
	--房间进入信息还未生成
	else
		--初次获取分配战斗服
		local locks = string.format(config.gid_lock_str, gid)		
		room_info, err_ret = router_cls.opdata_with_lock(locks, function()
			local new_room_info = cache:GetRoomInfo(gid)
			if new_room_info then
				return new_room_info, nil
			end			
		
			--找个可用的战斗服
			local battle_server = self:choose_battle_server()
			if not battle_server then
				return nil, {ret = 4, msg = 'can not find battle_server'}	 
			end				
		
			--初始化房间的信息
			new_room_info = {}
			new_room_info.war_id = string.format('group%u', gid)
			new_room_info.pos = 1
			new_room_info.battle_server = battle_server
			new_room_info.player_count = 1
			new_room_info.drop_count = 0
			
			return new_room_info, nil
		end)
		
		if room_info == nil then
			return err_ret
		end
	end
	
	
	--保存一下分组房间信息
	local room_info_to_json = json_encode(room_info)
	cache:SetRoomInfo(gid, room_info_to_json)	

	--保存到数据库中持久化
	local db = dbAccess.getDBObj(conf.db_name)
	if db then
		local wheres = {}
		wheres._id = string.format(config.gid_db_str, gid)
		
		local value = {}
		value.date = os.date('%Y%m%d') --这个时间很关键，用于重启的时候要不要设置缓存
		value.gid = gid
		value.room_info = room_info_to_json
		db.world_boss_room_info:update(wheres, {["$set"] = value}, true, false)
	end	

	local enter_info = {}
	enter_info.war_id = room_info.war_id
	enter_info.pos = room_info.pos
	enter_info.battle_server = room_info.battle_server
	return {ret = 0, msg = 'success', enter_info = json_encode(enter_info)}		
end


--同步队伍人数
function _M:sync_player_count(gid, player_count)
	local room_info = cache:GetRoomInfo(gid)
	--没有房间信息就不管了
	if room_info == nil then	
		return {ret = 2, msg = 'can not find room'}	
	end

	--更新一下分组房间信息	
	room_info.player_count = player_count
	local room_info_to_json = json_encode(room_info)
	cache:SetRoomInfo(gid, room_info_to_json)	

	--保存到数据库中持久化
	local db = dbAccess.getDBObj(conf.db_name)
	if db then
		local wheres = {}
		wheres._id = string.format(config.gid_db_str, gid)
		
		local value = {}	
		value.room_info = room_info_to_json
		db.world_boss_room_info:update(wheres, {["$set"] = value}, true, false)
	end	

	return {ret = 0, msg = 'success', player_count = player_count}		
end

--请求掉落数量
function _M:get_drop_count(server_name)
	--获取服务器所在的分组
	local gid = cache:GetGroup(server_name)
	if gid == nil then
		return {ret = 2, msg = 'gid not found'}
	end

	local room_info = cache:GetRoomInfo(gid)
	--没有房间信息就不管了
	if room_info == nil then	
		return {ret = 2, msg = 'can not find room'}	
	end	

	return {ret = 0, msg = 'success', drop_count = room_info.drop_count}
end

--请求掉落物品
function _M:apply_for_drop(gid)
	local room_info = cache:GetRoomInfo(gid)
	--没有房间信息就不管了
	if room_info == nil then	
		return {ret = 2, msg = 'can not find room'}	
	end
	
	--达到最大次数就不管了
	if room_info.drop_count >= config.max_drop_count then
		return {ret = 3, msg = 'already max drop count'}
	end

	--更新一下分组房间信息	
	room_info.drop_count = room_info.drop_count + 1
	local room_info_to_json = json_encode(room_info)
	cache:SetRoomInfo(gid, room_info_to_json)	

	--保存到数据库中持久化
	local db = dbAccess.getDBObj(conf.db_name)
	if db then
		local wheres = {}
		wheres._id = string.format(config.gid_db_str, gid)
		
		local value = {}	
		value.room_info = room_info_to_json
		db.world_boss_room_info:update(wheres, {["$set"] = value}, true, false)
	end	

	return {ret = 0, msg = 'success', drop_count = room_info.drop_count}		
end

--同步怪物状态
function _M:set_boss_state(gid, boss_state)
	local room_info = cache:GetRoomInfo(gid)
	--没有房间信息就不管了
	if room_info == nil then	
		return {ret = 2, msg = 'can not find room'}	
	end
	
	cache:SetBossInfo(gid, boss_state)
	return {ret = 0, msg = 'success'}
end

--获取怪物状态
function _M:get_boss_state(server_name)
	--获取服务器所在的分组
	local gid = cache:GetGroup(server_name)
	if gid == nil then
		return {ret = 2, msg = 'gid not found'}
	end

	local boss_state = cache:GetBossInfo(gid)
	return {ret = 0, msg = 'success', boss_state = boss_state}
end

--增加拾取信息
function _M:add_pick_info(gid, pick_data)
	local room_info = cache:GetRoomInfo(gid)
	--没有房间信息就不管了
	if room_info == nil then	
		return {ret = 2, msg = 'can not find room'}	
	end

	local pick_strs = cache:GetPickInfo(gid)
	local pick_info = {}
	if pick_strs then
		pick_info = json_decode(pick_strs)
	end
	pick_info[#pick_info + 1] = pick_data
	while #pick_info > config.max_pick_info_count do
		table.remove(pick_info, 1)
	end	
	
	cache:SetPickInfo(gid, json_encode(pick_info))
	return {ret = 0, msg = 'success'}
end

--获取拾取信息
function _M:get_pick_info(server_name)
	--获取服务器所在的分组
	local gid = cache:GetGroup(server_name)
	if gid == nil then
		return {ret = 2, msg = 'gid not found'}
	end

	local pick_info = cache:GetPickInfo(gid)
	return {ret = 0, msg = 'success', pick_info = pick_info}
end

--选一个战斗服
function _M:choose_battle_server()
	local db = dbAccess.getDBObj(conf.db_name )
	if not db then
		return nil
	end
	
	local where = {}
	where['reg_time'] = {['$gte'] = os.time() - 660}	
	local cursor = db.battle_server_list:find(where,{})
	local result = {}
	while cursor:hasNext() do
		local data = cursor:next()
		result[#result + 1] = data
	end
	
	if #result > 0 then
		local index = math.random(1, 10000) % (#result) + 1
		return result[index].server_info
	else
		return nil
	end
end

return _M
