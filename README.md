### 前言
写这个工具主要是为了解决一个困惑了我四年的难题，即：**多层ssh跳转时的文件传输**。  
由于工作中，经常需要ssh连接到产线服务器进行代码调试。中间经过3层，4层甚至更多层跳转。这就导致在实际操作时常常面临两个问题：
1. 需要多个窗口进行调试时，多次重复的多层跳转，此问题已解决：tmux/screen
2. 本地与远端服务器文件传输时，多层文件传输需要逐层scp。最近由于专案需求，频繁的文件传输实在让人不堪重负。故尝试完成此自动化脚本

### Github
https://github.com/pedroqin/Multi-layer-scp


### 实现
#### 实现基础
此脚本工具的实现主要依靠`expect`:
```
Expect is a program that "talks" to other interactive programs
according to a script. Following the script, Expect knows what can be
expected from a program and what the correct response should be. An
interpreted language provides branching and high-level control
structures to direct the dialogue. In addition, the user can take
control and interact directly when desired, afterward returning control
to the script.
```
而expect采用TCL(即 Tool Command Language 工具脚本语言)开发，故用TCL中语法实现部分逻辑。


#### 实现逻辑
以 **从多层远端服务器传输文件到本地**  为例，在实现的逻辑上，为了实现多层服务器传输功能的统一部署，在expect脚本代码实现上采用了类似**递归调用**的方式：在本地运行 transfer_file.sh 脚本，并依次带入各层跳转服务器的`username`/`IP`/`passwd`等信息作为参数，而后在每层的跳转服务器自动调用脚本 transfer_file.sh 完成文件传输 。

transfer_file.sh :
```
#!/usr/bin/expect
###############################################
# Author      :   PedroQin
# Date        :   2020-04-26 20:26:20
# Description :
# Version     :   1.0.0
###############################################


#if {$argc <3} {
#    puts "Usage: cmd <username> <host> <passwd> <file>"
#    exit 1
#}
set timeout     -1
set my_name     $argv0
set file_name   [lindex $argv 0]
set username    [lindex $argv 1]
set host        [lindex $argv 2]
set passwd      [lindex $argv 3]
set remain_argv [lrange $argv 4 999]

set basename    [lindex [split "$file_name" "/"] end]

if {$remain_argv!=""} {

    spawn ssh $username@$host
    expect {
        "yes/no"                { send "yes\n"; exp_continue}
        "$host's password:"     { send "$passwd\n" ; exp_continue}
        "*#"                    { send "$my_name $file_name $remain_argv && wait && sync && exit\n" ; exp_continue}
    }

    spawn scp -r $username@$host:/tmp/$basename /tmp/
    expect {
        "yes/no"                { send "yes\n"; exp_continue}
        "$host's password:"     { send "$passwd\n" ; exp_continue}
    }
} else {
    spawn scp $username@$host:$file_name /tmp/
    expect {
        "*#"                    { send "sync && exit\n"}
    }
}
```
以下以 4层远端服务器传输文件到本地 作为例子讲解：
- 实现目标，本地跳转到 server1(192.168.1.1) -> server2(192.168.2.1) -> server3(192.168.3.1) -> 目标机server4(192.168.4.1)
- 复制 transfer_file.sh 到 本地/server1/server2/server3 的 /root 目录
- 本地执行 `/root/transfer_file.sh /root/startservices.sh root 192.168.1.1 123456 root 192.168.2.1 123456 root 192.168.3.1 123456 root 192.168.4.1 123456`，其中`/root/startservices.sh`为传输的文件参数，其后为每层跳转机用户名，IP和密码
- 脚本执行过程
    -   当本地 transfer_file.sh 脚本登入 server1(192.168.1.1) 后，检测到“\*#”关键字，执行server1上 transfer_file.sh，`if`判断带入参数中第5到999个参数不为空，即说明还有server要登陆，则继续登入 server2(192.168.2.1) ，检测到“\*#”关键字，执行server2上 transfer_file.sh ... 
    -   当执行到 server3(192.168.3.1) 的 transfer_file.sh 时，`if`判断带入参数中第5到999个参数为空，说明已经完成所有server的登陆，则直接从 目标机server4(192.168.4.1) scp 文件到server3 `/tmp`下，
    -   然后server3 上 transfer_file.sh 执行完退出到 server2，server2 至此执行完`ssh`命令的`expect`，继续执行`ssh`之后的`scp`，复制server3 的文件到server2 `/tmp`下，至此server2的 transfer_file.sh执行完成，退出到server1...
    -   最后本机从server1 `scp`文件到本地`/tmp`,整个scp过程完成

由以上逻辑可以看出，功能实现主要有以下要素:
- 各层执行命令为固定的脚本名称，此例子中为`/root/transfer_file.sh`，后续实现一键部署时，该脚本名称会被替换成命令`transfer_file`
- 文件参数。文件参数为文件绝对路径。如以上例子中文件参数为`/root/startservices.sh`,当到达server3，即最后一层跳转服务器后，使用该文件路径获取文件，剩下每层跳转服务器复制文件时将文件copy到 `/tmp` 下,直至copy到本地`/tmp`

以下为测试脚本功能时log记录，其中登录到server2 和server3 执行`/root/transfer_file.sh`时有多余打印，此为上层跳转服务器`expect`匹配，可加判断进行精确匹配，以避免此问题

```
[root@diag ~]# /root/transfer_file.sh /root/startservices.sh root 192.168.1.1 123456 root 192.168.2.1 123456 root 192.168.3.1 123456 root 192.168.4.1 123456
spawn ssh root@192.168.1.1
root@192.168.1.1's password:
Last login: Tue Apr 28 12:36:54 2020 from 10.67.18.82
[root@server1 ~]# /root/transfer_file.sh /root/startservices.sh root 192.168.2.1 123456 root 192.168.3.1 123456 root 192.168.4.1 123456 && wait && sync && exit
spawn ssh root@192.168.2.1
root@192.168.2.1's password:
Last login: Tue Apr 28 14:15:55 2020 from 172.22.0.66
SIOCADDRT: No such process
[root@server2 ~]# /root/transfer_file.sh /root/startservices.sh root 192.168.2.1 123456 root 192.168.3.1 123456 root 192.168.4.1 123456 && wait && sync && exit
/root/transfer_file.sh /root/startservices.sh root 192.168.3.1 123456 root 192.168.4.1 123456 && wait && sync && exit
spawn ssh root@192.168.3.1
root@192.168.3.1's password:
Last login: Tue Apr 28 13:35:13 2020 from 172.21.35.2
[root@server3 ~]# /root/transfer_file.sh /root/startservices.sh root 192.168.4.1/root/transfer_file.sh /root/startservices.sh root 192.168.2.1 123456 root 192.168.3.1 423456 root 192.168.4.1 123 123456 && wait && sync && /root/transfer_file.sh /root/startservices.sh root 192.168.3.1 123456 root 192.168.4.1 123456 && wait && sync && exit
exit
56 && wait && sync && exit
spawn scp root@192.168.4.1:/root/startservices.sh /tmp/
startservices.sh                                                                                                                            100%  334     1.0MB/s   00:00
logout
Connection to 192.168.3.1 closed.
spawn scp -r root@192.168.3.1:/tmp/startservices.sh /tmp/
root@192.168.3.1's password:
startservices.sh                                                                                                                            100%  334     0.3KB/s   00:00
logout
Connection to 192.168.2.1 closed.
spawn scp -r root@192.168.2.1:/tmp/startservices.sh /tmp/
root@192.168.2.1's password:
startservices.sh                                                                                                                            100%  334     0.3KB/s   00:00
logout
Connection to 192.168.1.1 closed.
spawn scp -r root@192.168.1.1:/tmp/startservices.sh /tmp/
root@192.168.1.1's password:
startservices.sh                                                                                                                            100%  334     0.3KB/s   00:00

```

#### 优化进阶
1. 精确匹配：保证没有多余无效匹配，回显明确友好
2. 完善功能：传输文件到远端服务器，从远端服务器获取文件到本地
3. 参数生成：由于脚本需要多个服务器参数，故需要做一个参数生成脚本 multi_scp.sh ，只需填入目标机id，传输文件，以及传输方式（发送/接收），即可自动生成参数并执行。配置文件 multi_scp_conf.xml 格式如下
```
<route>                                 <!-- the route to server -->
    <to_server_2 1 > 2 />               <!-- local(1) to server2 -->
    <to_server_3 1 > 2 > 3 />
    <to_server_4 1 > 2 > 3 > 4 />
    <to_server_5 1 > 2 > 3 > 4 > 5 />
    <to_server_6 1 > 2 > 3 > 4 > 6 />   <!-- local(1) to server6 -->
</route>
<common>
    <command>transfer_file</command>    <!-- the expect script name -->
    <dir>/tmp</dir>                     <!-- the path which transfer server save files in -->
</common>
<server_info>
    <server.1 item="local server">      <!-- server name -->
        <username>root</username>       <!-- username -->
        <IP>192.168.0.1</IP>            <!-- ip address -->
        <passwd>123456</passwd>         <!-- passwd -->
        <hostname>local</hostname>      <!-- hostname -->
    </server.1>
    ...
        <server.6 item="server 5">
        <username>root</username>
        <IP>192.168.5.1</IP>
        <passwd>123456</passwd>
        <hostname>server5</hostname>
    </server.6>
</server_info>
```
### 实现一键部署
简单写个安装脚本 `install.sh`,主要内容如下，主要完成包的解压和可执行文件的配置。
```
print_run "tar -xf /tmp/multi_scp.tgz -C /tmp"
print_run "cp /tmp/multi_scp/transfer_file.sh /usr/bin/transfer_file"   || install_fail
print_run "(cd /usr/bin; chmod +x transfer_file)"
print_run "cp /tmp/multi_scp/multi_scp.sh /usr/bin/multi_scp"           || install_fail
print_run "(cd /usr/bin; chmod +x multi_scp)"
print_run "cp /tmp/multi_scp/multi_scp_conf.xml /etc"                   || install_fail
print_run "rm -rf /tmp/multi_scp*"
```
打包成一个文件`install_multi_scp.run`：
```
[root@diag ~]# ls multi_scp
multi_scp.sh       multi_scp_conf.xml transfer_file.sh
[root@diag ~]# tar -zcf multi_scp.tgz multi_scp/
[root@diag ~]# cat install.sh multi_scp.tgz > install_multi_scp.run
[root@diag ~]# ls
install.sh  install_multi_scp.run  multi_scp  multi_scp.tgz
```
### 部署
需要在本地及中转机执行以下操作
1. 安装expect和tcl：由于本功能基于expect实现，tcl是expect的依赖，故需要安装expect和tcl
2. 执行安装文件`install_multi_scp.run`
3. 更新配置文件`/etc/multi_scp_conf.xml`

### 实现效果
1. 将本地`/root/StorageStressTest.pyc`文件传输到远端（故方式为`send`）服务器（id为5）上，命令：`multi_scp -t 5 -m s -f /root/StorageStressTest.pyc`。   
命令运行完毕后，文件从本地`/root`传输到远端服务器`/tmp`下，中间跳转服务器将文件保存在`/tmp`
```
[root@diag ~]# multi_scp -t 5 -m send -f /root/StorageStressTest.pyc
transfer_file send /tmp /root/StorageStressTest.pyc 0 ID.2 root 192.168.1.1 123456 server1 ID.3 root 192.168.2.1 123456 server2 ID.4 root 192.168.3.1 123456 server3 ID.5 root 192.168.4.1 123456 server3
1. scp to ID.2 192.168.1.1 ##**==++==**## ==> spawn scp -r /root/StorageStressTest.pyc root@192.168.1.1:/tmp/
root@192.168.1.1's password:
StorageStressTest.pyc                                                                                                                       100%   39KB  38.7KB/s   00:00
1. ssh to ID.2 192.168.1.1 ##**==++==**## ==> spawn ssh root@192.168.1.1
root@192.168.1.1's password:
Last login: Tue Apr 28 15:17:17 2020 from 10.67.18.82
[root@server1 ~]# /usr/bin/transfer_file send /tmp /root/StorageStressTest.pyc 1 ID.3 root 192.168.2.1 123456 server2 ID.4 root 192.168.3.1 123456 server3 ID.5 root 192.168.4.1 123456 server3 && wait && sync && exit
2. scp to ID.3 192.168.2.1 ##**==++==**## ==> spawn scp -r /tmp/StorageStressTest.pyc root@192.168.2.1:/tmp/
root@192.168.2.1's password:
StorageStressTest.pyc                                                                                                                       100%   39KB  38.7KB/s   00:00
2. ssh to ID.3 192.168.2.1 ##**==++==**## ==> spawn ssh root@192.168.2.1
root@192.168.2.1's password:
Last login: Tue Apr 28 16:55:15 2020 from 172.22.0.148
SIOCADDRT: No such process
[root@server2 ~]# /usr/bin/transfer_file send /tmp /root/StorageStressTest.pyc 2 ID.4 root 192.168.3.1 123456 server3 ID.5 root 192.168.4.1 123456 server3 && wait && sync && exit
3. scp to ID.4 192.168.3.1 ##**==++==**## ==> spawn scp -r /tmp/StorageStressTest.pyc root@192.168.3.1:/tmp/
root@192.168.3.1's password:
StorageStressTest.pyc                                                                                                                       100%   39KB  38.7KB/s   00:00
3. ssh to ID.4 192.168.3.1 ##**==++==**## ==> spawn ssh root@192.168.3.1
root@192.168.3.1's password:
Last login: Tue Apr 28 16:14:25 2020 from 172.21.35.2
[root@server3 ~]# /usr/bin/transfer_file send /tmp /root/StorageStressTest.pyc 3 ID.5 root 192.168.4.1 123456 server3 && wait && sync && exit
4. scp to ID.5 192.168.4.1 ##**==++==**## ==> spawn scp -r /tmp/StorageStressTest.pyc root@192.168.4.1:/tmp/
StorageStressTest.pyc                                                                                                                       100%   39KB  23.3MB/s   00:00
logout
Connection to 192.168.3.1 closed.
logout
Connection to 192.168.2.1 closed.
logout
Connection to 192.168.1.1 closed.

```
2. 将远端服务器（id为5）上`/root/StorageStressTest.pyc`传输到本地（故方式为`receive`）,命令：`multi_scp -t 5 -m receive -f /root/StorageStressTest.pyc`。  
命令运行完毕后，文件从远端服务器`/root`传输到本地`/tmp`下，中间跳转服务器将文件保存在`/tmp`

### 延伸
1. 后续可增加传输完成后，跳转服务器的文件清理动作
2. 实现一键部署步骤略显简陋，可用开源shell工具makeself（https://github.com/megastep/makeself）完善

### 参考链接
linux expect spawn的用法（https://www.cnblogs.com/jason2013/articles/4356352.html）  
Linux 中 TCL 和 Expect语法（https://blog.csdn.net/u010416101/article/details/58328244）
