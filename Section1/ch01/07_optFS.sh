#!/bin/bash

####
# 【ch01】 优化文件打开数 
####
# 【/etc/security/limit.conf】 系统安全限制配置
* soft nofile 65535 #所有用户软打开文件上限
* hard nofile 65535 #所有用户硬打开文件上限
# 【/etc/rc.local】 运行时本地配置文件
ulimit -SHn 65535 #使得生效

####
# 查看系统最大文件打开数 
####
#!/bin/bash
for pid in `ps aux | grep nginx | grep  -v grep | awk '{print $2}'` #遍历每个ngix进程
do
    cat /proc/${pid}/limits | grep 'Max open files'   #查看进程的最大打开限制
done 

