#!/bin/bash

###########################################################################
# ubuntu use
# eth0=$(ip address show eth0 | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')
# centos use
TOP_DIR=$(cd $(dirname "$0") && pwd)

source "$TOP_DIR/local.conf"

export INTERFACE_MGMT=${INTERFACE_MGMT:-eth0}
export INTERFACE_INT=${INTERFACE_INT:-eth1}
export INTERFACE_EXT=${INTERFACE_EXT:-eth2}

export VLAN_RANGES=${VLAN_RANGES:-physnet1:1009:1099}

export INTERFACE_INT_IP=$(ip address show $INTERFACE_INT | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')
export MGMT_IP=$(ip address show $INTERFACE_MGMT | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')

export CTRL_MGMT_IP=${CTRL_MGMT_IP:-$MGMT_IP}

export NTPSRV=${NTPSRV:-$CTRL_MGMT_IP}

export MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-root}
export RABBIT_USER=${RABBIT_USER:-guest}
export RABBIT_PASS=${RABBIT_PASS:-$RABBIT_USER}
export SERVICES=${SERVICES:-"nova keystone glance neutron cinder"}
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
    newton
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

###########################################################################

function _ERRTRAP() {
    FILENAME="$PWD/$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"
    INFO="[FILE: $FILENAME, LINE: $1] Error: The following command or function exited with status $2
    $(sed -n $1p $FILENAME)

"
    echo -e "$INFO"
}


function _import_config() {
    ## If any parameter's name is changed, the new name need to be defined and
    ## it's related references need to be replaced as below.
    ## e.g.
    ##   admin_password
    ##  ==>
    ##   ${KEYS[$INS_OPENSTACK_RELEASE,KEYSTONE_U_PWD_GLANCE]:-admin_password}
    _CONF_PATH="$TOP_DIR/conf/${INS_OPENSTACK_RELEASE,,}"
    _DB_CREATION="$_CONF_PATH/db_creation.sh"

    source $_DB_CREATION
 
    for service in $SERVICES horizon; do
        CONF="$_CONF_PATH/${service}_config.sh"
        if [ -e $CONF ]; then
            source $CONF
        else
            echo "cannot found the file $CONF"
            exit 8
        fi
    done
}

function _repo_epel() {
    if [[ "$*" == "starting" ]]; then
        _PARAMS=" > /dev/null 2>&1"
    else
        _PARAMS=""
    fi

    if [ ! -e "$OS_GPG_KEYS_PATH/$EPEL_GPG_KEY" ] && [ -e "$LOCAL_GPG_KEYS_PATH/$EPEL_GPG_KEY" ]; then
        eval "yes | cp ${LOCAL_GPG_KEYS_PATH}/${EPEL_GPG_KEY} ${OS_GPG_KEYS_PATH}/.$_PARAMS"
    fi
    eval "yum install -y epel-release$_PARAMS"
}

function _repo() {
    yum clean metadata
    yum update -y
    _repo_epel
    yum install -y centos-release-openstack-$INS_OPENSTACK_RELEASE
    if [ $? -ne 0 ]; then
        echo "## Fail to add Openstack repo centos-release-openstack-$INS_OPENSTACK_RELEASE"
        exit 7
    fi
    if [[ ${REPO_MIRROR_ENABLE^^} == 'TRUE' ]]; then
        for REPO_MIRROR in "${!REPO_MIRROR_URLS[@]}"; do
            eval _REPO_FILE="${REPO_FILES[$REPO_MIRROR]}"
            eval _REPO_URL="${REPO_MIRROR_URLS[$REPO_MIRROR]}"

            if [[ $REPO_MIRROR == 'base' ]] || [[ $REPO_MIRROR == 'epel' ]]; then
                crudini --set ${_REPO_FILE} $REPO_MIRROR baseurl ${_REPO_URL}
                crudini --del ${_REPO_FILE} $REPO_MIRROR mirrorlist
            elif [[ $REPO_MIRROR == 'cloud' ]]; then
                crudini --set ${_REPO_FILE} centos-openstack-$INS_OPENSTACK_RELEASE baseurl ${_REPO_URL}
            elif [[ $REPO_MIRROR == 'virt' ]]; then
                crudini --set ${_REPO_FILE} centos-qemu-ev baseurl ${_REPO_URL}
            fi
        done
        yum clean metadata
        yum update -y
    fi
}


function _ntp() {

    yum install -y ntp net-tools

    systemctl enable ntpd.service
    systemctl stop ntpd.service

    ip address |grep $NTPSRV >/dev/null

    if [ $? -eq 0 ]; then
        ntpdate -s ntp.org
    else
        sed -i.bak "s/^server 0.centos.pool.ntp.org iburst/server $NTPSRV/g" /etc/ntp.conf
        sed -i 's/^server 1.centos.pool.ntp.org iburst/# server 1.centos.pool.ntp.org iburst/g' /etc/ntp.conf
        sed -i 's/^server 2.centos.pool.ntp.org iburst/# server 2.centos.pool.ntp.org iburst/g' /etc/ntp.conf
        sed -i 's/^server 3.centos.pool.ntp.org iburst/# server 3.centos.pool.ntp.org iburst/g' /etc/ntp.conf
        ntpdate -s $NTPSRV
    fi
    systemctl restart ntpd.service
}

function _base() {
    trap '_ERRTRAP $LINENO $?' ERR

    set -o xtrace

    _repo

    _import_config

    # set installed Kernel limits(INS_KERNELS, default 2) and clean up old Kernels
    crudini --set /etc/yum.conf main installonly_limit $INS_KERNELS
    cur_kernels=$(rpm -q kernel | wc -l)
    if [ "$cur_kernels" -gt "$INS_KERNELS" ]; then
        yum install -y yum-utils wget
        package-cleanup -y --oldkernels --count=$INS_KERNELS
    fi

    yum autoremove -y firewalld
    yum install -y openstack-selinux python-pip python-openstackclient
    pip install --upgrade pip

    _ntp

    for service in $SERVICES; do
        eval DB_USER_${service^^}=$service
        eval DB_PWD_${service^^}=$service
        eval KEYSTONE_U_${service^^}=$service
        eval KEYSTONE_U_PWD_${service^^}=$service
    done

    cat > ~/openrc << EOF
export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_NAME=$KEYSTONE_T_NAME_ADMIN
export OS_USERNAME=$KEYSTONE_U_ADMIN
export OS_PASSWORD=$KEYSTONE_U_ADMIN_PWD
export OS_AUTH_URL=http://$CTRL_MGMT_IP:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF
    source ~/openrc
}

# check service existence before installing it.
function service_check() {
# $1 is the service name, e.g. database
# $2 is the listening port when the service was running, e.g. 3306
# if the service is running return 0 else return 1
    netstat -anp|grep ":$2" > /dev/nul
    if [ $? -eq 0 ]; then
        echo "Skip $1 installation, because a $1 service is running."
        return 0
    else
        echo "Installing $1..."
        return 1
    fi
}

function database() {
    service_check database 3306 && return
    yum install -y mariadb mariadb-server MySQL-python python-openstackclient
    # generate config file
    cat > /etc/my.cnf << EOF
[mysqld]
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock
# Disabling symbolic-links is recommended to prevent assorted security risks
symbolic-links=0
# Settings user and group are ignored when systemd is used.
# If you need to run mysqld under a different user or group,
# customize your systemd unit file for mariadb according to the
# instructions in http://fedoraproject.org/wiki/Systemd
bind-address = $MGMT_IP
default-storage-engine = innodb
innodb_file_per_table
collation-server = utf8_general_ci
init-connect = 'SET NAMES utf8'
character-set-server = utf8

[mysqld_safe]
log-error=/var/log/mariadb/mariadb.log
pid-file=/var/run/mariadb/mariadb.pid

#
# include all files from the config directory
#
!includedir /etc/my.cnf.d

EOF

    systemctl enable mariadb.service
    systemctl start mariadb.service

    (mysqlshow -uroot -p$MYSQL_ROOT_PASSWORD 2>&1) > /dev/nul

    if [ $? -ne 0 ]; then
        yum install -y expect

        # initialize database
        SECURE_MYSQL=$(expect -c "
set timeout 3

spawn mysql_secure_installation

expect \"Enter current password for root (enter for none):\"
send \"$MYSQL\r\"

expect \"Change the root password?\"
send \"y\r\"

expect \"New password:\"
send \"$MYSQL_ROOT_PASSWORD\r\"

expect \"Re-enter new password:\"
send \"$MYSQL_ROOT_PASSWORD\r\"

expect \"Remove anonymous users?\"
send \"y\r\"

expect \"Disallow root login remotely?\"
send \"n\r\"

expect \"Remove test database and access to it?\"
send \"y\r\"

expect \"Reload privilege tables now?\"
send \"y\r\"

expect eof
")

        echo "$SECURE_MYSQL"

        yum erase -y expect
    fi

    # Enable root remote access MySQL
    mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL ON *.* TO 'root'@'%' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';"
    mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL ON *.* TO 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';"
    
    _services_db_creation
}


function mq() {
    service_check rabbitmq-server 5672 && return
    ## install rabbitmq
    yum install -y rabbitmq-server

    sed -i.bak "s#%% {tcp_listeners, \[5672\]},#{tcp_listeners, \[{\"$MGMT_IP\", 5672}\]}#g" /etc/rabbitmq/rabbitmq.config

    systemctl enable rabbitmq-server.service
    systemctl restart rabbitmq-server.service

    rabbitmqctl change_password guest $RABBIT_PASS
}


function _memcached() {
    service_check _memcached 11211 && return
    yum install -y memcached
    crudini --set /etc/sysconfig/memcached '' OPTIONS "\"-l $MGMT_IP\""
    systemctl restart memcached
}


function keystone() {
    # install keystone
    yum install -y openstack-keystone httpd mod_wsgi
    #_memcached
    _keystone_configure

}


function glance() {
    ## glance
    yum install -y openstack-glance
    _memcached

    if [ -z "$KEYSTONE_T_ID_SERVICE" ]; then
        export KEYSTONE_T_ID_SERVICE=$(openstack project show service | grep '| id' | awk '{print $4}')
    fi

    _glance_configure

    su -s /bin/sh -c "glance-manage db_sync" glance

    systemctl enable openstack-glance-api.service openstack-glance-registry.service
    systemctl restart openstack-glance-api.service openstack-glance-registry.service

    [[ -e ~/openrc ]] && source ~/openrc
    openstack image show $IMAGE_NAME >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        if [ ! -e /tmp/images/$IMAGE_FILE ]; then
            mkdir -p /tmp/images
            wget -P /tmp/images $IMAGE_URL
        fi

        local _COUNT=0
        while true; do
            sleep 5s
            (netstat -anp|grep 9292) && (netstat -anp|grep 9191)
            if [ $? -eq 0 ]; then
                break
            fi
            if [ ${_COUNT} -gt 10 ]; then
                echo "glance service cannot work properly."
                exit 10
            fi
            let $((_COUNT++))
        done
        openstack image create --file /tmp/images/$IMAGE_FILE \
          --disk-format qcow2 --container-format bare --public $IMAGE_NAME
        openstack image list

        #rm -rf /tmp/images
    fi
}


function nova_ctrl() {
    ## nova controller
    yum install -y openstack-nova-api openstack-nova-cert openstack-nova-conductor \
      openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler

    _nova_configure nova_ctrl

    systemctl enable openstack-nova-api.service openstack-nova-cert.service \
      openstack-nova-consoleauth.service openstack-nova-scheduler.service \
      openstack-nova-conductor.service openstack-nova-novncproxy.service
    systemctl restart openstack-nova-api.service openstack-nova-cert.service \
      openstack-nova-consoleauth.service openstack-nova-scheduler.service \
      openstack-nova-conductor.service openstack-nova-novncproxy.service

}


function nova_compute() {
    yum install -y openstack-nova-compute sysfsutils

    _nova_configure nova_compute

    systemctl enable libvirtd.service openstack-nova-compute.service
    systemctl restart libvirtd.service openstack-nova-compute.service
}


function neutron_ctrl() {
    # neutron
    yum install -y openstack-neutron openstack-neutron-ml2 which

    _neutron_configure neutron_ctrl

    su -s /bin/sh -c "neutron-db-manage --config-file $NEUTRON_CONF --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron

    systemctl enable neutron-server.service
    systemctl restart neutron-server.service
}


function neutron_compute() {
    # install neutron components on compute nodes
    yum install -y openstack-neutron-ml2 openstack-neutron-openvswitch ipset

    systemctl enable openvswitch.service
    systemctl restart openvswitch.service

    _neutron_configure neutron_compute

    systemctl restart openstack-nova-compute.service
    systemctl enable neutron-openvswitch-agent.service
    systemctl restart neutron-openvswitch-agent.service

}


function neutron_network() {
    yum install -y openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch

    systemctl enable openvswitch.service
    systemctl restart openvswitch.service

    _neutron_configure neutron_network

    systemctl enable neutron-openvswitch-agent.service neutron-l3-agent.service \
    neutron-dhcp-agent.service neutron-metadata-agent.service neutron-ovs-cleanup.service

    systemctl restart neutron-openvswitch-agent.service neutron-l3-agent.service \
    neutron-dhcp-agent.service neutron-metadata-agent.service
}



function cinder_ctrl() {
    # cinder ctrl
    yum install -y openstack-cinder

    _cinder_configure

    su -s /bin/sh -c "cinder-manage db sync" cinder

    systemctl enable openstack-cinder-api.service openstack-cinder-scheduler.service
    systemctl restart openstack-cinder-api.service openstack-cinder-scheduler.service
}


function dashboard() {
    yum install -y openstack-dashboard memcached

    _horizon_configure

    systemctl enable httpd.service memcached.service
    systemctl restart httpd.service memcached.service

}


function allinone() {
    database
    mq
    keystone
    glance
    nova_ctrl
    neutron_ctrl
    cinder_ctrl
    dashboard
    nova_compute
    neutron_compute
    neutron_network
}


function controller() {
    database
    mq
    keystone
    glance
    nova_ctrl
    neutron_ctrl
    cinder_ctrl
    dashboard
}


function network() {
    neutron_network
}


function compute() {
    nova_compute
    neutron_compute
}


function _help() {
    usage="
./$(basename "$0") [-h] [-v openstack_releasename] rolenames

This script help you to install specific openstack roles to the machine,
before run the script, you need to update the environment variables in the
head of the script according to your setup.

options:
    -h  this help
    -v  assign an openstack version to be installed, currently supported
        Openstack version are: ${SUPPORTED_OPENSTACK_RELEASE[@]}
        the default openstack version is '${SUPPORTED_OPENSTACK_RELEASE[-1]}'

rolenames:
    The rolenames could be any one or combo of the follow role set.
    a) Openstack all-in-one installation role name list:
        allinone

    b) Openstack multi-nodes installation role name list:
        controller
        network
        compute

    c) Openstack component installation role name list:
        database
        mq
        dashboard
        keystone
        glance
        nova_ctrl
        nova_compute
        neutron_ctrl
        neutron_compute
        neutron_network
        cinder_ctrl

    Examples:
        # Install all openstack stuff(allinone role) in one machine
        ./ins.sh -v mitaka allinone

        # Install two roles(nova controller and neutron controller) in a machine
        ./ins.sh nova_ctrl neutron_ctrl

        # Install Openstack with fortinet plugins
        a) Before run the script, a fortigate need to be initialized properly.
           1) license activated
           2) enabled multi-vdom
           3) At least there are 3 ports in the fortigate: a port for management
           need to have a ip address, a port for openstack tenant network and
           a port for openstack external network.

        b) Customize the local.conf file before run ins.sh
            ############## EXAMPLE local.conf #################
            # openstack config
            CTRL_MGMT_IP=10.160.37.80
            INTERFACE_MGMT=eth0
            INTERFACE_INT=eth1
            INTERFACE_EXT=eth2

            # ml2 network type drive, could be vlan, gre, vxlan.
            TYPE_DR=vlan
            # All Vlanid in vlan ranges used by tenant networks need to be
            # pre-configured on all switches connected with tenant networks.
            VLAN_RANGES=physnet1:1000:1100

            # Enable fortinet plugin, when ENABLE_FORTINET_PLUGIN, TYPE_DR only
            # support vlan
            ENABLE_FORTINET_PLUGIN=True
            FORTINET_ADDRESS=10.160.37.96
            FORTINET_EXT_INTERFACE=port9
            FORTINET_INT_INTERFACE=port1

            ###################################################

        c) Install Openstack controller on a host:
            ./ins.sh -v mitaka controller

        d) Install Openstack compute on other hosts:
            ./ins.sh -v mitaka compute

    Notes:
         If you are doing multi-modes installation, the suggested script run
         sequence is:
         1. prepare your fortigate (if have)
         2. Install controller
         3. Install others (compute/network)
"

    if [ "$#" -eq 0 ]; then
        echo "$usage"
        exit 6
    fi
    while getopts ':hv:' option; do
        case "$option" in
        h)  echo "$usage"
            exit
            ;;
        v)  local version=${OPTARG,,}
            local _SUPPORTED=FALSE
            for VER in ${SUPPORTED_OPENSTACK_RELEASE[@]}; do
                if [[ $VER == "$version" ]]; then
                    _SUPPORTED=TRUE
                    INS_OPENSTACK_RELEASE=$VER
                    break
                fi
            done
            if [[ $_SUPPORTED != "TRUE" ]]; then
                echo -e "
Error: The assigned Openstack version is not supported so far,
the supported openstack version were listed as below:
${SUPPORTED_OPENSTACK_RELEASE[@]}
"
                exit 3
            fi
            ;;
        :)  printf "missing argument for -%s\n" "$OPTARG" >&2
            echo "$usage" >&2
            exit 2
            ;;
        \?) printf "illegal option: -%s\n" "$OPTARG" >&2
            echo "$usage" >&2
            exit 1
            ;;
        esac
    done
    return $((OPTIND - 1))
}


function _display() {
    # starting need to be run on the beginning
    if [[ "$*" == "starting" ]]; then
        _repo_epel $*
        sudo yum -y install figlet crudini >& /dev/null
        if [[ "$?" != "0" ]]; then
            echo "Failed to install the package figlet"
            exit 4
        fi
        figlet -tf slant Openstack installer && echo

    elif [[ "$*" == "completed" ]]; then
        figlet -tf slant Openstack installation $1
        echo -e "It takes\x1b[32m $SECONDS \x1b[0mseconds during the installation."
        echo "$LOGIN_INFO"

    else
        figlet -tf slant Openstack installation $1
    fi
}


function _log() {
    ## Log the script all outputs locally
    exec > >(sudo tee install.log)
    exec 2>&1
}


function _installation() {
    _base
    for service in "$@"; do
        echo "##### Installing $service ..."
        $service || exit $?
    done
}


function _timestamp {
    awk '{ print strftime("%Y-%m-%d %H:%M:%S | "), $0; fflush(); }'
}


function main {
    _help $@
    shift $?
    _log
    _display starting
    _installation $@ | _timestamp
    _display completed
}

main $@

