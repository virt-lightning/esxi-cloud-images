# Requirements

- A Linux system
- Libvirt and virt-install.
- ESXi ISO image

# Build your image

```shell
./build.sh isos/VMware-VMvisor-Installer-6.5.0.update01-5969303.x86_64.iso
./build.sh isos/VMware-VMvisor-Installer-6.7.0-8169922.x86_64.iso
./build.sh isos/VMware-VMvisor-Installer-6.7.0.update03-14320388.x86_64.iso
```

# KVM configuration

You need to add the two following lines in kvm module configuration:

```shell
options kvm_intel nested=1 enable_apicv=n
options kvm ignore_msrs=1
```

Depending on the Linux distribution, the configuration file is located here:

- Fedora: /etc/modprobe.d/kvm.conf
- Ubuntu: /etc/modprobe.d/qemu-system-x86.conf
