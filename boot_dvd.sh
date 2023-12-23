#!/bin/bash

# Exit if there is any error
set -e

echo "Copying bootfiles ..."
mkdir -p iso/EFI
cp -r /bootfiles/* iso/EFI

echo "Building EFI boot image ..."
mkdir -p iso/EFI/grub/x86_64-efi
dd if=/dev/zero of=iso/EFI/grub/x86_64-efi/efi.img bs=512 count=32K
mkfs.vfat iso/EFI/grub/x86_64-efi/efi.img
mount iso/EFI/grub/x86_64-efi/efi.img /mnt
grub-install --target=x86_64-efi --removable --efi-directory=/mnt --boot-directory=/mnt/EFI iso/EFI/grub/x86_64-efi/efi.img
cp -r /mnt/EFI/* iso/EFI
umount /mnt

echo "Building boot image for legacy BIOS ..."
grub-mkimage -O i386-pc -o core.img -p /EFI/grub iso9660 biosdisk search probe
mkdir -p iso/EFI/grub/i386-pc
cat /usr/lib/grub/i386-pc/cdboot.img core.img > iso/EFI/grub/i386-pc/eltorito.img
cp /usr/lib/grub/i386-pc/* iso/EFI/grub/i386-pc/

# Create disk image
xorriso -as mkisofs -r \
  -V 'Debian 12' \
  -o debian-12.4.0-xfce-ramfs.iso \
  -J -joliet-long \
  -b EFI/grub/i386-pc/eltorito.img \
  -boot-load-size 4 -boot-info-table -no-emul-boot \
  -eltorito-alt-boot \
  -e EFI/grub/x86_64-efi/efi.img -no-emul-boot \
  iso
