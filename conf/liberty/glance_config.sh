function _glance_configure() {
    crudini --set /etc/glance/glance-api.conf database connection mysql://$DB_USER_GLANCE:$DB_PWD_GLANCE@$CTRL_MGMT_IP/glance
    crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_uri http://$CTRL_MGMT_IP:5000
    crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_url http://$CTRL_MGMT_IP:35357
    crudini --set /etc/glance/glance-api.conf keystone_authtoken project_domain_name default
    crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_type password
    crudini --set /etc/glance/glance-api.conf keystone_authtoken user_domain_name default
    crudini --set /etc/glance/glance-api.conf keystone_authtoken admin_tenant_name $KEYSTONE_T_NAME_SERVICE
    crudini --set /etc/glance/glance-api.conf keystone_authtoken admin_user $KEYSTONE_U_GLANCE
    crudini --set /etc/glance/glance-api.conf keystone_authtoken admin_password $KEYSTONE_U_PWD_GLANCE
    crudini --set /etc/glance/glance-api.conf paste_deploy flavor keystone
    crudini --set /etc/glance/glance-api.conf DEFAULT notification_driver noop

    crudini --set /etc/glance/glance-registry.conf database connection mysql://$DB_USER_GLANCE:$DB_PWD_GLANCE@$CTRL_MGMT_IP/glance
    crudini --set /etc/glance/glance-registry.conf keystone_authtoken auth_uri http://$CTRL_MGMT_IP:5000
    crudini --set /etc/glance/glance-registry.conf keystone_authtoken auth_url http://$CTRL_MGMT_IP:35357
    crudini --set /etc/glance/glance-registry.conf keystone_authtoken project_domain_name default
    crudini --set /etc/glance/glance-registry.conf keystone_authtoken user_domain_name default
    crudini --set /etc/glance/glance-registry.conf keystone_authtoken auth_type password
    crudini --set /etc/glance/glance-registry.conf keystone_authtoken admin_tenant_name $KEYSTONE_T_NAME_SERVICE
    crudini --set /etc/glance/glance-registry.conf keystone_authtoken admin_user $KEYSTONE_U_GLANCE
    crudini --set /etc/glance/glance-registry.conf keystone_authtoken admin_password $KEYSTONE_U_PWD_GLANCE
    crudini --set /etc/glance/glance-registry.conf paste_deploy flavor keystone
    crudini --set /etc/glance/glance-registry.conf DEFAULT notification_driver noop
}

