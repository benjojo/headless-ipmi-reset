#!/bin/sh

set -e

GENIMAGE_CFG="$2"

support/scripts/genimage.sh -c "$GENIMAGE_CFG"

cd "$BINARIES_DIR"
mkdir -p root/boot
cp bzImage root/boot/vmlinuz
cp rootfs.cpio.gz root/boot/initrd.img
mkdir -p root/EFI/BOOT
cp efi-part/EFI/BOOT/* root/EFI/BOOT/
cp efiboot.img root/EFI/BOOT/

mkisofs \
   -o boot-mkisofs.iso \
   -R -J -v -d -N \
   -hide-rr-moved \
   -boot-load-size 4 -boot-info-table \
   -no-emul-boot \
   -eltorito-platform=efi \
   -eltorito-boot EFI/BOOT/efiboot.img \
   -V "EFIBOOTISO" \
   -A "EFI Boot ISO" \
   root

BOOT_IMG_DATA=$(mktemp -d)
BOOT_IMG="$BOOT_IMG_DATA/efi.img"
dd if=/dev/zero of="$BOOT_IMG" bs=1M count=50

# Format as FAT32
mkfs.vfat "$BOOT_IMG"

# Copy EFI directory contents to the image
mcopy -i "$BOOT_IMG" -s    root/EFI ::
mcopy -i "$BOOT_IMG" -s    root/boot ::

xorriso \
  -as mkisofs \
  -o boot-xorriso.iso \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  -eltorito-alt-boot \
  -e EFI/BOOT/efiboot.img \
  -no-emul-boot \
  -append_partition 2 0xef "$BOOT_IMG" \
  -iso-level 3 \
  root/

cd -
