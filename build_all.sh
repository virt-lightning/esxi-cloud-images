#!/bin/bash

set -eux

function bootstrap_esxi() {
    ESXI_ISO=$1
    NAME=$2
    IPV4=$3
    MEMORY=$4
    SIZE=$5
    # We use the label of the ISO image
    VERSION=$(file -b ${ESXI_ISO}| cut -d"'" -f2| cut -d"-" -f2)
    BASE_DIR=$(pwd)
    TMPDIR=${HOME}/tmp/${VERSION}
    ESXI_MOUNT_POINT=${TMPDIR}/mount
    VSHPERE_MOUNT_POINT=${TMPDIR}/vsphere
    TARGET_ISO=${TMPDIR}/new_${NAME}
    mkdir -p ${ESXI_MOUNT_POINT}
    mkdir -p ${TARGET_ISO}
    if [[ $(df --output=fstype ${ESXI_MOUNT_POINT}| tail -n1) != "iso9660" ]]; then
        sudo mount -o loop ${ESXI_ISO} ${ESXI_MOUNT_POINT}
    fi
    rsync -av ${ESXI_MOUNT_POINT}/ ${TARGET_ISO}
    sudo umount ${ESXI_MOUNT_POINT}
    echo "
vmaccepteula
# root/root
rootpw --iscrypted \$6\$NMbwKGV6gtYGDdrC\$6rDKgLzLpmxuNd9YZcC5ErOjxMWj/PDJknAJYgMGMvmjC7MI0mh6FErmC/.XzKCB0au.uH.U7tz2eTxerqXEG/
install --firstdisk --overwritevmfs
#network --bootproto=dhcp

%post --interpreter=busybox
# Flush the network configuration
echo 'vmx.allowNested = "TRUE"' >> /etc/vmware/config
halt

%firstboot --interpreter=busybox
vim-cmd hostsvc/enable_ssh
vim-cmd hostsvc/start_ssh
vim-cmd hostsvc/enable_esx_shell
vim-cmd hostsvc/start_esx_shell
esxcli system settings advanced set -o /UserVars/SuppressShellWarning -i 1
esxcli network vswitch standard policy security set --allow-promiscuous=1 --allow-forged-transmits=1 --allow-mac-change=1 --vswitch-name=vSwitch0
esxcli network ip interface ipv4 set -i vmk0 -I ${IPV4} -N 255.255.255.0 -t static
esxcli network ip route ipv4 add -g 192.168.122.1 -n default
esxcli network ip dns server add --server 192.168.122.1
esxcli system hostname set --host=${NAME}
esxcli system hostname set --fqdn=${NAME}.lab

EOL" > /tmp/ks_cust_${NAME}.cfg
    sudo cp /tmp/ks_cust_${NAME}.cfg ${TARGET_ISO}/ks_cust.cfg
    sudo sed -i s,timeout=5,timeout=1, ${TARGET_ISO}/boot.cfg
    sudo sed -i 's,\(kernelopt=.*\),\1 ks=cdrom:/KS_CUST.CFG,' ${TARGET_ISO}/boot.cfg
    sudo sed -i 's,TIMEOUT 80,TIMEOUT 1,' ${TARGET_ISO}/isolinux.cfg
    sudo genisoimage -relaxed-filenames -J -R -o ${TMPDIR}/new.iso -b isolinux.bin -c boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e efiboot.img -no-emul-boot ${TARGET_ISO}
    virt-install --connect qemu:///system \
    	-n ${NAME} -r ${MEMORY} \
    	--vcpus=sockets=1,cores=2,threads=2 \
    	--cpu host --disk path=/var/lib/libvirt/images/${NAME}.qcow2,size=${SIZE},sparse=yes \
    	-c ${TMPDIR}/new.iso --os-type generic \
    	--accelerate --network=network:default,model=e1000 \
    	--hvm --graphics vnc,listen=0.0.0.0 --noreboot
    sleep 10
    virsh -c qemu:///system start ${NAME}
}

DEFAULT_ISO=isos/VMware-VMvisor-Installer-6.7.0-8169922.x86_64.iso

bootstrap_esxi ${DEFAULT_ISO} esxi-vcenter 192.168.122.80 14096 40
bootstrap_esxi ${DEFAULT_ISO} esxi1 192.168.122.81 4096 10
bootstrap_esxi ${DEFAULT_ISO} esxi2 192.168.122.82 4096 10
