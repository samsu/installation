function _neutron_dvr_configure() {
    echo "starting _neutron_dvr_configure ..."

    if [[ "${DVR^^}" == 'TRUE' ]]; then
        if [[ 'neutron_ctrl' =~ "$1" ]]; then
            # enable dvr
            crudini --set $NEUTRON_CONF DEFAULT router_distributed True
        fi

        if [[ 'neutron_network' =~ "$1" ]]; then
            crudini --set /etc/neutron/l3_agent.ini DEFAULT agent_mode dvr_snat
            crudini --set /etc/neutron/l3_agent.ini DEFAULT router_namespaces True

            ovs-vsctl --may-exist add-br br-ex
            ovs-vsctl --may-exist add-port br-ex $INTERFACE_EXT
        fi

        if [[ 'neutron_compute' =~ "$1" ]]; then
            yum install -y openstack-neutron

            crudini --set /etc/neutron/l3_agent.ini DEFAULT agent_mode dvr
            crudini --set /etc/neutron/l3_agent.ini DEFAULT router_namespaces True

            ovs-vsctl --may-exist add-br br-ex
            ovs-vsctl --may-exist add-port br-ex $INTERFACE_EXT

            systemctl enable neutron-l3-agent.service
            systemctl restart neutron-l3-agent.service
        fi

        if [[ "$ML2_PLUGIN" == 'openvswitch' ]]; then
            for file in /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/openvswitch_agent.ini ; do
                if [ -e $file ]; then
                    crudini --set $file ovs tunnel_bridge br-tun
                    crudini --set $file agent enable_distributed_routing True
                    crudini --set $file agent l2_population True
                fi
            done
        fi
    fi
}


function _neutron_configure() {
    ## config neutron.conf
    if [ -z "$KEYSTONE_T_ID_SERVICE" ]; then
        export KEYSTONE_T_ID_SERVICE=$(openstack project show service | grep '| id' | awk '{print $4}')
    fi
    # $NEUTRON_CONF configuration
    if [ -e "$NEUTRON_CONF" ]; then
        crudini --set $NEUTRON_CONF DEFAULT debug True
        crudini --set $NEUTRON_CONF DEFAULT rpc_backend rabbit
        crudini --set $NEUTRON_CONF DEFAULT auth_strategy keystone
        crudini --set $NEUTRON_CONF DEFAULT core_plugin ml2
        crudini --set $NEUTRON_CONF DEFAULT service_plugins router
        crudini --set $NEUTRON_CONF DEFAULT allow_overlapping_ips True
        crudini --set $NEUTRON_CONF DEFAULT notify_nova_on_port_status_changes True
        crudini --set $NEUTRON_CONF DEFAULT notify_nova_on_port_data_changes True

        crudini --set $NEUTRON_CONF oslo_messaging_rabbit rabbit_host $CTRL_MGMT_IP
        crudini --set $NEUTRON_CONF oslo_messaging_rabbit rabbit_userid guest
        crudini --set $NEUTRON_CONF oslo_messaging_rabbit rabbit_password $RABBIT_PASS

        crudini --set $NEUTRON_CONF nova auth_url http://$CTRL_MGMT_IP:35357
        crudini --set $NEUTRON_CONF nova auth_type password
        crudini --set $NEUTRON_CONF nova region_name $REGION
        crudini --set $NEUTRON_CONF nova project_domain_name default
        crudini --set $NEUTRON_CONF nova user_domain_name default
        crudini --set $NEUTRON_CONF nova project_name $KEYSTONE_T_NAME_SERVICE
        crudini --set $NEUTRON_CONF nova username $KEYSTONE_U_NOVA
        crudini --set $NEUTRON_CONF nova password $KEYSTONE_U_PWD_NOVA

        crudini --set $NEUTRON_CONF database connection mysql://$DB_USER_NEUTRON:$DB_PWD_NEUTRON@$CTRL_MGMT_IP/neutron

        crudini --del $NEUTRON_CONF keystone_authtoken identity_uri
        crudini --del $NEUTRON_CONF keystone_authtoken admin_tenant_name
        crudini --del $NEUTRON_CONF keystone_authtoken admin_user
        crudini --del $NEUTRON_CONF keystone_authtoken admin_password

        crudini --set $NEUTRON_CONF keystone_authtoken auth_uri http://$CTRL_MGMT_IP:5000
        crudini --set $NEUTRON_CONF keystone_authtoken auth_url http://$CTRL_MGMT_IP:35357
        crudini --set $NEUTRON_CONF keystone_authtoken auth_plugin password
        crudini --set $NEUTRON_CONF keystone_authtoken project_domain_name default
        crudini --set $NEUTRON_CONF keystone_authtoken user_domain_name default
        crudini --set $NEUTRON_CONF keystone_authtoken project_name $KEYSTONE_T_NAME_SERVICE
        crudini --set $NEUTRON_CONF keystone_authtoken username $KEYSTONE_U_NEUTRON
        crudini --set $NEUTRON_CONF keystone_authtoken password $KEYSTONE_U_PWD_NEUTRON
        crudini --set $NEUTRON_CONF keystone_authtoken memcached_servers $CTRL_MGMT_IP:11211
    fi

    ## /etc/neutron/plugins/ml2/ml2_conf.ini
    if [ -e "/etc/neutron/plugins/ml2/ml2_conf.ini" ]; then
        crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers flat,$TYPE_DR
        crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types $TYPE_DR
        crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers $ML2_PLUGIN,l2population
        crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 external_network_type flat
        crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vni_ranges 1:1000
        crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_security_group True
        crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset True

        crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver $SECURITY_GROUP_DR
        crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini agent root_helper 'sudo neutron-rootwrap /etc/neutron/rootwrap.conf'
        crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini agent root_helper_daemon 'sudo /usr/bin/neutron-rootwrap-daemon /etc/neutron/rootwrap.conf'

        if [ $ML2_PLUGIN == 'openvswitch' ]; then
            for file in /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/openvswitch_agent.ini ; do
                if [ -e $file ]; then
                    crudini --set $file ovs integration_bridge br-int
                    ## crudini --set $file ovs bridge_mappings external:br-ex

                    if [[ $TYPE_DR =~ (^|[,])'vxlan'($|[,]) ]]; then
                        crudini --set $file ovs local_ip $INTERFACE_INT_IP
                        crudini --set $file ovs tunnel_bridge br-tun
                        TUNNEL_TYPES=vxlan
                        crudini --set $file agent tunnel_types $TUNNEL_TYPES

                        ovs-vsctl --may-exist add-br br-tun
                    fi

                    if [[ $TYPE_DR =~ (^|[,])'gre'($|[,]) ]]; then
                        crudini --set $file ovs local_ip $INTERFACE_INT_IP
                        crudini --set $file ovs tunnel_bridge br-tun
                        if [[ -z $TUNNEL_TYPES ]]; then
                            TUNNEL_TYPES="gre"
                         else
                            TUNNEL_TYPES="$TUNNEL_TYPES,gre"
                         fi
                         crudini --set $file agent tunnel_types $TUNNEL_TYPES

                         ovs-vsctl --may-exist add-br br-tun
                    fi

                    if [[ $TYPE_DR =~ (^|[,])'vlan'($|[,]) ]]; then
                        crudini --set $file ovs network_vlan_ranges physnet1:$VLAN_RANGES
                        crudini --set $file ovs bridge_mappings physnet1:br-vlan

                        ovs-vsctl --may-exist add-br br-vlan
                        ovs-vsctl --may-exist add-port br-vlan $INTERFACE_INT
                    fi
                fi
            done
        fi
    fi

    if [ ! -e "/etc/neutron/plugin.ini" ]; then
        ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
    fi

    ## configure the Layer-3 (L3) agent /etc/neutron/l3_agent.ini
    if [ -e "/etc/neutron/l3_agent.ini" ]; then
        crudini --set /etc/neutron/l3_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
        crudini --set /etc/neutron/l3_agent.ini DEFAULT use_namespaces True
        crudini --set /etc/neutron/l3_agent.ini DEFAULT external_network_bridge br-ex
        crudini --set /etc/neutron/l3_agent.ini DEFAULT router_delete_namespaces True
        crudini --set /etc/neutron/l3_agent.ini DEFAULT debug True
    fi

    ## configure the DHCP agent /etc/neutron/dhcp_agent.ini
    if [ -e "/etc/neutron/dhcp_agent.ini" ]; then
        cccrudini --set /etc/neutron/dhcp_agent.ini DEFAULT debug True
        crudini --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
        crudini --set /etc/neutron/dhcp_agent.ini DEFAULT dhcp_driver neutron.agent.linux.dhcp.Dnsmasq
        crudini --set /etc/neutron/dhcp_agent.ini DEFAULT use_namespaces True
        crudini --set /etc/neutron/dhcp_agent.ini DEFAULT dhcp_delete_namespaces True

        crudini --set /etc/neutron/dhcp_agent.ini DEFAULT dnsmasq_config_file /etc/neutron/dnsmasq-neutron.conf
        if [ ! -e "/etc/neutron/dnsmasq-neutron.conf" ]; then
            echo "dhcp-option-force=26,1454" > /etc/neutron/dnsmasq-neutron.conf
            chown -R neutron:neutron /etc/neutron
        fi

        crudini --set /etc/neutron/dhcp_agent.ini DEFAULT debug True
    fi

    ## config metadata agent /etc/neutron/metadata_agent.ini
    if [ -e "/etc/neutron/metadata_agent.ini" ]; then
        crudini --set /etc/neutron/metadata_agent.ini DEFAULT auth_url http://$CTRL_MGMT_IP:5000/v3
        crudini --set /etc/neutron/metadata_agent.ini DEFAULT auth_region $REGION
        crudini --set /etc/neutron/metadata_agent.ini DEFAULT admin_tenant_name $KEYSTONE_T_NAME_SERVICE
        crudini --set /etc/neutron/metadata_agent.ini DEFAULT admin_user $KEYSTONE_U_NEUTRON
        crudini --set /etc/neutron/metadata_agent.ini DEFAULT admin_password $KEYSTONE_U_PWD_NEUTRON
        crudini --set /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_ip $CTRL_MGMT_IP
        crudini --set /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret $METADATA_SECRET
        crudini --set /etc/neutron/metadata_agent.ini DEFAULT debug True
    fi

    _neutron_dvr_configure $1
}