#!/usr/bin/env bash

function _glance_configure() {
    crudini --set /etc/glance/glance-api.conf database connection mysql://$DB_USER_GLANCE:$DB_PWD_GLANCE@$DB_IP/glance
    crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_uri http://$CTRL_MGMT_IP:5000
    crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_url http://$CTRL_MGMT_IP:35357
    crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_type password
    crudini --set /etc/glance/glance-api.conf keystone_authtoken project_domain_name default
    crudini --set /etc/glance/glance-api.conf keystone_authtoken user_domain_name default
    crudini --set /etc/glance/glance-api.conf keystone_authtoken project_name $KEYSTONE_T_NAME_SERVICE
    crudini --set /etc/glance/glance-api.conf keystone_authtoken username $KEYSTONE_U_GLANCE
    crudini --set /etc/glance/glance-api.conf keystone_authtoken password $KEYSTONE_U_PWD_GLANCE
    crudini --set /etc/glance/glance-api.conf keystone_authtoken memcached_servers $CTRL_MGMT_IP:11211

    crudini --set /etc/glance/glance-api.conf paste_deploy flavor keystone

    crudini --set /etc/glance/glance-api.conf DEFAULT debug $DEBUG
    crudini --set /etc/glance/glance-api.conf DEFAULT notification_driver noop

    if [[ $GLANCE_STOR_BACKEND == "cinder" ]]; then
        crudini --set /etc/glance/glance-api.conf glance_store stores file,http,swift,cinder
        crudini --set /etc/glance/glance-api.conf glance_store default_store cinder
        crudini --set /etc/glance/glance-api.conf glance_store cinder_store_auth_address http://$CTRL_MGMT_IP:5000/v2.0
        crudini --set /etc/glance/glance-api.conf glance_store cinder_catalog_info volumev2::publicURL
        crudini --set /etc/glance/glance-api.conf glance_store rootwrap_config /etc/glance/rootwrap.conf
        crudini --set /etc/glance/glance-api.conf store_type_location_strategy store_type_preference cinder,file,http
        crudini --set /etc/glance/glance-api.conf store_type_location_strategy location_strategy store_type
        cat > /etc/glance/rootwrap.conf << EOF
[DEFAULT]
filters_path=/etc/cinder/rootwrap.d
exec_dirs=/sbin,/usr/sbin,/bin,/usr/bin,/usr/local/bin,/usr/local/sbin
use_syslog=False
syslog_log_facility=syslog
syslog_log_level=ERROR
EOF
    fi
         

    crudini --set /etc/glance/glance-registry.conf database connection mysql://$DB_USER_GLANCE:$DB_PWD_GLANCE@$DB_IP/glance
    crudini --set /etc/glance/glance-registry.conf keystone_authtoken auth_uri http://$CTRL_MGMT_IP:5000
    crudini --set /etc/glance/glance-registry.conf keystone_authtoken auth_url http://$CTRL_MGMT_IP:35357
    crudini --set /etc/glance/glance-registry.conf keystone_authtoken auth_type password
    crudini --set /etc/glance/glance-registry.conf keystone_authtoken project_domain_name default
    crudini --set /etc/glance/glance-registry.conf keystone_authtoken user_domain_name default
    crudini --set /etc/glance/glance-registry.conf keystone_authtoken project_name $KEYSTONE_T_NAME_SERVICE
    crudini --set /etc/glance/glance-registry.conf keystone_authtoken username $KEYSTONE_U_GLANCE
    crudini --set /etc/glance/glance-registry.conf keystone_authtoken password $KEYSTONE_U_PWD_GLANCE
    crudini --set /etc/glance/glance-registry.conf keystone_authtoken memcached_servers $CTRL_MGMT_IP:11211

    crudini --set /etc/glance/glance-registry.conf paste_deploy flavor keystone

    crudini --set /etc/glance/glance-registry.conf DEFAULT debug $DEBUG
    crudini --set /etc/glance/glance-registry.conf DEFAULT notification_driver noop
}
