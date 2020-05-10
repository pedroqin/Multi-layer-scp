#!/bin/bash
###############################################
# Author      :   PedroQin
# Date        :   2020-05-10 08:44:13
# Description :   Add list parameter, Can set the target server path now
# Version     :   1.0.1
# Date        :   2020-04-26 22:43:32
# Description :   
# Version     :   1.0.0
###############################################


config_file="/etc/multi_scp_conf.xml"
parameters=""
debug_mode=0
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
    eval `xml_parse "route" $config_file`
    route="to_server_${server_id}"
    route=${!route}
    if [ -z "${route}" ] ;then
        red_message "Can't find route info in $config_file !"
        usage
    fi
    # get script and dir
    eval `xml_parse common $config_file`
    if [ -z "$command" ] || [ -z "$dir" ] ;then
        red_message "common information(command and dir) in $config_file is not complete !"
    fi
    # this 0 using for transfer_file.sh to calculate how many floors now
    parameters="$command $method $dir $file_name ${target_path:-$dir} 0"
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
    if [ ${debug_mode:-0} -eq 0 ];then
        $parameters
    fi
}

function list_content()
{
    old_IFS="$IFS"
    IFS=$'\n'
    content=`xml_parse route $config_file`
    green_message "route:"
    for i in $content ;do
        green_message "    ${i%=*} : ${i##*=}"
    done

    content=`xml_parse common $config_file`
    green_message "common:"
    for i in $content ;do
        green_message "    ${i%=*} : ${i##*=}"
    done

    servers=`grep -Eo "server\.[0-9]+" $config_file | sort -u`
    green_message "server info:"
    for server in $servers ;do
        content=`xml_parse $server $config_file |tr '\n' ' '`
        green_message "    $server : $content"
    done
    IFS="$old_IFS"
    exit 0
}

function create_config()
{
    {
        cat <<CONFIG
<route>
    <to_server_2> 1 > 2 </to_server_2>
    <to_server_3> 1 > 2 > 3 </to_server_3>
    <to_server_4> 1 > 2 > 3 > 4 </to_server_4>
</route>
<common>
    <command>transfer_file</command>
    <dir>/tmp</dir>
</common>
<server_info>
    <server.1 item="local server">
        <username>root</username>
        <IP>192.168.0.1</IP>
        <passwd>123456</passwd>
        <hostname>localserver</hostname>
    </server.1>
    <server.2 item="server 1">
        <username>root</username>
        <IP>192.168.1.1</IP>
        <passwd>123456</passwd>
        <hostname>server1</hostname>
    </server.2>
    <server.3 item="server 2">
        <username>root</username>
        <IP>192.168.2.1</IP>
        <passwd>123456</passwd>
        <hostname>server2</hostname>
    </server.3>
    <server.4 item="server 3">
        <username>root</username>
        <IP>192.168.3.1</IP>
        <passwd>123456</passwd>
        <hostname>server3</hostname>
    </server.4>
</server_info>
CONFIG
    } > multi_scp_conf.xml
    exit 0
}

function usage()
{
    cat <<USAGE
Usage:
    send or recive files:
        -t id 
            server id in $config_file
        -f file
            file/folder name to send/receive
        -m send/recive
            what do you want? send(s) or recive(r) a file
        -c config_file
            specify configuration file
        -p path
            specify the path in target server where files saved. The default path is defined in $config_file ,element : "dir"
        -d
            use debug mode, command will not be executed, just display it
        -l 
            list all config info in $config_file , you can list specify configuration file 's config info by using : $0 -c \$config_file -l
        -C 
            create a configuration file sample
        -h
            show this message

example:
    list all config info in /etc/multi_scp_conf.xml 
        $0 -c /etc/multi_scp_conf.xml  -l

    send file /usr/bin/multi_scp to server5 's /usr/bin ( defined in $config_file ) :
        $0 -t 5 -f /usr/bin/multi_scp -m s -p /usr/bin 

    list all config info in $config_file
        $0 -c $config_file -l
USAGE
    exit 255
}

while [ -n $1 ] ;do
    case "$1" in 
        -m | --method)
        method="$2"
        shift && shift
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

        -t | --to)
        server_id="$2"
        shift && shift
        if ! isdigit "$server_id" ;then
            red_message "server_idi: $server_id is illegal !"
            usage
        fi
        ;;

        -c | --config)
        config_file="$2"
        if [ ! -s "$config_file" ] ;then
            red_message "Can't find the config file $config_file!"
            usage
        fi
        shift && shift
        ;;

        -l | --list)
        shift
        if [ ! -s "$config_file" ] ;then
            red_message "Can't find the config file $config_file!"
            usage
        fi
        list_content
        ;;

        -p | --path)
        target_path="$2"
        shift && shift
        ;;

        -f | --file)
        file_name="$2"
        shift && shift
        ;;

        -d | --debug)
        shift
        debug_mode=1
        ;;

        -C | --create)
        shift
        create_config
        ;;

        -h | --help)
        shift
        usage
        ;;

        *)
        break
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
