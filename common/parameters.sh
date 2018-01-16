#!/usr/bin/env bash

[[ -n $TOP_DIR ]] || TOP_DIR="$(cd "$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"/.. && pwd)"
source "$TOP_DIR/local.conf"

export DEBUG=${DEBUG:-False}
export INTERFACE_MGMT=${INTERFACE_MGMT:-eth0}
export INTERFACE_INT=${INTERFACE_INT:-eth1}
export INTERFACE_EXT=${INTERFACE_EXT:-eth2}

export VLAN_RANGES=${VLAN_RANGES:-physnet1:1009:1099}

export INTERFACE_INT_IP=$(ip address show $INTERFACE_INT | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')
export MGMT_IP=$(ip address show $INTERFACE_MGMT | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')

export CTRL_MGMT_IP=${CTRL_MGMT_IP:-$MGMT_IP}

export NTPSRV=${NTPSRV:-$CTRL_MGMT_IP}

export DB_IP=${DB_IP:-$CTRL_MGMT_IP}
export MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-root}

export DB_HA=${DB_HA:-False}
# Galera cluster configuration

export DB_HA_CONF=${DB_HA_CONF:-"/etc/my.cnf.d/mariadb-server.cnf"}
export DB_WSREP_PROVIDER=${DB_WSREP_PROVIDER:-"/usr/lib64/galera/libgalera_smm.so"}
export DB_CACHE_SIZE=${DB_CACHE_SIZE:-300M}
export DB_CLUSTER_NAME=${DB_CLUSTER_NAME:-"openstack_db"}
export DB_CLUSTER_IP_LIST=${DB_CLUSTER_IP_LIST:-"$DB_IP"}
export DB_XTRABACKUP_PASSWORD=${DB_XTRABACKUP_PASSWORD:-"galera"}
export DB_WSREP_SST_AUTH=${DB_WSREP_SST_AUTH:-"galera:$DB_XTRABACKUP_PASSWORD"}
export DB_WSREP_SST_METHOD=${DB_WSREP_SST_METHOD:-"xtrabackup-v2"}

export RABBIT_IP=${RABBIT_IP:-$CTRL_MGMT_IP}
export RABBIT_USER=${RABBIT_USER:-guest}
export RABBIT_PASS=${RABBIT_PASS:-$RABBIT_USER}
export RABBIT_PORT=${RABBIT_PORT:-5672}
#export RABBIT_LIST=${RABBIT_LIST:-$RABBIT_USER:$RABBIT_PASS@$RABBIT_IP:$RABBIT_PORT}
# rabbitmq ha
export RABBIT_HA=${RABBIT_HA:-False}
# the length is 20 letters
export ERLANG_COOKIE=${ERLANG_COOKIE:-RETATECCEBVIMIRCFTNT}
#declare -p RABBIT_CLUSTER > /dev/null 2>&1
#if [ $? -eq 1 ] && [[ ${RABBIT_HA^^} == 'TRUE' ]]; then
#    echo "rabbitmq ha required to define RABBIT_CLUSTER, but it was not defined" && exit 30
    #declare -a RABBIT_CLUSTER=(
    #    '10.160.37.51 centos7-1'
    #    '10.160.37.56 centos7-6'
    #)
#fi
#export RABBIT_CLUSTER

# openstack components
export SERVICES=${SERVICES:-"nova keystone glance neutron cinder"}
export SERVICES_NODB=${SERVICES_NODB:-"placement"}
export ADMIN_TOKEN=${ADMIN_TOKEN:-abc012345678909876543210cba}
export METADATA_SECRET=metadata_shared_secret

export KEYSTONE_T_NAME_ADMIN=admin
export KEYSTONE_T_NAME_SERVICE=service

export KEYSTONE_R_NAME_ADMIN=admin
export KEYSTONE_R_NAME_MEMBER=_member_

export KEYSTONE_U_ADMIN=admin
export KEYSTONE_U_ADMIN_PWD=$KEYSTONE_U_ADMIN

export REGION=${REGION:-RegionOne}

# Enable Distributed Virtual Routers(True or False)
export DVR=${DVR:-False}

export CONFIG_DRIVE=${CONFIG_DRIVE:-True}

# Need to update the params with name *FORTINET* to enable fortinet plugin on
# neutron server in addition to manually boot up your own fortigate.
export ENABLE_FORTINET_PLUGIN=${ENABLE_FORTINET_PLUGIN:-False}
# the fortigate management interface ip address
export FORTINET_ADDRESS=${FORTINET_ADDRESS:-''}
# The port in the fortigate to provide Openstack external network.
export FORTINET_EXT_INTERFACE=${FORTINET_EXT_INTERFACE:-''}
# The port in the fortigate to provide Openstack internal network(tenant network).
export FORTINET_INT_INTERFACE=${FORTINET_INT_INTERFACE:-''}

export FORTINET_NPU_AVAILABLE=${FORTINET_NPU_AVAILABLE:-False}
# username to access fortigate api (default None)
export FORTINET_PASSWORD=${FORTINET_PASSWORD:-''}
# username to access fortigate api (default admin)
export FORTINET_USERNAME=${FORTINET_USERNAME:-admin}
# use which protocol to access fortigate api (http or https, default https)
export FORTINET_PROTOCOL=${FORTINET_PROTOCOL:-https}
# use which protocol port to access fortigate api (default 443)
export FORTINET_PORT=${FORTINET_PORT:-443}
export FORTINET_ENABLE_DEFAULT_FWRULE=${FORTINET_ENABLE_DEFAULT_FWRULE:-False}

# cirros image
export IMAGE_FILE=${IMAGE_FILE:-"cirros-0.3.4-x86_64-disk.img"}
export IMAGE_URL=${IMAGE_URL:-"http://download.cirros-cloud.net/0.3.4/$IMAGE_FILE"}
export IMAGE_NAME=${IMAGE_NAME:-'cirros-0.3.4-x86_64'}

# service plugins
export SERVICE_PLUGINS=${SERVICE_PLUGINS:-router_fortinet,fwaas_fortinet}
# ml2 plugin configuration
export ML2_PLUGIN=${ML2_PLUGIN:-openvswitch}
export TYPE_DR=${TYPE_DR:-vxlan}
export SECURITY_GROUP_ENABLE=${SECURITY_GROUP_ENABLE:-False}

# config file path
export KEYSTONE_CONF=${KEYSTONE_CONF:-"/etc/keystone/keystone.conf"}
export NOVA_CONF=${NOVA_CONF:-"/etc/nova/nova.conf"}
export CINDER_CONF=${CINDER_CONF:-"/etc/cinder/cinder.conf"}
export NEUTRON_CONF=${NEUTRON_CONF:-"/etc/neutron/neutron.conf"}
export ML2_CONF=${ML2_CONF:-"/etc/neutron/plugins/ml2/ml2_conf.ini"}
export OVS_CONF=${OVS_CONF:-"/etc/neutron/plugins/ml2/openvswitch_agent.ini"}

export INS_KERNELS=${INS_KERNELS:-2}

LOGIN_INFO="
After all Openstack roles are installed, you can access the
Openstack dashboard at: http://$CTRL_MGMT_IP/dashboard
username: $KEYSTONE_U_ADMIN
password: $KEYSTONE_U_ADMIN_PWD
"

declare -a SUPPORTED_OPENSTACK_RELEASE=(
    liberty
    mitaka
    ocata
)
export SUPPORTED_OPENSTACK_RELEASE

export INS_OPENSTACK_RELEASE=${INS_OPENSTACK_RELEASE:-${SUPPORTED_OPENSTACK_RELEASE[-1]}}

## If there is any existed local repo mirror, updated the following variables.
export REPO_MIRROR_ENABLE=${REPO_MIRROR_ENABLE:-False}

declare -p REPO_MIRROR_URLS > /dev/null 2>&1
if [ $? -eq 1 ]; then
    declare -A REPO_MIRROR_URLS=(
        ['base']='http://10.160.37.50/centos/$releasever/os/$basearch/'
        ['epel']='http://10.160.37.50/epel/\$releasever/x86_64'
        ['cloud']='http://10.160.37.50/centos/\$releasever/cloud/\$basearch/openstack-${INS_OPENSTACK_RELEASE,,}/'
        ['virt']='http://10.160.37.50/centos/$releasever/virt/$basearch/kvm-common/'
    )
fi
export REPO_MIRROR_URLS

declare -A REPO_FILES=(
    ['base']='/etc/yum.repos.d/CentOS-Base.repo'
    ['epel']="/etc/yum.repos.d/epel.repo"
    ['cloud']='/etc/yum.repos.d/CentOS-OpenStack-$INS_OPENSTACK_RELEASE.repo'
    ['virt']='/etc/yum.repos.d/CentOS-QEMU-EV.repo'
)
export REPO_FILES

OS_MAJOR_REL_VER=$(rpm -q --qf "%{VERSION}" $(rpm -q --whatprovides redhat-release))
EPEL_GPG_KEY="RPM-GPG-KEY-EPEL-${OS_MAJOR_REL_VER}"
OS_GPG_KEYS_PATH="/etc/pki/rpm-gpg"
LOCAL_GPG_KEYS_PATH="${TOP_DIR}/distros/centos/gpgkeys"

## Assign security group drivers
export SECURITY_GROUP_DRS=(
    neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
    neutron.agent.firewall.NoopFirewallDriver
)

if [[ ${SECURITY_GROUP_ENABLE^^} == "TRUE" ]];then
    export SECURITY_GROUP_DR=${SECURITY_GROUP_DRS[0]}
else
    export SECURITY_GROUP_DR=${SECURITY_GROUP_DRS[1]}
fi

export DEFAULT_DOMAIN_ID=''

export GLANCE_STOR_BACKEND=${GLANCE_STOR_BACKEND: file}
