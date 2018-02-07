#!/bin/bash
####
# 定时校正时间 
####

#安装【ntp】时间校准模块
yum install ntp
crontab -e #启用当前用户的定时任务
#加入一行
*/5**** /usr/sbin/ntpdate ntp.api.bz #定时向ntp服务器群组校准时间

#查询ntp服务器群组
dig ntp.api.bz
