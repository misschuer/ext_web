#!/bin/bash
cd `dirname $0`
path=`pwd`
name=`echo $path |awk -F '/' '{print $3}'`
if [ $name == "conf_svr" ]
then 
    (crontab -l|grep -v ${path};echo "4 * * * * ${path}/create_index_timer.sh >> /var/log/${name}_timer.log")|crontab
elif [ $name == "ext_web" ]
then
    (crontab -l|grep -v ${path};echo "14 * * * * ${path}/create_index_timer.sh >> /var/log/${name}_timer.log")|crontab
else
    (crontab -l|grep -v ${path};echo "24 * * * * ${path}/create_index_timer.sh >> /var/log/${name}_timer.log")|crontab
fi
    
#执行中间件心跳定时器
if [ `ls |grep gm_update|wc -l` -eq 1 ]
then 
    kill `ps aux | grep gm_update.sh | grep -v grep | awk '{print $2}'`
	nohup ${path}/gm_update.sh >> /dev/null 2>&1 &
fi