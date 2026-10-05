#!/bin/bash
# Build the RedNext live ISO from the running system.
#   1. ./build-installer.sh        (as the normal user, once: ISO tools + Calamares stack)
#   2. ./prep-overlay.sh          (as the normal user: theme/config overlay)
#   3. sudo ./mkiso.sh [step...]   steps: rootfs initramfs squashfs iso (default: all)
# Work dir: $W (default ~<sudo user>/apps/dl/rednext-iso); scripts + installer config live next to this file.
# Output: $W/out/rednext-live-<date>.iso  (hybrid BIOS + UEFI, dd-able to USB)
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "run with sudo" >&2; exit 1; }

S=$(cd "$(dirname "$0")" && pwd)   # this scripts dir (calamares/ config tree, scrub-paths.py)
W=${W:-$(getent passwd "${SUDO_USER:-root}" | cut -d: -f6)/apps/dl/rednext-iso}
BU=${SUDO_USER:?run with sudo from the build user}   # build user: must not appear anywhere in the image
# extra words that must never end up in the image (e.g. your email name, GitHub handle), space-separated:
#   sudo PRIVATE_WORDS="myname42 MyGitHub" ./mkiso.sh
PW=(); for w in ${PRIVATE_WORDS:-}; do PW+=(-e "$w"); done
R=$W/rootfs            # staged live root filesystem
I=$W/iso               # ISO tree
N=$W/initramfs         # initramfs tree
K=$W/kernel/stage      # staged ISO kernel + modules
IS=$W/installer/stage  # Calamares + kpmcore + yaml-cpp + dosfstools + squashfs-tools (live image only)
KVER=6.18.10-rednext-generic
LABEL=REDNEXT_LIVE
OUT=$W/out/rednext-live-$(date +%Y%m%d).iso
export PATH=$W/tools/stage/usr/bin:$PATH   # mksquashfs, xorriso, mtools
LOG=$W/out/mkiso.log
mkdir -p "$W/out"
exec > >(tee -a "$LOG") 2>&1
say() { printf '\n==> %s\n' "$*"; }

step_rootfs() {
  say "copying system into $R"
  # never rsync --delete into a leftover bind mount (it would delete the host's /dev etc.)
  if grep -q " $R/" /proc/mounts; then echo "something is still mounted under $R; unmount it first" >&2; exit 1; fi
  mkdir -p "$R"
  rsync -aHAX --delete --delete-excluded --one-file-system --info=progress2 \
    --exclude='/home/*' --exclude='/root/*' --exclude='/sources' --exclude='/lost+found' \
    --exclude='/tmp/*' --exclude='/var/tmp/*' --exclude='/var/log/*' --exclude='/var/cache/*' \
    --exclude='/var/lib/systemd/coredump/*' --exclude='/var/lib/bluetooth/*' \
    --exclude='/var/lib/NetworkManager/*' --exclude='/var/lib/rednext-installer' \
    --exclude='/var/lib/sddm/.local' --exclude='/var/lib/sddm/.cache' --exclude='/var/lib/sddm/state.conf' \
    --exclude='/etc/NetworkManager/system-connections/*' --exclude='/etc/ssh/ssh_host_*' \
    --exclude='/boot/*' --exclude='/swapfile' \
    --exclude='/usr/lib/modules/*' --exclude='/usr/include' --exclude='/usr/local/include' \
    --exclude='/usr/share/doc' --exclude='/usr/share/gtk-doc' --exclude='/usr/local/go' \
    --exclude='/opt/rustc*' --exclude='/etc/profile.d/rustc.sh' --exclude='/etc/profile.d/go.sh' \
    --exclude='*.bak-*' --exclude='*.orig' --exclude='/.Trash-*' --exclude='/tmpjcef-*' \
    --exclude='/var/lib/upower/*' --exclude='/var/lib/sddm/.config/pulse' --exclude='/var/lib/sddm/.dbus' \
    --exclude='/var/db/sudo/*' --exclude='/var/lib/systemd/backlight/*' --exclude='/var/lib/systemd/rfkill/*' \
    --exclude='/var/lib/systemd/timesync/*' --exclude='/var/lib/systemd/linger/*' --exclude='/var/lib/systemd/pstore/*' \
    --exclude='/var/lib/plymouth/*' --exclude='/var/lib/AccountsService/users/*' --exclude='/var/lib/AccountsService/icons/*' \
    --exclude='/var/lib/private/*' --exclude='/var/lib/udisks2/*' --exclude='/var/lib/locate/*' --exclude='/var/spool/cups/*' \
    --exclude='/var/lib/machines/*' --exclude='/var/lib/portables/*' --exclude='/var/lib/sshd/*' \
    --exclude='/etc/credstore/*' --exclude='/etc/credstore.encrypted/*' --exclude='/usr/src/*' \
    --exclude='/usr/share/sddm/themes/*/.git' --exclude='/etc/*-' --exclude='/etc/.pwd.lock' \
    / "$R/"
  # rsync --one-file-system skips mount points' contents; make sure they exist
  mkdir -p "$R"/{proc,sys,dev,run,tmp,mnt,media,boot,home,root,live}
  chmod 1777 "$R/tmp"; chmod 700 "$R/root"

  say "fix ownership of system files (build uids -> root)"
  find "$R" -xdev -path "$R/home" -prune -o \( -uid 1000 -o -uid 1001 -o -uid 50501 -o -gid 1000 -o -gid 1001 -o -gid 50501 \) \
    -exec chown -h root:root {} +

  say "kernel modules $KVER"
  cp -a "$K/lib/modules/$KVER" "$R/usr/lib/modules/"
  chown -R root:root "$R/usr/lib/modules/$KVER"
  rm -f "$R/usr/lib/modules/$KVER"/{build,source}
  depmod -b "$R" "$KVER"

  say "theme overlay"
  rsync -rlptK --chown=root:root "$W/overlay/" "$R/"

  say "installer (Calamares) + RedNext config"
  rsync -rlptK --chown=root:root --exclude=/usr/include --exclude=/usr/lib/cmake --exclude=/usr/lib/pkgconfig \
    --exclude=/usr/share/cmake --exclude='*.a' "$IS/" "$R/"
  # installer config tree: ../calamares in the GitHub repo layout, ./calamares in a flat scripts dir
  CT=$S/../calamares; [ -d "$CT" ] || CT=$S/calamares
  rsync -rlptK --chown=root:root "$CT/" "$R/"
  # everything the installed system must NOT keep; installer-prepare-target deletes these
  mkdir -p "$R/usr/lib/rednext"
  { ( cd "$IS" && find . -name '*calamares*' -prune -print | sed 's#^\.##' )
    printf '%s\n' /etc/calamares /usr/lib/calamares /usr/bin/rednext-installer \
      /usr/share/applications/rednext-installer.desktop /usr/libexec/rednext/installer-prepare-target \
      /usr/libexec/rednext/install-optional-app /usr/libexec/rednext/rednext-disk /usr/lib/rednext/spotify-deps
  } | sort -u > "$R/usr/lib/rednext/live-only.list"

  say "scrub build-user paths from binaries (same-length rewrite, image copy only)"
  python3 "$S/scrub-paths.py" "$BU" "$R" | sed 's/^/  /'

  say "host identity -> live identity"
  # drop the build user; the live user is created fresh below
  for f in passwd shadow; do sed -i "/^$BU:/d" "$R/etc/$f"; done
  for f in group gshadow; do
    [ -f "$R/etc/$f" ] || continue
    sed -i "/^$BU:/d; s/\([:,]\)$BU\(,\|$\)/\1/; s/,$//" "$R/etc/$f"
  done
  : > "$R/etc/machine-id"
  rm -f "$R/var/lib/systemd/random-seed" "$R/var/lib/dbus/machine-id"
  echo rednext-live > "$R/etc/hostname"
  cat > "$R/etc/fstab" <<'FSTAB'
# RedNext live: / is an overlay (squashfs + tmpfs) set up by the initramfs
FSTAB
  ln -sf /dev/null "$R/etc/systemd/system/systemd-firstboot.service"

  say "live user (no password)"
  for m in dev proc sys; do mount --bind /$m "$R/$m"; done
  trap 'for m in sys proc dev; do umount "$R/$m" 2>/dev/null; done' EXIT
  chroot "$R" /usr/bin/bash -c '
    id live >/dev/null 2>&1 || useradd -m -u 1000 -G wheel,audio,video,input,netdev,lp,kvm -s /usr/bin/fish -c "RedNext Live" live
    passwd -d live >/dev/null
    passwd -l root >/dev/null
    # /var/cache is excluded, so build the font cache here; without it the first
    # SDDM greeter rescans every font straight off the USB and looks stuck
    fc-cache -sf >/dev/null'

  say "live-only installer launchers (never in /etc/skel, so installed users don't get them)"
  LH=$R/home/live
  install -Dm755 "$R/usr/share/applications/rednext-installer.desktop" "$LH/Desktop/rednext-installer.desktop"
  # Hyprland/Caelestia: open the installer once the shell is up, Super+I opens it again
  cat >> "$LH/.config/caelestia/hypr-user.lua" <<'HL'

-- RedNext live session only (not on installed systems): installer autostart + Super+I
hl.on("hyprland.start", function()
    hl.exec_cmd("sh -c 'sleep 5; rednext-installer'")
end)
hl.bind("SUPER + I", hl.dsp.exec_cmd("rednext-installer"))
hl.window_rule({ match = { class = "(?i).*calamares.*" }, float = true, center = true, opaque = true })
HL
  chown -R 1000:1000 "$LH"

  say "live readahead (pull the login screen off the USB while the splash plays)"
  install -Dm755 /dev/stdin "$R/usr/libexec/rednext/live-readahead" <<'RA'
#!/bin/bash
# RedNext live only: read what the SDDM greeter needs into the page cache while
# Plymouth is still playing, so the login screen comes up without a long pause.
T=/usr/share/sddm/themes/sddm-astronaut-theme
Q=/opt/qt6
{
  find $T -path "$T/Backgrounds" -prune -o -type f -print
  echo $T/Backgrounds/sekhiro_sddm.mp4
  ls /usr/bin/sddm-greeter-qt6 $Q/lib/libQt6*.so.6.* | grep -v WebEngine
  find $Q/qml/QtQuick $Q/qml/QtQml $Q/qml/QtMultimedia $Q/qml/Qt5Compat $Q/qml/SddmComponents \
       $Q/plugins/platforms $Q/plugins/multimedia $Q/plugins/imageformats $Q/plugins/wayland-* \
       $Q/plugins/xcbglintegrations $Q/plugins/egldeviceintegrations -type f 2>/dev/null
  ls /usr/lib/libavcodec.so.* /usr/lib/libavformat.so.* /usr/lib/libavutil.so.* /usr/lib/libswscale.so.* /usr/lib/libswresample.so.* 2>/dev/null
} | xargs -r -d '\n' cat > /dev/null 2>&1
exit 0
RA
  cat > "$R/etc/systemd/system/rednext-live-readahead.service" <<'UNIT'
[Unit]
Description=RedNext live: preload the login screen
DefaultDependencies=no
After=plymouth-start.service
ConditionPathIsDirectory=/live/sfs

[Service]
ExecStart=/usr/libexec/rednext/live-readahead
# idle priority: never steal CPU/disk from the splash animation
Nice=19
CPUSchedulingPolicy=idle
IOSchedulingClass=idle

[Install]
WantedBy=sysinit.target
UNIT
  mkdir -p "$R/etc/systemd/system/sysinit.target.wants"
  ln -sf ../rednext-live-readahead.service "$R/etc/systemd/system/sysinit.target.wants/"
  # live boots from USB and plymouthd starts later (no plymouth in our initramfs): give the
  # 4 s intro a little more headroom than the installed system's 5.2 s
  sed -i 's#splash-min-time 5\.2#splash-min-time 6.0#' "$R/etc/systemd/system/plymouth-quit.service.d/rednext-min-time.conf"

  say "PATH: /usr/local/bin + /usr/sbin for every user"
  # /etc/profile sets PATH=/usr/bin; on the build host /usr/local/bin only came from the
  # user's fish universal variables, so the live session couldn't find Hyprland, qs, hyprctl...
  cat > "$R/etc/profile.d/00-rednext-path.sh" <<'P'
# RedNext: programs built into /usr/local (Hyprland, quickshell, ...) and /usr/sbin
pathprepend /usr/sbin
pathprepend /usr/local/bin
P
  say "per-user home paths in skel files (Dolphin Places) -> filled at first login"
  cat > "$R/etc/profile.d/10-rednext-home-paths.sh" <<'P'
# RedNext: /etc/skel's Dolphin Places list holds @HOME@; point it at this user's home once
_rn_f="$HOME/.local/share/user-places.xbel"
[ -f "$_rn_f" ] && grep -q '@HOME@' "$_rn_f" 2>/dev/null && sed -i "s#@HOME@#$HOME#g" "$_rn_f"
unset _rn_f
P
  cat > "$R/etc/fish/conf.d/00-rednext-path.fish" <<'P'
# RedNext: fish doesn't read /etc/profile; same PATH as profile.d/00-rednext-path.sh
fish_add_path -gP /usr/local/bin /usr/sbin
P
  # shadow-utils leaves *- backups of the pre-edit files; drop them, and any sudo rule naming the build user
  rm -f "$R"/etc/{passwd,shadow,group,gshadow,subuid,subgid}-
  sed -i "/^$BU[: ]/d" "$R"/etc/subuid "$R"/etc/subgid 2>/dev/null || true
  grep -rlw "$BU" "$R/etc/sudoers" "$R/etc/sudoers.d" 2>/dev/null | xargs -r sed -i "/\b$BU\b/d" || true
  install -d -m750 "$R/etc/sudoers.d"
  echo 'live ALL=(ALL:ALL) NOPASSWD: ALL' > "$R/etc/sudoers.d/live"
  chmod 440 "$R/etc/sudoers.d/live"
  grep -qE '^[@#]includedir /etc/sudoers.d' "$R/etc/sudoers" || echo '@includedir /etc/sudoers.d' >> "$R/etc/sudoers"
  # SDDM: let "live" in with an empty password (live image only)
  grep -q 'user = live' "$R/etc/pam.d/sddm" || \
    sed -i '0,/^auth.*include.*system-auth/s//auth     sufficient     pam_succeed_if.so user = live quiet\n&/' "$R/etc/pam.d/sddm"

  say "checks"
  local ok=1
  chk() { if eval "$2"; then echo "  ok   $1"; else echo "  FAIL $1"; ok=0; fi; }
  chk "plymouth theme rednext"       "[ -f $R/usr/share/plymouth/themes/rednext/rednext.script ] && grep -q '^Theme=rednext' $R/etc/plymouth/plymouthd.conf"
  chk "plymouth min-time hold"       "[ -f $R/etc/systemd/system/plymouth-quit.service.d/rednext-min-time.conf ] && [ -x $R/usr/libexec/rednext/splash-min-time ]"
  chk "plymouth shutdown masks"      "[ -L $R/etc/systemd/system/plymouth-poweroff.service ]"
  chk "sddm astronaut theme"         "grep -q sddm-astronaut-theme $R/etc/sddm.conf"
  chk "sddm video audio (Main.qml)"  "grep -q AudioOutput $R/usr/share/sddm/themes/sddm-astronaut-theme/Main.qml"
  chk "sddm loud video"              "[ -f $R/usr/share/sddm/themes/sddm-astronaut-theme/Backgrounds/sekhiro_sddm.mp4 ]"
  chk "sddm greeter volume unit"     "ls $R/var/lib/sddm/.config/systemd/user/default.target.wants/sddm-volume.service >/dev/null"
  chk "sddm pam live line"           "grep -q 'user = live' $R/etc/pam.d/sddm"
  chk "live user, empty password"    "grep -q '^live::' $R/etc/shadow"
  chk "no build-user leftovers"      "! grep -q '^$BU:' $R/etc/passwd"
  chk "no saved wifi"                "[ -z \"\$(ls -A $R/etc/NetworkManager/system-connections 2>/dev/null)\" ]"
  chk "caelestia cli runs"           "chroot $R /usr/bin/python3 -c 'import caelestia, materialyoucolor, PIL'"
  chk "Hyprland on the login PATH"   "chroot $R /usr/bin/bash -lc 'command -v Hyprland && command -v qs' >/dev/null"
  # fish writes ~/.config/fish and ~/.local/share/fish, so give it a throwaway HOME (not /root)
  fishchk() { local d; d=$(mktemp -d -p "$R/tmp"); chroot "$R" env HOME="/tmp/${d##*/}" /usr/bin/fish -c 'command -q Hyprland; and command -q qs'; local r=$?; rm -rf "$d"; return $r; }
  chk "Hyprland on fish PATH"        "fishchk"
  chk "live splash hold 6.0 s"       "grep -q 'splash-min-time 6.0' $R/etc/systemd/system/plymouth-quit.service.d/rednext-min-time.conf"
  chk "dolphin layout + places in skel" "[ -f $R/etc/skel/.local/state/dolphinstaterc ] && grep -q '@HOME@' $R/etc/skel/.local/share/user-places.xbel && [ -f $R/etc/profile.d/10-rednext-home-paths.sh ]"
  chk "skel in /home/live"           "[ -f $R/home/live/.config/hypr/hyprland.lua ]"
  local U=$BU
  chk "privacy: no '$U' in etc/var/root/home" "! grep -rIlsw -e '$U' ${PW[*]} $R/etc $R/var $R/root $R/home $R/opt $R/usr/local/etc"
  chk "privacy: no ~$U paths anywhere in text" "! grep -rIls '/home/$U' $R/etc $R/var $R/root $R/home $R/usr/share/sddm $R/usr/share/plymouth $R/usr/libexec/rednext"
  chk "privacy: no device history/state" "[ -z \"\$(find $R/var/lib/upower $R/var/lib/bluetooth $R/var/lib/NetworkManager $R/var/db/sudo $R/var/lib/AccountsService/users -mindepth 1 -print 2>/dev/null | tee /dev/stderr)\" ]"
  chk "privacy: no git metadata" "[ -z \"\$(find $R -xdev -name .git -print -quit)\" ]"
  chk "privacy: /root empty" "[ -z \"\$(ls -A $R/root)\" ]"
  chk "privacy: no stray top-level files" "[ -z \"\$(find $R -maxdepth 1 -type f)\" ] && ! ls -d $R/.Trash-* >/dev/null 2>&1"
  chk "installer: calamares + config"  "[ -x $R/usr/bin/calamares ] && [ -f $R/etc/calamares/settings.conf ] && [ -f $R/etc/calamares/branding/rednext/branding.desc ]"
  chk "installer: tools (unsquashfs, mkfs.fat, sfdisk, wipefs, partx, mkswap)" "[ -x $R/usr/bin/unsquashfs ] && [ -x $R/usr/sbin/mkfs.fat ] && chroot $R /bin/sh -c 'for t in sfdisk wipefs partx blockdev mkswap mkfs.ext4 findmnt udevadm; do command -v \$t >/dev/null || exit 1; done'"
  chk "installer: disk engine + page" "[ -x $R/usr/libexec/rednext/rednext-disk ] && [ -d $R/usr/lib/calamares/modules/rednextdisk ] && [ -f $R/etc/calamares/branding/rednext/rednext-disk.qml ] && REDNEXT_DISK_FAKE= chroot $R /usr/libexec/rednext/rednext-disk --help >/dev/null"
  chk "installer: calamares libs resolve" "! chroot $R /usr/bin/ldd /usr/bin/calamares | grep -q 'not found'"
  chk "installer: live launchers" "[ -x $R/home/live/Desktop/rednext-installer.desktop ] && grep -q rednext-installer $R/home/live/.config/caelestia/hypr-user.lua"
  chk "installer: nothing live-only in skel" "! grep -rqs rednext-installer $R/etc/skel"
  chk "privacy: no symlink into a home dir" "[ -z \"\$(find $R -xdev -path $R/proc -prune -o -type l -lname '*/home/*' -print | tee /dev/stderr)\" ]"
  chk "privacy: no /home/$BU in any file (incl. binaries)" "! grep -rlsa --devices=skip -e '/home/$BU' $R/usr $R/opt $R/etc $R/var $R/home | tee /dev/stderr | grep -q ."
  [ ${#PW[@]} -gt 0 ] && chk "privacy: no PRIVATE_WORDS in any file" "! grep -rlsaI --devices=skip ${PW[*]} $R/usr $R/opt $R/etc $R/var $R/home | tee /dev/stderr | grep -q ."
  chk "privacy: no '$BU' word in text files" "! grep -rlswI --devices=skip --exclude-dir=dict -e '$BU' $R/usr $R/opt $R/etc $R/var $R/home $R/root | tee /dev/stderr | grep -q ."
  chk "modules.dep"                  "[ -s $R/usr/lib/modules/$KVER/modules.dep ]"
  for m in sys proc dev; do umount "$R/$m"; done; trap - EXIT
  [ $ok = 1 ] || { echo "rootfs checks failed" >&2; exit 1; }
}

step_initramfs() {
  say "initramfs"
  rm -rf "$N"; mkdir -p "$N"/{usr/bin,usr/lib,dev,proc,sys,run,newroot,live/iso,live/sfs,live/rw}
  ln -s usr/bin "$N/bin"; ln -s usr/bin "$N/sbin"; ln -s usr/lib "$N/lib"; ln -s usr/lib "$N/lib64"; ln -s bin "$N/usr/sbin"
  for b in bash mount umount blkid switch_root mkdir sleep cat ls; do
    p=$(command -v $b); cp -L "$p" "$N/usr/bin/"
    ldd "$p" | grep -o '/[^ ]*' | while read -r l; do cp -Ln "$l" "$N/usr/lib/" 2>/dev/null || true; done
  done
  cat > "$N/init" <<'INIT'
#!/usr/bin/bash
# RedNext live initramfs: find the ISO by label, mount squashfs + tmpfs overlay, switch_root.
export PATH=/usr/bin
mount -t proc proc /proc; mount -t sysfs sys /sys; mount -t devtmpfs dev /dev 2>/dev/null
label=REDNEXT_LIVE
for a in $(cat /proc/cmdline); do case $a in rednext.label=*) label=${a#*=};; esac; done
rescue() { echo "RedNext live: $*"; echo "Dropping to a shell (exit to retry)."; bash; }
# grub-mkrescue images carry the label on an HFS+ partition too, so don't trust blkid:
# try every block device and take the first iso9660 that has our rootfs.
found=
for i in {1..60}; do
  for d in /sys/class/block/*; do
    dev=/dev/${d##*/}
    case ${d##*/} in loop*|ram*|zram*|dm-*) continue;; esac
    mount -t iso9660 -o ro "$dev" /live/iso 2>/dev/null || continue
    [ -f /live/iso/rednext/rootfs.sfs ] && { found=$dev; break; }
    umount /live/iso
  done
  [ -n "$found" ] && break; sleep 0.5
done
[ -n "$found" ] || rescue "no RedNext live medium found (label $label)"
echo "RedNext live: using $found"
mount -t squashfs -o ro,loop /live/iso/rednext/rootfs.sfs /live/sfs || rescue "cannot mount rootfs.sfs"
# Pre-read the splash frames (~61 MB) into the page cache. Read on demand from the
# USB they arrive too slowly and the intro gets cut off when the splash quits.
# The cache is shared with the overlay's lower layer, so Plymouth reads them from RAM.
for f in /live/sfs/usr/share/plymouth/themes/rednext/*; do cat "$f" > /dev/null 2>&1; done
mount -t tmpfs -o mode=755 tmpfs /live/rw
mkdir -p /live/rw/upper /live/rw/work
mount -t overlay overlay -o lowerdir=/live/sfs,upperdir=/live/rw/upper,workdir=/live/rw/work /newroot || rescue "overlay failed"
for m in iso sfs rw; do mkdir -p /newroot/live/$m; mount --move /live/$m /newroot/live/$m; done
umount /proc /sys; mount --move /dev /newroot/dev 2>/dev/null
exec switch_root /newroot /usr/lib/systemd/systemd
INIT
  chmod 755 "$N/init"
  # cpio via the kernel's gen_init_cpio (no cpio binary on this system)
  local list=$W/out/initramfs.list
  { ( cd "$N" && find . -mindepth 1 | sort | while read -r p; do
        q=${p#.}
        if [ -L "$p" ]; then echo "slink $q $(readlink "$p") 777 0 0"
        elif [ -d "$p" ]; then echo "dir $q $(stat -c %a "$p") 0 0"
        else echo "file $q $N$q $(stat -c %a "$p") 0 0"; fi
      done )
    echo "nod /dev/console 600 0 0 c 5 1"
    echo "nod /dev/null 666 0 0 c 1 3"; } > "$list"
  gen_init_cpio "$list" | zstd -19 -q -f -o "$W/out/initrd.img"
  ls -lh "$W/out/initrd.img"
}

step_squashfs() {
  say "squashfs (xz) — this takes a while"
  mkdir -p "$I/rednext"
  rm -f "$I/rednext/rootfs.sfs"
  mksquashfs "$R" "$I/rednext/rootfs.sfs" -comp xz -Xbcj x86 -b 1M -noappend
  ls -lh "$I/rednext/rootfs.sfs"
}

step_iso() {
  say "ISO"
  mkdir -p "$I/boot/grub"
  cp "$K/boot/vmlinuz-$KVER" "$I/boot/vmlinuz"
  cp "$W/out/initrd.img" "$I/boot/initrd.img"
  # same GRUB theme as the host; its font doubles as grub-mkrescue's label font
  # (this GRUB has no grub-mkfont, so there is no unicode.pf2)
  GT=/boot/grub/themes/grub-of-tsushima
  rm -rf "$I/boot/grub/themes"; mkdir -p "$I/boot/grub/themes"
  cp -a "$GT" "$I/boot/grub/themes/"
  cat > "$I/boot/grub/grub.cfg" <<GRUB
set timeout=10
set default=0
search --no-floppy --set=root --label $LABEL
insmod all_video
insmod gfxterm
insmod png
if loadfont /boot/grub/themes/grub-of-tsushima/fira_code_16.pf2; then
  for f in /boot/grub/themes/grub-of-tsushima/*.pf2; do loadfont \$f; done
  set gfxmode=auto
  terminal_output gfxterm
  set theme=/boot/grub/themes/grub-of-tsushima/theme.txt
fi
set gfxpayload=keep

menuentry "RedNext Live  (user: live, no password)" {
  linux /boot/vmlinuz rednext.label=$LABEL quiet loglevel=3 splash
  initrd /boot/initrd.img
}
menuentry "RedNext Live  (safe graphics: nomodeset)" {
  linux /boot/vmlinuz rednext.label=$LABEL nomodeset
  initrd /boot/initrd.img
}
menuentry "RedNext Live  (text boot, no splash)" {
  linux /boot/vmlinuz rednext.label=$LABEL loglevel=4 systemd.unit=multi-user.target
  initrd /boot/initrd.img
}
GRUB
  rm -f "$OUT"
  grub-mkrescue --fonts= --locales= --themes= --label-font="$GT/fira_code_16.pf2" \
    -o "$OUT" "$I" -- -volid "$LABEL"
  chown "${SUDO_USER:-root}:" "$OUT" "$LOG"
  ls -lh "$OUT"; sha256sum "$OUT" | tee "$OUT.sha256"
}

steps=${*:-rootfs initramfs squashfs iso}
for s in $steps; do "step_$s"; done
say "done: $OUT"
