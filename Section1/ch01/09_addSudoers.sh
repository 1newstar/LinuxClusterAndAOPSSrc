#!/bin/bash

####
# 【ch01】 增加 sudo 权限用户 
####
# 【/etc/sudoers】 sudo 用户注册文件
root ALL=(ALL) ALL #允许 root 用户在任何位置允许任何命令
admin ALL=(ALL) NOPASSWD:ALL #添加具有 root 权限的用户 admin，并且切换时候不需要密码

