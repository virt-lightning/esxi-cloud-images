#!/bin/bash

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
python /etc/esxi-cloud-init.py
exit 0
EOF
chmod +x /etc/rc.local.d/local.sh

# This is a base64 copy of
# https://github.com/goneri/esxi-cloud-init/blob/master/esxi-cloud-init.py
python -m base64 -d -<< 'EOF' > /etc/esxi-cloud-init.py
IyEvYmluL3B5dGhvbgoKaW1wb3J0IGNyeXB0CmltcG9ydCByZQppbXBvcnQgc3VicHJvY2Vzcwpp
bXBvcnQganNvbgoKZGVmIGZpbmRfY2Ryb21fZGV2KCk6CiAgICBtcGF0aF9iID0gc3VicHJvY2Vz
cy5jaGVja19vdXRwdXQoWydlc3hjZmctbXBhdGgnLCAnLWInXSkKICAgIGZvciBsaW5lIGluIG1w
YXRoX2IuZGVjb2RlKCkuc3BsaXQoJ1xuJyk6CiAgICAgICAgbSA9IHJlLm1hdGNoKHInXihcUyop
Lipcc0NELVJPTVxzLionLCBsaW5lKQogICAgICAgIGlmIG06CiAgICAgICAgICAgIHJldHVybiBt
Lmdyb3VwKDEpCgpkZWYgbW91bnRfY2Ryb20oY2Ryb21fZGV2KToKICAgIHN1YnByb2Nlc3MuY2Fs
bChbJ3ZzaXNoJywgJy1lJywgJ3NldCcsICcvdm1rTW9kdWxlcy9pc285NjYwL21vdW50JywgY2Ry
b21fZGV2XSkKCmRlZiB1bW91bnRfY2Ryb20oY2Ryb21fZGV2KToKICAgIHN1YnByb2Nlc3MuY2Fs
bChbJ3ZzaXNoJywgJy1lJywgJ3NldCcsICcvdm1rTW9kdWxlcy9pc285NjYwL3Vtb3VudCcsIGNk
cm9tX2Rldl0pCgpkZWYgbG9hZF9uZXR3b3JrX2RhdGEoKToKICAgICMgU2hvdWxkIGJlIG9wZW5z
dGFjay9sYXRlc3QvbmV0d29ya19kYXRhLmpzb24KICAgIHdpdGggb3BlbignL3ZtZnMvdm9sdW1l
cy9jaWRhdGEvT1BFTlNUQUMvTEFURVNUL05FVFdPUktfLkpTTycsICdyJykgYXMgZmQ6CiAgICAg
ICAgZnJvbSBwcHJpbnQgaW1wb3J0IHBwcmludAogICAgICAgIHJldHVybiBqc29uLmxvYWRzKGZk
LnJlYWQoKSkKCmRlZiBsb2FkX21ldGFfZGF0YSgpOgogICAgIyBTaG91bGQgYmUgb3BlbnN0YWNr
L2xhdGVzdC9tZXRhX2RhdGEuanNvbgogICAgd2l0aCBvcGVuKCcvdm1mcy92b2x1bWVzL2NpZGF0
YS9PUEVOU1RBQy9MQVRFU1QvTUVUQV9EQVQuSlNPJywgJ3InKSBhcyBmZDoKICAgICAgICBmcm9t
IHBwcmludCBpbXBvcnQgcHByaW50CiAgICAgICAgZGF0YSA9IGpzb24ubG9hZHMoZmQucmVhZCgp
KQogICAgICAgIHBwcmludChkYXRhKQogICAgICAgIHJldHVybiBkYXRhCgpkZWYgbG9hZF91c2Vy
X2RhdGEoKToKICAgICMgU2hvdWxkIGJlIG9wZW5zdGFjay9sYXRlc3QvdXNlci1kYXRhCiAgICB1
c2VyX2RhdGEgPSB7fQogICAgd2l0aCBvcGVuKCcvdm1mcy92b2x1bWVzL2NpZGF0YS9PUEVOU1RB
Qy9MQVRFU1QvVVNFUi1EQVQnLCAncicpIGFzIGZkOgogICAgICAgIGZvciBsaW5lIGluIGZkLnJl
YWRsaW5lcygpOgogICAgICAgICAgICBpZiBsaW5lLnN0YXJ0c3dpdGgoJyMnKToKICAgICAgICAg
ICAgICAgIGNvbnRpbnVlCiAgICAgICAgICAgIGssIHYgPSBsaW5lLnNwbGl0KCc6ICcsIDEpCiAg
ICAgICAgICAgIHVzZXJfZGF0YVtrXSA9IHYKICAgICAgICByZXR1cm4gdXNlcl9kYXRhCgpkZWYg
c2V0X2hvc3RuYW1lKG1ldGFfZGF0YSk6CiAgICBob3N0ID0gbWV0YV9kYXRhWydob3N0bmFtZSdd
CiAgICBzdWJwcm9jZXNzLmNhbGwoWydlc3hjbGknLCAnc3lzdGVtJywgJ2hvc3RuYW1lJywgJ3Nl
dCcsICctLWhvc3Q9JXMnICUgaG9zdF0pCgpkZWYgc2V0X25ldHdvcmsobmV0d29ya19kYXRhKToK
ICAgIHN1YnByb2Nlc3MuY2FsbChbJ2VzeGNsaScsICduZXR3b3JrJywgJ2lwJywgJ2RucycsICdz
ZXJ2ZXInLCAncmVtb3ZlJywgJy0tYWxsJ10pCiAgICAjIEFzc3VtaW5nIG9uZSBuZXR3b3JrIHBl
ciBpbnRlcmZhY2UgYW5kIGludGVyZmFjZXMgYXJlIGluIHRoZSBnb29kIG9yZGVyCiAgICBmb3Ig
aSBpbiByYW5nZShsZW4obmV0d29ya19kYXRhWyduZXR3b3JrcyddKSk6CiAgICAgICAgaWZkZWYg
PSBuZXR3b3JrX2RhdGFbJ25ldHdvcmtzJ11baV0KICAgICAgICBpZiBpZmRlZlsndHlwZSddID09
ICdpcHY0JzoKICAgICAgICAgICAgc3VicHJvY2Vzcy5jYWxsKFsnZXN4Y2xpJywgJ25ldHdvcmsn
LCAnaXAnLCAnaW50ZXJmYWNlJywgJ2lwdjQnLCAnc2V0JywgJy1pJywgJ3ZtayVpJyAlIGksICct
ZycsIGlmZGVmWydyb3V0ZXMnXVswXVsnZ2F0ZXdheSddLCAnLUknLCBpZmRlZlsnaXBfYWRkcmVz
cyddLCAnLU4nLCBpZmRlZlsnbmV0bWFzayddLCAnLXQnLCAnc3RhdGljJ10pCiAgICAgICAgICAg
IGZvciByIGluIGlmZGVmWydyb3V0ZXMnXToKICAgICAgICAgICAgICAgIHN1YnByb2Nlc3MuY2Fs
bChbJ2VzeGNsaScsICduZXR3b3JrJywgJ2lwJywgJ3JvdXRlJywgJ2lwdjQnLCAnYWRkJywgJy1n
JywgclsnZ2F0ZXdheSddLCAnLW4nLCByWyduZXR3b3JrJ11dKQogICAgICAgIGVsc2U6CiAgICAg
ICAgICAgIHN1YnByb2Nlc3MuY2FsbChbJ2VzeGNsaScsICduZXR3b3JrJywgJ2lwJywgJ2ludGVy
ZmFjZScsICdpcHY0JywgJ3NldCcsICctaScsICd2bWslaScgJSBpLCAnLXQnLCAnZGhjcCddKQoK
ICAgIGZvciBzIGluIG5ldHdvcmtfZGF0YVsnc2VydmljZXMnXToKICAgICAgICBpZiBzWyd0eXBl
J10gPT0gJ2Rucyc6CiAgICAgICAgICAgIHN1YnByb2Nlc3MuY2FsbChbJ2VzeGNsaScsICduZXR3
b3JrJywgJ2lwJywgJ2RucycsICdzZXJ2ZXInLCAnYWRkJywgJy0tc2VydmVyJywgc1snYWRkcmVz
cyddXSkKCmRlZiBzZXRfc3NoX2tleXMobWV0YV9kYXRhKToKICAgICMgQSBiaXQgaGFja2lzaCBi
ZWNhdXNlIFB5WUFNTCBiZWNhdXNlIEVTWGkncyBQeXRob24gZG9lcyBub3QgcHJvdmlkZSBQeVlB
TUwKICAgIGFkZF9rZXlzID0gbWV0YV9kYXRhWydwdWJsaWNfa2V5cyddLnZhbHVlcygpCiAgICBj
dXJyZW50X2tleXMgPSBbXQoKICAgIHdpdGggb3BlbignL2V0Yy9zc2gva2V5cy1yb290L2F1dGhv
cml6ZWRfa2V5cycsICdyJykgYXMgZmQ6CiAgICAgICAgZm9yIGxpbmUgaW4gZmQucmVhZGxpbmVz
KCk6CiAgICAgICAgICAgIG0gPSByZS5tYXRjaChyJ1teI10uKihzc2gtcnNhXHNcUyspLionLCBs
aW5lKQogICAgICAgICAgICBpZiBtOgogICAgICAgICAgICAgICAgY3VycmVudF9rZXlzLmFwcGVu
ZCA9IGZkLmdyb3VwKDEpCgogICAgd2l0aCBvcGVuKCcvZXRjL3NzaC9rZXlzLXJvb3QvYXV0aG9y
aXplZF9rZXlzJywgJ3crJykgYXMgZmQ6CiAgICAgICAgZm9yIGtleSBpbiBzZXQoYWRkX2tleXMp
OgogICAgICAgICAgICBpZiBrZXkgbm90IGluIGN1cnJlbnRfa2V5czoKICAgICAgICAgICAgICAg
IGZkLndyaXRlKGtleSArICdcbicpCgpkZWYgYWxsb3dfbmVzdGVkX3ZtKCk6CiAgICB3aXRoIG9w
ZW4oJy9ldGMvdm13YXJlL2NvbmZpZycsICdyJykgYXMgZmQ6CiAgICAgICAgZm9yIGxpbmUgaW4g
ZmQucmVhZGxpbmVzKCk6CiAgICAgICAgICAgIG0gPSByZS5tYXRjaChyJ152bXguYWxsb3dOZXN0
ZWQnLCBsaW5lKQogICAgICAgICAgICBpZiBtOgogICAgICAgICAgICAgICAgcmV0dXJuCiAgICB3
aXRoIG9wZW4oJy9ldGMvdm13YXJlL2NvbmZpZycsICd3KycpIGFzIGZkOgogICAgICAgIGZkLndy
aXRlKCdcbnZteC5hbGxvd05lc3RlZCA9ICJUUlVFIlxuJykKCmRlZiBzZXRfcm9vdF9wdyh1c2Vy
X2RhdGEpOgogICAgaGFzaGVkX3B3ID0gY3J5cHQuY3J5cHQodXNlcl9kYXRhWydwYXNzd29yZCdd
LCBjcnlwdC5ta3NhbHQoY3J5cHQuTUVUSE9EX1NIQTUxMikpCiAgICBjdXJyZW50ID0gb3Blbign
L2V0Yy9zaGFkb3cnLCAncicpLnJlYWRsaW5lcygpCiAgICB3aXRoIG9wZW4oJy9ldGMvc2hhZG93
JywgJ3cnKSBhcyBmZDoKICAgICAgICBmb3IgbGluZSBpbiBjdXJyZW50OgogICAgICAgICAgICBz
ID0gbGluZS5zcGxpdCgnOicpCiAgICAgICAgICAgIGlmIHNbMF0gPT0gJ3Jvb3QnOgogICAgICAg
ICAgICAgICAgc1sxXSA9IGhhc2hlZF9wdwogICAgICAgICAgICBmZC53cml0ZSgnOicuam9pbihz
KSkKCgp0cnk6CiAgICBzdWJwcm9jZXNzLmNhbGwoWyd2bWtsb2FkX21vZCcsICdpc285NjYwJ10p
CiAgICBjZHJvbV9kZXYgPSBmaW5kX2Nkcm9tX2RldigpCiAgICBtb3VudF9jZHJvbShjZHJvbV9k
ZXYpCiAgICBuZXR3b3JrX2RhdGEgPSBsb2FkX25ldHdvcmtfZGF0YSgpCiAgICBzZXRfbmV0d29y
ayhuZXR3b3JrX2RhdGEpCiAgICBtZXRhX2RhdGEgPSBsb2FkX21ldGFfZGF0YSgpCiAgICBzZXRf
aG9zdG5hbWUobWV0YV9kYXRhKQogICAgc2V0X3NzaF9rZXlzKG1ldGFfZGF0YSkKICAgIHVzZXJf
ZGF0YSA9IGxvYWRfdXNlcl9kYXRhKCkKICAgIHNldF9yb290X3B3KHVzZXJfZGF0YSkKICAgIGFs
bG93X25lc3RlZF92bSgpCmZpbmFsbHk6CiAgICB1bW91bnRfY2Ryb20oY2Ryb21fZGV2KQogICAg
c3VicHJvY2Vzcy5jYWxsKFsndm1rbG9hZF9tb2QnLCAnLXUnLCAnaXNvOTY2MCddKQo=
EOF

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


sudo cp /var/lib/libvirt/images/esxi-${VERSION}.qcow2 .
sudo virsh undefine --remove-all-storage esxi-${VERSION}
