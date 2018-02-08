#!/bin/bash

####
# 【ch01】 优化 TCP 套接字 
####
# 【Squid】 服务器优化方案
# 【/etc/sysctl.conf】
net.ipv4.tcp_fin_timeout=30 # FIN 信号超时时间
net.ipv4.tcp_keepalive_time =1200 # 连接超时时间
net.ipv4.tcp_syncookies =1 # 开启 SYN cookie 溢出cookie功能
net.ipv4.tcp_max_syn_backlog =8192 # 增大 SYN 等待队列
net.ipv4.tcp_tw_reuse =1 # 开启 TIME_WAIT 状态的套接字复用
net.ipv4.tcp_tw_recycle =1 # 开启 TIME_WAIT 状态的套接字快速回收
net.ipv4.tcp_max_tw_buckets =5000 #最大 TIME_WAIT 状态的套接字数量
net.ipv4.ip_local_port_range =10000 65000 #增大端口变动范围

#内核立马生效
/sbin/sysctl -p 

# 【Apache/Nginx】 web服务器
net.ipv4.tcp_syncookies =1 # 开启 SYN cookie 溢出cookie功能
net.ipv4.tcp_tw_reuse =1 # 开启 TIME_WAIT 状态的套接字复用
net.ipv4.tcp_tw_recycle =1 # 开启 TIME_WAIT 状态的套接字快速回收
net.ipv4.ip_local_port_range =10000 65000 #增大端口变动范围

# Postfix 邮件服务器
net.ipv4.tcp_fin_timeout=30 # FIN 信号超时时间
net.ipv4.tcp_keepalive_time =1200 # 连接超时时间
net.ipv4.tcp_tw_reuse =1 # 开启 TIME_WAIT 状态的套接字复用
net.ipv4.tcp_tw_recycle =1 # 开启 TIME_WAIT 状态的套接字快速回收
net.ipv4.ip_local_port_range =10000 65000 #增大端口变动范围
kernel.shmmax=134217728 #单个共享内存大小
