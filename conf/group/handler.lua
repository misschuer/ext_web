-----------------------------------------------------------------------------------
--world_3v3------------------------------------------------------------------------
-----------------------------------------------------------------------------------

local dbAccess = require 'util.db_access'
local json = require 'cjson'
local json_encode = json.encode
local json_decode = json.decode

local router_cls = require 'util.router_map'
local vaildArgs = router_cls.vaildArgs
local cache = require 'world_3v3.cache'
local manager = require 'world_3v3.manager'
local config = require 'world_3v3.config'

local _M = {}
function _M:init()
	local db = dbAccess.getDBObj(conf.db_name )
	if not db then
		return
	end
	
	--圣兽房间信息
	local cursor = db.world_3v3_saint_beast_room_info:find()
	while cursor:hasNext() do
		local data = cursor:next()
		if data.date == os.date('%Y%m%d') then
			cache:SetSaintBeastRoomInfo(data.fenqu, data.saint_beast_type, data.room_info)
		end
	end

	--宝箱开启信息	
	local key_1 = string.format('fenqu#%u#box_info#%s', 1, os.date('%Y%m%d', os.time() - 86400))
	local key_2 = string.format('fenqu#%u#box_info#%s', 1, os.date('%Y%m%d', os.time()))
	local key_3 = string.format('fenqu#%u#box_info#%s', 2, os.date('%Y%m%d', os.time() - 86400))
	local key_4 = string.format('fenqu#%u#box_info#%s', 2, os.date('%Y%m%d', os.time()))	
	local cursor = db.world_3v3_box_info:find({_id = {['$in'] = {key_1, key_2, key_3, key_4}}})
	while cursor:hasNext() do
		local data = cursor:next()
		cache:SetBoxInfo(data.fenqu, data.time, data.box_info)
	end	
end

--队伍请求匹配
function _M:match()
	local args = vaildArgs({'group_guid', 'open_time'},{'open_time'}) 
	if not args then
		return
	end

	local fenqu = config:get_fenqu(args.open_time)
	local ret_tab = router_cls.opdata_with_lock('match_list#' .. fenqu, function() 
		return manager:match(fenqu, args.group_guid, args.use_battle_server or '')
	end)	
	return ngx.print(json_encode(ret_tab))
end

--队伍取消匹配
function _M:cancel_match()
	local args = vaildArgs({'group_guid', 'open_time'},{'open_time'}) 
	if not args then
		return
	end	
	
	local fenqu = config:get_fenqu(args.open_time)
	local ret_tab = router_cls.opdata_with_lock('match_list#' .. fenqu, function() 
		return manager:cancel_match(fenqu, args.group_guid)
	end)	
	return ngx.print(json_encode(ret_tab))	
end

function _M:extend(hanlder)
	hanlder['/group/match'] = self.match --队伍请求匹配
	hanlder['/group/cancel_match'] = self.cancel_match --队伍取消匹配
end

return _M
