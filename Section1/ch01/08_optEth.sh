#!/bin/bash


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
