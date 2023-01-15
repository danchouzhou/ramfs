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
```
```
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
```
```
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
```
```
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
```
```
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
- [Specifications | Unified Extensible Firmware Interface Forum](https://uefi.org/specifications)
- [Ubuntu Manpage: grub-install - install GRUB to a device](https://manpages.ubuntu.com/manpages/jammy/man8/grub-install.8.html)
- [Ubuntu Manpage: grub-mkrescue - make a GRUB rescue image](https://manpages.ubuntu.com/manpages/jammy/en/man1/grub-mkrescue.1.html)
- [Ubuntu Manpage: grub-mkimage - make a bootable image of GRUB](https://manpages.ubuntu.com/manpages/jammy/man1/grub-mkimage.1.html)
- [Ubuntu Manpage: grub-mkstandalone - make a memdisk-based GRUB image](https://manpages.ubuntu.com/manpages/jammy/man1/grub-mkstandalone.1.html)
- [硬碟多重開機與BootLoader - 餃子海盜股份有限公司](https://sites.google.com/site/gyozapriate/Home/linux-island/boot/hdd-boot-multi)
- [玩具烏托邦: 製作 UEFI 開機光碟 iso 映像檔](https://newtoypia.blogspot.com/2020/11/uefi-iso.html)
- [8.4. 使用 GRUB 设定引导过程](https://lfs.xry111.site/zh_CN/8.3/chapter08/grub.html)
- [GNU GRUB Manual 2.06: Making a GRUB bootable CD-ROM](https://www.gnu.org/software/grub/manual/grub/html_node/Making-a-GRUB-bootable-CD_002dROM.html)
- [Making a GRUB bootable CD-ROM | GRUB Manual](https://www.gnu.org/software/grub/manual/legacy/Making-a-GRUB-bootable-CD-ROM.html)
- [Chris's Wiki :: blog/linux/Ubuntu2004ISOWithUEFI](https://utcc.utoronto.ca/~cks/space/blog/linux/Ubuntu2004ISOWithUEFI)
- [Installing GRUB on an hybrid BIOS/UEFI stick](https://www.normalesup.org/~george/comp/live_iso_usb/grub_hybrid.html)
- [E.2.2. GRUB and the Boot Process on UEFI-based x86 Systems Red Hat Enterprise Linux 6 | Red Hat Customer Portal](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/installation_guide/s2-grub-whatis-booting-uefi)
