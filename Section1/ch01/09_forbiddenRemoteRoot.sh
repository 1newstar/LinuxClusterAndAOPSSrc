#!/bin/bash

####
# 【ch01】 禁止远程root 
####
sed -i 's@PermitRootLogin yes@PermitRootLogin no@' \
    /etc/ssh/sshd_config #禁止远程 root 登录

sed -i 's@PermitEmptyPasswords no@PermitEmptyPasswords no@' \
    /etc/ssh/sshd_config #禁止空密码登录

sed -i 's@UseDNS yes@UseDNS no@' \
    /etc/ssh/sshd_config #关闭 SSH  反向查询，加快 SSH 查询速度

