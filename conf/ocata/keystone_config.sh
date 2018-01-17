function _keystone_add_user_role() {
    service=$1
    eval SERVICE_U=\$$(echo KEYSTONE_U_${service^^})
    eval SERVICE_U_PWD=\$$(echo KEYSTONE_U_PWD_${service^^})
    openstack user show $service 2>/dev/null
    if [ $? -ne 0 ]; then
        openstack user create --domain default --password $SERVICE_U_PWD $SERVICE_U
        openstack role add --project $KEYSTONE_T_NAME_SERVICE --user $SERVICE_U $KEYSTONE_R_NAME_ADMIN
    fi
}

function _keystone_configure() {
    crudini --set $KEYSTONE_CONF DEFAULT admin_token $ADMIN_TOKEN
    crudini --set $KEYSTONE_CONF DEFAULT debug $DEBUG
    crudini --set $KEYSTONE_CONF database connection mysql://$DB_USER_KEYSTONE:$DB_PWD_KEYSTONE@$DB_IP/keystone
    crudini --set $KEYSTONE_CONF token provider fernet
    #crudini --set $KEYSTONE_CONF token driver memcache

    keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
    keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
    #keystone-manage pki_setup --keystone-user keystone --keystone-group keystone

    mkdir -p /etc/keystone/fernet-keys
    chown -R keystone:keystone /etc/keystone
    chown -R keystone:keystone /var/log/keystone
    #chmod -R o-rwx /etc/keystone/ssl

    su -s /bin/sh -c "keystone-manage db_sync" keystone

    keystone-manage bootstrap --bootstrap-password $KEYSTONE_U_ADMIN_PWD \
      --bootstrap-admin-url http://$CTRL_MGMT_IP:35357/v3/ \
      --bootstrap-internal-url http://$CTRL_MGMT_IP:5000/v3/ \
      --bootstrap-public-url http://$CTRL_MGMT_IP:5000/v3/ \
      --bootstrap-region-id RegionOne

    # configure apache http server
    [[ -e /etc/httpd/conf.d/wsgi-keystone.conf ]] || ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/
    systemctl restart httpd.service || exit 11

    #export OS_TOKEN=$ADMIN_TOKEN
    #export OS_URL=http://$CTRL_MGMT_IP:35357/v3
    #export OS_IDENTITY_API_VERSION=3
    #if [[ -n $OS_AUTH_URL ]]; then
    #    unset OS_AUTH_URL
    #fi
    #set |grep OS_
    openstack domain show default || openstack domain create --description "Default Domain" default
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
                openstack service create --name keystone --description "OpenStack Identity v3" identity
                openstack endpoint create --region $REGION identity public http://$CTRL_MGMT_IP:5000/v3
                openstack endpoint create --region $REGION identity internal http://$CTRL_MGMT_IP:5000/v3
                openstack endpoint create --region $REGION identity admin http://$CTRL_MGMT_IP:35357/v3

            elif [ $service == 'glance' ] ; then
                openstack service create --name glance --description "OpenStack Image service" image
                openstack endpoint create --region $REGION image public http://$CTRL_MGMT_IP:9292
                openstack endpoint create --region $REGION image internal http://$CTRL_MGMT_IP:9292
                openstack endpoint create --region $REGION image admin http://$CTRL_MGMT_IP:9292

            elif  [ $service == 'nova' ] ; then
                openstack service create --name nova --description "OpenStack Compute" compute
                openstack endpoint create --region $REGION compute public http://$CTRL_MGMT_IP:8774/v2.1
                openstack endpoint create --region $REGION compute internal http://$CTRL_MGMT_IP:8774/v2.1
                openstack endpoint create --region $REGION compute admin http://$CTRL_MGMT_IP:8774/v2.1

                openstack service create --name placement --description "Placement API" placement
                openstack endpoint create --region $REGION placement public http://$CTRL_MGMT_IP:8778
                openstack endpoint create --region $REGION placement internal http://$CTRL_MGMT_IP:8778
                openstack endpoint create --region $REGION placement admin http://$CTRL_MGMT_IP:8778

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
            _keystone_add_user_role $service
            [ $service == 'nova' ] && _keystone_add_user_role placement
        fi
    done

    #catalog check for cinder v2
    grep -i volumev /etc/keystone/default_catalog.templates || cat >> /etc/keystone/default_catalog.templates << EOF
catalog.RegionOne.volumev2.publicURL = http://localhost:8776/v2/$(tenant_id)s
catalog.RegionOne.volumev2.adminURL = http://localhost:8776/v2/$(tenant_id)s
catalog.RegionOne.volumev2.internalURL = http://localhost:8776/v2/$(tenant_id)s
catalog.RegionOne.volumev2.name = Volume Service
EOF

    # disable the temporary authentication token mechanism
    _sections="pipeline:public_api pipeline:admin_api pipeline:api_v3"
    for section in $_sections; do
        cur_val=$(crudini --get /etc/keystone/keystone-paste.ini $section pipeline)
        if [[ $cur_val == *"admin_token_auth"* ]]; then
            new_val=${cur_val/admin_token_auth/}
            crudini --set /etc/keystone/keystone-paste.ini $section pipeline "$new_val"
        fi
    done

    export KEYSTONE_T_ID_SERVICE=$(openstack project show service | grep '| id' | awk '{print $4}')

    # test the admin user, request an authentication token
    openstack --os-auth-url http://$CTRL_MGMT_IP:35357/v3 \
        --os-project-domain-name default --os-user-domain-name default \
        --os-project-name $KEYSTONE_T_NAME_ADMIN \
        --os-username $KEYSTONE_U_ADMIN token issue
}