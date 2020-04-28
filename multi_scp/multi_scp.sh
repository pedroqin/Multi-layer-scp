#!/bin/bash
###############################################
# Author      :   PedroQin
# Date        :   2020-04-26 22:43:32
# Description :   
# Version     :   1.0.0
###############################################


config_file="/etc/multi_scp_conf.xml"
parameters=""
# the file is not in $dir
not_dir=0
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

function isdigit()
{
    local str=
    for str in $@
    do
        str=$1  
        while [ -n "$str" ]; do
            echo ${str:0:1} | grep "[-.0-9]" > /dev/null 2>&1
            [ $? -ne 0 ] && return 27 
            str=`echo ${str:1}`
        done
        shift
    done
    return 0
}

# $1 - keyword
# $2 - path to xml file
function xml_parse()
{
    local keyword=""
    local line=""
    local col=`sed -n "/<$1\>/=" $2`
    local last=`sed -n "/<\/$1>/=" $2`

    [ -z "$col" ] && echo "err=255" && return 255

    line=`sed -n "$col p" $2`
    line=${line#*$1}

    if [ -z "$last" ]; then
        line=${line%/>*}
        echo ${line} | awk '{for (c=1;c<=NF;c++) print $c}'
        last=0
    else
        echo ${line%*>}
    fi

    let col+=1
    while (( $col < $last )); do
        line=`sed -n "$col p" $2`
        if [ -n "$line" ]; then
            keyword=${line##*/}
            line=${line%<*}
            echo "${keyword/>/=}\"${line#*>}\""
        fi
        let col+=1
    done
    return 0
}

# decode the cmd
function parse_cmd()
{
    # decode the config
    route=`xml_parse "to_server_${server_id}" $config_file`
    if [ -z "$route" ] ;then
        red_message "Can't find route info in $config_file !"
        usage
    fi
    # get script and dir
    eval `xml_parse common $config_file`
    if [ -z "$command" ] || [ -z "$dir" ] ;then
        red_message "common information(command and dir) in $config_file is not complete !"
    fi
    # this 0 using for transfer_file.sh to calculate how many floors now
    parameters="$command $method $dir $file_name 0"
    offset=0
    for i in `echo "$route"|tr '>' ' '`;do
        # skip the local server
        [ $offset -eq 0 ] && let offset+=1 && continue

        eval `xml_parse server.$i $config_file`
        if [ -z "$username" ] || [ -z "$IP" ] || [ -z "$passwd" ] ;then
            red_message "server.$i information in $config_file is not complete !"
            exit 254
        fi
        
        parameters="$parameters ID.$i $username $IP $passwd $hostname"
    done
    echo "$parameters"
    $parameters

}

function usage()
{
    cat <<USAGE
    $0 -t <server id in $config_file> -f <file name to send/receive> -m <send or receive> [ -c <config_file> ]
    $0 -h
USAGE
    exit 255
}

while getopts ":t:hc:f:m:" optname ;do
    case "$optname" in 
        "m")
        method="$OPTARG"
        method=`echo "$method"|tr 'A-Z' 'a-z'`
        if [ "$method" == "send" -o "$method" == "s" ] ;then
            method="send"
        elif [ "$method" == "receive" -o "$method" == "r" ];then
            method="receive"
        else
            red_message "transfer method must be send/receive !"
            usage
        fi
        ;;

        "t")
        server_id="$OPTARG"
        if ! isdigit "$server_id" ;then
            red_message "server_idi: $server_id is illegal !"
            usage
        fi
        ;;

        "c")
        config_file="$OPTARG"
        ;;

        "f")
        file_name="$OPTARG"
        ;;

        "h")
        usage
        ;;
    esac
done
if [ -z "$method" ] || [ -z "$server_id" ] ||[ -z "$file_name" ] ;then
    usage
fi
if [ ! -f "$config_file" ];then
    red_message "Can't locate config file $config_file"
    exit 253
fi
parse_cmd
