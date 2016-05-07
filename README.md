# Installation

This script will help you to install specific openstack roles to the machine,
before run the script, you need to update the environment variables in the
head of the script according to your setup.


Prerequisites:

    1. host os support: Centos 7 and up minimal installation.
       e.g. CentOS-7-x86_64-Minimal-1511.iso

    2. Three ethernet interfaces are required, these interfaces will by used
       as below:
           one interface for Openstack management, default eth0
           one interface for tenant network (vm <-> vm), default eth1
           one interface for external network (vm <-> outside ), default eth2
       The management network nic and the tenant network nic should have
       an working static ipv4 address for each interface.
       If your nic name or nic assignment is different with default, you need
       to update the following three variables in the file ins.sh:
       e.g.
       the default:
           export INTERFACE_MGMT=${INTERFACE_MGMT:-eth0}
           export INTERFACE_INT=${INTERFACE_INT:-eth1}
           export INTERFACE_EXT=${INTERFACE_EXT:-eth2} 
       updated:
           export INTERFACE_MGMT=eno16777728
           export INTERFACE_INT=eno33554952
           export INTERFACE_EXT=eno50332176

    3. If run multi-nodes installation, you need to assign controller ip on
       the variable 'CTRL_MGMT_IP' in the file ins.sh
           CTRL_MGMT_IP=[default is host INTERFACE_MGMT ip]
           e.g. CTRL_MGMT_IP=10.160.37.60

    4. Execute the script as root

    5. Internet connection is required


Usage:

    ./ins.sh [-h] [-v openstack_releasename] rolenames


Options:

    -h  this help
    -v  assign an openstack version to be installed, currently supported
        Openstack version are: liberty, mitaka
        the default openstack version is 'mitaka'


Rolenames:
    The rolenames could be any one or combo of the follow role set.

    a) Openstack all-in-one installation role name list:
        allinone

    b) Openstack multi-nodes installation role name list:
        controller
        network
        compute

    c) Openstack component installation role name list:
        database
        mq
        dashboard
        keystone
        glance
        nova_ctrl
        nova_compute
        neutron_ctrl
        neutron_compute
        neutron_network
        cinder_ctrl


Examples:

    # Install all openstack stuff(allinone role) in one machine
    ./ins.sh allinone

    # Install two roles(nova controller and neutron controller) in a machine
    ./ins.sh nova_ctrl neutron_ctrl


