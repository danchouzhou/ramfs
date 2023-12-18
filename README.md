# Build a ramfs boot medium.

## Usage
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
# Mount boot partition to /mnt
sudo mount /dev/sdb1 /mnt

# Copy the boot files
sudo mkdir /mnt/EFI
sudo cp -r /bootfiles/* /mnt/EFI

# Install GRUB
sudo grub-install --target=x86_64-efi --removable --efi-directory=/mnt --boot-directory=/mnt/EFI
sudo grub-install --target=i386-pc --root-directory=/mnt/EFI --boot-directory=/mnt/EFI /dev/sdb

# Unmount and your disk is ready to boot!
sudo umount /mnt
```

## Read this article for more detail
[Build a RAM based filesystem server | Danny’s tech blog](https://danchouzhou.github.io/2022/10/31/ram-based-rootfs-server.html)
## Tested distributions
- Debian 11.6 (bullseye)
