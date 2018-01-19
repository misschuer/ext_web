local dbAccess = require 'util.db_access'
local json = require 'cjson'
local json_encode = json.encode
local json_decode = json.decode

local router_cls = require 'util.router_map'
local vaildArgs = router_cls.vaildArgs

local baoku_manager = require 'world_zhuanbei_baoku.zhuangbei_baoku_db_mgr'

local _M = {}


--增加装备宝库抽取次数
function _M:add_choujiang_times()
	router_cls.opdata_with_lock('zhuangbei_baoku', function() 
		local args = vaildArgs({'platid','count'},{'platid','count'})
		if not args then
			return 
		end
		
		local choujiang_times = baoku_manager:getChouJiangTimes(args.platid)
		local new_choujiang_times = choujiang_times + args.count
	
		local values={}
		values.platid = args.platid
		values.choujiang_times = new_choujiang_times
		baoku_manager:setChoujiangTimes(args.platid,new_choujiang_times)
		local db = dbAccess.getDBObj(conf.db_name)
		db.world_zhuangbei_baoku:update({platid=args.platid},{['$set']=values},true)
		ngx.print(json_encode({ret = 0,old_choujiang_times = choujiang_times, new_choujiang_times = new_choujiang_times,msg = 'ok'}))
	end)
end

function _M:get_choujiang_times()
	local args = vaildArgs({'platid'},{'platid'})
	if not args then
		return 
	end
	
	local choujiang_times = baoku_manager:getChouJiangTimes(platid)
	local result = json_encode({ret = 0,choujiang_times = choujiang_times})
	ngx.print(result)
end


function _M:extend(hanlder)
	hanlder['/handle_zhuangbei_baoku/get_choujiang_times'] = self.get_choujiang_times
	hanlder['/handle_zhuangbei_baoku/add_choujiang_times'] = self.add_choujiang_times
	
end

return _M