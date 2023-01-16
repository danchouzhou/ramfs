#!/bin/bash

# Exit if there is any error
set -e

# echo "Setup GRUB ..."
# if ! test -f /etc/default/grub.original; then
# 	mv /etc/default/grub /etc/default/grub.original
# fi
# cat << EOF > /etc/default/grub
# GRUB_DEFAULT=0
# GRUB_TIMEOUT=5
# GRUB_DISTRIBUTOR=\`lsb_release -i -s 2> /dev/null || echo Debian\`
# GRUB_CMDLINE_LINUX_DEFAULT=""
# GRUB_CMDLINE_LINUX="console=tty0 console=ttyS0,115200n8"
# GRUB_TERMINAL="console serial"
# GRUB_SERIAL_COMMAND="serial --speed=115200 --unit=0 --word=8 --parity=no --stop"
# GRUB_DISABLE_OS_PROBER=true
# EOF
# update-grub

echo "Install additional software ..."
apt update
apt install htop screen wget tcpdump dosfstools exfat-utils mdadm lvm2 linux-cpupower ethtool -y
apt clean

echo "Customizing initramfs script ..."
if ! test -f /usr/share/initramfs-tools/scripts/local.original; then
     cp /usr/share/initramfs-tools/scripts/local /usr/share/initramfs-tools/scripts/local.original
fi
cp local.ramfs /usr/share/initramfs-tools/scripts/local.ramfs

echo "Adding additional kernel module for FAT and exFAT ..."
if ! test -f /etc/initramfs-tools/modules.original; then
     cp /etc/initramfs-tools/modules /etc/initramfs-tools/modules.original
fi
if ! test -f /etc/initramfs-tools/modules.ramfs; then
     cp /etc/initramfs-tools/modules /etc/initramfs-tools/modules.ramfs
     ls /lib/modules/`uname -r`/kernel/fs/fat/ | cut -f1 -d '.' | tee -a /etc/initramfs-tools/modules.ramfs
     ls /lib/modules/`uname -r`/kernel/fs/exfat/ | cut -f1 -d '.' | tee -a /etc/initramfs-tools/modules.ramfs
     ls /lib/modules/`uname -r`/kernel/fs/nls/ | cut -f1 -d '.' | tee -a /etc/initramfs-tools/modules.ramfs
fi

echo "Adding tar binary to initramfs"
cat << EOF > /usr/share/initramfs-tools/hooks/tar
#!/bin/sh
PREREQ=""
prereqs()
{
     echo "\$PREREQ"
}
case \$1 in
prereqs)
     prereqs
     exit 0
     ;;
esac
. /usr/share/initramfs-tools/hook-functions
rm -f \${DESTDIR}/bin/tar
copy_exec /usr/bin/tar /bin/tar
EOF
chmod +x /usr/share/initramfs-tools/hooks/tar

echo "Customizing fstab ..."
if ! test -f /etc/fstab.original; then
     cp /etc/fstab /etc/fstab.original
fi
echo 'none /   tmpfs size=95% 0 0' | tee /etc/fstab.ramfs

echo "Setup startup.service ..."
cat << EOF > /etc/systemd/system/startup.service
[Unit]
Description=Startup script
After=network.target

[Service]
ExecStart=/start.sh

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable startup.service

echo "Copying all customized files ..."
cp /usr/share/initramfs-tools/scripts/local.ramfs /usr/share/initramfs-tools/scripts/local
cp /etc/initramfs-tools/modules.ramfs /etc/initramfs-tools/modules
cp /etc/fstab.ramfs /etc/fstab

echo "Always show the sudo lecture ..."
echo 'Defaults lecture = always' | tee -a /etc/sudoers.d/privacy

echo "Preparing boot files ..."
echo "Packing rootfs ..."
mkdir -p /bootfiles
tar zcvf /bootfiles/rootfs.tar.gz --exclude='ramfs_setup.sh' --exclude='local.ramfs' --exclude='/bootfiles' --one-file-system /

echo "Copying Linux kernel ..."
cp /boot/vmlinuz-`uname -r` /bootfiles/vmlinuz-`uname -r`

echo "Building initramfs ..."
mkinitramfs -o /bootfiles/initrd.img-`uname -r`

echo "Generating initramfs script ..."
cat << EOF > /bootfiles/init.sh
#!/bin/sh

echo "Copying rootfs.tar.gz ..."
cp /mount/EFI/rootfs.tar.gz .
echo "Copying start.sh ..."
cp /mount/EFI/start.sh .
chmod +x start.sh
echo "Unmount boot device ..."
umount /mount
echo -n "Extracting from rootfs.tar.gz ..."
tar zxf rootfs.tar.gz --checkpoint=.5000
rm rootfs.tar.gz
EOF

echo "Generating systemd startup.service script ..."
cat << EOF > /bootfiles/start.sh
#!/bin/bash

## APT ##
apt-mark hold linux-image* grub*

## Network ##
sed -in '/enp/d' /etc/network/interfaces

for i in $(ip link show | grep enp | cut -f2 -d' ' | sed 's/://g'); do
	echo "" >> /etc/network/interfaces
	echo "auto \${i}" >> /etc/network/interfaces
	echo "allow-hotplug \${i}" >> /etc/network/interfaces
	echo "iface \${i} inet dhcp" >> /etc/network/interfaces
	if ! ethtool \${i} | grep -sq 'Supports Wake-on: d'; then
		echo "up ethtool -s \${i} wol g" >> /etc/network/interfaces
	fi
done

systemctl restart networking.service
EOF

echo "Boot files are ready, restore to original files ..."
cp /usr/share/initramfs-tools/scripts/local.original /usr/share/initramfs-tools/scripts/local
cp /etc/initramfs-tools/modules.original /etc/initramfs-tools/modules
cp /etc/fstab.original /etc/fstab
systemctl disable startup.service
rm /etc/systemd/system/startup.service
systemctl daemon-reload