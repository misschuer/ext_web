
mid=`ps -ef|grep nginx_extweb.conf|grep -v grep|awk {'print $2'}`
if !([ -z "$mid" ];) then
    echo "killed nginx_extweb.conf", $mid
    kill $mid 
fi
