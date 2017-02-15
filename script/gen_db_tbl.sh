#!/bin/bash

ip=127.0.0.1
port=3306
dbname=skynet
user=godman
pwd=thegodofman

#公会商品基本信息
sql=$(printf "
CREATE TABLE user_info( \
	uid int(10) unsigned NOT NULL AUTO_INCREMENT, \
	user_name varchar(64) NOT NULL DEFAULT '' COMMENT '账号', \
	passwd varchar(64)  NOT NULL DEFAULT '' COMMENT '密码', \
	moeny int(10) unsigned  NOT NULL DEFAULT 0 COMMENT '钱', \
	PRIMARY KEY (uid) \
	) ENGINE=InnoDB DEFAULT CHARSET=utf8;" $i )

#echo $sql;
#mysql -h 127.0.0.1 -P 3306 -Dappsvr -ugodman -pthegodofman -A -e "$sql"
mysql -h $ip -P $port -D$dbname -u$user -p$pwd -A -e "$sql"
