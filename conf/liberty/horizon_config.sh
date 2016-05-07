function _horizon_configure() {
    sed -i.bak "s#OPENSTACK_HOST = \"127.0.0.1\"#OPENSTACK_HOST = \"$CTRL_MGMT_IP\"#g" /etc/openstack-dashboard/local_settings
    sed -i "s#ALLOWED_HOSTS = \['horizon.example.com', 'localhost'\]#ALLOWED_HOSTS = \['*', \]#g" /etc/openstack-dashboard/local_settings
    sed -i "s#'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',#'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',\n\t'LOCATION': '127.0.0.1:11211',#g" /etc/openstack-dashboard/local_settings
    sed -i "s/^#OPENSTACK_API_VERSIONS = {/OPENSTACK_API_VERSIONS = {/g" /etc/openstack-dashboard/local_settings
    sed -i 's/^#    "identity": 3,/     "identity": 3,/g' /etc/openstack-dashboard/local_settings
    sed -i "s/^#    \"volume\": 2,/     \"volume\": 2,\n}/g" /etc/openstack-dashboard/local_settings
}
