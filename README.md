# Build a ramfs boot medium.

## Usage
### Install Ubuntu Server 22.04.1 minimal
### Clone the project
```
git clone https://github.com/danchouzhou/ramfs.git
```
### Excuting shell script
```
cd ramfs
chmod +x ramfs_setup.sh
sudo ./ramfs_setup.sh
```
### Make a boot medium
Assume that your boot partition is /dev/sdb1
```
# Mount boot partition to /boot
sudo umount /boot/efi
sudo umount /boot
sudo mount /dev/sdb1 /boot

# Copy the boot files
sudo mkdir /boot/EFI
sudo cp /bootfiles/* /boot/EFI

# Install GRUB
sudo grub-install --target=x86_64-efi --removable --efi-directory=/boot --boot-directory=/boot/EFI /dev/sdb
sudo grub-install --target=i386-pc --removable --root-directory=/boot/EFI --boot-directory=/boot/EFI /dev/sdb

# Create GRUB boot menu
sudo nano /boot/EFI/grub/grub.cfg

set timeout=5

set menu_color_normal=white/black
set menu_color_highlight=black/light-gray

probe -u $root --set=boot_uuid

menuentry "Ubuntu" {
	linux	/EFI/vmlinuz-5.15.0-57-generic root=UUID=$boot_uuid ro console=tty0
	initrd	/EFI/initrd.img-5.15.0-57-generic
}
grub_platform
if [ "$grub_platform" = "efi" ]; then
menuentry 'UEFI Firmware Settings' {
	fwsetup
}
fi

# Check UUID of your boot partition
sudo blkid

# Change root UUID in the boot menu
sudo nano /boot/grub/grub.cfg

# Unmount and your disk is ready to boot!
# Binded /boot/EFI
sudo umount /boot
# Actual /boot
sudo umount /boot
```
### Read this article for more detail
[Build a RAM based filesystem server | Danny’s tech blog](https://danchouzhou.github.io/2022/10/31/ram-based-rootfs-server.html)
## Tested distributions
- Debian 11.5 (bullseye)
