# Requirements

- A Linux system
- Libvirt and virt-install.
- ESXi ISO image

# Build your ESXi VM

By default, the scrip will prepare 3 ESXi VM.

- esxi-vcenter
    - IP: 192.168.122.80
    - Memory: 14096MB
    - Disk: 40GiB
- esxi1
    - IP: 192.168.122.81
    - Memory: 4096MB
    - Disk: 10GiB
- esxi2
    - IP: 192.168.122.82
    - Memory: 4096MB
    - Disk: 10GiB10

```shell
./build_all.sh
```
