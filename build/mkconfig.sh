#!/bin/bash
# RedNext ISO kernel config (separate from the host kernel: LOCALVERSION -rednext-generic).
#  1. start from the host's own config (/sources/LFS/linux-6.18.10/.config)
#  2. add Arch linux-lts driver coverage for options the host config does not set
#  3. host wins: every value the host sets explicitly is kept
#  4. force the live-boot / installer essentials
set -euo pipefail
W=$HOME/apps/dl/rednext-iso/kernel
K=$W/linux-6.18.10-iso
HOST=$W/config-current-host
ARCH=$W/config-arch-lts-reference
cd "$K"
cp "$HOST" .config

# 2. Arch =m/=y options the host doesn't set (absent or "is not set"),
#    minus host-tuned choice groups where the host's pick must stay
grep -E '^CONFIG_[A-Z0-9_]+=' "$HOST" | cut -d= -f1 | sort -u > "$W/.host-set"
grep -E '^CONFIG_[A-Z0-9_]+=(m|y)$' "$ARCH" \
  | grep -vE '^CONFIG_(HZ_[0-9]+|PREEMPT[A-Z_]*|NO_HZ[A-Z_]*|CPU_FREQ_DEFAULT_GOV_[A-Z]+|DEFAULT_SECURITY_[A-Z]+|KERNEL_(GZIP|BZIP2|LZMA|XZ|LZO|LZ4|ZSTD)|X86_INTEL_TSX_MODE_[A-Z]+|TICK_CPU_ACCOUNTING|VIRT_CPU_ACCOUNTING_GEN|CC_OPTIMIZE_FOR_[A-Z]+|RCU_EXPERT|EXPERT|MAXSMP|RUST|DEBUG_INFO[A-Z0-9_]*|MODULE_SIG[A-Z_]*|LOCALVERSION_AUTO)=' \
  | awk -F= 'NR==FNR{h[$1]=1;next} !($1 in h)' "$W/.host-set" - > "$W/.arch-add"
echo "taken from Arch: $(wc -l < "$W/.arch-add") options"
while IFS='=' read -r k v; do sed -i "/^# $k is not set$/d" .config; done < "$W/.arch-add"
cat "$W/.arch-add" >> .config
make olddefconfig > /dev/null 2>&1

s() { scripts/config --file .config "$@"; }
essentials() {
  s --set-str LOCALVERSION "-rednext-generic" --disable LOCALVERSION_AUTO
  s --set-str DEFAULT_HOSTNAME "rednext"
  s --disable RUST --disable DEBUG_INFO_BTF --enable DEBUG_INFO_NONE \
    --disable DEBUG_INFO_DWARF5 --disable DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT
  s --disable MODULE_SIG --disable MODULE_SIG_ALL
  s --enable FW_LOADER_COMPRESS --enable FW_LOADER_COMPRESS_ZSTD --enable FW_LOADER_COMPRESS_XZ
  s --enable MODULE_COMPRESS --enable MODULE_COMPRESS_ZSTD --enable MODULE_COMPRESS_ALL
  local o
  for o in SQUASHFS SQUASHFS_XZ SQUASHFS_ZSTD SQUASHFS_XATTR SQUASHFS_FILE_DIRECT OVERLAY_FS \
           ISO9660_FS JOLIET ZISOFS BLK_DEV_LOOP EXT4_FS VFAT_FS NLS_CP437 NLS_ISO8859_1 NLS_UTF8 \
           BLK_DEV_SD BLK_DEV_SR SATA_AHCI ATA_PIIX BLK_DEV_NVME USB_XHCI_HCD USB_EHCI_HCD USB_OHCI_HCD \
           USB_UHCI_HCD USB_STORAGE USB_UAS HID_GENERIC USB_HID VIRTIO_PCI VIRTIO_BLK SCSI_VIRTIO \
           INTEL_IDLE EFIVAR_FS DEVTMPFS DEVTMPFS_MOUNT BLK_DEV_INITRD RD_ZSTD RD_XZ; do
    s --enable $o
  done
}
# the ISO needs these built in even where the host has them as modules
SKIP='CONFIG_LOCALVERSION|CONFIG_DEFAULT_HOSTNAME|CONFIG_MODULE_SIG*|CONFIG_DEBUG_INFO*|CONFIG_USB_UAS|CONFIG_EFIVAR_FS'

# 3. host wins (except the ISO-specific settings above), until stable
for pass in 1 2 3 4 5; do
  essentials
  make olddefconfig > /dev/null 2>&1
  changed=0
  while IFS= read -r line; do
    k=${line%%=*}
    grep -qxF "$line" .config && continue
    eval "case \$k in $SKIP) continue;; esac"
    sed -i "/^$k=/d;/^# $k is not set$/d" .config; echo "$line" >> .config; changed=$((changed+1))
  done < <(grep -E '^CONFIG_[A-Z0-9_]+=' "$HOST")
  make olddefconfig > /dev/null 2>&1
  echo "pass $pass: re-asserted $changed host values"
  [ $changed = 0 ] && break
done
essentials; make olddefconfig > /dev/null 2>&1

# report host values that still could not be kept
lost=0
while IFS= read -r line; do
  k=${line%%=*}
  eval "case \$k in $SKIP) continue;; esac"
  grep -qxF "$line" .config || { echo "host value not kept: $line -> $(grep -E "^$k=|^# $k is not set" .config || echo gone)"; lost=$((lost+1)); }
done < <(grep -E '^CONFIG_[A-Z0-9_]+=' "$HOST")
echo "host values not kept: $lost"

fail=0
for o in SQUASHFS SQUASHFS_XZ SQUASHFS_ZSTD OVERLAY_FS ISO9660_FS BLK_DEV_LOOP EXT4_FS VFAT_FS BLK_DEV_NVME \
         SATA_AHCI USB_XHCI_HCD USB_STORAGE USB_UAS INTEL_IDLE FW_LOADER_COMPRESS_ZSTD; do
  grep -q "^CONFIG_$o=y" .config || { echo "MISSING CONFIG_$o=y -> $(grep -E "^CONFIG_$o=|^# CONFIG_$o is not set" .config || echo gone)"; fail=1; }
done
grep -q '^CONFIG_LOCALVERSION="-rednext-generic"' .config || { echo "BAD LOCALVERSION"; fail=1; }
echo "kernel release: $(make -s kernelrelease)"
echo "modules: $(grep -c '=m$' .config)   built-in: $(grep -c '=y$' .config)"
cp .config "$W/config-rednext-generic"
rm -f "$W/.host-set" "$W/.arch-add"
[ $fail = 0 ] && echo CONFIG OK
