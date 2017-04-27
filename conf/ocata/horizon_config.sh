function _horizon_configure() {
    crudini --set /etc/openstack-dashboard/local_settings '' OPENSTACK_HOST "\"$CTRL_MGMT_IP\""
    crudini --set /etc/openstack-dashboard/local_settings '' ALLOWED_HOSTS "['*', ]"
    crudini --set /etc/openstack-dashboard/local_settings '' CACHES "{
    'default': {
        'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',
        'LOCATION': '$CTRL_MGMT_IP:11211',
    },
}"
    crudini --set local_settings '' OPENSTACK_KEYSTONE_URL '"http://%s:5000/v3" % OPENSTACK_HOST'
    sed -i "s/^#OPENSTACK_API_VERSIONS = {/OPENSTACK_API_VERSIONS = {/g" /etc/openstack-dashboard/local_settings
    sed -i 's/^#    "identity": 3,/     "identity": 3,/g' /etc/openstack-dashboard/local_settings
    sed -i "s/^#    \"volume\": 2,/     \"volume\": 2,\n}/g" /etc/openstack-dashboard/local_settings
}
