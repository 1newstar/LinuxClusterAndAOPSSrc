#!/bin/bash

####
# 草稿 
####


####
# 优化 IP6 
####
# 查看 IP6 是否被启动
lsmod | grep ipv6

# 停止 IP6
echo "install ipv6 /bin/true" 
    > /etc/modprobe.d/disable-ipv6.conf #使用 /bin/true 代替 ipv6 模块的加载
echo "IPV6INIT=no" 
    >> /etc/sysconfig/network-scripts/ifcfg-eth0 #禁用基于 IP6 的网络

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


####
# 【ch01】 开启启动网卡 
####
# 【/etc/sysconfig/network-scripts/ifcfg-eth0】 网卡配置文件
DEVICE=eth0 #网卡名
TYPE=Ethernet  #以太网类型
ONBOOT=yes #【系统启动时候就启动网卡】
BOOTPROTO=static #静态ip
IPADDR=203.93.236.146 #ip地址
HWADDR=00:14:22:1b:71:20 #设备地址
NETMASK=255.255.255.192 #子网掩码
GATEWAY=203.93.236.129 #网关
PEERDNS=yes #允许 DHCP 的 DNS 覆盖本地的 DNS
IPV6INIT=no #禁用 IP6
IPV6_AUTOCONF=yes #自动配置 IP6
USERCTL=no #不允许普通用户修改网卡



####
# 【ch01】 禁止远程root 
####
sed -i 's@PermitRootLogin yes@PermitRootLogin no@' \
    /etc/ssh/sshd_config #禁止远程 root 登录

sed -i 's@PermitEmptyPasswords no@PermitEmptyPasswords no@' \
    /etc/ssh/sshd_config #禁止空密码登录

sed -i 's@UseDNS yes@UseDNS no@' \
    /etc/ssh/sshd_config #关闭 SSH  反向查询，加快 SSH 查询速度

####
# 【ch01】 增加 sudo 权限用户 
####
# 【/etc/sudoers】 sudo 用户注册文件
root ALL=(ALL) ALL #允许 root 用户在任何位置允许任何命令
admin ALL=(ALL) NOPASSWD:ALL #添加具有 root 权限的用户 admin，并且切换时候不需要密码

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
