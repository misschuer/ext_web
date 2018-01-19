local dbAccess = require 'util.db_access'
local json = require 'cjson'
local json_encode = json.encode
local json_decode = json.decode

local router_cls = require 'util.router_map'
local vaildArgs = router_cls.vaildArgs

local mw_helper = require 'world_million_war/million_war_helper'
local mw_config =  require 'world_million_war.million_war_config'

local dictMgr = require 'world_million_war.million_war_dict_mgr'
local logMgr = require('world_million_war.million_war_log_mgr').new()

local _M = {}

---------------------------------------------------------------------------------
--启动加载
function _M:init()
	mw_helper.loadFromDB()
end


--获取配置
function _M.get_config()	
	local values = {
		fight_begin = 	mw_config.fight_begin 	,--73800-60,--算一分钟的等待时间 晚上八点半
		round_time  = 	mw_config.round_time  	,--300,--除了第一轮 每一轮历时5分钟
		readay_time = 	mw_config.readay_time 	,--60,--每轮的场外备战时间
		fengqu_time	= 	mw_config:getFenquTime(),--分区时间
	}
	ngx.print(json_encode(values))
end

--获取人数和奖金
function _M.get_member_bouns()
	local args = vaildArgs({'open_time'},{'open_time'}) 
	if not args then
		return 
	end
	local fenqu = mw_config:getFenqu(args.open_time)
	
	local values = {
		bonus 		=  mw_config.bonus[fenqu],
		max_member  = 	mw_config.max_member[fenqu]  	,--16384, --门徒世界最大武将队伍数
	}
	ngx.print(json_encode(values))
end

--获取最大人数
function _M.get_max_member()
	local data = {}
	for fenqu, value in ipairs(mw_config.max_member) do
		data[tostring(fenqu)] = value
	end
	ngx.print(json_encode(data))
end

function _M.get_new_vs_old_member()
	local data = {}
	for fenqu = 1, #mw_config.new_member, 1 do
		local key = tostring(fenqu)
		data[key] = {}
		data[key][1] = mw_config.new_member[fenqu]		
		data[key][2] = mw_config.old_member[fenqu]
	end
	ngx.print(json_encode(data))
end

function _M.set_config()
	local args = vaildArgs({'max_member','reg_begin','reg_end','fight_begin','round_time','readay_time'},
							{'max_member','reg_begin','reg_end','fight_begin','round_time','readay_time'}) 
	if not args then
		return 
	end
	--赋值
	mw_config.fight_begin   = args.fight_begin
	mw_config.round_time    = args.round_time 
	mw_config.readay_time   = args.readay_time
	--ngx.print(json_encode({ret=0,msg = 'ok'..args.reg_begin..' '..args.reg_end ..' '..args.fight_begin}))
	
	
		local values = {
		fight_begin = 	mw_config.fight_begin 	,--73800-60,--算一分钟的等待时间 晚上八点半
		round_time  = 	mw_config.round_time  	,--300,--除了第一轮 每一轮历时5分钟
		readay_time = 	mw_config.readay_time, 	--60,--每轮的场外备战时间
		IP = ngx.var.remote_addr,
		cur_time = os.time()
	}
	
	local dir = "data/who_set_config.data"
	local file = io.open(dir,"a+")
	if(file)then
		local str = json_encode(values)..'\n'
		file:write(str)
		file:close()
	end
    
	
	ngx.print(json_encode(values))
end

--报名结果
function _M.reg()
	local args = vaildArgs({'guid','name','open_time','force','show_str', 'gold'},{'open_time','force','gold'}) 
	if not args then
		return 
	end
	if not mw_helper.isRegTime() then
		ngx.print(json_encode({ret=1,msg = 'reg time error'}))
		return
	end
	--注册
	local ret = mw_helper.reg(args)
	logMgr:writeRegLog(args["guid"], args["name"], ret.ret or 1, ret.msg or "")
	ngx.print(json_encode(ret))
end

--获取入选结果
function _M.get_reg_result()
	local args = vaildArgs({'guid','open_time'},{'open_time'}) 
	if not args then
		return 
	end

	local result = mw_helper.getRegResult(args)
	ngx.print(json_encode(result))
end

--传送
function _M.enter()
	local args = vaildArgs({'guid','round'},{'round'}) 
	if not args then
		return 
	end
	local result = mw_helper.getEnterInfo(args)
	ngx.print(json_encode(result))
end

--战斗结果
function _M.fight_result()
	local args = vaildArgs({'win_guid','round','show_data'},{'round'}) 
	if not args then
		return 
	end
	
	local result = mw_helper.calFightResult(args)
	logMgr:writeFightResultLog(args["win_guid"], args["round"])
	return ngx.print(json_encode(result))
end

--获取八强晋级图
function _M.get_baqiang_info()
	local args = vaildArgs({'open_time'},{'open_time'}) 
	if not args then
		return 
	end
	local jie = mw_helper.getCurJie()
	local fenqu = mw_config:getFenqu(args.open_time)
	local null_str = {{},{},{},{},{},{},{},{},{},{},{},{},{},{},{}}
	local str = dictMgr:getBaQIangStr(fenqu,jie) or json_encode(null_str)
	ngx.print(str)
end

--报名人数
function _M.get_reg_count()
	local args = vaildArgs({'open_time'},{'open_time'}) 
	if not args then
		return 
	end
	local jie = mw_helper.getCurJie()
	local fenqu = mw_config:getFenqu(args.open_time)
	local count = dictMgr:getRegCount(jie,fenqu) or 0
	ngx.print(json_encode({ret=0,count = count}))
end

--获取战斗结果 暂时作废
--function _M.get_fight_result()
--	local args = vaildArgs({'guid','name','open_time','force'},{'open_time','force'}) 
--	if not args then
--		return 
--	end
--end
function _M.gold_statistical()
	local args = vaildArgs({'nums','open_time','sign'},{'nums','open_time'}) 
	if not args then
		return 
	end
	local db = dbAccess.getDBObj(conf.db_name )
	local jie = mw_helper.getCurJie()
	local fenqu = mw_config:getFenqu(args.open_time)
	local values = {total_gold = args.nums}
	db.million_war_gold_statistical:update({jie= jie,fenqu=fenqu},{['$inc']=values},true)
	ngx.print(json_encode({ret=0,msg = 'ok'}))
end

--获取历届冠军
function _M.get_champion()
	local args = vaildArgs({'open_time','page'},{'open_time','page'}) 
	if not args then
		return 
	end
	local fenqu = mw_config:getFenqu(args.open_time)
	local str = dictMgr:getChampionStr(fenqu,args.page) or ''
	local count = dictMgr:getChampionCounts(fenqu) or 0
	local info = {
		ret = 0,champions = str,champion_count = count
	}
	ngx.print(json_encode(info))
	--local jies = mw_helper.getThreeJie()
	--local info = {}
	--for i=1,#jies,1 do
	--	local jie = jies[i]
	--	info[jie] = dictMgr:getChampionStr(fenqu,jie) or ''
	--end
	--ngx.print(json_encode(info))
end

function _M.clear()
	local db = dbAccess.getDBObj(conf.db_name)
	local jie = mw_helper.getCurJie() 
	--dictMgr:setMacth(jie)
	dictMgr:dictFrush()
	--ngx.print(tostring(dictMgr:isMacth(jie)))
	local table_name = mw_helper.getDbTableName('million_war_reg')
	db[table_name]:delete({})
	table_name = mw_helper.getDbTableName('million_war_macth')
	db[table_name]:delete({})
	table_name = mw_helper.getDbTableName('million_war_enter')
	db[table_name]:delete({})
	db.million_war_min_force:delete({})
	 
	if dictMgr:isMacth(jie) then
		ngx.print(json_encode({ret=1,msg = 'clear fail'}))
	else
		ngx.print(json_encode({ret=0,msg = 'ok'}))
	end
	--ngx.print(json_encode({ret=0,msg = 'ok'}))
end




function _M:extend(hanlder)
	hanlder['/million_war/get_config'] 			= self.get_config	
	--hanlder['/million_war/set_config'] 		= self.set_config
	
	hanlder['/million_war/get_member_bouns'] 	= self.get_member_bouns
	hanlder['/million_war/get_max_member'] 		= self.get_max_member	
	hanlder['/million_war/get_new_vs_old_member'] = self.get_new_vs_old_member	
	hanlder['/million_war/reg'] 				= self.reg				--报名结果
	hanlder['/million_war/get_reg_result'] 		= self.get_reg_result   --获取入选结果
	hanlder['/million_war/enter'] 				= self.enter 		--传送
	hanlder['/million_war/fight_result']		= self.fight_result  	--战斗结果
	--hanlder['/million_war/get_fight_result']	= self.get_fight_result --获取战斗结果
	hanlder['/million_war/get_baqiang_info']	= self.get_baqiang_info --获取八强晋级图
	hanlder['/million_war/get_reg_count']		= self.get_reg_count --获取报名人数
	
	hanlder['/million_war/clear']				= self.clear --获取八强晋级图
	
	hanlder['/million_war/gold_statistical']	= self.gold_statistical --元宝统计
	hanlder['/million_war/get_champion']		= self.get_champion --获取历届冠军
	
	
	
end

return _M
