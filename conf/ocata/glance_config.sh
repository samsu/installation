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
    crudini --set /etc/glance/glance-api.conf keystone_authtoken memcached_servers $MEMCACHED_SERVERS

    crudini --set /etc/glance/glance-api.conf paste_deploy flavor keystone

    crudini --set /etc/glance/glance-api.conf DEFAULT debug $DEBUG
    crudini --set /etc/glance/glance-api.conf oslo_messaging_notifications driver noop

    if [[ "${GLANCE_STOR_BACKEND^^}" == 'CINDER' ]]; then
        crudini --set /etc/glance/glance-api.conf glance_store stores file,http,swift,cinder
        crudini --set /etc/glance/glance-api.conf glance_store default_store cinder
        crudini --set /etc/glance/glance-api.conf glance_store cinder_store_auth_address http://$CTRL_MGMT_IP:5000/v2.0
        crudini --set /etc/glance/glance-api.conf glance_store cinder_store_user_name $KEYSTONE_U_ADMIN 
        crudini --set /etc/glance/glance-api.conf glance_store cinder_store_project_name $KEYSTONE_T_NAME_ADMIN 
        crudini --set /etc/glance/glance-api.conf glance_store cinder_store_password $KEYSTONE_U_ADMIN_PWD
        crudini --set /etc/glance/glance-api.conf glance_store cinder_catalog_info volumev2::publicURL
        crudini --set /etc/glance/glance-api.conf glance_store rootwrap_config /etc/glance/rootwrap.conf
        crudini --set /etc/glance/glance-api.conf store_type_location_strategy store_type_preference cinder,file,http
        crudini --set /etc/glance/glance-api.conf store_type_location_strategy location_strategy store_type
        crudini --set /etc/glance/glance-api.conf privsep_osbrick helper_command "sudo /usr/bin/glance-rootwrap /etc/glance/rootwrap.conf privsep-helper --config-file /etc/glance/glance-api.conf"
        # due to this rdo bug, https://bugzilla.redhat.com/show_bug.cgi?id=1394559 rootwrap filters should be manually defined here.
        cat > /etc/glance/rootwrap.conf << EOF
[DEFAULT]
filters_path=/etc/glance/rootwrap.d
exec_dirs=/sbin,/usr/sbin,/bin,/usr/bin,/usr/local/bin,/usr/local/sbin
use_syslog=False
syslog_log_facility=syslog
syslog_log_level=ERROR
EOF
        cat > /etc/glance/rootwrap.d/glance_cinder_store.filters << EOF
# glance-rootwrap command filters for glance cinder store
# This file should be owned by (and only-writable by) the root user

[Filters]
# cinder store driver
disk_chown: RegExpFilter, chown, root, chown, \d+, /dev/(?!.*/\.\.).*

# os-brick
mount: CommandFilter, mount, root
blockdev: RegExpFilter, blockdev, root, blockdev, (--getsize64|--flushbufs), /dev/.*
tee: CommandFilter, tee, root
mkdir: CommandFilter, mkdir, root
chown: RegExpFilter, chown, root, chown root:root /etc/pstorage/clusters/(?!.*/\.\.).*
ip: CommandFilter, ip, root
dd: CommandFilter, dd, root
iscsiadm: CommandFilter, iscsiadm, root
aoe-revalidate: CommandFilter, aoe-revalidate, root
aoe-discover: CommandFilter, aoe-discover, root
aoe-flush: CommandFilter, aoe-flush, root
read_initiator: ReadFileFilter, /etc/iscsi/initiatorname.iscsi
multipath: CommandFilter, multipath, root
multipathd: CommandFilter, multipathd, root
systool: CommandFilter, systool, root
sg_scan: CommandFilter, sg_scan, root
cp: CommandFilter, cp, root
drv_cfg: CommandFilter, /opt/emc/scaleio/sdc/bin/drv_cfg, root, /opt/emc/scaleio/sdc/bin/drv_cfg, --query_guid
sds_cli: CommandFilter, /usr/local/bin/sds/sds_cli, root
vgc-cluster: CommandFilter, vgc-cluster, root
scsi_id: CommandFilter, /lib/udev/scsi_id, root
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
    crudini --set /etc/glance/glance-registry.conf keystone_authtoken memcached_servers $MEMCACHED_SERVERS
    crudini --set /etc/glance/glance-registry.conf keystone_authtoken service_token_roles_required true

    crudini --set /etc/glance/glance-registry.conf paste_deploy flavor keystone

    crudini --set /etc/glance/glance-registry.conf DEFAULT debug $DEBUG

    crudini --set /etc/glance/glance-registry.conf oslo_messaging_notifications driver noop
}
