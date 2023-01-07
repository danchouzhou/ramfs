# Build a ramfs boot medium.

## Usage
- Clone the project
```
git clone https://github.com/danchouzhou/ramfs.git
```
- Excuting shell script
```
cd ramfs
chmod +x ramfs_setup.sh
sudo ./ramfs_setup.sh
```
- Make a boot medium
Assume that your boot partition is /dev/sdb1
```
# Mount boot partition to /boot
sudo umount /boot
sudo mount /dev/sdb1 /boot

# Copy the boot files
sudo cp /bootfiles/* /boot

# Install GRUB
sudo grub-install /dev/sdb

# Create GRUB boot menu
sudo update-grub

# Check UUID of your boot partition
sudo blkid

# Change root UUID in the boot menu
sudo nano /boot/grub/grub.cfg

# Unmount and your disk is ready to boot!
sudo umount /boot
```
- Read this article for more detail
[Build a RAM based filesystem server | Danny’s tech blog](https://danchouzhou.github.io/2022/10/31/ram-based-rootfs-server.html)
## Tested distributions
- Debian 11.5 (bullseye)
