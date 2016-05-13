#!/bin/bash

unset SUBNETS_INFO
declare -A SUBNETS_INFO

SUBNETS_INFO=(
    [public]="10.160.37.0/24 10.160.37.1 10.160.37.181 10.160.37.190"
    [private]="192.168.10.0/24 192.168.10.254"
)

# cirros image
export IMAGE_FILE=${IMAGE_FILE:-"cirros-0.3.4-x86_64-disk.img"}
export IMAGE_URL=${IMAGE_URL:-"http://download.cirros-cloud.net/0.3.4/$IMAGE_FILE"}
export IMAGE_NAME=${IMAGE_NAME:-'cirros-0.3.4-x86_64'}


################################################

source ~/openrc

image_upload() {
    yum install -y wget
    openstack image show $IMAGE_NAME >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        mkdir -p /tmp/images
        wget -P /tmp/images $IMAGE_URL
        openstack image create --file /tmp/images/$IMAGE_FILE --disk-format qcow2 --container-format bare --public $IMAGE_NAME
        openstack image list
    fi
}


network_creation() {
    neutron subnet-show pubsubnet && neutron subnet-show subnet1
    if [ $? -ne 0 ]; then
        for _SUBNET in ${!SUBNETS_INFO[@]}; do
            read -r -a _SUBNET_INFO <<< "${SUBNETS_INFO[$_SUBNET]}"
            for NUM in ${!_SUBNET_INFO[@]}; do
                case "$NUM" in
                0)  _CIDR=${_SUBNET_INFO[0]}
                    ;;
                1)  _GW=${_SUBNET_INFO[1]}
                    ;;
                2)  _START_IP=${_SUBNET_INFO[2]}
                    ;;
                3)  _END_IP=${_SUBNET_INFO[3]}
                    ;;
                *)  echo "too many paramters inputed"
                    echo "exit"
                    ;;
                esac
            done

            case "$_SUBNET" in
            'public')
                neutron net-show pubnet || neutron net-create pubnet --router:external True --provider:network_type flat --provider:physical_network default
                neutron subnet-show pubsubnet || neutron subnet-create --name pubsubnet --gateway ${_GW} --allocation-pool start=${_START_IP},end=${_END_IP} --disable-dhcp pubnet $_CIDR
                ;;
            'private')
                neutron net-show net1 || neutron net-create net1
                if [ -z ${!_SUBNET_INFO[2]} ]; then
                    neutron subnet-show subnet1 || neutron subnet-create --name subnet1 --gateway ${_GW} --enable-dhcp net1 $_CIDR
                else
                    neutron subnet-show subnet1 || neutron subnet-create --name subnet1 --gateway ${_GW} --allocation-pool start=${_START_IP},end=${_END_IP} --enable-dhcp net1 $_CIDR
                fi
                ;;
            esac
        done
    fi

    neutron router-show router
    if [ $? -ne 0 ]; then
        neutron router-create router
        neutron router-gateway-set router pubnet
        neutron router-interface-add router subnet1
    fi
}


function vm_creation() {
    _VM_NAME=${$1:-test}
    nova boot --flavor m1.tiny --image $IMAGE_NAME --nic net-id=$(neutron net-show net1 |grep " id "|awk '{print $4}') $_VM_NAME
}


function ops() {
    set -o xtrace
    image_upload
    network_creation

    if [ -z "$@" ]; then
        vm_creation
    else
        for vm in "$@"; do
            vm_creation $vm
        done
    fi
}

function timestamp {
    awk '{ print strftime("%Y-%m-%d %H:%M:%S | "), $0; fflush(); }'
}

ops $@ | timestamp

