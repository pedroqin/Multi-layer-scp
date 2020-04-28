#!/usr/bin/expect
###############################################
# Author      :   PedroQin
# Date        :   2020-04-26 20:26:20
# Description :   
# Version     :   1.0.0
###############################################


set timeout         -1
set script_name     $argv0
# send or recive file
set send_receive    [lindex $argv 0]
set dir_name        [lindex $argv 1]
set file_name       [lindex $argv 2]
set server_offset   [lindex $argv 3]
set server_id       [lindex $argv 4]
set username        [lindex $argv 5]
set host            [lindex $argv 6]
set passwd          [lindex $argv 7]
set hostname        [lindex $argv 8]
set remain_argv     [lrange $argv 9 999]

set basename        [lindex [split "$file_name" "/"] end]
set server_offset   [expr $server_offset + 1]

if {$send_receive=="send"} {
    # send file

    if {$remain_argv!=""} {
        send_user "$server_offset. scp to $server_id $host ##**==++==**## ==> "
        if {$server_offset=="1"} {
            spawn scp -r $file_name $username@$host:$dir_name/
        } else {
            spawn scp -r $dir_name/$basename $username@$host:$dir_name/
        }
        expect {
            "yes/no"                { send "yes\n"; exp_continue}
            "password:"             { send "$passwd\n" ; exp_continue}
        }

        send_user "$server_offset. ssh to $server_id $host ##**==++==**## ==> "
        spawn ssh $username@$host
        expect {
            "yes/no"                { send "yes\n"; exp_continue}
            "$host's password:"     { send "$passwd\n" ; exp_continue}
            "$hostname*#"           { send "$script_name $send_receive $dir_name $file_name $server_offset $remain_argv && wait && sync && exit\n" ; exp_continue}
        }
        
    } else {

        send_user "$server_offset. scp to $server_id $host ##**==++==**## ==> "
        spawn scp -r $dir_name/$basename $username@$host:$dir_name/
        expect {
            "yes/no"                { send "yes\n"; exp_continue}
            "password:"             { send "$passwd\n" ; exp_continue}
        }

    }
} else {
    # recive file
    spawn mkdir -p $dir_name
    if {$remain_argv!=""} {
    
        send_user "$server_offset. ssh to $server_id $host ##**==++==**## ==> "
        spawn ssh $username@$host
        expect {
            "yes/no"                { send "yes\n"; exp_continue}
            "$host's password:"     { send "$passwd\n" ; exp_continue}
            "$hostname*#"           { send "$script_name $send_receive $dir_name $file_name $server_offset $remain_argv && wait && sync && exit\n" ; exp_continue}
        }
        
        send_user "$server_offset. scp from $server_id $host ##**==++==**## ==> "
        spawn scp -r $username@$host:$dir_name/$basename $dir_name/
        expect {
            "yes/no"                { send "yes\n"; exp_continue}
            "$host's password:"     { send "$passwd\n" ; exp_continue}
        }
    } else {
        send_user "$server_offset. scp from $server_id $host ##**==++==**## ==> "
        spawn scp -r $username@$host:$file_name $dir_name/
        expect {
            "yes/no"                { send "yes\n"; exp_continue}
            "password:"             { send "$passwd\n" ; exp_continue}
        }
    }
}
#interact
#expect eof
