local dbAccess = require 'util.db_access'
local json = require 'cjson'
local json_encode = json.encode
local json_decode = json.decode

local router_cls = require 'util.router_map'
local vaildArgs = router_cls.vaildArgs

local _HH = ngx.shared.happy_hundred_winner

local _M = {}

--活动的时间段
local HAPPY_BEGIN = 8
local HAPPY_END = 20

--数据库
function _M:initWinerInfo(w_date,hour)
	local winer_info = ''
	local difficulty = 0
	local cash = 0
	local db = dbAccess.getDBObj(conf.db_name )
	local tbl = db.world_happy_hundred:findOne({w_date= w_date,hour=hour})
	if tbl then
		winer_info = tbl.winner_info
		difficulty = tbl.difficulty
		cash = tbl.cash or 0
	end
	_M.setWinner(w_date,hour,winer_info)
	_M.setDifficulty(w_date,hour,difficulty)
	_M.setCash(w_date,hour, cash)
	
end


----------------------------------------------------------------------------------
---------------------------====共享内存==----------------------------------------

--胜者信息
function _M.getWinner(w_date,hour)
	--print(w_date,hour)
	local winner_info = _HH:get("winer#"..w_date.."#"..hour)
	if not winner_info then
		_M:initWinerInfo(w_date,hour)
		winner_info = _HH:get("winer#"..w_date.."#"..hour)
		assert(winner_info)
	end
	return winner_info
end

function _M.setWinner(w_date,hour,winer_info)
	_HH:set("winer#"..w_date.."#"..hour,winer_info,86400)
end

--难度系数
function _M.getDifficulty(w_date,hour)
	local difficulty =  _HH:get("Difficulty#"..w_date.."#"..hour)
	if not difficulty then
		_M:initWinerInfo(w_date,hour)
		difficulty =  _HH:get("Difficulty#"..w_date.."#"..hour)
		assert(difficulty)
	end
	return difficulty
end

function _M.setDifficulty(w_date,hour,value)
	_HH:set("Difficulty#"..w_date.."#"..hour,value,86400)
end

--现金信息
function _M.getCash(w_date,hour)
	local cash =  _HH:get("Cash#"..w_date.."#"..hour)
	if not cash then
		_M:initWinerInfo(w_date,hour)
		cash =  _HH:get("Cash#"..w_date.."#"..hour)
		assert(cash)
	end
	return cash
end

function _M.setCash(w_date, hour, value)
	_HH:set("Cash#"..w_date.."#"..hour, value)
end

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------



--获取最近三轮的冠军时间 没用了
function _M.getLatelyHour(hour)

	local today_date = os.date("%Y%m%d",os.time())
	local ystoday_date = os.date("%Y%m%d",os.time()-86400)

	
	--如果过了晚上八点 那么起始时间应该算在9点
	if hour > HAPPY_END then
		hour = HAPPY_END+ 1
	end
	
	local info = {}
	info.date1 = today_date
	info.hour1 = hour-1
	
	info.date2 = today_date
	info.hour2 = hour-2
	
	info.date3 = today_date
	info.hour3 = hour-3
	
	--有可能有昨天的
	if info.hour1 < 8 then
		info.date1 = ystoday_date
		info.hour1 = HAPPY_END
		info.date2 = ystoday_date
		info.hour2 = HAPPY_END-1
		info.date3 = ystoday_date
		info.hour3 = HAPPY_END-2
	elseif info.hour2 < 8 then
		info.date2 = ystoday_date
		info.hour2 = HAPPY_END
		info.date3 = ystoday_date
		info.hour3 = HAPPY_END-1		
	elseif info.hour3 < 8 then
		info.date3 = ystoday_date
		info.hour3 = HAPPY_END
	end

	return info
end

--更新冠军
function _M.update_winner()
	local cur_date = os.date("*t",os.time())
	local hour = cur_date.hour
	--活动时间

	
	--更新共享内存 更新数据库 更新难度系数
	local args = vaildArgs({'hour','winner_info','sign', 'item_id', 'item_cn', 'cash'},{'hour', 'item_id', 'item_cn', 'cash'}) 
	if not args then
		return
	end
	
	local sign = args.sign
	local hour = args.hour
	local winner_info = args.winner_info
	--检查下加密
	local  check_str = ngx.md5(hour..winner_info..conf.auth_sign)
	if sign ~= check_str then
		ngx.print(json_encode({ret= 2,msg = 'md5 error'}))
		return 
	end
	
	local w_date = os.date("%Y%m%d",os.time())
	
	local difficulty = _M.getDifficulty(w_date,hour) or 0
	local new_difficulty = difficulty+1
	local curr_cash = _M.getCash(w_date, hour)	
	if curr_cash < 500 then --单位是角，所以是50元
		curr_cash = curr_cash + args.cash
	else
		args.cash = 0
	end
	
	--共享内存的
	_M.setWinner(w_date,hour,winner_info)
	_M.setDifficulty(w_date,hour,new_difficulty)
	_M.setCash(w_date,hour,curr_cash)

	local values = {
		w_date=w_date,
		hour = hour,
		winner_info = winner_info,
		difficulty = new_difficulty,
		cash = curr_cash
	}
	--数据库的
	local db = dbAccess.getDBObj(conf.db_name )
	db.world_happy_hundred:update({w_date=w_date,hour = hour},{['$set']=values},true)
	ngx.print(json_encode({ret = 0, msg = 'ok', item_id = args.item_id, item_cn = args.item_cn, cash = args.cash}))
end

--查看当前冠军
function _M.query_winner()
	local cur_date = os.date("*t",os.time())
	local hour = cur_date.hour
	--活动时间
	--if hour < HAPPY_BEGIN or hour > HAPPY_END then
	--	local r = json_encode({ret= 1,msg = 'time error cur hour='..hour})
	--	ngx.print(r)
	--	return 
	--end	
	--更新共享内存 更新数据库
	local args = vaildArgs({'hour'},{'hour'}) 
	if not args then
		return 
	end
	local today_date = os.date("%Y%m%d",os.time())
	local hour = args.hour 
	--返回难度和当前胜者
	local winer_info = _M.getWinner(today_date,hour)
	local difficulty = _M.getDifficulty(today_date,hour)
	local result = json_encode({ret = 0,winer_info=winer_info,difficulty=difficulty})
	ngx.print(result)
end

--查看冠军
function _M.query_old_winner()
	local cur_date = os.date("*t",os.time())
	local hour = cur_date.hour

	--更新共享内存 更新数据库
	local args = vaildArgs({'begin_hour','end_hour'},{'begin_hour','end_hour'}) 
	if not args then
		return 
	end
	local begin_hour = args.begin_hour 
	local end_hour = args.end_hour 
	--local info = _M.getLatelyHour(hour)
	local today_date = os.date("%Y%m%d",os.time())
	local info = {}
	for i=begin_hour,end_hour,1 do
		local winer_info1 = _M.getWinner(today_date,i)
		table.insert(info,winer_info1)
	end

	local result = json_encode(info)
	ngx.print(result)
end





function _M:extend(hanlder)
	hanlder['/happy_hundred/update_winner'] 			= self.update_winner	
	hanlder['/happy_hundred/query_winner'] 				= self.query_winner
	hanlder['/happy_hundred/query_old_winner'] 				= self.query_old_winner
end

return _M