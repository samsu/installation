function _cinder_configure() {
    crudini --set $CINDER_CONF database connection mysql://$DB_USER_CINDER:$DB_PWD_CINDER@$DB_IP/cinder
    crudini --set $CINDER_CONF DEFAULT rpc_backend rabbit
    crudini --set $CINDER_CONF DEFAULT auth_strategy keystone
    crudini --set $CINDER_CONF DEFAULT my_ip $MGMT_IP
    crudini --set $CINDER_CONF DEFAULT debug $DEBUG

    crudini --set $CINDER_CONF DEFAULT rabbit_ha_queues $RABBIT_HA
    crudini --set $CINDER_CONF DEFAULT transport_url "rabbit://$RABBIT_LIST"
    #crudini --set $CINDER_CONF oslo_messaging_rabbit rabbit_host $RABBIT_IP
    #crudini --set $CINDER_CONF oslo_messaging_rabbit rabbit_password $RABBIT_PASS
    #crudini --set $CINDER_CONF oslo_messaging_rabbit rabbit_userid $RABBIT_USER
    crudini --set $CINDER_CONF oslo_concurrency lock_path /var/lib/cinder/tmp

    crudini --set $CINDER_CONF keymgr encryption_auth_url http://$CTRL_MGMT_IP:5000/v3

    crudini --del $CINDER_CONF keystone_authtoken identity_uri
    crudini --del $CINDER_CONF keystone_authtoken admin_tenant_name
    crudini --del $CINDER_CONF keystone_authtoken admin_user
    crudini --del $CINDER_CONF keystone_authtoken admin_password

    crudini --set $CINDER_CONF keystone_authtoken auth_uri http://$CTRL_MGMT_IP:5000
    crudini --set $CINDER_CONF keystone_authtoken auth_url http://$CTRL_MGMT_IP:35357
    crudini --set $CINDER_CONF keystone_authtoken project_domain_name default
    crudini --set $CINDER_CONF keystone_authtoken user_domain_name default
    crudini --set $CINDER_CONF keystone_authtoken auth_type password
    crudini --set $CINDER_CONF keystone_authtoken project_name $KEYSTONE_T_NAME_SERVICE
    crudini --set $CINDER_CONF keystone_authtoken username $KEYSTONE_U_NOVA
    crudini --set $CINDER_CONF keystone_authtoken password $KEYSTONE_U_PWD_NOVA
    crudini --set $CINDER_CONF keystone_authtoken memcached_servers $MEMCACHED_SERVERS
}
