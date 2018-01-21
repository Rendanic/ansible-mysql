#!/bin/bash
#
# (c) 2018 by Thorsten Bruhns (thorsten.bruhns@opitz-consulting.com)
#
# CREATE USER 'mybinlogcopy'@'localhost'  IDENTIFIED BY 'secretpassword';
# GRANT SUPER, RELOAD ON *.*  TO 'mybinlogcopy'@'localhost';
#
# Plese define a connection with:
# mysql_config_editor set --login-path=mybinlogcopy --host=localhost --user=mybinlogcopy -p
#
# - FLUSH BINARY LOGS
#   make sure we copy the most current data
# - gather list of BINARY LOGS
# - cp BINARY LOGS except last one
# - PURGE BINARY LOGS except the last one
#
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA


dest_dir=$1
login_path=mybinlogcopy

PROGNAME=`basename $0`

function print_help() {
  echo ""
  print_usage
  echo ""
  echo "copy BINARY LOGS to destination directory and purge from MySQL"
  echo ""
  echo "-d/--dest_dir          Destination directory for compressed BINARY LOGS"
  
}

function setenv()
{
    SHORTOPTS="hd:"
    LONGOPTS="help,dest_dir:"

    ARGS=$(getopt -s bash --options $SHORTOPTS  --longoptions $LONGOPTS --name $PROGNAME -- "$@" ) 
    if [ ${?} -ne 0 ] ; then
        exit
    fi

    echo Logincheck
    mysql --login-path=${login_path} --skip-column-names -B -e quit
    if [ $? -ne 0 ] ; then
        echo "login not possible"
        exit 20
    fi

    eval set -- "$ARGS"
    while true;
    do
        case "$1" in
            -h|--help)
                print_help
                exit 0;;
            -d|-data_dir)
                dest_dir=${2}
                shift 2;;
            --)
                shift
                break;;
        esac
    done
    test -d ${dest_dir:-"lllllllllll"} > /dev/null 2>&1
    if [ $? -ne 0 ] ; then
        echo "Directory not existing"
        exit 10
    fi

    binlog_index=$(mysql --login-path=${login_path} --skip-column-names -B -e "SHOW  GLOBAL VARIABLES LIKE 'log_bin_index'" | cut -f2-)
    test -f $binlog_index || exit 10

    binlog_dir=$(dirname $(mysql --login-path=${login_path} --skip-column-names -B -e "SHOW  GLOBAL VARIABLES LIKE 'log_bin_basename'" | cut -f2-))

    if [ ! -d $binlog_dir ] ; then
        echo "$binlog_dir not existing!"
        exit 10
    fi

    export binlog_index binlog_dir
}

function mysqlcmd()
{
    echo "${1}" | mysql --login-path=${login_path}
}

check_log_bin_mode() {
    binlogmode=$(mysql --login-path=${login_path} --skip-column-names -B -e "SHOW  GLOBAL VARIABLES LIKE 'log_bin'" | cut -f2-)
    if [ ${binlogmode} = 'ON' ] ; then
        echo "Active log_bin mode found."
    else
        echo "Please enable log_bin. Current mode: "${binlogmode}
        exit 12
    fi

}

###########################################################
#A##########################################################

date +%c

setenv "$@"

check_log_bin_mode
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

date +%c
echo copy binary logs and delete old files before $binlog_last
cp ${binlog_list} ${dest_dir}
if [ $? -eq 0 ] ; then
    date +%c
    echo "PURGE BINARY LOGS"
    mysqlcmd "PURGE BINARY LOGS TO '$binlog_last'"

    date +%c
    echo "compress BINARY LOGS"
    cd ${dest_dir}
    gzip -1 ${binlog_list}
fi

date +%c
