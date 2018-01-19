require 'util.functions'
local dbAccess = require 'util.db_access'
local json = require 'cjson'
local json_encode = json.encode
local json_decode = json.decode
local router_cls = require 'util.router_map'
local logMgr = require('world_million_war.million_war_log_mgr').new()

local mw_config = require 'world_million_war.million_war_config'

local dictMgr = require 'world_million_war.million_war_dict_mgr'

local _M = {}

--从数据库中加载
function _M.loadFromDB()

	local jie = _M.getCurJie()
	--匹配信息
	local db = dbAccess.getDBObj(conf.db_name)
	local t_name = _M.getDbTableName('million_war_macth')
	local c = db[t_name]:find()
	local all_match = {} 
	local fequ_list = {} --用来判断是不是要更新八强串
	local is_match = false 
	while c:hasNext() do
		local info = c:next()
		info._id = nil
		local macth_info_str = json_encode(info)
--print(macth_info_str)
		dictMgr:setPosMacthInfo(info.round,info.fenqu,info.pos,jie,macth_info_str)
		dictMgr:setGuidMacthInfo(info.round,info.guid,jie,macth_info_str)	
		is_match = true
	end
	
	for fenqu,count in pairs(fequ_list) do
		_M.updateMacthStr(fenqu)
	end
	
	
	--报名人数
	table_name = _M.getDbTableName('million_war_reg')
	c = db[table_name]:find()
	local all_reg = {}
	while c:hasNext() do
		local r = c:next()
		local fenqu = tostring(r.fenqu)
		all_reg[fenqu] = all_reg[fenqu] or 0
		all_reg[fenqu] = all_reg[fenqu] + 1 	
	end	
	
	for fenqu,count in pairs(all_reg) do
		dictMgr:setRegCount(jie,fenqu,count)
	end

	--告诉全世界我匹配过了
	if is_match then
		dictMgr:setMacth(jie)
	end
	
	--最低战斗力,fenqu=fenqu,min_force=min_force
	c = db.million_war_min_force:find({jie=jie})
	while c:hasNext() do
		local info = c:next()
		info._id = nil
		dictMgr:setMinForce(jie,info.fenqu,info.min_force)
	end
	
	--进场信息
	t_name = _M.getDbTableName('million_war_enter')
	local c = db[t_name]:find()
	while c:hasNext() do
		local info = c:next()
		dictMgr:setEnterInfo(jie,info.guid,info.round,enter_info)
	end
	
	--for i = 1,30,1 do
	--	local j = i%7
	--	local values = {
	--		jie = '201606'..i,		
	--		guid= "2_3_"..j,
	--		fenqu = 1,
	--		show_data = 'test_name'..j
	--	}
	--	db.million_war_champion:insert(values)
	--end
	--历届冠军信息
	
	_M.updateChampionStr()
	
	
	--后台配置信息 2016/08/10
	--c = db.million_war_config:find()
	--while c:hasNext() do
	--	local info = c:next()
	--	info._id = nil
	--	dictMgr:setConfigInfo(info.fenqu,json_encode(info))
	--end


	--c = db.million_war_champion:find()
	--local jies = _M.getThreeJie()
	--while c:hasNext() do
	--	local info = c:next()
	--	info._id = nil
	--	local fenqu = info.fenqu
	--	local that_jie = info.jie
	--	--是最近三届的才要处理
	--	if that_jie == jies[1] or that_jie == jies[2] or that_jie == jies[3] then
	--		dictMgr:setChampionStr(fenqu,that_jie,info.show_data)
	--	end
	--end	
end

------------------------------------------------------------
--一些验证类的接口封装
--是否是报名时间
function _M.isRegTime()
	local cur_sec = mw_config:getCurrSec() --今天的秒数
	if (cur_sec < mw_config.fight_begin - mw_config.reg_diff) or (cur_sec > mw_config.fight_begin + mw_config.reg_diff + 3600 + mw_config.reg_diff) then
		return true
	end
	
	return false
end

--获取总轮数
function _M.getTotalRound(fenqu)
	local _,round_p = math.frexp(mw_config.max_member[fenqu])
	return round_p-1
end

--获取当前轮数 再看看
--function _M.getCurRound()
--	local cur_sec = mw_config:getCurrSec() --今天的秒数
--	if cur_sec then
--		return nil
--	end
--end

--是否传送时间
function _M.isEnterTime(round)
	local cur_sec = mw_config:getCurrSec() --今天的秒数
	--每轮开始时间加上一分钟备战 就是传送开始时间
	local enter_begin = mw_config.fight_begin+(round-1)*mw_config.round_time
	--TODO误差要给多大呢呢呢呢呢 考虑对时
	local enter_end = enter_begin+60+60 --误差一分钟？？
	if cur_sec >= enter_begin and cur_sec <= enter_end then
		return true
	end
	return false,cur_sec,enter_begin,enter_end
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--功能接口封装

--获取报名界数 同时也是表名后缀
function _M.getRegJie()
	local cur_sec = mw_config:getCurrSec() --今天的秒数
	local cur_tim = os.time()
	if cur_sec > mw_config:getCurrEnd() then 
		cur_tim = cur_tim + 86400
	end

	local cur_date = os.date("*t", cur_tim)
	local cur_year = tostring(cur_date.year)
	local cur_month = tostring(cur_date.month)
	if(cur_date.month<10)then
		cur_month = "0"..cur_month
	end
	
	local cur_day = tostring(cur_date.day)
	if cur_date.day < 10 then
		cur_day = "0"..cur_day
	end

	return cur_year..cur_month..cur_day
end

--获取当前界数 同时也是表名后缀
function _M.getCurJie()
	local cur_date = os.date("*t",os.time())
	local cur_year = tostring(cur_date.year)
	local cur_month = tostring(cur_date.month)
	if(cur_date.month<10)then
		cur_month = "0"..cur_month
	end
	
	local cur_day = tostring(cur_date.day)
	if cur_date.day < 10 then
		cur_day = "0"..cur_day
	end

	return cur_year..cur_month..cur_day
end

--获取三界 
--function _M.getThreeJie()
--	local cur_date = os.date("*t",os.time())
--	local cur_year = tostring(cur_date.year)
--	local cur_month = tostring(cur_date.month)
--	if(cur_date.month<10)then
--		cur_month = "0"..cur_month
--	end
--	local cur_day = tostring(cur_date.day)
--	if cur_date.day < 10 then
--		cur_day = "0"..cur_day
--	end
--	
--	local jie1 = cur_year..cur_month..cur_day
--	
--	---昨天的 
--	cur_date = os.date("*t",os.time()-86400)	
--	cur_year = tostring(cur_date.year)
--	cur_month = tostring(cur_date.month)
--	if cur_date.month<10 then
--		cur_month = "0"..cur_month
--	end
--	cur_day = tostring(cur_date.day)
--	if cur_date.day < 10 then
--		cur_day = "0"..cur_day
--	end
--	
--	local jie2 = cur_year..cur_month..cur_day
--	
--	--前天的
--	cur_date = os.date("*t",os.time()-86400*2)
--	cur_year = tostring(cur_date.year)
--	cur_month = tostring(cur_date.month)
--	if(cur_date.month<10)then
--		cur_month = "0"..cur_month
--	end
--	cur_day = tostring(cur_date.day)
--	if cur_date.day < 10 then
--		cur_day = "0"..cur_day
--	end
--	
--	local jie3 = cur_year..cur_month..cur_day
--    
--	return {jie1,jie2,jie3}
--end

--统一拼装表名
function _M.getRegDbTableName(name)
	local jie = _M.getRegJie()
	return name.."_"..jie
end


--统一拼装表名
function _M.getDbTableName(name)
	local jie = _M.getCurJie()
	return name.."_"..jie
end

--选择战斗服
function _M.chooseBattle_server()
	local db = dbAccess.getDBObj(conf.db_name )
	--更新注册时间 ['$set']={server_info= info,reg_time = os.time()}
	local where = {}
	--十来分钟以内有来注册的
	where['reg_time'] = {['$gte'] = os.time()-660}
	local c = db.battle_server_list:find(where,{})
	local battle_server = {}
	while c:hasNext() do
		local r = c:next()
		table.insert(battle_server,r)
		--也不要没边没际的 差不多就得了
		if(#battle_server>50)then
			break
		end
	end
	
--	if true then
--		return '2_3;192.168.8.147;443'
--	end 
	
	--随机一个
	if(#battle_server>0)then
		local index = randIntD(1,#battle_server)
		return battle_server[index].server_info
	else
		return nil
	end
end

--创建匹配信息 封装一下
function _M.createMatchInfo(round,pos,guid,name,fenqu,force,show_str)
	local macth_info = {}
	macth_info.round = round
	macth_info.pos = pos
	macth_info.guid = guid
	macth_info.name = name
	macth_info.fenqu =fenqu
	macth_info.force = force
	macth_info.show_str = show_str
	return macth_info
end

--检查是否匹配
function _M.checkMacth()
	local jie = _M.getCurJie()
	if dictMgr:isMacth(jie) then
		--ngx.print(' isMacth='..tostring(dictMgr:isMacth(jie)))
		return 
	end
	--时间检查实际上可有可无
	local cur_sec = mw_config:getCurrSec() --今天的秒数
	--每轮开始时间加上一分钟备战 就是传送开始时间
	if cur_sec> mw_config:getCurrEnd() then
		router_cls.opdata_with_lock('million_war_macth',function()
			if dictMgr:isMacth(jie) then
				return 
			end

			_M.macth()
		end)
	end
end

--是否需要补机器人
function _M.is_need_rebot(round,fenqu)
	--找信息来拼
	local max_round = _M.getTotalRound(fenqu)
	--最后三轮不补机器人
	return max_round - round >= 3 
end

--获取一个机器人信息
function _M.getRobotMacthInfo(round,pos,fenqu)
	local info = _M.createMatchInfo(round,pos,mw_config.robot_guid,mw_config.robot_name,fenqu,0,'')
	return info
end

--更新八强列表
function _M.updateMacthStr(fenqu)
	--看下第几轮开始
	local jie = _M.getCurJie()
	local max_round = _M.getTotalRound(fenqu)
	local begin_round = max_round-2
	local info = {}
	--一层的人数
	local member = 8
	--一共三轮加冠军
	for i = 0,3,1 do
		for pos = 1, member,1 do 
			local macth_info_t = {}
			local macth_info  =  dictMgr:getPosMacthInfo(begin_round+i,fenqu,pos,jie)
		
			if macth_info then
				macth_info_t = json_decode(macth_info)
			end
			table.insert(info,macth_info_t)
		end
		--每一轮少一个
		member = member/2
	end
	
	local str = json_encode(info)	
	--存存存存起来
	dictMgr:setBaQIangStr(fenqu,jie,str)
end


--计算冠军数量
function _M.calculChampionCount(guid,champion_table)
	local count = 0
	for i = 1,#champion_table,1 do
		local cham = champion_table[i]	
		if guid == cham.guid then
			count = count+1
		end
	end
	return count
end

--更新冠军
function _M.updateChampionStr()

	local db = dbAccess.getDBObj(conf.db_name)
	local c = db.million_war_champion:find()
	local all_champion = {}
	--先全部取出来
	while c:hasNext() do
		local info = c:next()
		info._id = nil
		local fenqu = info.fenqu
		if not all_champion[fenqu] then
			all_champion[fenqu] = {}
		end
		table.insert(all_champion[fenqu],info)
	end	
	
	--排下序--
	for fenqu,champions in pairs(all_champion) do
		--排个降序
		table.sort(champions,function (a,b)
			return tonumber(a.jie)>tonumber(b.jie)
		end)
		
		--一共有几个冠军
		dictMgr:setChampionCounts(fenqu,#champions)
		
		local champion_count = {} --获得了几届冠军
		local page = {}	--一页的数据
		local cur_page = 1	--当前打包到第几页
		--统计冠军届数 开始拼接
		for i =1,#champions,1 do
			local info = champions[i]
			if not champion_count[info.guid] then
				champion_count[info.guid] = _M.calculChampionCount(info.guid,champions)
			end
			--装上冠军数量
			info.champion_times = champion_count[info.guid]
			table.insert(page,info)
			--装满一页了
			if #page == mw_config.rank_page_count then
				dictMgr:setChampionStr(fenqu,cur_page,json_encode(page))
				page = {}
				cur_page = cur_page+1
			end			
		end
		--最后一页没满的
		if #page then
			dictMgr:setChampionStr(fenqu,cur_page,json_encode(page))
		end
	end
end
	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--handler接口封装
function _M.reg(args)
	--'guid','name','open_time','force
	--获取分区
	local fenqu = mw_config:getRegFenqu(args.open_time)
	--更新数据
	args.open_time = nil
	args.fenqu = fenqu
		
	local db = dbAccess.getDBObj(conf.db_name )
	local table_name = _M.getRegDbTableName('million_war_reg')
	--更新注册时间
	db[table_name]:update({guid= args.guid},{['$set']=args},true)
	
	--增加报名人数
	local jie = _M.getRegJie()
	dictMgr:addRegCount(jie,fenqu)
	
	return {ret = 0, msg='sucess', end_time = mw_config:getRegEndTime()}
end

--报名结果
function _M.getRegResult(args)
	local cur_sec = mw_config:getCurrSec() --今天的秒数
	--检查下时间
	if cur_sec <= mw_config:getCurrEnd() + 300 then
		local diff = mw_config:getCurrEnd() - cur_sec
		return {ret = 1,msg='time_error '..diff}
	end
	
	--检查下匹配还是必要的
	_M.checkMacth()
	
	local jie = _M.getCurJie()
	local fenqu = mw_config:getFenqu(args.open_time)
	local guid = args.guid
	--看下有没匹配成功
	local macth_info = dictMgr:getGuidMacthInfo(1,guid,jie) 
	local min_force = dictMgr:getMinForce(jie,fenqu)
	if (not min_force) then
		return {ret = 3, msg='not ready min force is nil'}
	end	
	
	if(not macth_info)then
		return {ret = 2,msg='out',min_force = min_force}
	else
		return {ret = 0,msg='sucess',min_force = min_force}	
	end
end

--筛选
function _M.macth()
	--从数据库中载出当天报名数据筛选一下
	--打乱洗牌一下
	--弄成匹配信息
	--分别存入数据库和共享内存
	
	--清理下共享内存，释放空间
	dictMgr:dictFrush()
	
	local db = dbAccess.getDBObj(conf.db_name )
	--更新配置信息
	local c = db.million_war_config:find()
	while c:hasNext() do
		local info = c:next()
		info._id = nil
		dictMgr:setConfigInfo(info.fenqu,json_encode(info))
	end
	
	
	--当前比赛界数
	local jie = _M.getCurJie() 
	--从数据库中载出当天报名数据

	local table_name = _M.getDbTableName('million_war_reg_sifting')
	c = db[table_name]:find()
	local all_reg = {}
	while c:hasNext() do
		local r = c:next()
		local fenqu = tostring(r.fenqu)
		local index = r.new_player or 0
		all_reg[fenqu] = all_reg[fenqu] or {}
		all_reg[fenqu][index] = all_reg[fenqu][index] or {}
		
		table.insert(all_reg[fenqu][index],r)
	end
	
	--正常永远用不到
	if table.nums(all_reg) == 0 then		
		table_name = _M.getDbTableName('million_war_reg')
		c = db[table_name]:find()
		while c:hasNext() do
			local r = c:next()
			local fenqu = tostring(r.fenqu)
			local index = 0
			all_reg[fenqu] = all_reg[fenqu] or {}
			all_reg[fenqu][index] = all_reg[fenqu][index] or {}
			
			table.insert(all_reg[fenqu][index],r)
		end
	end
	
	local old_player_index = 0
	local new_player_index = 1
	
	--逐个分区处理匹配信息
	for i, fenqu_reg in pairs(all_reg) do 
		local fenqu = tonumber(i)
			
		local max_member = mw_config.max_member[fenqu]	    --允许参赛人数
		--新老玩家数量
		local old_players = fenqu_reg[old_player_index] or {}
		local new_players = fenqu_reg[new_player_index] or {}
		logMgr:writeTableLog(string.format('table = %s fenqu = %u old_players = %u new_players = %u', table_name, fenqu, #old_players, #new_players))
		
		--最终能参赛的老玩家列表
		local last_old_players = {}
		--总玩家超出最大数量，新玩家不可能超标（小吴那边控制），所以一定是从老玩家里面干掉
		if #old_players > mw_config.old_member[fenqu] then
			--按身价排个序 
			table.sort(old_players,function (a,b) 
				local a_gold = tonumber(a.gold) or 0
				local b_gold = tonumber(b.gold) or 0
				if a_gold == b_gold then
					return a.force>b.force
				else
					return a_gold > b_gold
				end
			end)
			--干掉身价比较低的
			for i=1, mw_config.old_member[fenqu],1 do
				table.insert(last_old_players,old_players[i])
			end
		else
			last_old_players = old_players
		end
		
		--分别打乱新老玩家数组
		table.shuffle(last_old_players,#last_old_players)
		table.shuffle(new_players,#new_players)
		--开始花样做表，分大组 8强，分小组 4老玩家4新玩家随机组合
		local last_in_war = {}	
		--游标
		local old_index = 1
		local new_index = 1
		
		local all_player_count = #last_old_players + #new_players		
		local real_player_count = math.floor(all_player_count / 8) --优先保证真人
		local remain_player_count = all_player_count - real_player_count * 8
		for big_group = 1, 8, 1 do --分大组插入数据 优先保证8强有玩家
			local diff = 0
			if remain_player_count > 0 then
				diff = 1
				remain_player_count = remain_player_count - 1 -- 比如14个人分八组则是（2,2,2,2,2,2,1,1）而不会变成这样（2,2,2,2,2,2,2,0）
			end		
		
			for min_group = 1, math.floor(max_member / 8), 4 do	--分小组插入数据 新人和老人随机插入	
				--看下这个位置的新老因子
				local factor = math.random(1, 10000)%2--math.floor((i-1)/4)%2			
				for j = 0, 3, 1 do
					if min_group + j <= real_player_count + diff then 
						--老玩家
						if factor == 0 then
							if last_old_players[old_index] then
								table.insert(last_in_war,last_old_players[old_index])
								old_index = old_index+1
							elseif new_players[new_index] then
								table.insert(last_in_war,new_players[new_index])
								new_index = new_index+1	
							else
								local robot = {name = mw_config.robot_name,guid = mw_config.robot_guid,fenqu=fenqu,force = 0}
								table.insert(last_in_war, robot)
							end
						else --新玩家 
							if new_players[new_index] then
								table.insert(last_in_war,new_players[new_index])
								new_index = new_index+1		
							elseif last_old_players[old_index] then
								table.insert(last_in_war,last_old_players[old_index])
								old_index = old_index+1
							else
								local robot = {name = mw_config.robot_name,guid = mw_config.robot_guid,fenqu=fenqu,force = 0}
								table.insert(last_in_war, robot)
							end
						end
					else
						local robot = {name = mw_config.robot_name,guid = mw_config.robot_guid,fenqu=fenqu,force = 0}
						table.insert(last_in_war, robot)				
					end
				end
			end
		end
		
		local round = 1
		--到这就开始处理成匹配信息了	
		local last_in_war_count = #last_in_war
		for i = 1, last_in_war_count, 1 do
			local info = last_in_war[i]
			--机器人不要乱来
			if info.guid ~= mw_config.robot_guid then
				local macth_info = _M.createMatchInfo(1,i,info.guid,info.name,info.fenqu,info.force,info.show_str)				
				--共享内存 要存两套分别以guid和位置为key
				local macth_info_str = json_encode(macth_info)
				dictMgr:setPosMacthInfo(round,info.fenqu,i,jie,macth_info_str)
				dictMgr:setGuidMacthInfo(round,info.guid,jie,macth_info_str)
				
				--数据库
				local t_name = _M.getDbTableName('million_war_macth')
				db[t_name]:insert(macth_info)
				logMgr:writeMatchLog(fenqu, jie, all_player_count, max_member, 0, last_in_war_count, i, info.guid, info.name, info.force, info.new_player)
			end
		end
		
		--保存最低战斗力 共享内存和数据库		
		local min_force = 0 --最低战斗力 用不着了 设置成0就好了	
		dictMgr:setMinForce(jie,fenqu,min_force)
		db.million_war_min_force:insert({jie=jie,fenqu=fenqu,min_force=min_force})
		--告诉全世界我匹配过了
		dictMgr:setMacth(jie)
	end
end



--获取进场信息
function _M.getEnterInfo(args)
	--检查下时间 
	local jie = _M.getCurJie()
	local round = args.round
	local guid = args.guid
	
	
	local is_right_time,cur,begin,_end = _M.isEnterTime(round)
	if not is_right_time then
		return {ret = 1,msg = 'is not enter_time '..cur..' '..begin..' '.._end}
	end
	
	--先查看现成的数据
	local enter_info = dictMgr:getEnterInfo(jie,guid,round)
	if enter_info then
		local enter_info_data = json_decode(enter_info)
		if enter_info_data then
			local match_info_data = json_decode(enter_info_data.p1)
			local guid2 = match_info_data and match_info_data.guid or ''
			logMgr:writeEnterLog(guid, jie, round, enter_info_data.war_id or 0, guid2, enter_info_data.battle_server)
		end
		
		return {ret = 0,msg = 'old ok',enter_info = enter_info}
	end

	local macth_info = dictMgr:getGuidMacthInfo(round,guid,jie)
	if not macth_info then
		return {ret = 2,msg = 'you not contestants'..round..guid..jie}
	end
	
	--战斗服数据取出来
	local battle_server = _M.chooseBattle_server()
	if(not battle_server)then
		return {ret = 3,msg = 'can find battle_server'}
	end
	
	
	--转出来取点数据
	local macth_info_t = json_decode(macth_info)
	local pos = macth_info_t.pos
	local fenqu = macth_info_t.fenqu
	
	local max_round = _M.getTotalRound(fenqu)  
	if round<1 or round> max_round then
		return {ret = 1,msg = 'round error'}
	end
	
	
	--把对手整出来
	local pos2 = pos+1
	local lock_name = tostring(pos2)..'_'..tostring(pos)
	if pos%2==0 then
		pos2 = pos-1
		lock_name = tostring(pos)..'_'..tostring(pos2)
	end
	
	local macth_info2 = dictMgr:getPosMacthInfo(round,fenqu,pos2,jie) 
	--没人 看下要不要补机器人
	if not macth_info2 then
		if _M.is_need_rebot(round,fenqu) then 
			local robot_macth_info = _M.getRobotMacthInfo(round,pos,fenqu)
			macth_info2 = json_encode(robot_macth_info)
		else
			macth_info2 = json_encode({})
		end
	end
	
		
	local macth_info2_t = json_decode(macth_info2)
	local guid2 = macth_info2_t.guid or ''
	local result_t ={}
	router_cls.opdata_with_lock('million_war_get_enter_info_'..lock_name,function()
		local enter_info = dictMgr:getEnterInfo(jie,guid,round)
		if enter_info then		
			result_t = {ret = 0,msg = 'old ok',enter_info = enter_info}
			return 
		end
		--把进场信息整出来 双方信息加加密串 
		enter_info = {}
		enter_info.p1 = macth_info
		enter_info.p2 = macth_info2
		enter_info.war_id = jie..'_'..macth_info_t.fenqu..'_'..round..'_'..pos 
		enter_info.sign = ngx.md5(macth_info_t.guid..guid2..battle_server..conf.auth_sign)
		enter_info.battle_server = battle_server
		--弄成json格式
		enter_info = json_encode(enter_info)
		
		--存起来 
		local db = dbAccess.getDBObj(conf.db_name )
		local table_name = _M.getDbTableName('million_war_enter')
		--处理一个玩家
		local values = {
			guid =  guid,
			round = round,
			enter_info = enter_info
		}
		db[table_name]:insert(values)
		dictMgr:setEnterInfo(jie,guid,round,enter_info)
		
		--处理另一个玩家
		--是活人才处理
		if macth_info2_t.guid and  macth_info2_t.guid ~= mw_config.robot_guid then
			local values = {
				guid =  macth_info2_t.guid,
				round = round,
				enter_info = enter_info
			}
			db[table_name]:insert(values)
			dictMgr:setEnterInfo(jie,macth_info2_t.guid,round,enter_info)
		end
		result_t = {ret = 0,msg = 'ok',enter_info = enter_info}
		return 
	end)
	
	if not result_t.enter_info then
		logMgr:writeEnterLog(guid, jie, round, 0, guid2, 'error')
		return {ret = 4, msg = 'enter_info error'}
	end
	
	logMgr:writeEnterLog(guid, jie, round, json_decode(result_t.enter_info).war_id or 0, guid2, battle_server)
	return result_t
end

--战绩处理
function _M.calFightResult(args)
	local guid = args.win_guid
	local round = args.round
	local show_data= args.show_data

	
	--时间检查一下
	local cur_sec = mw_config:getCurrSec() --今天的秒数 
	--开打之后
	local result_begin = mw_config.fight_begin+(round-1)*mw_config.round_time 
	--TODO误差要给多大呢呢呢呢呢
	local result_end = result_begin+300+10
	 if cur_sec < result_begin or  cur_sec > result_end then
		return {ret = 1,msg = 'time error'}
	end
	
	--检查下这个人是不是比赛选手
	local jie = _M.getCurJie()
	local macth_info = dictMgr:getGuidMacthInfo(round,guid,jie)
	if not macth_info then
		return {ret = 2,msg = 'you not contestants'}
	end
	local macth_info_t = json_decode(macth_info)	
	--防止重复
	local check_macth_info = dictMgr:getGuidMacthInfo(round+1,guid,jie)
	if check_macth_info then
		return {ret = 2,msg = 'had result'}
	end
	
	local max_round = _M.getTotalRound(macth_info_t.fenqu) 
	if round<1 or round> max_round then
		return {ret = 1,msg = 'round error'}
	end
	
	--生成新的匹配信息
	local new_round = round+1
	local pos  = macth_info_t.pos
	if(pos%2==1)then pos = pos+1 end
	local new_pos = pos/2
	
	macth_info_t.pos = new_pos
	macth_info_t.round = new_round
		
	--共享内存
	local new_macth_info = json_encode(macth_info_t)
	dictMgr:setPosMacthInfo(new_round,macth_info_t.fenqu,new_pos,jie,new_macth_info)
	dictMgr:setGuidMacthInfo(new_round,guid,jie,new_macth_info)	
	
	--数据库
	local db = dbAccess.getDBObj(conf.db_name)
	local t_name = _M.getDbTableName('million_war_macth')
	db[t_name]:insert(macth_info_t)

	--冠军另外存库	
	macth_info_t._id= nil
	if round == max_round then
		local values = {
			jie = jie,
			guid= guid,
			fenqu = macth_info_t.fenqu,
			--show_data = show_data
			show_data = macth_info_t.name,
			other_show_data = macth_info_t.show_str,
			force = macth_info_t.force			
		}
		db.million_war_champion:insert(values)
		--更新冠军串
		_M.updateChampionStr()
		--dictMgr:setChampionStr(macth_info_t.fenqu,jie,show_data)
	end
	
	--如果是八强需要处理八强名单
	if not _M.is_need_rebot(round,macth_info_t.fenqu) then
		_M.updateMacthStr(macth_info_t.fenqu)
	end
	return {ret = 0,msg = 'ok'} 
end



return _M


