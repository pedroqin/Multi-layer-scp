#!/bin/bash
###############################################
# Author      :   PedroQin
# Date        :   2020-04-28 15:40:50
# Description :   
# Version     :   1.0.0
###############################################

Lines=66
MD5="1a9ac23cfcd9ba741a5d4a43329e36e8"
# show message in green
function green_message()
{
    tput bold
    echo -ne "\033[32m$@\033[0m"
    tput sgr0
    echo
}

# show message in red
function red_message()
{
    tput bold
    echo -ne "\033[31m$@\033[0m"
    tput sgr0
    echo
}

# print description and then run it
function print_run()
{
    if [ $# -eq 1 ];then
        green_message "$1"
        eval "$1"
    elif [ $# -eq 2 ];then
        green_message "$1"
        eval "$2"
    else
        return 1
    fi
}

function install_fail()
{
    red_message "install fail"
    exit 255
}

cat $0 |tail -n +$Lines > /tmp/multi_scp.tgz
md5_cur=`md5sum /tmp/multi_scp.tgz | awk '{print $1}'`
if [ "$md5_cur" != "$MD5" ];then
    red_message "Wrong md5sum ..."
    exit 255
else
    green_message "md5sum check pass"
fi
print_run "tar -xf /tmp/multi_scp.tgz -C /tmp"
print_run "cp /tmp/multi_scp/transfer_file.sh /usr/bin/transfer_file"   || install_fail
print_run "(cd /usr/bin; chmod +x transfer_file)"
print_run "cp /tmp/multi_scp/multi_scp.sh /usr/bin/multi_scp"           || install_fail
print_run "(cd /usr/bin; chmod +x multi_scp)"
print_run "cp /tmp/multi_scp/multi_scp_conf.xml /etc"                   || install_fail
print_run "rm -rf /tmp/multi_scp*"
echo Done
exit
