#!/bin/bash

# Exit if there is any error
set -e

echo "Install additional software ..."
apt update
# system utilities
apt install htop screen nano wget bash-completion eject dosfstools ntfs-3g exfat-fuse grub-pc-bin mdadm lvm2 iptables net-tools network-manager -y
# driver
apt install firmware-linux-nonfree firmware-iwlwifi firmware-realtek firmware-atheros -y
# xfce enviroment
apt install xserver-xorg xserver-xorg-core xserver-xorg-video-all xfonts-base xinit x11-xserver-utils xfce4 tango-icon-theme xfce4-terminal thunar-volman gvfs mousepad blueman bluetooth network-manager-gnome --no-install-recommends -y
apt install pavucontrol -y
# browser
apt install chromium --no-install-recommends -y
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
echo 'none / tmpfs size=95% 0 0' | tee /etc/fstab.ramfs

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

echo "Preparing boot files ..."
echo "Packing rootfs ..."
mkdir -p /bootfiles/grub
systemctl stop systemd-journald.service
tar zcf /bootfiles/rootfs.tar.gz --exclude='/home/*/ramfs' --exclude='/bootfiles' --one-file-system / --checkpoint=.5000
systemctl start systemd-journald.service

echo "Copying Linux kernel ..."
cp /boot/vmlinuz-`uname -r` /bootfiles/vmlinuz-`uname -r`

echo "Building initramfs ..."
mkinitramfs -o /bootfiles/initrd.img-`uname -r`

echo "Generating initramfs script ..."
cat << EOF > /bootfiles/init.sh
#!/bin/sh

echo "Copying rootfs.tar.gz ..."
cp /mnt/EFI/rootfs.tar.gz .
echo "Copying start.sh ..."
cp /mnt/EFI/start.sh .
chmod +x start.sh
echo "Unmount boot device ..."
umount /mnt
echo -n "Extracting from rootfs.tar.gz ..."
tar zxf rootfs.tar.gz --checkpoint=.5000
echo
rm rootfs.tar.gz
EOF

echo "Generating systemd startup.service script ..."
cat << EOF > /bootfiles/start.sh
#!/bin/bash

## APT ##
apt-mark hold linux-image* grub*

## Network ##
# sed -in '/enp/d' /etc/network/interfaces

# for i in $(ip link show | grep enp | cut -f2 -d' ' | sed 's/://g'); do
# 	echo "" >> /etc/network/interfaces
# 	echo "auto \${i}" >> /etc/network/interfaces
# 	echo "allow-hotplug \${i}" >> /etc/network/interfaces
# 	echo "iface \${i} inet dhcp" >> /etc/network/interfaces
# 	if ! ethtool \${i} | grep -sq 'Supports Wake-on: d'; then
# 		echo "up ethtool -s \${i} wol g" >> /etc/network/interfaces
# 	fi
# done
# systemctl restart networking.service

## Firewall ##
iptables -F
iptables -X
iptables -Z
iptables -P INPUT DROP
iptables -P OUTPUT ACCEPT
iptables -P FORWARD DROP
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

ip6tables -F
ip6tables -X
ip6tables -Z
ip6tables -P INPUT DROP
ip6tables -P OUTPUT ACCEPT
ip6tables -P FORWARD DROP
ip6tables -A INPUT -i lo -j ACCEPT
ip6tables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
EOF

echo "Create GRUB boot menu ..."
cat << EOF > /bootfiles/grub/grub.cfg
serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1
terminal_input console serial
terminal_output console serial
set timeout=5
probe -u \$root --set=boot_uuid
menuentry "Debian" {
	linux	/EFI/vmlinuz-`uname -r` root=UUID=\$boot_uuid ro console=ttyS0,115200 console=tty0
	initrd	/EFI/initrd.img-`uname -r`
}
if [ "\$grub_platform" = "efi" ]; then
menuentry 'UEFI Firmware Settings' {
	fwsetup
}
fi
EOF

echo "Boot files are ready, restore to original files ..."
cp /usr/share/initramfs-tools/scripts/local.original /usr/share/initramfs-tools/scripts/local
cp /etc/initramfs-tools/modules.original /etc/initramfs-tools/modules
cp /etc/fstab.original /etc/fstab
systemctl disable startup.service
rm /etc/systemd/system/startup.service
systemctl daemon-reload