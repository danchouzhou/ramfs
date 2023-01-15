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
## Make a boot disk
Assume that your boot partition is /dev/sdb1
```
# Mount boot partition to /mnt
sudo mount /dev/sdb1 /mnt

# Copy the boot files
sudo mkdir /mnt/EFI
sudo cp /bootfiles/* /mnt/EFI

# Install GRUB
sudo grub-install --target=x86_64-efi --removable --efi-directory=/mnt --boot-directory=/mnt/EFI /dev/sdb
sudo grub-install --target=i386-pc --removable --root-directory=/mnt/EFI --boot-directory=/mnt/EFI /dev/sdb

# Create GRUB boot menu
sudo nano /mnt/EFI/grub/grub.cfg

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

# Unmount and your disk is ready to boot!
sudo umount /mnt
```
## Make a boot DVD
```
# Copy boot files
mkdir -p iso/EFI
sudo cp /bootfiles/* iso/EFI

# Build EFI boot image
mkdir -p iso/boot/grub/x86_64-efi
dd if=/dev/zero of=iso/boot/grub/x86_64-efi/efi.img bs=512 count=32K
mkfs.vfat iso/boot/grub/x86_64-efi/efi.img
sudo mount iso/boot/grub/x86_64-efi/efi.img /mnt
sudo grub-install --target=x86_64-efi --removable --efi-directory=/mnt --boot-directory=/mnt iso/boot/grub/x86_64-efi/efi.img
sudo umount /mnt

# Build legacy BIOS boot image
sudo grub-mkimage -O i386-pc -o core.img -p /boot/grub iso9660 biosdisk search probe
mkdir -p iso/boot/grub/i386-pc
cat /usr/lib/grub/i386-pc/cdboot.img core.img > iso/boot/grub/i386-pc/eltorito.img
cp /usr/lib/grub/i386-pc/* iso/boot/grub/i386-pc/

# Create GRUB boot menu
nano iso/boot/grub/grub.cfg

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

# Create disk image
sudo xorriso -as mkisofs -r \
  -V Ubuntu-22.04 \
  -o ubuntu-22.04-xfce-ramfs.iso \
  -J -joliet-long \
  -b boot/grub/i386-pc/eltorito.img \
  -boot-load-size 4 -boot-info-table -no-emul-boot \
  -eltorito-alt-boot \
  -e boot/grub/x86_64-efi/efi.img -no-emul-boot \
  iso
```
## Read this article for more detail
[Build a RAM based filesystem server | Danny’s tech blog](https://danchouzhou.github.io/2022/10/31/ram-based-rootfs-server.html)

## Tested distributions
- Debian 11.5 (bullseye)

## Reference
[Specifications | Unified Extensible Firmware Interface Forum](https://uefi.org/specifications)
