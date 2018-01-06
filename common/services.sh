#!/usr/bin/env bash

source "$TOP_DIR/common/utils.sh"

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
    # install essential packages and tools
    yum install -y psmisc tcpdump

    yum install -y openstack-selinux python-pip python-openstackclient
    pip install --upgrade pip

    _ntp

    for service in $SERVICES; do
        eval DB_USER_${service^^}=$service
        eval DB_PWD_${service^^}=$service
     done

     for service in $SERVICES $SERVICES_NODB; do
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
        echo "Skip $1 installation, because the $1 service is running."
        return 0
    else
        echo "Installing $1..."
        return 1
    fi
}


function database() {
    service_check database 3306 && return
    if [[ ${DB_HA^^} == 'TRUE' ]]; then
        yum install -y mariadb-galera-server galera
    else
        yum install -y mariadb mariadb-server MySQL-python python-openstackclient
    fi
    # generate config file
cat > ~/my.cnf << EOF
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
# innodb_file_per_table = 1
collation-server = utf8_general_ci
init-connect = 'SET NAMES utf8'
character-set-server = utf8
EOF

_start_options=''
if [[ ${DB_HA^^} == 'TRUE' ]]; then
cat >> ~/my.cnf << EOF
user=mysql
binlog_format=ROW
innodb_autoinc_lock_mode=2
innodb_flush_log_at_trx_commit=0
innodb_buffer_pool_size=122M

wsrep_provider=$DB_WSREP_PROVIDER
wsrep_provider_options="pc.recovery=TRUE;gcache.size=$DB_CACHE_SIZE"
wsrep_cluster_name="$DB_CLUSTER_NAME"
wsrep_cluster_address="gcomm://$DB_CLUSTER_IP_LIST"
wsrep_sst_method=rsync
EOF
    OIFS=$IFS
    IFS=','
    set -- junk $DB_CLUSTER_IP_LIST
    shift
    primary_ip=$1
    other_ips=$2
    IFS="$OIFS"
    if [ -z "$other_ips" ]; then
        echo "Error: multiply ips required at the option 'DB_CLUSTER_IP_LIST' for database HA."
        exit 30
    fi
    ip address | grep "$primary_ip"
    if [ $? -eq 0 ]; then
        _start_options="--wsrep-new-cluster"
    fi
fi

cat >> ~/my.cnf << EOF

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

    if [[ ${DB_HA^^} == 'TRUE' ]]; then
        # show how many nodes in the cluster
        mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "SHOW STATUS LIKE 'wsrep_cluster_size';"
    fi

    _services_db_creation
}


function mq() {
    service_check rabbitmq-server 5672 && return
    ## install rabbitmq
    yum install -y rabbitmq-server
    sed -i.bak "s#%% {tcp_listeners, \[5672\]},#{tcp_listeners, \[{\"$MGMT_IP\", 5672}\]}#g" /etc/rabbitmq/rabbitmq.config

    if [[ ${RABBIT_HA^^} == 'TRUE' ]]; then
        declare -p RABBIT_CLUSTER > /dev/null 2>&1
        if [ $? -eq 1 ]; then
            echo "rabbitmq ha required to define RABBIT_CLUSTER, but it was not defined" && exit 30
        fi

        if [ ! -z "$ERLANG_COOKIE" ]; then
            echo "$ERLANG_COOKIE" > /var/lib/rabbitmq/.erlang.cookie
        else
            echo "Error: the option ERLANG_COOKIE is empty."
            exit 20
        fi
        chown rabbitmq:rabbitmq /var/lib/rabbitmq/.erlang.cookie
        chmod 400 /var/lib/rabbitmq/.erlang.cookie
        rabbitmqctl set_cluster_name openstack
        rabbitmqctl set_policy ha-all '^(?!amq\.).*' '{"ha-mode": "all"}'
        RABBIT_LIST=''
        _first_node=True
        for node in "${!RABBIT_CLUSTER[@]}"; do
            node_info=${RABBIT_CLUSTER[$node]}
            set -- junk "$node_info"
            shift
            grep "$node_info" /etc/hosts || echo $$node_info >> /etc/hosts
            _ip=$1
            _hostname=$2
            if [ -z "$RABBIT_LIST" ]; then
                RABBIT_LIST="$RABBIT_USER:$RABBIT_PASS@$_ip:$RABBIT_PORT"
            else
                RABBIT_LIST="$RABBIT_USER:$RABBIT_PASS@$_ip:$RABBIT_PORT,$RABBIT_LIST"
            fi
            if [[ "${_first_node^^}" == 'TRUE' ]]; then
                _first_node="$_hostname"
            else
                rabbitmqctl stop_app
                rabbitmqctl join_cluster --ram "rabbit@$_first_node"
                rabbitmqctl start_app
                rabbitmqctl cluster_status | grep "rabbit@$_first_node"
            fi
        done
    fi

    systemctl enable rabbitmq-server.service
    systemctl restart rabbitmq-server.service

    rabbitmqctl change_password "$RABBIT_USER" "$RABBIT_PASS"
}


function _memcached() {
    service_check memcached 11211 && return
    yum install -y memcached
    pip install --upgrade python-memcached
    crudini --set /etc/sysconfig/memcached '' OPTIONS "\"-l $MGMT_IP\""
    systemctl restart memcached
}


function _httpd() {
    service_check httpd 80 && return
    yum install -y httpd
    sed -i "s#^ServerName www.example.com:80#ServerName 127.0.0.1#g" /etc/httpd/conf/httpd.conf
    systemctl enable httpd.service
    systemctl restart httpd.service
}


function keystone() {
    # install keystone
    yum install -y openstack-keystone mod_wsgi

    _httpd
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
    yum install -y openstack-nova-api openstack-nova-conductor \
                   openstack-nova-console openstack-nova-novncproxy \
                   openstack-nova-scheduler openstack-nova-placement-api

    _nova_configure nova_ctrl

    systemctl enable openstack-nova-api.service \
      openstack-nova-consoleauth.service openstack-nova-scheduler.service \
      openstack-nova-conductor.service openstack-nova-novncproxy.service
    systemctl restart openstack-nova-api.service \
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
    yum install -y openstack-dashboard

    # need to install httpd first
    _httpd
    _memcached
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


function main {
    _help $@
    shift $?
    _log
    _display starting
    _installation $@ | _timestamp
    _display completed
}