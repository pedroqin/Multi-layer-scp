#!/bin/bash
###############################################
# Author      :   PedroQin
# Date        :   2020-05-10 22:43:30
# Description :   
# Version     :   1.0.0
###############################################

whereami=`cd $(dirname $0);pwd`


tar -zcf multi_scp.tgz multi_scp make_install.sh install.sh
MD5=`md5sum multi_scp.tgz|awk '{print $1}'`
Lines=`echo "$(wc -l install.sh | awk '{print $1}') + 1" |bc`
sed -i -e "/^MD5/c\MD5=\"${MD5}\"" install.sh
sed -i -e "/^Lines/c\Lines=\"${Lines}\"" install.sh
cat install.sh multi_scp.tgz > install_multi_scp.run
rm multi_scp.tgz
chmod +x install_multi_scp.run
