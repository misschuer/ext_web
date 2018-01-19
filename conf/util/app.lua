handler_map = handler_map or {}
local dbAccess = require 'util.db_access'
local router_cls = require 'util.router_map'

local vaildArgs = router_cls.vaildArgs
--默认处理函数
handler_map['']  = function ()
    ngx.say('oh,no!')
    --ngx.exit(404)
end

handler_map['/battble_server_reg']  = function ()
	local args = vaildArgs({'info'}) 
	if not args then
		return
	end
	
	local db = dbAccess.getDBObj(conf.db_name )
	--更新注册时间
	db.battle_server_list:update({server_info= args.info},{['$set']={server_info= args.info,reg_time = os.time()}},true)
end

--初始化路由表
local router_cls = require 'util.router_map'
local router = router or router_cls.new(handler_map)

if router:doWork() == true then
	ngx.exit(200)
end

