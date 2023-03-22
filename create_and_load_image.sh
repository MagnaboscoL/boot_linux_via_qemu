#!/bin/bash

# Create an empty 1G disk image.
qemu-img create -f raw fs.img 1G

# Format the image with an MBR artition table on the first sector of the disk.
/sbin/parted -s fs.img mktable msdos

# Use the rest of the image as the primary bootable partition.
/sbin/parted -s fs.img mkpart primary ext4 1 "100%"
/sbin/parted -s fs.img set 1 boot on

# Attach the image to a loopback device.
HDA_LOOP_DEV=$(sudo losetup -Pf --show fs.img)
FS_LOOP_DEV="${HDA_LOOP_DEV?}p1"
# Echo the loop device in case we need to losetup it "manually"
echo HDA_LOOP_DEV=${HDA_LOOP_DEV}

# Initialize the filesystem in the primary partition.
sudo mkfs -t ext4 -v "${FS_LOOP_DEV?}"

# Mount the file system
mkdir tmpmnt
sudo mount "${FS_LOOP_DEV?}" tmpmnt
sudo chown -R ${USER?} tmpmnt

# Install grub2.
mkdir -p tmpmnt/boot/grub
echo "(hd0) ${HDA_LOOP_DEV?}" >tmpmnt/boot/grub/device.map
sudo grub-install \
  -v \
  --directory=modules \
  --locale-directory=locale \
  --boot-directory=tmpmnt/boot \
  ${HDA_LOOP_DEV?} \
  2>&1

# Create a minimal grub.cfg
cat >tmpmnt/boot/grub/grub.cfg <<EOF
serial
terminal_input serial
terminal_output serial
set root=(hd0,1)
linux /boot/bzImage \
  root=/dev/sda1 \
  console=ttyS0 \
  init=/bin/hello_world \
  noapic \
  acpi=off
boot
EOF

# Install the kernel into the ext4 FS.
cp ./bzImage tmpmnt/boot/bzImage

# Copy the binary to run after boot.
mkdir tmpmnt/bin/
cp bin/hello_world tmpmnt/bin/hello_world
sudo chmod +x tmpmnt/bin/hello_world

sudo umount tmpmnt
rm -rf tmpmnt
sudo losetup -d ${HDA_LOOP_DEV}

echo The bootable image is ready
sleep 10s
echo Loading the image using QEMU
sleep 10s

qemu-system-x86_64 -m 1024 -drive format=raw,file=fs.img -nographic -serial mon:stdio
