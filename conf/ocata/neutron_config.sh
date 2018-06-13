#!/usr/bin/env bash

function _neutron_dvr_configure() {
    if [[ "${DVR^^}" == 'TRUE' ]]; then
        echo -e "\n#### Starting _neutron_dvr_configure ..."

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
            crudini --set /etc/neutron/l3_agent.ini DEFAULT agent_mode dvr
            crudini --set /etc/neutron/l3_agent.ini DEFAULT router_namespaces True

            ovs-vsctl --may-exist add-br br-ex
            ovs-vsctl --may-exist add-port br-ex $INTERFACE_EXT

            systemctl enable neutron-l3-agent.service
            systemctl restart neutron-l3-agent.service
        fi

        if [[ "$ML2_PLUGIN" == 'openvswitch' ]]; then
            for file in "$ML2_CONF" "$OVS_CONF" ; do
                if [ -e $file ]; then
                    crudini --set $file ml2 mechanism_drivers $ML2_PLUGIN,l2population
                    crudini --set $file ovs tunnel_bridge br-tun
                    crudini --set $file agent enable_distributed_routing True
                    crudini --set $file agent l2_population True
                fi
            done
        fi
    fi
}


function _neutron_fortinet_configure() {
    if [[ "${ENABLE_FORTINET_PLUGIN^^}" == 'TRUE' ]]; then
        if [[ -z $FORTINET_ADDRESS ]] || [[ -z $FORTINET_EXT_INTERFACE ]] || [[ -z $FORTINET_INT_INTERFACE ]]; then
            echo -e "\nThe following variables all need to be set according to
your environment:
FORTINET_ADDRESS=$FORTINET_ADDRESS
FORTINET_EXT_INTERFACE=$FORTINET_EXT_INTERFACE
FORTINET_INT_INTERFACE=$FORTINET_INT_INTERFACE
please set them and run again.
"
        exit 30
        fi

        echo -e "\n#### Starting _neutron_fortinet_configure ..."

        if [[ 'neutron_ctrl' =~ "$1" ]]; then
            if [ -e $ML2_CONF ]; then
                if [[ $TYPE_DR =~ (^|[,])'vxlan'($|[,]) ]]; then
                    # Not supported yet, pass
                    echo "Enabled the fortinet driver ENABLE_FORTINET_PLUGIN but assigned not supported TYPE_DRIVER $TYPE_DR"
                    exit 20
                fi

                if [[ $TYPE_DR =~ (^|[,])'gre'($|[,]) ]]; then
                    # Not supported yet, pass
                    echo "Enabled the fortinet driver ENABLE_FORTINET_PLUGIN but assigned not supported TYPE_DRIVER $TYPE_DR"
                    exit 20
                fi

                if [[ $TYPE_DR =~ (^|[,])'vlan'($|[,]) ]]; then
                    crudini --set $ML2_CONF ml2_fortinet npu_available ${FORTINET_NPU_AVAILABLE}
                    crudini --set $ML2_CONF ml2_fortinet tenant_network_type $TYPE_DR
                    crudini --set $ML2_CONF ml2_fortinet ext_interface ${FORTINET_EXT_INTERFACE}
                    crudini --set $ML2_CONF ml2_fortinet int_interface ${FORTINET_INT_INTERFACE}
                    crudini --set $ML2_CONF ml2_fortinet password ${FORTINET_PASSWORD}
                    crudini --set $ML2_CONF ml2_fortinet username ${FORTINET_USERNAME}
                    crudini --set $ML2_CONF ml2_fortinet protocol ${FORTINET_PROTOCOL}
                    crudini --set $ML2_CONF ml2_fortinet port ${FORTINET_PORT}
                    crudini --set $ML2_CONF ml2_fortinet address ${FORTINET_ADDRESS}
                    crudini --set $ML2_CONF ml2_fortinet enable_default_fwrule ${FORTINET_ENABLE_DEFAULT_FWRULE}

                    crudini --set $ML2_CONF ml2 mechanism_drivers fortinet,$ML2_PLUGIN
                fi
            fi

            if [[ $SERVICE_PLUGINS =~(^|[,])'fwaas_fortinet'($|[,]) ]]; then
                yum install -y openstack-neutron-fwaas
            fi
            ## install networking-fortinet from source instead of from python package
            pip install git+https://github.com/openstack/networking-fortinet@stable/$INS_OPENSTACK_RELEASE

            if [ -e $NEUTRON_CONF ]; then
                crudini --set $NEUTRON_CONF DEFAULT service_plugins $SERVICE_PLUGINS
            fi
        fi

    fi
}

function _neutron_configure() {
    ## config neutron.conf
    if [ -z "$KEYSTONE_T_ID_SERVICE" ]; then
        export KEYSTONE_T_ID_SERVICE=$(openstack project show service | grep '| id' | awk '{print $4}')
    fi

    # $NEUTRON_CONF configuration
    if [ -z $_NEUTRON_CONFIGED ]; then
        if [ -e "$NEUTRON_CONF" ]; then
            crudini --set $NEUTRON_CONF DEFAULT debug $DEBUG
            crudini --set $NEUTRON_CONF DEFAULT rpc_backend rabbit
            crudini --set $NEUTRON_CONF DEFAULT auth_strategy keystone
            crudini --set $NEUTRON_CONF DEFAULT core_plugin ml2
            crudini --set $NEUTRON_CONF DEFAULT service_plugins router
            crudini --set $NEUTRON_CONF DEFAULT allow_overlapping_ips True
            crudini --set $NEUTRON_CONF DEFAULT notify_nova_on_port_status_changes True
            crudini --set $NEUTRON_CONF DEFAULT notify_nova_on_port_data_changes True
            crudini --set $NEUTRON_CONF DEFAULT transport_url "rabbit://$RABBIT_LIST"
            crudini --set $NEUTRON_CONF DEFAULT dhcp_agents_per_network $NEUTRON_DHCP_PER_NET
            #crudini --set $NEUTRON_CONF oslo_messaging_rabbit rabbit_host $RABBIT_IP
            #crudini --set $NEUTRON_CONF oslo_messaging_rabbit rabbit_userid guest
            #crudini --set $NEUTRON_CONF oslo_messaging_rabbit rabbit_password $RABBIT_PASS
            crudini --set $NEUTRON_CONF oslo_messaging_rabbit rabbit_ha_queues $RABBIT_HA
            crudini --set $NEUTRON_CONF oslo_concurrency lock_path /var/lib/neutron/tmp

            crudini --set $NEUTRON_CONF nova auth_url http://$CTRL_MGMT_IP:35357
            crudini --set $NEUTRON_CONF nova auth_type password
            crudini --set $NEUTRON_CONF nova region_name $REGION
            crudini --set $NEUTRON_CONF nova project_domain_name default
            crudini --set $NEUTRON_CONF nova user_domain_name default
            crudini --set $NEUTRON_CONF nova project_name $KEYSTONE_T_NAME_SERVICE
            crudini --set $NEUTRON_CONF nova username $KEYSTONE_U_NOVA
            crudini --set $NEUTRON_CONF nova password $KEYSTONE_U_PWD_NOVA

            crudini --set $NEUTRON_CONF database connection mysql://$DB_USER_NEUTRON:$DB_PWD_NEUTRON@$DB_IP/neutron

            crudini --del $NEUTRON_CONF keystone_authtoken identity_uri
            crudini --del $NEUTRON_CONF keystone_authtoken admin_tenant_name
            crudini --del $NEUTRON_CONF keystone_authtoken admin_user
            crudini --del $NEUTRON_CONF keystone_authtoken admin_password

            crudini --set $NEUTRON_CONF keystone_authtoken auth_uri http://$CTRL_MGMT_IP:5000
            crudini --set $NEUTRON_CONF keystone_authtoken auth_url http://$CTRL_MGMT_IP:35357
            crudini --set $NEUTRON_CONF keystone_authtoken auth_type password
            crudini --set $NEUTRON_CONF keystone_authtoken project_domain_name default
            crudini --set $NEUTRON_CONF keystone_authtoken user_domain_name default
            crudini --set $NEUTRON_CONF keystone_authtoken project_name $KEYSTONE_T_NAME_SERVICE
            crudini --set $NEUTRON_CONF keystone_authtoken username $KEYSTONE_U_NEUTRON
            crudini --set $NEUTRON_CONF keystone_authtoken password $KEYSTONE_U_PWD_NEUTRON
            crudini --set $NEUTRON_CONF keystone_authtoken memcached_servers $MEMCACHED_SERVERS

            crudini --set $NEUTRON_CONF oslo_messaging_notifications driver noop
        fi

        ## /etc/neutron/plugins/ml2/ml2_conf.ini
        if [ -e $ML2_CONF ]; then
            crudini --set $ML2_CONF ml2 type_drivers flat,$TYPE_DR
            crudini --set $ML2_CONF ml2 mechanism_drivers $ML2_PLUGIN,l2population
            crudini --set $ML2_CONF ml2 tenant_network_types $TYPE_DR
            crudini --set $ML2_CONF ml2 external_network_type flat
            crudini --set $ML2_CONF securitygroup enable_security_group True
            crudini --set $ML2_CONF securitygroup enable_ipset True

            crudini --set $ML2_CONF securitygroup firewall_driver $SECURITY_GROUP_DR
            crudini --set $ML2_CONF agent root_helper 'sudo neutron-rootwrap /etc/neutron/rootwrap.conf'
            crudini --set $ML2_CONF agent root_helper_daemon 'sudo /usr/bin/neutron-rootwrap-daemon /etc/neutron/rootwrap.conf'

            if [[ $TYPE_DR =~ (^|[,])'vxlan'($|[,]) ]]; then
                crudini --set $ML2_CONF ml2_type_vxlan vni_ranges 1:1000

                crudini --set $ML2_CONF ovs local_ip $INTERFACE_INT_IP
                crudini --set $ML2_CONF ovs tunnel_bridge br-tun
                TUNNEL_TYPES=vxlan
                crudini --set $ML2_CONF agent tunnel_types $TUNNEL_TYPES
            fi

            if [[ $TYPE_DR =~ (^|[,])'gre'($|[,]) ]]; then
                crudini --set $ML2_CONF ml2_type_gre tunnel_id_ranges 1:1000

                crudini --set $ML2_CONF ovs local_ip $INTERFACE_INT_IP
                crudini --set $ML2_CONF ovs tunnel_bridge br-tun
                if [[ -z $TUNNEL_TYPES ]]; then
                    TUNNEL_TYPES="gre"
                 else
                    TUNNEL_TYPES="$TUNNEL_TYPES,gre"
                 fi
                 crudini --set $ML2_CONF agent tunnel_types $TUNNEL_TYPES
            fi

            if [[ $TYPE_DR =~ (^|[,])'vlan'($|[,]) ]]; then
                crudini --set $ML2_CONF ml2_type_vlan network_vlan_ranges $VLAN_RANGES
                crudini --set $ML2_CONF ovs network_vlan_ranges $VLAN_RANGES
                crudini --set $ML2_CONF ovs bridge_mappings physnet1:br-vlan
            fi


        fi

        if [ ! -e "/etc/neutron/plugin.ini" ]; then
            ln -s $ML2_CONF /etc/neutron/plugin.ini
        fi

        ## configure the Layer-3 (L3) agent /etc/neutron/l3_agent.ini
        if [[ "${DVR^^}" == 'TRUE' ]] && [[ 'neutron_compute' =~ "$1" ]]; then
            yum install -y openstack-neutron
        fi

        if [ -e "/etc/neutron/l3_agent.ini" ]; then
            crudini --set /etc/neutron/l3_agent.ini DEFAULT interface_driver openvswitch
            crudini --set /etc/neutron/l3_agent.ini DEFAULT use_namespaces True
            crudini --set /etc/neutron/l3_agent.ini DEFAULT external_network_bridge br-ex
            crudini --set /etc/neutron/l3_agent.ini DEFAULT router_delete_namespaces True
            crudini --set /etc/neutron/l3_agent.ini DEFAULT debug True
        fi

        ## configure the DHCP agent /etc/neutron/dhcp_agent.ini
        if [ -e "/etc/neutron/dhcp_agent.ini" ]; then
            crudini --set /etc/neutron/dhcp_agent.ini DEFAULT debug False
            crudini --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver openvswitch
            crudini --set /etc/neutron/dhcp_agent.ini DEFAULT dhcp_driver neutron.agent.linux.dhcp.Dnsmasq
            crudini --set /etc/neutron/dhcp_agent.ini DEFAULT use_namespaces True
            crudini --set /etc/neutron/dhcp_agent.ini DEFAULT dhcp_delete_namespaces True

            crudini --set /etc/neutron/dhcp_agent.ini DEFAULT dnsmasq_config_file /etc/neutron/dnsmasq-neutron.conf
            if [ ! -e "/etc/neutron/dnsmasq-neutron.conf" ]; then
                echo "dhcp-option-force=26,1454" > /etc/neutron/dnsmasq-neutron.conf
                chown -R neutron:neutron /etc/neutron
            fi

        fi

        ## config metadata agent /etc/neutron/metadata_agent.ini
        if [ -e "/etc/neutron/metadata_agent.ini" ]; then
            crudini --set /etc/neutron/metadata_agent.ini DEFAULT auth_uri http://$CTRL_MGMT_IP:5000
            crudini --set /etc/neutron/metadata_agent.ini DEFAULT auth_url http://$CTRL_MGMT_IP:35357
            crudini --set /etc/neutron/metadata_agent.ini DEFAULT auth_region $REGION
            crudini --set /etc/neutron/metadata_agent.ini DEFAULT auth_plugin password
            crudini --set /etc/neutron/metadata_agent.ini DEFAULT project_domain_id default
            crudini --set /etc/neutron/metadata_agent.ini DEFAULT user_domain_id default
            crudini --set /etc/neutron/metadata_agent.ini DEFAULT project_name $KEYSTONE_T_NAME_SERVICE
            crudini --set /etc/neutron/metadata_agent.ini DEFAULT username $KEYSTONE_U_NEUTRON
            crudini --set /etc/neutron/metadata_agent.ini DEFAULT password $KEYSTONE_U_PWD_NEUTRON
            crudini --set /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_ip $CTRL_MGMT_IP
            crudini --set /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret $METADATA_SECRET
            crudini --set /etc/neutron/metadata_agent.ini DEFAULT debug True
        fi

        export _NEUTRON_CONFIGED=True
    fi

    if [[ $ML2_PLUGIN =~ 'openvswitch' ]]; then
        if [ -e $OVS_CONF ]; then
            crudini --set $OVS_CONF ovs integration_bridge br-int
            ## crudini --set $OVS_CONF ovs bridge_mappings external:br-ex

            if [[ $TYPE_DR =~ (^|[,])'vxlan'($|[,]) ]]; then
                crudini --set $OVS_CONF ovs local_ip $INTERFACE_INT_IP
                crudini --set $OVS_CONF ovs tunnel_bridge br-tun
                if [[ -z $TUNNEL_TYPES ]]; then
                    TUNNEL_TYPES=vxlan
                else
                    TUNNEL_TYPES="$TUNNEL_TYPES,vxlan"
                fi
                crudini --set $OVS_CONF agent tunnel_types $TUNNEL_TYPES
            fi

            if [[ $TYPE_DR =~ (^|[,])'gre'($|[,]) ]]; then
                crudini --set $OVS_CONF ovs local_ip $INTERFACE_INT_IP
                crudini --set $OVS_CONF ovs tunnel_bridge br-tun
                if [[ -z $TUNNEL_TYPES ]]; then
                    TUNNEL_TYPES="gre"
                else
                    TUNNEL_TYPES="$TUNNEL_TYPES,gre"
                fi

                crudini --set $OVS_CONF agent tunnel_types $TUNNEL_TYPES
            fi

            if [[ $TYPE_DR =~ (^|[,])'vlan'($|[,]) ]]; then
                crudini --set $OVS_CONF ovs network_vlan_ranges $VLAN_RANGES
                crudini --set $OVS_CONF ovs bridge_mappings physnet1:br-vlan
            fi
        fi
    fi

    case "$1" in
        'neutron_ctrl' )
            _neutron_dvr_configure $1
            _neutron_fortinet_configure $1
            ;;

        'neutron_compute' )
            _neutron_dvr_configure $1
            if [[ $ML2_PLUGIN =~ 'openvswitch' ]]; then
                if [[ $TYPE_DR =~ (^|[,])'vxlan'($|[,]) ]]; then
                    ovs-vsctl --may-exist add-br br-tun
                fi

                if [[ $TYPE_DR =~ (^|[,])'gre'($|[,]) ]]; then
                    ovs-vsctl --may-exist add-br br-tun
                fi

                if [[ $TYPE_DR =~ (^|[,])'vlan'($|[,]) ]]; then
                    ovs-vsctl --may-exist add-br br-vlan
                    ovs-vsctl --may-exist add-port br-vlan $INTERFACE_INT
                fi
            fi
            ;;

        'neutron_network' )
            _neutron_dvr_configure $1

            if [[ $ML2_PLUGIN =~ 'openvswitch' ]]; then
                if [[ $TYPE_DR =~ (^|[,])'vxlan'($|[,]) ]]; then
                    ovs-vsctl --may-exist add-br br-tun
                fi

                if [[ $TYPE_DR =~ (^|[,])'gre'($|[,]) ]]; then
                    ovs-vsctl --may-exist add-br br-tun
                fi

                if [[ $TYPE_DR =~ (^|[,])'vlan'($|[,]) ]]; then
                    ovs-vsctl --may-exist add-br br-vlan
                    ovs-vsctl --may-exist add-port br-vlan $INTERFACE_INT
                fi

                for file in /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/openvswitch_agent.ini ; do
                    if [ -e $file ]; then
                        crudini --set $file ovs bridge_mappings external:br-ex
                    fi
                done
                ovs-vsctl --may-exist add-br br-ex
                ovs-vsctl --may-exist add-port br-ex $INTERFACE_EXT
            fi
            ;;

        'neutron_dhcp' )
            # noop
            ;;

        * ) echo "The inputed params $1 is invaild."
            exit 12
            ;;
    esac
}
