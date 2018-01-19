// 对Date的扩展，将 Date 转化为指定格式的String
// 月(M)、日(d)、小时(h)、分(m)、秒(s)、季度(q) 可以用 1-2 个占位符， 
// 年(y)可以用 1-4 个占位符，毫秒(S)只能用 1 个占位符(是 1-3 位的数字) 
// 例子： 
// (new Date()).Format("yyyy-MM-dd hh:mm:ss.S") ==> 2006-07-02 08:09:04.423 
// (new Date()).Format("yyyy-M-d h:m:s.S")      ==> 2006-7-2 8:9:4.18 
Date.prototype.Format = function (fmt) {
    var o = {
        "M+": this.getMonth() + 1, //月份 
        "d+": this.getDate(), //日 
        "h+": this.getHours(), //小时 
        "m+": this.getMinutes(), //分 
        "s+": this.getSeconds(), //秒 
        "q+": Math.floor((this.getMonth() + 3) / 3), //季度 
        "S": this.getMilliseconds() //毫秒 
    };
    if (/(y+)/.test(fmt)) fmt = fmt.replace(RegExp.$1, (this.getFullYear() + "").substr(4 - RegExp.$1.length));
    for (var k in o){
        if (new RegExp("(" + k + ")").test(fmt)) {
            fmt = fmt.replace(RegExp.$1, (RegExp.$1.length == 1) ? (o[k]) : (("00" + o[k]).substr(("" + o[k]).length)));
        }
    }
    
    return fmt;
}

//删除过期的八点半表
function deleteOldTable(){
    //当前时间戳*1000
    var cur_time = new Date().getTime();
    //获取30天前的时间戳
    var old_time = cur_time-30*86400*1000;

    var coll_name = "million_war_reg_"+new Date(old_time).Format("yyyyMMdd");
    var coll = db.getMongo().getDB("dtx_web").getCollection(coll_name);
    coll.drop();
	
	coll_name = "million_war_macth_"+new Date(old_time).Format("yyyyMMdd");
    coll = db.getMongo().getDB("dtx_web").getCollection(coll_name);
    coll.drop();
	
	coll_name = "million_war_enter_"+new Date(old_time).Format("yyyyMMdd");
    coll = db.getMongo().getDB("dtx_web").getCollection(coll_name);
    coll.drop();
}
deleteOldTable();

function createIndex(coll,key){
    var hasIndex = false;
    coll.getIndexes().forEach(function(it){
        if(it.name == key+"_1") hasIndex = true;
    });
    if (hasIndex) return;
    var o = {};
    o[key] = 1;
    coll.ensureIndex(o);
    print("create OK:",key);
}

function createUnionIndex(coll,key1,key2){
    var hasIndex = false;
    coll.getIndexes().forEach(function(it){
        if(it.name == key1+"_1_"+key2+"_1") hasIndex = true;
    });
    if (hasIndex) return;
    var o = {};
    o[key1] = 1;
	o[key2] = 1;
    coll.ensureIndex(o);
    print("create OK:",key1,key2);
}

coll_name = "world_happy_hundred";
coll = db.getMongo().getDB("dtx_web").getCollection(coll_name);
createIndex(coll,"w_date");
createIndex(coll,"hour");
createUnionIndex(coll,"w_date","hour");

coll_name = "battle_server_list";
coll = db.getMongo().getDB("dtx_web").getCollection(coll_name);
createIndex(coll,"guid");

coll_name = "million_war_reg_"+new Date().Format("yyyyMMdd");
coll = db.getMongo().getDB("dtx_web").getCollection(coll_name);
createIndex(coll,"guid");

coll_name = "million_war_reg_"+new Date(new Date().getTime() + 86400).Format("yyyyMMdd");
coll = db.getMongo().getDB("dtx_web").getCollection(coll_name);
createIndex(coll,"guid");

coll_name = "million_war_macth_"+new Date().Format("yyyyMMdd");
coll = db.getMongo().getDB("dtx_web").getCollection(coll_name);
createIndex(coll,"guid");

coll_name = "million_war_enter_"+new Date().Format("yyyyMMdd");
coll = db.getMongo().getDB("dtx_web").getCollection(coll_name);
createIndex(coll,"guid");



