#!/usr/bin/env bash

HOSTNAME="centos7-11"
NIC_CUR_NAMES="ens32 ens33 ens34"
NIC_NAMES="eth0 eth1 eth2"
IPADDRS="10.160.37.61 172.20.37.61"
NETMASKS="255.255.255.0 255.255.255.0"
GATEWAYS="10.160.37.1"

NIC_NAMES=${NIC_NAMES:-'eth0'}
DNS_SERVER=${DNS_SERVER:-'8.8.8.8'}
CFG_NET_PATH=/etc/sysconfig/network-scripts

function cfg_hostname() {
    if [ ! -z "$HOSTNAME" ]; then
        hostnamectl set-hostname "$HOSTNAME"
        echo "$HOSTNAME" > /etc/hostname
    fi
}

# disable the predictable naming rule
function cfg_dis_name_predict() {
    sed -i 's#GRUB_CMDLINE_LINUX="rd.lvm.lv=centos/root#GRUB_CMDLINE_LINUX="biosdevname=0 rd.lvm.lv=centos/root#g' /etc/default/grub
    grub2-mkconfig -o /boot/grub2/grub.cfg
}

# change nic naming style from enoxxxxx to ethxx

function cfg_network() {
    i=1
    IFS=" "
    set -- $NIC_NAMES
    INITIP=False
    for nic_cur_name in $NIC_CUR_NAMES; do
        nic_name=${!i}
        ipaddr=$(echo $IPADDRS | awk -v i=$i '{print $i}')
        netmask=$(echo $NETMASKS | awk -v i=$i '{print $i}')
        gateway=$(echo $GATEWAYS | awk -v i=$i '{print $i}')

        if [ "${INITIP^^}" == "FALSE" ] && [[ ! -z $gateway ]]; then
           ip addr add $ipaddr/$netmask dev $nic_cur_name
           ip link set $nic_cur_name up
           ip route add default via $gateway
        fi

        if [ -e "$CFG_NET_PATH/ifcfg-$nic_cur_name" ] && [ ! -e "$CFG_NET_PATH/ifcfg-$nic_name" ]; then
            mac_addr=$(ip addr show eth0 | grep link/ether | awk '{print $2}')
            echo "nic_cur_name=$nic_cur_name, nic_name=$nic_name, HWADDR=$mac_addr"
            cat >> "$CFG_NET_PATH/ifcfg-$nic_name" << EOF
TYPE=Ethernet
BOOTPROTO=none
DEFROUTE=yes
PEERDNS=yes
PEERROUTES=yes
IPV4_FAILURE_FATAL=no
NAME=$nic_name
DEVICE=$nic_name
ONBOOT=yes
HWADDR=$mac_addr
EOF
            for param in 'ipaddr' 'netmask' 'gateway'; do
                if [[ ! -z "${param// }" ]] && [[ ! -z $ipaddr ]]; then
                    echo "${param^^}=${!param}" >> $CFG_NET_PATH/ifcfg-$nic_name
                fi
            done
            ipaddr=''
            gateway=''
            rm -rf "$CFG_NET_PATH/ifcfg-$nic_cur_name"
        fi
        ((i+=1))
    done
}

# backup repos
function cfg_repos() {
    cp -r /etc/yum.repos.d/ ~/yum.repos.d.bak
    curl -o /etc/yum.repos.d/CentOS-Base.repo http://10.160.37.50/centos/CentOS-Base.repo
    curl -o /etc/yum.repos.d/epel.repo http://10.160.37.50/epel/epel.repo
    curl -o /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7 http://10.160.37.50/epel/RPM-GPG-KEY-EPEL-7
}

# dns
function cfg_dns() {
    cat > /etc/resolv.conf << EOF
nameserver $DNS_SERVER
EOF
}

# disable firewall
function cfg_dis_fw() {
    yum remove -y firewalld
    sed -i 's/enforcing/disabled/g' /etc/selinux/config
    echo 0 > /sys/fs/selinux/enforce
}

# enable the command ifconfig
function install_basic_pkgs() {
    yum update -y
    yum install -y net-tools tcpdump vim ntp wget
}

function main() {
    cfg_dis_name_predict
    cfg_network
    cfg_dns
    cfg_repos
    cfg_hostname
    install_basic_pkgs
    cfg_dis_fw
}

main