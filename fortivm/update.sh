#!/bin/bash

set -o xtrace

## use a specific folder as the workfolder ($PWD)
W_DIR=/root/fortivm

IMG_DIR=/var/lib/libvirt/images
IMG_FILE=fortios.qcow2_1044
VM=fortivm
CONFIG_ISO=disk.config
DIR_LIC=cloud_init/openstack/content
DIR_CONF=cloud_init/openstack/latest
 
 
# clean current VM data
virsh destroy $VM
virsh undefine $VM


# create a nat network for the fgtvm management plane.
FGT_BR=fgt-br
FGT_MGMT_NET=fgt-mgmt

virsh net-list --all |grep $FGT_MGMT_NET > /dev/null
if [[ $? -eq 0 ]]; then
    echo "virtual network $FGT_MGMT_NET existed, clean it first"
    echo "deleting $FGT_MGMT_NET"
    virsh net-destroy $FGT_MGMT_NET
    virsh net-undefine $FGT_MGMT_NET
fi

#sleep(10s)

# create a nat network for the fgtvm management plane.
brctl show |grep  $FGT_BR >> /dev/null
if [[ $? -ne 0 ]]; then
    echo "create bridge"
    cat > $FGT_MGMT_NET.xml << EOF
<network>
  <name>$FGT_MGMT_NET</name>
  <bridge name="$FGT_BR"/>
  <forward mode="nat"/>
  <ip address="169.254.254.1" netmask="255.255.255.0">
    <dhcp>
      <range start="169.254.254.100" end="169.254.254.254"/>
    </dhcp>
  </ip>
</network>
EOF
    virsh net-define $FGT_MGMT_NET.xml
    virsh net-start $FGT_MGMT_NET
    virsh net-autostart $FGT_MGMT_NET
fi


# update cloud init file
cd $W_DIR
mkdir -p $DIR_LIC
mkdir -p $DIR_CONF
yes|cp init.conf cloud_init/openstack/latest/user_data
yes|cp vm.lic cloud_init/openstack/content/0000

if [[ $# -eq 0 ]]; then
    echo 'no params inputed'
    params=""
else
    params="$*"
fi


if [[ $params == *"lic=no"* ]]; then
    echo "remove the license file"
    rm -rf $DIR_LIC
fi

if [[ $params == *"conf=no"* ]]; then
    echo "remove the config file"
    rm -rf $DIR_CONF
fi


# generate iso file with label config-2
genisoimage -output $CONFIG_ISO -ldots -allow-lowercase -allow-multidot -l -volid cidata -joliet -rock -V config-2 cloud_init

# update the VM data
yes | cp $CONFIG_ISO $IMG_DIR/.
yes | cp $IMG_DIR/$IMG_FILE $IMG_DIR/fortios.qcow2

# create VM with the updated data
virsh define libvirt.xml
virsh start $VM

