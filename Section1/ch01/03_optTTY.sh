#!/bin/bash

####
# 优化终端 
####
#仅保留2个默认开启终端【/etc/init/start-ttys.conf】
start on stopped rc RUNLEVEL=[2345]

#设置环境变量
env ACTIVE_CONSOLES=/dev/tty[1-2] #2个默认终端
env X_TTY=/dev/tty1 

#执行创建终端的脚本
task
script
    . /etc/sysconfig/init #执行init脚本
    for ttyNO in $(echo $ACTIVE_CONSOLES) ; do
        [ "$RUNLEVEL" = "5" -a "$ttyNO" = "$X_TTY" ] && continue
        initctl start tty TTY=$ttyNO  #启用终端
    done
end script

#查看运行中的终端
ps aux | grep tty | grpe -v grep