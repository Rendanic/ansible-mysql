#!/bin/bash
#
# (c) by Thorsten Bruhns (thorsten.bruhns@opitz-consulting.com)
#
# CREATE USER 'binlogcopy'@'localhost'  IDENTIFIED BY 'secretpassword';
# GRANT SUPER, RELOAD ON *.*  TO 'binlogcopy'@'localhost';
#
# Plese define a connection with:
# mysql_config_editor set --login-path=mybinlogcopy --host=localhost --user=mybinlogcopy -p
#
# - FLUSH BINARY LOGS
#   make sure we copy the most current data
# - gather list of BINARY LOGS
# - cp BINARY LOGS except last one
# - PURGE BINARY LOGS except the last one

dest_dir=$1
login_path=mybinlogcopy

setenv()
{
    binlog_index=/$(mysql --login-path=${login_path} --skip-column-names -B -e "SHOW  GLOBAL VARIABLES LIKE 'log_bin_index'" | cut -d"/" -f2-)
    test -f $binlog_index || exit 10

    binlog_dir=/$(dirname $(mysql --login-path=${login_path} --skip-column-names -B -e "SHOW  GLOBAL VARIABLES LIKE 'log_bin_basename'" | cut -d"/" -f2-))

    if [ ! -d $binlog_dir ] ; then
        echo "$binlog_dir not existing!"
        exit 10
    fi

    export binlog_index binlog_dir
}

mysqlcmd()
{
    echo "${1}" | mysql --login-path=${login_path}
}



###########################################################
###########################################################
setenv
echo "Reading binary logs from "$binlog_dir

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
gzip -1 ${binlog_list}

