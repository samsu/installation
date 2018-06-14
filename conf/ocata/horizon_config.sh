function _horizon_configure() {
    _CONF='/etc/openstack-dashboard/local_settings'
    crudini --set $_CONF '' OPENSTACK_HOST "\"$CTRL_MGMT_IP\""
    crudini --set $_CONF '' ALLOWED_HOSTS "['*', ]"
    sed -i "s#'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',#'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',\n\t'LOCATION': '$CTRL_MGMT_IP:11211',#g" $_CONF
    crudini --set $_CONF '' OPENSTACK_KEYSTONE_URL '"http://%s:5000/v3" % OPENSTACK_HOST'
    sed -i "s/^#OPENSTACK_API_VERSIONS = {/OPENSTACK_API_VERSIONS = {/g" $_CONF
    sed -i 's/^#    "identity": 3,/     "identity": 3,/g' $_CONF
    sed -i "s/^#    \"volume\": 2,/     \"volume\": 2,\n}/g" $_CONF
    # due to the bug https://bugzilla.redhat.com/show_bug.cgi?id=1478042
    # need to add the following file to the file /etc/httpd/conf.d/openstack-dashboard.conf
    grep "WSGIApplicationGroup %{GLOBAL}" /etc/httpd/conf.d/openstack-dashboard.conf || echo "WSGIApplicationGroup %{GLOBAL}" >> /etc/httpd/conf.d/openstack-dashboard.conf
}
