#!/bin/bash

####
# 替换为网易源 
####

#下载163网易仓库源
wget http://mirrors.163.com/.help/CentOS6-Base-163.repo 

# 替换【repo】文件
cd /etc/yum.repos.d
mv CentOS-Base.repo CentOS-Base.repo.bak #备份原仓库
mv CentOS6-Base-163.repo CentOS-Base.repo #替换为网易源

#更新源
yum clean all #清空缓存
yum makecache #重建缓存
yum update #升级Linux系统

####
# 增加epel源 
####
wget http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm #下载epel
rpm -ivh epel-release-6-8.noarch.rpm #安装 epel

####
# 配置yum源优先级 
####
#安装优先级插件
yum install yum-priorities

#启动优先级功能【/etc/yum/pluginconf.d/priorities.conf】
[main]
enabled=1



