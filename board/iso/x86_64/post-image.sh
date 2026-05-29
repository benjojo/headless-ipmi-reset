#!/bin/sh

set -e

BOARD_DIR=$(dirname "$0")
GENIMAGE_CFG="$2"

support/scripts/genimage.sh -c "$GENIMAGE_CFG"

cd "$BINARIES_DIR"
mkdir -p root/boot
cp bzImage root/boot/vmlinuz
cp rootfs.cpio.gz root/boot/initrd.img
mkdir -p root/EFI/BOOT
cp efi-part/EFI/BOOT/* root/EFI/BOOT/
cp efiboot.img root/EFI/BOOT/

# Legacy BIOS boot: setup ISOLINUX
mkdir -p root/isolinux
cp "$BINARIES_DIR/syslinux/isolinux.bin" root/isolinux/
cp "$HOST_DIR/share/syslinux/ldlinux.c32" root/isolinux/
cp "$BOARD_DIR/isolinux.cfg" root/isolinux/isolinux.cfg

# Create hybrid ISO with BIOS (primary, ISOLINUX) and EFI (alt) El Torito entries
xorriso -as mkisofs \
   -o boot-mkisofs.iso \
   -R -J -v -d -N \
   -hide-rr-moved \
   -b isolinux/isolinux.bin \
   -no-emul-boot \
   -boot-load-size 4 \
   -boot-info-table \
   -eltorito-alt-boot \
   -e EFI/BOOT/efiboot.img \
   -no-emul-boot \
   -V "EFIBOOTISO" \
   -A "Hybrid Boot ISO" \
   root

# Make ISO bootable from USB on legacy BIOS
"${HOST_DIR}/bin/isohybrid" -t 0x96 boot-mkisofs.iso

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
  -b isolinux/isolinux.bin \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  -eltorito-alt-boot \
  -e EFI/BOOT/efiboot.img \
  -no-emul-boot \
  -append_partition 2 0xef "$BOOT_IMG" \
  -iso-level 3 \
  root/

# Make ISO bootable from USB on legacy BIOS
"${HOST_DIR}/bin/isohybrid" -t 0x96 boot-xorriso.iso

cd -
