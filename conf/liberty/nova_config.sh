function _nova_configure() {
    if [ -e "$NOVA_CONF" ]; then
        crudini --set $NOVA_CONF database connection mysql://$DB_USER_NOVA:$DB_PWD_NOVA@$CTRL_MGMT_IP/nova
        crudini --set $NOVA_CONF DEFAULT rpc_backend rabbit
        crudini --set $NOVA_CONF DEFAULT rabbit_host $CTRL_MGMT_IP
        crudini --set $NOVA_CONF DEFAULT rabbit_password $RABBIT_PASS
        crudini --set $NOVA_CONF DEFAULT auth_strategy keystone
        crudini --set $NOVA_CONF DEFAULT network_api_class nova.network.neutronv2.api.API
        crudini --set $NOVA_CONF DEFAULT linuxnet_interface_driver nova.network.linux_net.LinuxOVSInterfaceDriver
        #crudini --set $NOVA_CONF DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
        crudini --set $NOVA_CONF DEFAULT security_group_api neutron
        crudini --set $NOVA_CONF DEFAULT my_ip $MGMT_IP
        crudini --set $NOVA_CONF DEFAULT vnc_enabled True
        crudini --set $NOVA_CONF DEFAULT vncserver_listen 0.0.0.0
        crudini --set $NOVA_CONF DEFAULT vncserver_proxyclient_address $MGMT_IP
        crudini --set $NOVA_CONF DEFAULT novncproxy_base_url http://$CTRL_MGMT_IP:6080/vnc_auto.html
        if [[ ${CONFIG_DRIVE^^} == 'TRUE' ]]; then
            crudini --set $NOVA_CONF DEFAULT force_config_drive True
        else
            crudini --set $NOVA_CONF DEFAULT force_config_drive False
        fi
        crudini --set $NOVA_CONF DEFAULT debug True

        crudini --set $NOVA_CONF keystone_authtoken auth_uri http://$CTRL_MGMT_IP:5000/v3
        crudini --set $NOVA_CONF keystone_authtoken identity_uri http://$CTRL_MGMT_IP:35357
        crudini --set $NOVA_CONF keystone_authtoken admin_tenant_name $KEYSTONE_T_NAME_SERVICE
        crudini --set $NOVA_CONF keystone_authtoken admin_user $KEYSTONE_U_NOVA
        crudini --set $NOVA_CONF keystone_authtoken admin_password $KEYSTONE_U_PWD_NOVA

        crudini --set $NOVA_CONF glance host $CTRL_MGMT_IP
        crudini --set $NOVA_CONF libvirt virt_type qemu

        crudini --set $NOVA_CONF neutron url http://$CTRL_MGMT_IP:9696
        crudini --set $NOVA_CONF neutron auth_url http://$CTRL_MGMT_IP:35357
        crudini --set $NOVA_CONF neutron auth_plugin password
        crudini --set $NOVA_CONF neutron project_domain_id default
        crudini --set $NOVA_CONF neutron user_domain_id default
        crudini --set $NOVA_CONF neutron region_name $REGION
        crudini --set $NOVA_CONF neutron project_name $KEYSTONE_T_NAME_SERVICE
        crudini --set $NOVA_CONF neutron username $KEYSTONE_U_NEUTRON
        crudini --set $NOVA_CONF neutron password $KEYSTONE_U_PWD_NEUTRON
        crudini --set $NOVA_CONF neutron service_metadata_proxy True
        crudini --set $NOVA_CONF neutron metadata_proxy_shared_secret $METADATA_SECRET

        crudini --set $NOVA_CONF cinder os_region_name $REGION
        su -s /bin/sh -c "nova-manage db sync" nova 
    fi
}
