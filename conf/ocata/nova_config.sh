#!/usr/bin/env bash

function _nova_configure() {
    if [ -e "$NOVA_CONF" ]; then
        crudini --set $NOVA_CONF DEFAULT enabled_apis "osapi_compute,metadata"
        crudini --set $NOVA_CONF api_database connection mysql://$DB_USER_NOVA:$DB_PWD_NOVA@$DB_IP/nova_api
        crudini --set $NOVA_CONF database connection mysql://$DB_USER_NOVA:$DB_PWD_NOVA@$DB_IP/nova

        crudini --set $NOVA_CONF oslo_messaging_rabbit rabbit_ha_queues $RABBIT_HA
        crudini --set $NOVA_CONF DEFAULT transport_url "rabbit://$RABBIT_LIST"

        #crudini --set $NOVA_CONF DEFAULT rpc_backend rabbit
        #crudini --set $NOVA_CONF DEFAULT rabbit_host $RABBIT_IP
        #crudini --set $NOVA_CONF DEFAULT rabbit_password $RABBIT_PASS
        crudini --set $NOVA_CONF DEFAULT use_neutron True
        crudini --set $NOVA_CONF DEFAULT linuxnet_interface_driver nova.network.linux_net.LinuxOVSInterfaceDriver
        crudini --set $NOVA_CONF DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
        crudini --set $NOVA_CONF DEFAULT security_group_api neutron
        crudini --set $NOVA_CONF DEFAULT my_ip $MGMT_IP
        crudini --set $NOVA_CONF vnc vnc_enabled True
        crudini --set $NOVA_CONF vnc vncserver_listen 0.0.0.0
        crudini --set $NOVA_CONF vnc vncserver_proxyclient_address $MGMT_IP
        crudini --set $NOVA_CONF vnc novncproxy_base_url http://$CTRL_MGMT_IP:6080/vnc_auto.html
        crudini --set $NOVA_CONF cache memcache_servers "$MEMCACHED_SERVERS"
        crudini --set $NOVA_CONF cache enabled true
        crudini --set $NOVA_CONF cache backend oslo_cache.memcache_pool
        crudini --set $NOVA_CONF consoleauth token_ttl 600

        crudini --set $NOVA_CONF cells enable false
        crudini --set $NOVA_CONF cells name cell0

        if [[ ${CONFIG_DRIVE^^} == 'TRUE' ]]; then
            crudini --set $NOVA_CONF DEFAULT force_config_drive True
        else
            crudini --set $NOVA_CONF DEFAULT force_config_drive False
        fi

        crudini --set $NOVA_CONF DEFAULT debug $DEBUG

        crudini --set $NOVA_CONF api auth_strategy keystone

        crudini --set $NOVA_CONF keystone_authtoken auth_uri http://$CTRL_MGMT_IP:5000
        crudini --set $NOVA_CONF keystone_authtoken auth_url http://$CTRL_MGMT_IP:35357
        crudini --set $NOVA_CONF keystone_authtoken auth_type password
        crudini --set $NOVA_CONF keystone_authtoken project_domain_name default
        crudini --set $NOVA_CONF keystone_authtoken user_domain_name default
        crudini --set $NOVA_CONF keystone_authtoken project_name $KEYSTONE_T_NAME_SERVICE
        crudini --set $NOVA_CONF keystone_authtoken username $KEYSTONE_U_NOVA
        crudini --set $NOVA_CONF keystone_authtoken password $KEYSTONE_U_PWD_NOVA
        crudini --set $NOVA_CONF keystone_authtoken memcached_servers $MEMCACHED_SERVERS

        crudini --set $NOVA_CONF glance api_servers http://$CTRL_MGMT_IP:9292

        crudini --set $NOVA_CONF oslo_concurrency lock_path /var/lib/nova/tmp
        crudini --set $NOVA_CONF oslo_messaging_notifications driver noop

        crudini --set $NOVA_CONF placement os_region_name $REGION
        crudini --set $NOVA_CONF placement project_domain_name default
        crudini --set $NOVA_CONF placement project_name $KEYSTONE_T_NAME_SERVICE
        crudini --set $NOVA_CONF placement auth_type password
        #crudini --set $NOVA_CONF placement auth_uri http://$CTRL_MGMT_IP:5000
        crudini --set $NOVA_CONF placement auth_url http://$CTRL_MGMT_IP:35357/v3
        crudini --set $NOVA_CONF placement user_domain_name default
        crudini --set $NOVA_CONF placement username $KEYSTONE_U_PLACEMENT
        crudini --set $NOVA_CONF placement password $KEYSTONE_U_PWD_PLACEMENT

        # enable host aggregate to seperate FAC from LOG instances
        crudini --set $NOVA_CONF filter_scheduler enabled_filters AggregateInstanceExtraSpecsFilter,RetryFilter,AvailabilityZoneFilter,RamFilter,DiskFilter,ComputeFilter,ComputeCapabilitiesFilter,ImagePropertiesFilter,ServerGroupAntiAffinityFilter,ServerGroupAffinityFilter

        # Need to enable access to the Placement API by adding the following
        # configuration to /etc/httpd/conf.d/00-nova-placement-api.conf
        # due to a packaging bug.
        grep 'Directory /usr/bin' /etc/httpd/conf.d/00-nova-placement-api.conf || \
        cat >> /etc/httpd/conf.d/00-nova-placement-api.conf << EOF

<Directory /usr/bin>
   <IfVersion >= 2.4>
      Require all granted
   </IfVersion>
   <IfVersion < 2.4>
      Order allow,deny
      Allow from all
   </IfVersion>
</Directory>

EOF

        egrep -wo 'vmx|svm' /proc/cpuinfo > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            crudini --set $NOVA_CONF libvirt virt_type kvm
        else
            crudini --set $NOVA_CONF libvirt virt_type qemu
        fi

        crudini --set $NOVA_CONF neutron url http://$CTRL_MGMT_IP:9696
        crudini --set $NOVA_CONF neutron auth_url http://$CTRL_MGMT_IP:35357
        crudini --set $NOVA_CONF neutron auth_type password
        crudini --set $NOVA_CONF neutron project_domain_name default
        crudini --set $NOVA_CONF neutron user_domain_name default
        crudini --set $NOVA_CONF neutron region_name $REGION
        crudini --set $NOVA_CONF neutron project_name $KEYSTONE_T_NAME_SERVICE
        crudini --set $NOVA_CONF neutron username $KEYSTONE_U_NEUTRON
        crudini --set $NOVA_CONF neutron password $KEYSTONE_U_PWD_NEUTRON

        crudini --set $NOVA_CONF neutron service_metadata_proxy True
        crudini --set $NOVA_CONF neutron metadata_proxy_shared_secret $METADATA_SECRET

        crudini --set $NOVA_CONF cinder os_region_name $REGION

        if [ ! -z $1 ] && [[ 'nova_ctrl' =~ "$1" ]]; then
            crudini --set $NOVA_CONF scheduler discover_hosts_in_cells_interval 300
            su -s /bin/sh -c "nova-manage api_db sync" nova
            su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova
            su -s /bin/sh -c "nova-manage db sync" nova
        fi
    fi
}

function _nova_ssh_key_login() {
    if [ -z $SSH_PRIVATE_KEY ]; then
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "key pair is needed for nova compute to trust each other for resizing"
        return 0
    fi
    setenforce 0
    crudini --set /etc/selinux/config '' SELINUX permissive
    usermod -s /bin/bash nova
    mkdir /var/lib/nova/.ssh
    echo "$SSH_PRIVATE_KEY" > /var/lib/nova/.ssh/id_rsa
    echo "$SSH_PUBLIC_KEY" > /var/lib/nova/.ssh/authorized_keys
    echo 'StrictHostKeyChecking no' > /var/lib/nova/.ssh/config
    chown nova:nova /var/lib/nova/.ssh -R
    chmod 600 /var/lib/nova/.ssh/id_rsa /var/lib/nova/.ssh/authorized_keys
}

function _nova_map_hosts_cell0 {
    nova-manage cell_v2 map_cell_and_hosts --name cell0
    nova-manage cell_v2 discover_hosts
}
