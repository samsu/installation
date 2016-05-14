#!/bin/bash

# example hostname="centos7-1"
hostname=""

# The element format in the array NIC_NAME_MAP:
# current_nic_name = new_nic_name [ip] [netmask] [gateway]
declare -A NIC_NAME_MAP=(
    [eno16777728]="eth0 10.160.37.61 255.255.255.0 10.160.37.1"
    [eno33554952]="eth1 192.168.100.61 255.255.255.0"
    [eno50332176]="eth2"
)

NIC_CONF_PATH="/etc/sysconfig/network-scripts"
NIC_CONF_FILE_PREFIX="$NIC_CONF_PATH/ifcfg"

[ -d "$NIC_CONF_PATH" ] || exit $?

if [ ! -z "$hostname" ]; then
    hostnamectl set-hostname "$hostname"
fi

# enable the command ifconfig
#yum update -y
#yum install -y net-tools tcpdump vim

set -o xtrace

# change nic naming style from enoxxxxx to ethxx
for NIC in ${!NIC_NAME_MAP[@]}; do
    read -r -a NIC_INFO <<< "${NIC_NAME_MAP[$NIC]}"
    NEW_NIC=${NIC_INFO[0]}

    if [ ! -z $NEW_NIC ]; then
        MAC=$(cat /sys/class/net/$NIC/address) || exit $?
        cat > $NIC_CONF_FILE_PREFIX-$NEW_NIC << EOF
TYPE=Ethernet
BOOTPROTO=none
DEFROUTE=yes
PEERDNS=yes
PEERROUTES=yes
IPV4_FAILURE_FATAL=no
NAME=$NEW_NIC
DEVICE=$NEW_NIC
HWADDR=$MAC
ONBOOT=yes
EOF
        if [ ! -z "${NIC_INFO[1]}" ]; then
            IPADDR="${NIC_INFO[1]}"
            cat >> $NIC_CONF_FILE_PREFIX-$NEW_NIC << EOF
IPADDR=$IPADDR
EOF
        fi

        if [ ! -z "${NIC_INFO[2]}" ]; then
            NETMASK="${NIC_INFO[2]}"
            cat >> $NIC_CONF_FILE_PREFIX-$NEW_NIC << EOF
NETMASK=$NETMASK
EOF
        fi

        if [ ! -z "${NIC_INFO[3]}" ]; then
            GATEWAY="${NIC_INFO[3]}"
            cat >> $NIC_CONF_FILE_PREFIX-$NEW_NIC << EOF
GATEWAY=$GATEWAY
EOF
        fi

        if [ -e "$NIC_CONF_FILE_PREFIX-$NIC" ]; then
            rm -rf $NIC_CONF_FILE_PREFIX-$NIC
        fi
    fi
done

# disable the predictable naming rule
sed -i 's#GRUB_CMDLINE_LINUX="rd.lvm.lv=centos/root#GRUB_CMDLINE_LINUX="net.ifnames=0 rd.lvm.lv=centos/root#g' /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg
