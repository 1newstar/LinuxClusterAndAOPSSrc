#!/bin/bash

####
# 优化系统的服务 
####
#安装ntsysv
yum install -y ntsysv
# 设置需要启动的服务
ntsysv network #启动网络服务
ntsysv sshd #启用ssh远程登录服务
ntsysv crond #启动自动任务服务
ntsysv rsyslog #启动日志服务
