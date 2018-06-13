function _cinder_configure() {
    crudini --set $CINDER_CONF database connection mysql://$DB_USER_CINDER:$DB_PWD_CINDER@$DB_IP/cinder
    #crudini --set $CINDER_CONF DEFAULT rpc_backend rabbit
    crudini --set $CINDER_CONF DEFAULT auth_strategy keystone
    crudini --set $CINDER_CONF DEFAULT my_ip $STORAGE_IP
    crudini --set $CINDER_CONF DEFAULT debug $DEBUG
    crudini --set $CINDER_CONF DEFAULT transport_url "rabbit://$RABBIT_LIST"

    crudini --set $CINDER_CONF oslo_messaging_rabbit rabbit_ha_queues $RABBIT_HA
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
    crudini --set $CINDER_CONF keystone_authtoken username $KEYSTONE_U_CINDER
    crudini --set $CINDER_CONF keystone_authtoken password $KEYSTONE_U_PWD_CINDER
    crudini --set $CINDER_CONF keystone_authtoken memcached_servers $MEMCACHED_SERVERS
    crudini --set $CINDER_CONF oslo_messaging_notifications driver noop
    if [[ $GLANCE_STOR_BACKEND == "cinder" ]]; then
        crudini --set $CINDER_CONF DEFAULT image_upload_use_cinder_backend true
    fi
    case "$1" in
    'cinder_ctrl' )

    ;;

    'cinder_storage' )
        crudini --set $CINDER_CONF DEFAULT enabled_backends lvm
        crudini --set $CINDER_CONF DEFAULT glance_api_servers http://$CTRL_MGMT_IP:9292

        crudini --set $CINDER_CONF lvm volume_driver cinder.volume.drivers.lvm.LVMVolumeDriver
        crudini --set $CINDER_CONF lvm volume_group cinder-volumes
        crudini --set $CINDER_CONF lvm iscsi_protocol iscsi
        crudini --set $CINDER_CONF lvm iscsi_helper lioadm

        crudini --set $CINDER_CONF oslo_concurrency lock_path /var/lib/cinder/tmp
    ;;
    * ) echo "The inputed params $1 is invaild."
        exit 52
        ;;
    esac
}
