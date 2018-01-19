local dbAccess = require 'util.db_access'local json = require 'cjson'
local json_encode = json.encode
local json_decode = json.decode

local _M = {}
local zhuangbei_cashe = ngx.shared.zhuangbei_baoku_times_cashe

function _M:init()
	local db = dbAccess.getDBObj(conf.db_name)
	local result = db.world_zhuangbei_baoku:find()
	local zhuangbei_choujiang_times = {}
	while result:hasNext() do
		local info = result:next()
		info._id = nil
		table.insert(zhuangbei_choujiang_times,info)
	end
	
	--清理缓存
	self:clearCache()
	for i=1,#zhuangbei_choujiang_times,1 do 
		self:setChoujiangTimes(zhuangbei_choujiang_times[i].platid,zhuangbei_choujiang_times[i].choujiang_times)
	end
	
end

function _M:getChouJiangTimes(platid)
	local choujiang_times =  zhuangbei_cashe:get("choujiang_times#"..platid)
	if not choujiang_times then
		self:initChouJiangInfo(platid)
		choujiang_times =  zhuangbei_cashe:get("choujiang_times#"..platid)
	end
	return choujiang_times
end



--清理缓存
function _M:clearCache()
	zhuangbei_cashe:flush_all()
	zhuangbei_cashe:flush_expired()
end
--设置抽奖次数
function _M:setChoujiangTimes(platid,value)
	zhuangbei_cashe:set("choujiang_times#"..platid,value)
end
--数据库
function _M:initChouJiangInfo(platid)
	local choujiang_times = 0
	local db = dbAccess.getDBObj(conf.db_name )
	local tbl = db.world_zhuangbei_baoku:findOne({platid=platid})
	if tbl then
		choujiang_times = tbl.choujiang_times
	end
	self:setChoujiangTimes(platid,choujiang_times)
end

return _M