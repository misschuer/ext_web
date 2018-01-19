--比赛开始和结束时间
local fight_begin_hour 	= 20
local fight_begin_min 	= 30
--配置 local先去掉 方便改数值测试
million_war_config = {
	--各分区最大参赛人数
	max_member = 
	{
		[1] = 512, 
	}, 
	
	new_member =
	{
		[1] = 0, 
	},
	
	old_member =
	{
		[1] = 256, 
	},	
	--各分区每轮的奖励池
	bonus = 
	{
		[1] = {'71;1', '72;1', '71,72;1,1', '73;1',  '74;1', '75;1', '76;1', '76;4', '76;10'},
	},
	
	
	--报名离战斗区间差值
	reg_diff			= 600,
	
	--当天八点半数据配置
	fight_begin 		= fight_begin_hour * 3600 + fight_begin_min * 60, --算一分钟的等待时间 晚上八点半
	round_time 			= 300,--除了第一轮 每一轮历时5分钟
	readay_time 		= 60,--每轮的场外备战时间
	rank_page_count 	= 12,--历届榜一页12个冠军

	
	--机器人相关数据配置
	robot_guid = 'robot',
	robot_name = '',
	
	fenqu_change_divtime = 1480867200,	--分区变更划分时间2016,12,05,00:00:00
	fenqu_divide_oldtime = 1478131200,	--分区老的划分时间2016,11,03,08:00:00
	fenqu_divide_newtime = 1480867200,	--分区新的划分时间2016,12,05,00:00:00	
	
	--计算分区的函数接口 暂时不能分区
	getFenqu = function(self, open_time)
		return 1
		-- if os.time() < self.fenqu_change_divtime then
			-- if open_time < self.fenqu_divide_oldtime then
				-- return 1
			-- else
				-- return 2
			-- end
		-- else
			-- if open_time < self.fenqu_divide_newtime then
				-- return 1
			-- else
				-- return 2
			-- end	
		-- end
	end,

	fenqu_reg_divtime = 1480854600,		--报名分区变更划分时间2016,12,04,20:30:00
	getRegFenqu = function(self, open_time)
		return 1
		-- if os.time() < self.fenqu_reg_divtime then
			-- if open_time < self.fenqu_divide_oldtime then
				-- return 1
			-- else
				-- return 2
			-- end
		-- else
			-- if open_time < self.fenqu_divide_newtime then
				-- return 1
			-- else
				-- return 2
			-- end	
		-- end
	end,
	
	--分区时间
	getFenquTime = function(self)
		-- if os.time() < self.fenqu_change_divtime then
			return self.fenqu_divide_oldtime
		-- else
			-- return self.fenqu_divide_newtime
		-- end
	end,
	
	getCurrSec = function()
		local cur_date = os.date('*t', os.time())
		cur_date.hour = 0
		cur_date.sec = 0
		cur_date.min = 0		
		
		return os.time() - os.time(cur_date)
	end,
	
	getRegEndTime = function(self)		
		local cur_date = os.date('*t', os.time())
		cur_date.hour = 0
		cur_date.sec = 0
		cur_date.min = 0
		
		local end_time = os.time(cur_date) - self.reg_diff + self.fight_begin
		if os.time() > end_time then
			end_time = end_time + 86400
		end
		
		return end_time
	end,
	
	getCurrEnd = function(self)		
		return self.fight_begin - self.reg_diff
	end,	
}



return million_war_config