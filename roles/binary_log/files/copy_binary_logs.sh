#!/bin/bash
#
# CREATE USER 'binlogbck'@'%'  IDENTIFIED BY 'slavepass';
# GRANT SUPER, RELOAD ON *.*  TO 'binlogbck'@'%';
#
# - FLUSH BINARY LOGS
#   make sure we copy the most current data
# - gather list of BINARY LOGS
# - cp BINARY LOGS except last one
# - PURGE BINARY LOGS except the last one
#
#

dest_dir=$1

binlog_index=/var/lib/mysql/binary-log.index
binlog_dir=$(dirname $binlog_index)
login_path=mybinlogcopy

mysqlcmd()
{
    echo "${1}" | mysql --login-path=${login_path}
}



###########################################################
###########################################################
echo "Reading binary logs from "$binlog_dir
if [ ! -d $binlog_dir ] ; then
    echo "$binlog_dir not existing!"
    exit 10
fi

if [ ! -d $dest_dir ] ; then
    echo "$dest_dir not existing!"
    exit 11
fi

echo "FLUSH BINARY LOGS"
mysqlcmd "FLUSH BINARY LOGS"

binlog_list="$(head -n-1 $binlog_index)"
binlog_last=$(basename $(tail -1 $binlog_index))

cd $binlog_dir

echo copy binary logs and delete old files before $binlog_last
cp ${binlog_list} ${dest_dir}
if [ $? -eq 0 ] ; then
    mysqlcmd "PURGE BINARY LOGS TO '$binlog_last'"
fi

cd ${dest_dir}
gzip -3 ${binlog_list}

