#!/bin/bash

###########################################################################
# ubuntu use
# eth0=`ifconfig eth0 |grep 'inet addr' | cut -f 2 -d ":" | cut -f 1 -d " "`
# centos use

CTRL_MGMT_IP=10.160.37.56

INTERFACE_MGMT=eth0
INTERFACE_INT=eth1
INTERFACE_EXT=eth2

VLAN_RANGES=1000:2000
INTERFACE_INT_IP=`ifconfig $INTERFACE_INT |grep 'inet '| cut -f 10 -d " "`
MGMT_IP=`ifconfig $INTERFACE_MGMT |grep 'inet '| cut -f 10 -d " "`

NTPSRV=$CTRL_MGMT_IP

MYSQL_ROOT_PASSWORD=root
RABBIT_USER=guest
RABBIT_PASS=$RABBIT_USER
SERVICES="nova keystone glance neutron cinder"
ADMIN_TOKEN=abc012345678909876543210cba
METADATA_SECRET=metadata_shared_secret

KEYSTONE_T_NAME_ADMIN=admin
KEYSTONE_T_NAME_SERVICE=service

KEYSTONE_R_NAME_ADMIN=admin
KEYSTONE_R_NAME_MEMBER=_member_

KEYSTONE_U_ADMIN=admin
KEYSTONE_U_ADMIN_PWD=$KEYSTONE_U_ADMIN
REGION=RegionOne

# Enable Distributed Virtual Routers(True or False)
DVR=True

CONFIG_DRIVE=True

IMAGE_FILE=cirros-0.3.4-x86_64-disk.img
IMAGE_URL=http://download.cirros-cloud.net/0.3.4/$IMAGE_FILE
IMAGE_NAME='cirros-0.3.4-x86_64'

ML2_PLUGIN=openvswitch
TYPE_DR=vxlan

INS_KERNELS=2
LOGIN_INFO="
Openstack dashboard url: http://$CTRL_MGMT_IP/dashboard
username: $KEYSTONE_U_ADMIN
password: $KEYSTONE_U_ADMIN_PWD
"

###########################################################################

ERRTRAP() {
    echo "[FILE: "$PWD/$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")", LINE: $1] Error: Command or function exited with status $?"
}


function _ntp() {

    yum install -y ntp

    systemctl enable ntpd.service
    systemctl stop ntpd.service

    ifconfig |grep $NTPSRV >/dev/null

    if [ $? -eq 0 ]; then
        ntpdate -s ntp.org
    else
        sed -i.bak 's/^server 0.centos.pool.ntp.org iburst/server $NTPSRV/g' /etc/ntp.conf
        sed -i 's/^server 1.centos.pool.ntp.org iburst/# server 1.centos.pool.ntp.org iburst/g' /etc/ntp.conf
        sed -i 's/^server 2.centos.pool.ntp.org iburst/# server 2.centos.pool.ntp.org iburst/g' /etc/ntp.conf
        sed -i 's/^server 3.centos.pool.ntp.org iburst/# server 3.centos.pool.ntp.org iburst/g' /etc/ntp.conf
        ntpdate -s $NTPSRV
    fi
    systemctl restart ntpd.service
}

function base() {
    trap 'ERRTRAP $LINENO $?' ERR

    set -o xtrace

    yum update -y
    yum upgrade -y

    # set installed Kernel limits(INS_KERNELS, default 2) and clean up old Kernels
    crudini --set /etc/yum.conf main installonly_limit $INS_KERNELS
    cur_kernels=$(rpm -q kernel | wc -l)
    if [ "$cur_kernels" -gt "$INS_KERNELS" ]; then
        yum install -y yum-utils
        package-cleanup -y --oldkernels --count=$INS_KERNELS
    fi

    yum autoremove -y firewalld
    yum install -y crudini
    yum install -y openstack-selinux python-pip
    pip install --upgrade pip

    _ntp

    for service in $SERVICES; do
        eval DB_USER_${service^^}=$service
        eval DB_PWD_${service^^}=$service
        eval KEYSTONE_U_${service^^}=$service
        eval KEYSTONE_U_PWD_${service^^}=$service
    done
        cat > ~/openrc << EOF
export OS_TENANT_NAME=$KEYSTONE_T_NAME_ADMIN
export OS_USERNAME=$KEYSTONE_U_ADMIN
export OS_PASSWORD=$KEYSTONE_U_ADMIN_PWD
export OS_AUTH_URL=http://$CTRL_MGMT_IP:35357/v2.0
EOF
    source ~/openrc
}

function database() {
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

    for service in $SERVICES; do
        mysqlshow -uroot -p$MYSQL_ROOT_PASSWORD $service 2>&1| grep -o "Database: $service" > /dev/nul
        if [ $? -ne 0 ]; then
            eval SERVICE_DB_USER=\$$(echo DB_USER_${service^^})
            eval SERVICE_DB_PWD=\$$(echo DB_PWD_${service^^})
            echo "Creating database $service,  db user: '$SERVICE_DB_USER', db password: '$SERVICE_DB_PWD...'"
            mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE $service;"
            mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL ON $service.* TO '$(echo $SERVICE_DB_USER)'@'%' IDENTIFIED BY '$(echo $SERVICE_DB_PWD)';"
            mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL ON $service.* TO '$(echo $SERVICE_DB_USER)'@'localhost' IDENTIFIED BY '$(echo $SERVICE_DB_PWD)';"
        fi
    done

}


function mq() {
    ## install rabbitmq
    yum install -y rabbitmq-server

    sed -i.bak "s#%% {tcp_listeners, \[5672\]},#{tcp_listeners, \[{\"$MGMT_IP\", 5672}\]}#g" /etc/rabbitmq/rabbitmq.config

    systemctl enable rabbitmq-server.service
    systemctl restart rabbitmq-server.service

    rabbitmqctl change_password guest $RABBIT_PASS
}


function keystone() {
    # install keystone
    yum install -y openstack-keystone
    ##python-keystoneclient

    ## TODO: update keystone.conf
    ## scp 10.160.37.51:/root/bak/keystone.conf /etc/keystone/keystone.conf
    crudini --set /etc/keystone/keystone.conf DEFAULT admin_token $ADMIN_TOKEN
    crudini --set /etc/keystone/keystone.conf DEFAULT debug True
    crudini --set /etc/keystone/keystone.conf database connection mysql://$DB_USER_KEYSTONE:$DB_PWD_KEYSTONE@$CTRL_MGMT_IP/keystone
    crudini --set /etc/keystone/keystone.conf token provider keystone.token.providers.uuid.Provider
    crudini --set /etc/keystone/keystone.conf token driver keystone.token.persistence.backends.sql.Token
    crudini --set /etc/keystone/keystone.conf revoke driver keystone.contrib.revoke.backends.sql.Revoke

    keystone-manage pki_setup --keystone-user keystone --keystone-group keystone

    chown -R keystone:keystone /var/log/keystone
    chown -R keystone:keystone /etc/keystone/ssl
    chmod -R o-rwx /etc/keystone/ssl

    su -s /bin/sh -c "keystone-manage db_sync" keystone

    systemctl enable openstack-keystone.service
    systemctl restart openstack-keystone.service

    (crontab -l -u keystone 2>&1 | grep -q token_flush) || \
      echo '@hourly /usr/bin/keystone-manage token_flush >/var/log/keystone/keystone-tokenflush.log 2>&1' \
      >> /var/spool/cron/keystone


    export OS_TOKEN=$ADMIN_TOKEN
    export OS_URL=http://$CTRL_MGMT_IP:35357/v3
    export OS_IDENTITY_API_VERSION=3


    openstack project show $KEYSTONE_T_NAME_ADMIN || openstack project create --domain default --description "Admin Project" $KEYSTONE_T_NAME_ADMIN
    openstack user show $KEYSTONE_U_ADMIN || openstack user create --domain default --password $KEYSTONE_U_ADMIN_PWD $KEYSTONE_U_ADMIN
    openstack role show $KEYSTONE_R_NAME_ADMIN || openstack role create $KEYSTONE_R_NAME_ADMIN
    openstack role show $KEYSTONE_R_NAME_MEMBER || (openstack role create $KEYSTONE_R_NAME_MEMBER && \
    openstack user role list | grep $KEYSTONE_U_ADMIN || openstack role add --project $KEYSTONE_T_NAME_ADMIN --user $KEYSTONE_U_ADMIN $KEYSTONE_R_NAME_ADMIN)
    openstack project show $KEYSTONE_T_NAME_SERVICE || openstack project create --domain default --description "Service Project" $KEYSTONE_T_NAME_SERVICE


    # unset OS_TOKEN OS_URL
    # sed -i 's/sizelimit url_normalize request_id build_auth_context token_auth admin_token_auth json_body ec2_extension user_crud_extension public_service/sizelimit url_normalize request_id build_auth_context token_auth json_body ec2_extension user_crud_extension public_service/g' /etc/keystone/keystone-paste.ini
    # sed -i 's/sizelimit url_normalize request_id build_auth_context token_auth admin_token_auth json_body ec2_extension s3_extension crud_extension admin_service/sizelimit url_normalize request_id build_auth_context token_auth json_body ec2_extension s3_extension crud_extension admin_service/g' /etc/keystone/keystone-paste.ini
    # sed -i 's/sizelimit url_normalize request_id build_auth_context token_auth admin_token_auth json_body ec2_extension_v3 s3_extension simple_cert_extension revoke_extension federation_extension oauth1_extension endpoint_filter_extension service_v3/sizelimit url_normalize request_id build_auth_context token_auth json_body ec2_extension_v3 s3_extension simple_cert_extension revoke_extension federation_extension oauth1_extension endpoint_filter_extension service_v3/g' /etc/keystone/keystone-paste.ini


    for service in $SERVICES; do
        openstack endpoint list --service $service 2>/dev/null
        if [ $? -ne 0 ]; then
            if [ $service == 'keystone' ] ; then
                openstack service create --name keystone --description "OpenStack Identity" identity
                openstack endpoint create --region $REGION identity public http://$CTRL_MGMT_IP:5000/v2.0
                openstack endpoint create --region $REGION identity internal http://$CTRL_MGMT_IP:5000/v2.0
                openstack endpoint create --region $REGION identity admin http://$CTRL_MGMT_IP:35357/v2.0

                openstack service create --name keystonev3 --description "OpenStack Identity v3" identityv3
                openstack endpoint create --region $REGION identityv3 public http://$CTRL_MGMT_IP:5000/v3.0
                openstack endpoint create --region $REGION identityv3 internal http://$CTRL_MGMT_IP:5000/v3.0
                openstack endpoint create --region $REGION identityv3 admin http://$CTRL_MGMT_IP:35357/v3.0

            elif [ $service == 'glance' ] ; then
                openstack service create --name glance --description "OpenStack Image service" image
                openstack endpoint create --region $REGION image public http://$CTRL_MGMT_IP:9292
                openstack endpoint create --region $REGION image internal http://$CTRL_MGMT_IP:9292
                openstack endpoint create --region $REGION image admin http://$CTRL_MGMT_IP:9292

            elif  [ $service == 'nova' ] ; then
                openstack service create --name nova --description "OpenStack Compute" compute
                openstack endpoint create --region $REGION compute public http://$CTRL_MGMT_IP:8774/v2/%\(tenant_id\)s
                openstack endpoint create --region $REGION compute internal http://$CTRL_MGMT_IP:8774/v2/%\(tenant_id\)s
                openstack endpoint create --region $REGION compute admin http://$CTRL_MGMT_IP:8774/v2/%\(tenant_id\)s

            elif  [ $service == 'neutron' ] ; then
                openstack service create --name neutron --description "OpenStack Networking" network
                openstack endpoint create --region $REGION network public http://$CTRL_MGMT_IP:9696
                openstack endpoint create --region $REGION network internal http://$CTRL_MGMT_IP:9696
                openstack endpoint create --region $REGION network admin http://$CTRL_MGMT_IP:9696

            elif  [ $service == 'cinder' ] ; then
                openstack service create --name cinder --description "OpenStack Volume Service" volume
                openstack endpoint create --region $REGION volume public http://$CTRL_MGMT_IP:8776/v1/%\(tenant_id\)s
                openstack endpoint create --region $REGION volume internal http://$CTRL_MGMT_IP:8776/v1/%\(tenant_id\)s
                openstack endpoint create --region $REGION volume admin http://$CTRL_MGMT_IP:8776/v1/%\(tenant_id\)s

                openstack service create --name cinderv2 --description "OpenStack Volume Service v2" volumev2
                openstack endpoint create --region $REGION volumev2 public http://$CTRL_MGMT_IP:8776/v2/%\(tenant_id\)s
                openstack endpoint create --region $REGION volumev2 internal http://$CTRL_MGMT_IP:8776/v2/%\(tenant_id\)s
                openstack endpoint create --region $REGION volumev2 admin http://$CTRL_MGMT_IP:8776/v2/%\(tenant_id\)s
            fi
        fi
        if [ $service != 'keystone' ] ; then
            eval SERVICE_U=\$$(echo KEYSTONE_U_${service^^})
            eval SERVICE_U_PWD=\$$(echo KEYSTONE_U_PWD_${service^^})
            openstack user show $service 2>/dev/null
            if [ $? -ne 0 ]; then
                openstack user create --domain default --password $SERVICE_U_PWD $SERVICE_U
                openstack role add --project $KEYSTONE_T_NAME_SERVICE --user $SERVICE_U $KEYSTONE_R_NAME_ADMIN
            fi
        fi
    done

    #catalog check for cinder v2
    grep -i volumev /etc/keystone/default_catalog.templates || cat >> /etc/keystone/default_catalog.templates << EOF
catalog.RegionOne.volumev2.publicURL = http://localhost:8776/v2/$(tenant_id)s
catalog.RegionOne.volumev2.adminURL = http://localhost:8776/v2/$(tenant_id)s
catalog.RegionOne.volumev2.internalURL = http://localhost:8776/v2/$(tenant_id)s
catalog.RegionOne.volumev2.name = Volume Service
EOF

    export KEYSTONE_T_ID_SERVICE=$(openstack project show service | grep '| id' | awk '{print $4}')

}


function glance() {
    ## glance
    yum install -y openstack-glance

    if [ -z "$KEYSTONE_T_ID_SERVICE" ]; then
        export KEYSTONE_T_ID_SERVICE=$(openstack project show service | grep '| id' | awk '{print $4}')
    fi

    crudini --set /etc/glance/glance-api.conf database connection mysql://$DB_USER_GLANCE:$DB_PWD_GLANCE@$CTRL_MGMT_IP/glance
    crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_uri http://$CTRL_MGMT_IP:5000/v2.0
    crudini --set /etc/glance/glance-api.conf keystone_authtoken identity_uri http://$CTRL_MGMT_IP:35357
    crudini --set /etc/glance/glance-api.conf keystone_authtoken admin_tenant_name $KEYSTONE_T_NAME_SERVICE
    crudini --set /etc/glance/glance-api.conf keystone_authtoken admin_user $KEYSTONE_U_GLANCE
    crudini --set /etc/glance/glance-api.conf keystone_authtoken admin_password $KEYSTONE_U_PWD_GLANCE
    crudini --set /etc/glance/glance-api.conf paste_deploy flavor keystone
    crudini --set /etc/glance/glance-api.conf DEFAULT notification_driver noop

    crudini --set /etc/glance/glance-registry.conf database connection mysql://$DB_USER_GLANCE:$DB_PWD_GLANCE@$CTRL_MGMT_IP/glance
    crudini --set /etc/glance/glance-registry.conf keystone_authtoken auth_uri http://$CTRL_MGMT_IP:5000/v2.0
    crudini --set /etc/glance/glance-registry.conf keystone_authtoken identity_uri http://$CTRL_MGMT_IP:35357
    crudini --set /etc/glance/glance-registry.conf keystone_authtoken admin_tenant_name $KEYSTONE_T_NAME_SERVICE
    crudini --set /etc/glance/glance-registry.conf keystone_authtoken admin_user $KEYSTONE_U_GLANCE
    crudini --set /etc/glance/glance-registry.conf keystone_authtoken admin_password $KEYSTONE_U_PWD_GLANCE
    crudini --set /etc/glance/glance-registry.conf paste_deploy flavor keystone
    crudini --set /etc/glance/glance-registry.conf DEFAULT notification_driver noop


    su -s /bin/sh -c "glance-manage db_sync" glance

    systemctl enable openstack-glance-api.service openstack-glance-registry.service
    systemctl restart openstack-glance-api.service openstack-glance-registry.service

    openstack image show $IMAGE_NAME 2>/dev/null
    if [ $? -ne 0 ]; then
        mkdir -p /tmp/images
        wget -P /tmp/images $IMAGE_URL

        openstack image create --file /tmp/images/$IMAGE_FILE \
          --disk-format qcow2 --container-format bare --public $IMAGE_NAME

        openstack image list

        yes | rm -r /tmp/images
    fi
}


function _nova_configure() {
    if [ -e "/etc/nova/nova.conf" ]; then
        crudini --set /etc/nova/nova.conf database connection mysql://$DB_USER_NOVA:$DB_PWD_NOVA@$CTRL_MGMT_IP/nova
        crudini --set /etc/nova/nova.conf DEFAULT rpc_backend rabbit
        crudini --set /etc/nova/nova.conf DEFAULT rabbit_host $CTRL_MGMT_IP
        crudini --set /etc/nova/nova.conf DEFAULT rabbit_password $RABBIT_PASS
        crudini --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
        crudini --set /etc/nova/nova.conf DEFAULT network_api_class nova.network.neutronv2.api.API
        crudini --set /etc/nova/nova.conf DEFAULT linuxnet_interface_driver nova.network.linux_net.LinuxOVSInterfaceDriver
        crudini --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
        crudini --set /etc/nova/nova.conf DEFAULT my_ip $MGMT_IP
        crudini --set /etc/nova/nova.conf DEFAULT vnc_enabled True
        crudini --set /etc/nova/nova.conf DEFAULT vncserver_listen 0.0.0.0
        crudini --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address $MGMT_IP
        crudini --set /etc/nova/nova.conf DEFAULT novncproxy_base_url http://$CTRL_MGMT_IP:6080/vnc_auto.html
        if [[ ${CONFIG_DRIVE^^} == 'TRUE' ]]; then
            crudini --set /etc/nova/nova.conf DEFAULT force_config_drive True
        else
            crudini --set /etc/nova/nova.conf DEFAULT force_config_drive False
        fi
        crudini --set /etc/nova/nova.conf DEFAULT debug True

        crudini --set /etc/nova/nova.conf keystone_authtoken auth_uri http://$CTRL_MGMT_IP:5000/v2.0
        crudini --set /etc/nova/nova.conf keystone_authtoken identity_uri http://$CTRL_MGMT_IP:35357
        crudini --set /etc/nova/nova.conf keystone_authtoken admin_tenant_name $KEYSTONE_T_NAME_SERVICE
        crudini --set /etc/nova/nova.conf keystone_authtoken admin_user $KEYSTONE_U_NOVA
        crudini --set /etc/nova/nova.conf keystone_authtoken admin_password $KEYSTONE_U_PWD_NOVA

        crudini --set /etc/nova/nova.conf glance host $CTRL_MGMT_IP
        crudini --set /etc/nova/nova.conf libvirt virt_type qemu

        crudini --set /etc/nova/nova.conf neutron url http://$CTRL_MGMT_IP:9696
        crudini --set /etc/nova/nova.conf neutron auth_url http://$CTRL_MGMT_IP:35357
        crudini --set /etc/nova/nova.conf neutron auth_plugin password
        crudini --set /etc/nova/nova.conf neutron project_domain_id default
        crudini --set /etc/nova/nova.conf neutron user_domain_id default
        crudini --set /etc/nova/nova.conf neutron region_name $REGION
        crudini --set /etc/nova/nova.conf neutron project_name $KEYSTONE_T_NAME_SERVICE
        crudini --set /etc/nova/nova.conf neutron username $KEYSTONE_U_NEUTRON
        crudini --set /etc/nova/nova.conf neutron password $KEYSTONE_U_PWD_NEUTRON
        crudini --set /etc/nova/nova.conf neutron service_metadata_proxy True
        crudini --set /etc/nova/nova.conf neutron metadata_proxy_shared_secret $METADATA_SECRET

        crudini --set /etc/nova/nova.conf cinder os_region_name $REGION
    fi
}


function nova_ctrl() {
    ## nova controller
    yum install -y openstack-nova-api openstack-nova-cert openstack-nova-conductor \
      openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler

    _nova_configure

    su -s /bin/sh -c "nova-manage db sync" nova

    systemctl enable openstack-nova-api.service openstack-nova-cert.service \
      openstack-nova-consoleauth.service openstack-nova-scheduler.service \
      openstack-nova-conductor.service openstack-nova-novncproxy.service
    systemctl restart openstack-nova-api.service openstack-nova-cert.service \
      openstack-nova-consoleauth.service openstack-nova-scheduler.service \
      openstack-nova-conductor.service openstack-nova-novncproxy.service

}


function nova_compute() {
    yum install -y openstack-nova-compute sysfsutils
    _nova_configure
    systemctl enable libvirtd.service openstack-nova-compute.service
    systemctl restart libvirtd.service openstack-nova-compute.service
}


function _neutron_dvr_configure() {
    echo "starting _neutron_dvr_configure ..."

    if [[ "${DVR^^}" == 'TRUE' ]]; then
        if [[ 'neutron_ctrl' =~ "$1" ]]; then
            # enable dvr
            crudini --set /etc/neutron/neutron.conf DEFAULT router_distributed True
        fi

        if [[ 'neutron_network ' =~ "$1" ]]; then
            crudini --set /etc/neutron/l3_agent.ini DEFAULT agent_mode dvr_snat
            crudini --set /etc/neutron/l3_agent.ini DEFAULT router_namespaces True

            ovs-vsctl --may-exist add-br br-ex
            ovs-vsctl --may-exist add-port br-ex $INTERFACE_EXT
        fi

        if [[ 'neutron_compute ' =~ "$1" ]]; then
            yum install -y openstack-neutron

            crudini --set /etc/neutron/l3_agent.ini DEFAULT agent_mode dvr
            crudini --set /etc/neutron/l3_agent.ini DEFAULT router_namespaces True

            ovs-vsctl --may-exist add-br br-ex
            ovs-vsctl --may-exist add-port br-ex $INTERFACE_EXT

            systemctl enable neutron-l3-agent.service
            systemctl restart neutron-l3-agent.service
        fi

        if [[ "$ML2_PLUGIN" == 'openvswitch' ]]; then
            for file in /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/openvswitch_agent.ini ; do
                if [ -e $file ]; then
                    crudini --set $file ovs tunnel_bridge br-tun
                    crudini --set $file agent enable_distributed_routing True
                    crudini --set $file agent l2_population True
                fi
            done
        fi
    fi
}


function _neutron_configure() {
    ## config neutron.conf
    if [ -z "$KEYSTONE_T_ID_SERVICE" ]; then
        export KEYSTONE_T_ID_SERVICE=$(openstack project show service | grep '| id' | awk '{print $4}')
    fi
    if [ -e "/etc/neutron/neutron.conf" ]; then
        crudini --set /etc/neutron/neutron.conf DEFAULT debug True
        crudini --set /etc/neutron/neutron.conf DEFAULT rpc_backend rabbit
        crudini --set /etc/neutron/neutron.conf DEFAULT rabbit_host $CTRL_MGMT_IP
        crudini --set /etc/neutron/neutron.conf DEFAULT rabbit_password $RABBIT_PASS
        crudini --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone
        crudini --set /etc/neutron/neutron.conf DEFAULT core_plugin ml2
        crudini --set /etc/neutron/neutron.conf DEFAULT service_plugins router
        crudini --set /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips True
        crudini --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_status_changes True
        crudini --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_data_changes True
        crudini --set /etc/neutron/neutron.conf DEFAULT nova_url http://$CTRL_MGMT_IP:8774/v2
        crudini --set /etc/neutron/neutron.conf DEFAULT nova_admin_auth_url http://$CTRL_MGMT_IP:35357/v2.0/
        crudini --set /etc/neutron/neutron.conf DEFAULT nova_region_name regionOne
        crudini --set /etc/neutron/neutron.conf DEFAULT nova_admin_username $KEYSTONE_U_NOVA
        crudini --set /etc/neutron/neutron.conf DEFAULT nova_admin_tenant_id $KEYSTONE_T_ID_SERVICE
        crudini --set /etc/neutron/neutron.conf DEFAULT nova_admin_password $KEYSTONE_U_PWD_NOVA

        crudini --set /etc/neutron/neutron.conf database connection mysql://$DB_USER_NEUTRON:$DB_PWD_NEUTRON@$CTRL_MGMT_IP/neutron

        crudini --del /etc/neutron/neutron.conf keystone_authtoken identity_uri
        crudini --del /etc/neutron/neutron.conf keystone_authtoken admin_tenant_name
        crudini --del /etc/neutron/neutron.conf keystone_authtoken admin_user
        crudini --del /etc/neutron/neutron.conf keystone_authtoken admin_password
        crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_uri http://$CTRL_MGMT_IP:5000
        crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_url http://$CTRL_MGMT_IP:35357
        crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_plugin password
        crudini --set /etc/neutron/neutron.conf keystone_authtoken project_domain_id default
        crudini --set /etc/neutron/neutron.conf keystone_authtoken user_domain_id default
        crudini --set /etc/neutron/neutron.conf keystone_authtoken project_name $KEYSTONE_T_NAME_SERVICE
        crudini --set /etc/neutron/neutron.conf keystone_authtoken username $KEYSTONE_U_NEUTRON
        crudini --set /etc/neutron/neutron.conf keystone_authtoken password $KEYSTONE_U_PWD_NEUTRON
    fi

    ## /etc/neutron/plugins/ml2/ml2_conf.ini
    if [ -e "/etc/neutron/plugins/ml2/ml2_conf.ini" ]; then
        crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers flat,$TYPE_DR
        crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types $TYPE_DR
        crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers $ML2_PLUGIN,l2population
        crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 external_network_type flat
        crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vni_ranges 1:1000
        crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_security_group True
        crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset True
        crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver

        crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini agent root_helper 'sudo neutron-rootwrap /etc/neutron/rootwrap.conf'
        crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini agent root_helper_daemon 'sudo /usr/bin/neutron-rootwrap-daemon /etc/neutron/rootwrap.conf'

        if [ $ML2_PLUGIN == 'openvswitch' ]; then
            for file in /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/openvswitch_agent.ini ; do
                if [ -e $file ]; then
                    crudini --set $file ovs integration_bridge br-int
                    ## crudini --set $file ovs bridge_mappings external:br-ex

                    if [[ $TYPE_DR =~ (^|[,])'vxlan'($|[,]) ]]; then
                        crudini --set $file ovs local_ip $INTERFACE_INT_IP
                        crudini --set $file ovs tunnel_bridge br-tun
                        TUNNEL_TYPES=vxlan
                        crudini --set $file agent tunnel_types $TUNNEL_TYPES

                        ovs-vsctl --may-exist add-br br-tun
                    fi

                    if [[ $TYPE_DR =~ (^|[,])'gre'($|[,]) ]]; then
                        crudini --set $file ovs local_ip $INTERFACE_INT_IP
                        crudini --set $file ovs tunnel_bridge br-tun
                        if [[ -z $TUNNEL_TYPES ]]; then
                            TUNNEL_TYPES="gre"
                         else
                            TUNNEL_TYPES="$TUNNEL_TYPES,gre"
                         fi
                         crudini --set $file agent tunnel_types $TUNNEL_TYPES

                         ovs-vsctl --may-exist add-br br-tun
                    fi

                    if [[ $TYPE_DR =~ (^|[,])'vlan'($|[,]) ]]; then
                        crudini --set $file ovs network_vlan_ranges physnet1:$VLAN_RANGES
                        crudini --set $file ovs bridge_mappings physnet1:br-vlan

                        ovs-vsctl --may-exist add-br br-vlan
                        ovs-vsctl --may-exist add-port br-ex $INTERFACE_INT
                    fi
                fi
            done
        fi
    fi

    if [ ! -e "/etc/neutron/plugin.ini" ]; then
        ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
    fi

    ## configure the Layer-3 (L3) agent /etc/neutron/l3_agent.ini
    if [ -e "/etc/neutron/l3_agent.ini" ]; then
        crudini --set /etc/neutron/l3_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
        crudini --set /etc/neutron/l3_agent.ini DEFAULT use_namespaces True
        crudini --set /etc/neutron/l3_agent.ini DEFAULT external_network_bridge br-ex
        crudini --set /etc/neutron/l3_agent.ini DEFAULT router_delete_namespaces True
        crudini --set /etc/neutron/l3_agent.ini DEFAULT debug True
    fi

    ## configure the DHCP agent /etc/neutron/dhcp_agent.ini
    if [ -e "/etc/neutron/dhcp_agent.ini" ]; then
        cccrudini --set /etc/neutron/dhcp_agent.ini DEFAULT debug True
        crudini --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
        crudini --set /etc/neutron/dhcp_agent.ini DEFAULT dhcp_driver neutron.agent.linux.dhcp.Dnsmasq
        crudini --set /etc/neutron/dhcp_agent.ini DEFAULT use_namespaces True
        crudini --set /etc/neutron/dhcp_agent.ini DEFAULT dhcp_delete_namespaces True

        crudini --set /etc/neutron/dhcp_agent.ini DEFAULT dnsmasq_config_file /etc/neutron/dnsmasq-neutron.conf
        if [ ! -e "/etc/neutron/dnsmasq-neutron.conf" ]; then
            echo "dhcp-option-force=26,1454" > /etc/neutron/dnsmasq-neutron.conf
            chown -R neutron:neutron /etc/neutron
        fi

        crudini --set /etc/neutron/dhcp_agent.ini DEFAULT debug True
    fi

    ## config metadata agent /etc/neutron/metadata_agent.ini
    if [ -e "/etc/neutron/metadata_agent.ini" ]; then
        crudini --set /etc/neutron/metadata_agent.ini DEFAULT auth_url http://$CTRL_MGMT_IP:5000/v2.0
        crudini --set /etc/neutron/metadata_agent.ini DEFAULT auth_region $REGION
        crudini --set /etc/neutron/metadata_agent.ini DEFAULT admin_tenant_name $KEYSTONE_T_NAME_SERVICE
        crudini --set /etc/neutron/metadata_agent.ini DEFAULT admin_user $KEYSTONE_U_NEUTRON
        crudini --set /etc/neutron/metadata_agent.ini DEFAULT admin_password $KEYSTONE_U_PWD_NEUTRON
        crudini --set /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_ip $CTRL_MGMT_IP
        crudini --set /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret $METADATA_SECRET
        crudini --set /etc/neutron/metadata_agent.ini DEFAULT debug True
    fi

    _neutron_dvr_configure $1
}


function neutron_ctrl() {
    # neutron
    yum install -y openstack-neutron openstack-neutron-ml2 which

    _neutron_configure neutron_ctrl

    su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron

    systemctl enable neutron-server.service
    systemctl restart neutron-server.service
}


function neutron_compute() {
    # install neutron components on compute nodes
    yum install -y openstack-neutron-ml2 openstack-neutron-openvswitch ipset

    _neutron_configure neutron_compute

    systemctl restart openstack-nova-compute.service
    systemctl enable openvswitch.service neutron-openvswitch-agent.service
    systemctl restart openvswitch.service neutron-openvswitch-agent.service

}


function neutron_network() {
    yum install -y openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch

    _neutron_configure neutron_network

    systemctl enable openvswitch.service
    systemctl restart openvswitch.service

    if [ $ML2_PLUGIN == 'openvswitch' ]; then
        for file in /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/openvswitch_agent.ini ; do
            if [ -e $file ]; then
                crudini --set $file ovs bridge_mappings external:br-ex
            fi
        done
    fi

    ovs-vsctl --may-exist add-br br-ex
    ovs-vsctl --may-exist add-port br-ex $INTERFACE_EXT

    systemctl enable neutron-openvswitch-agent.service neutron-l3-agent.service \
    neutron-dhcp-agent.service neutron-metadata-agent.service neutron-ovs-cleanup.service

    systemctl restart neutron-openvswitch-agent.service neutron-l3-agent.service \
    neutron-dhcp-agent.service neutron-metadata-agent.service
}



function cinder_ctrl() {
    # cinder ctrl
    yum install -y openstack-cinder

    crudini --set /etc/cinder/cinder.conf database connection mysql://$DB_USER_CINDER:$DB_PWD_CINDER@$CTRL_MGMT_IP/cinder
    crudini --set /etc/cinder/cinder.conf DEFAULT rpc_backend rabbit
    crudini --set /etc/cinder/cinder.conf DEFAULT auth_strategy keystone
    crudini --set /etc/cinder/cinder.conf DEFAULT my_ip $MGMT_IP
    crudini --set /etc/cinder/cinder.conf DEFAULT debug True

    crudini --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_host $CTRL_MGMT_IP
    crudini --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_password $RABBIT_PASS
    crudini --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_userid $RABBIT_USER
    crudini --set /etc/cinder/cinder.conf oslo_concurrency lock_path /var/lib/cinder/tmp

    crudini --set /etc/cinder/cinder.conf keymgr encryption_auth_url http://$CTRL_MGMT_IP:5000/v3

    crudini --del /etc/cinder/cinder.conf keystone_authtoken identity_uri
    crudini --del /etc/cinder/cinder.conf keystone_authtoken admin_tenant_name
    crudini --del /etc/cinder/cinder.conf keystone_authtoken admin_user
    crudini --del /etc/cinder/cinder.conf keystone_authtoken admin_password
    crudini --set /etc/cinder/cinder.conf keystone_authtoken auth_uri http://$CTRL_MGMT_IP:5000
    crudini --set /etc/cinder/cinder.conf keystone_authtoken auth_url http://$CTRL_MGMT_IP:35357
    crudini --set /etc/cinder/cinder.conf keystone_authtoken auth_plugin password
    crudini --set /etc/cinder/cinder.conf keystone_authtoken project_domain_id default
    crudini --set /etc/cinder/cinder.conf keystone_authtoken user_domain_id default
    crudini --set /etc/cinder/cinder.conf keystone_authtoken project_name $KEYSTONE_T_NAME_SERVICE
    crudini --set /etc/cinder/cinder.conf keystone_authtoken username $KEYSTONE_U_CINDER
    crudini --set /etc/cinder/cinder.conf keystone_authtoken password $KEYSTONE_U_PWD_CINDER

    su -s /bin/sh -c "cinder-manage db sync" cinder

    ##systemctl restart openstack-nova-api.service

    systemctl enable openstack-cinder-api.service openstack-cinder-scheduler.service
    systemctl restart openstack-cinder-api.service openstack-cinder-scheduler.service
}


function dashboard() {
    yum install -y openstack-dashboard memcached
    sed -i.bak "s#OPENSTACK_HOST = \"127.0.0.1\"#OPENSTACK_HOST = \"$CTRL_MGMT_IP\"#g" /etc/openstack-dashboard/local_settings
    sed -i "s#ALLOWED_HOSTS = \['horizon.example.com', 'localhost'\]#ALLOWED_HOSTS = \['*', \]#g" /etc/openstack-dashboard/local_settings
    sed -i "s#'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',#'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',\n\t'LOCATION': '127.0.0.1:11211',#g" /etc/openstack-dashboard/local_settings
    sed -i "s/^#OPENSTACK_API_VERSIONS = {/OPENSTACK_API_VERSIONS = {/g" /etc/openstack-dashboard/local_settings
    ## sed -i 's/^#    "identity": 3,/     "identity": 3,/g' /etc/openstack-dashboard/local_settings
    sed -i "s/^#    \"volume\": 2,/     \"volume\": 2,\n}/g" /etc/openstack-dashboard/local_settings

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


function help() {
    usage="./$(basename "$0") [-h] [rolenames]

This script help you to install specific openstack roles to the machine,
before run the script, you need to update the environment variables in the
head of the script according to your setup.

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
    ./ins.sh allinone

    # Install two roles(nova controller and neutron controller) in a machine
    ./ins.sh nova_ctrl neutron_ctrl
"

    if [ "$#" -eq 0 ]; then
        echo "$usage"
        exit
    fi

    while getopts ':h' option; do
      case "$option" in
        h) echo "$usage"
           exit
           ;;
        :) printf "missing argument for -%s\n" "$OPTARG" >&2
           echo "$usage" >&2
           exit 1
           ;;
       \?) printf "illegal option: -%s\n" "$OPTARG" >&2
           echo "$usage" >&2
           exit 1
           ;;
      esac
    done
    shift $((OPTIND - 1))
}


function _display() {
    sudo yum -y install figlet >& /dev/null

    if [[ "$?" != "0" ]]; then
        echo "Failed to install the package figlet"
        exit 1
    fi

    if [[ "$*" == "starting" ]]; then
        figlet -tf slant Openstack installer

    elif [[ "$*" == "completed" ]]; then
        figlet -tf slant Openstack installation $1
        echo "$LOGIN_INFO"

    else
        figlet -tf slant Openstack installation $1
    fi
}


function installation() {
    base
    for service in "$@"; do
        echo "##### Installing $service ..."
        $service
    done
}


function timestamp {
    awk '{ print strftime("%Y-%m-%d %H:%M:%S | "), $0; fflush(); }'
}


function main {
    help $@
    _display starting
    installation $@ | timestamp
    _display completed
}


main $@
