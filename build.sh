#!/bin/bash
set -eux
if [ -z $1 ]; then
    echo "Usage: $0 ESXi.iso"
    exit 1
fi
if [ ! -f $1 ]; then
    echo "$1 is not a file"
    exit 1
fi

set -eux
ESXI_ISO=$1
# We use the label of the ISO image
VERSION=$(file -b ${ESXI_ISO}| cut -d"'" -f2| cut -d"-" -f2)
BASE_DIR=$(pwd)
TMPDIR=${HOME}/tmp/${VERSION}
ESXI_MOUNT_POINT=${TMPDIR}/mount
VSHPERE_MOUNT_POINT=${TMPDIR}/vsphere
TARGET_ISO=${TMPDIR}/new

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
esxcli network ip dns server remove --all
echo '' > /etc/resolv.conf
esxcli network ip interface ipv4 set -i vmk0 -t none
chkconfig usbarbitrator off

halt

%firstboot --interpreter=busybox
vim-cmd hostsvc/enable_ssh
vim-cmd hostsvc/start_ssh
vim-cmd hostsvc/enable_esx_shell
vim-cmd hostsvc/start_esx_shell
esxcli system settings advanced set -o /UserVars/SuppressShellWarning -i 1

cat << 'EOF' > /etc/rc.local.d/local.sh
# This is a base64 copy of
# https://github.com/goneri/esxi-cloud-init/blob/master/esxi-cloud-init.py
echo '$(curl -L -s https://raw.githubusercontent.com/goneri/esxi-cloud-init/master/esxi-cloud-init.py|base64 -)' | python -m base64 -d - > /etc/esxi-cloud-init.py

python /etc/esxi-cloud-init.py
exit 0
EOF
chmod +x /etc/rc.local.d/local.sh


# Reset the UUID
sed -i 's#/system/uuid.*##' /etc/vmware/esx.conf
# Reset the vswitch MAC address
esxcli system settings advanced set -o /Net/FollowHardwareMac -i 1
sed -i 's,.*child.0000./mac.*,,' /etc/vmware/esx.conf
/sbin/backup.sh 0
halt

EOL" > /tmp/ks_cust.cfg
sudo cp /tmp/ks_cust.cfg ${TARGET_ISO}/ks_cust.cfg
sudo sed -i s,timeout=5,timeout=1, ${TARGET_ISO}/boot.cfg
sudo sed -i 's,\(kernelopt=.*\),\1 ks=cdrom:/KS_CUST.CFG,' ${TARGET_ISO}/boot.cfg
sudo sed -i 's,TIMEOUT 80,TIMEOUT 1,' ${TARGET_ISO}/isolinux.cfg

sudo genisoimage -relaxed-filenames -J -R -o ${TMPDIR}/new.iso -b isolinux.bin -c boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e efiboot.img -no-emul-boot ${TARGET_ISO}

echo "Deployment ongoing, you will just have to press [ENTER] at the end."
virt-install --connect qemu:///system \
	-n esxi-${VERSION} -r 4096 \
	--vcpus=sockets=1,cores=2,threads=2 \
	--cpu host --disk path=/var/lib/libvirt/images/esxi-${VERSION}.qcow2,size=10,sparse=yes \
	-c ${TMPDIR}/new.iso --os-type generic \
	--accelerate --network=network:default,model=e1000 \
	--hvm --graphics vnc,listen=0.0.0.0


qemu-img convert -f qcow2 -O qcow2 -c /var/lib/libvirt/images/esxi-${VERSION}.qcow2 esxi-${VERSION}.qcow2
sudo virsh undefine --remove-all-storage esxi-${VERSION}
