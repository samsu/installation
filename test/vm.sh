#!/bin/bash

declare -A NETS
declare -A NODES

NETS=( 
    ["net1"]=fd277638-23e7-4aec-85bc-8ed4779bc5da
    ["net2"]=2debf095-62c7-4856-8324-dd0f702c5065
)

NODES=(
    ["57"]=centos7-7
    ["58"]=centos7-8
)

IMAGEID=acf5f3fe-84ab-425d-99df-cafc5b16d77c

FLVRID=1

function create() {
    for net in "${!NETS[@]}"; do
        i=1
        for node in "${!NODES[@]}"; do
            echo -e "create VM $net-$node-vm$i in the $net on the ${NODES["$node"]}"
            ## echo -e "$node  ${NODES["$node"]}\n"
            openstack server create $net-$node-vm$i --image $IMAGEID --flavor $FLVRID --nic net-id=${NETS["$net"]} --availability-zone nova:${NODES["$node"]}
            ((i+=1))
        done
    done
}

function delete() {
    for net in "${!NETS[@]}"; do
        i=1
        for node in "${!NODES[@]}"; do
            echo -e "Delete VM $net-$node-vm$i in the $net on the ${NODES["$node"]}"
            openstack server delete $net-$node-vm$i
            ((i+=1))
        done
    done
}

function ops() {
    set -o xtrace
    for op in "$@"; do
        $op
    done
}

function timestamp {
    awk '{ print strftime("%Y-%m-%d %H:%M:%S | "), $0; fflush(); }'
}

ops $@ | timestamp

