#!/bin/bash
# Build the ISO tools and the Calamares installer stack as the normal user (no sudo).
#   tools/stage      host-side build tools for mkiso.sh (mksquashfs, xorriso, mtools)
#   installer/stage  shipped inside the live image only (calamares + the rednextdisk page,
#                    yaml-cpp, dosfstools, squashfs-tools); never installed on the build host
# Partitioning is RedNext's own (installer/rednextdisk + calamares/usr/libexec/rednext/rednext-disk),
# so neither kpmcore nor Calamares' partition module is built.
# Sources are expected in $W/src (see SRC list below). Build trees are deleted afterwards.
# Usage: ./build-installer.sh [tools] [installer] [yamlcpp] [calamares]   (default: tools installer)
set -euo pipefail
W=${W:-$HOME/apps/dl/rednext-iso}
SRC=$W/src
B=$W/build
TS=$W/tools/stage
IS=$W/installer/stage
J=$(nproc)
# x86-64 baseline (public ISO, old CPUs); map build dirs so no home path ends up in binaries
flags() { echo "-O2 -pipe -march=x86-64 -mtune=generic -ffile-prefix-map=$B=/usr/src"; }
export CFLAGS="$(flags)" CXXFLAGS="$(flags)"
export CMAKE_PREFIX_PATH="$IS/usr:/opt/kf6:/opt/qt6"   # env form is colon-separated
export PKG_CONFIG_PATH="$IS/usr/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
say() { printf '\n==> %s\n' "$*"; }
unpack() { rm -rf "$B/$1"; mkdir -p "$B/$1"; tar -xf "$SRC"/$2 -C "$B/$1" --strip-components=1; cd "$B/$1"; }

build_squashfs() {   # $1 = DESTDIR
  unpack squashfs-tools 'squashfs-tools-4.*.tar.gz'
  cd squashfs-tools
  local opts="XZ_SUPPORT=1 ZSTD_SUPPORT=1 GZIP_SUPPORT=1 LZ4_SUPPORT=0 LZO_SUPPORT=0 LZMA_XZ_SUPPORT=0"
  make -j$J $opts EXTRA_CFLAGS="$CFLAGS"
  make $opts INSTALL_PREFIX="$1/usr" INSTALL_MANPAGES_DIR= install
}

step_tools() {
  say "tools -> $TS"
  rm -rf "$TS"; mkdir -p "$TS"
  build_squashfs "$TS"
  unpack mtools 'mtools-*.tar.gz'
  ./configure --prefix=/usr --disable-floppyd >/dev/null; make -j$J >/dev/null; make DESTDIR="$TS" install >/dev/null
  unpack xorriso 'xorriso-*.tar.gz'
  ./configure --prefix=/usr >/dev/null; make -j$J >/dev/null; make DESTDIR="$TS" install >/dev/null
  # gen_init_cpio (mkiso.sh packs the initramfs with it; there's no cpio binary): one file of the kernel tree
  local ksrc; ksrc=$(ls /sources/LFS/linux-6.*.tar.xz 2>/dev/null | head -1)
  [ -n "$ksrc" ] || { echo "kernel tarball not found in /sources/LFS" >&2; exit 1; }
  mkdir -p "$B/gic"; tar -xJf "$ksrc" -C "$B/gic" --wildcards '*/usr/gen_init_cpio.c' --strip-components=2
  gcc -O2 -o "$TS/usr/bin/gen_init_cpio" "$B/gic/gen_init_cpio.c"
  ls "$TS/usr/bin"
}

cm() {   # cmake configure+build+install into $IS
  cmake -S . -B _b -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_INSTALL_LIBDIR=lib -DBUILD_TESTING=OFF -DCMAKE_SKIP_INSTALL_RPATH=ON "$@"
  cmake --build _b -j$J
  DESTDIR="$IS" cmake --install _b
}

step_installer() {
  say "installer stack -> $IS"
  rm -rf "$IS"; mkdir -p "$IS"
  build_squashfs "$IS"
  unpack dosfstools 'dosfstools-*.tar.gz'
  ./configure --prefix=/usr --sbindir=/usr/sbin --enable-compat-symlinks --mandir=/usr/share/man >/dev/null
  make -j$J >/dev/null; make DESTDIR="$IS" install >/dev/null
  step_yamlcpp
  step_calamares
}

step_yamlcpp() {
  say "yaml-cpp -> $IS"
  unpack yaml-cpp 'yaml-cpp-*.tar.gz'
  cm -DYAML_BUILD_SHARED_LIBS=ON -DYAML_CPP_BUILD_TESTS=OFF -DYAML_CPP_BUILD_TOOLS=OFF
}

# Calamares alone (needs the yaml-cpp headers still in $IS): ./build-installer.sh calamares
step_calamares() {
  say "calamares -> $IS"
  unpack calamares 'calamares-*.tar.gz'
  # QML pages must take keyboard input (upstream's Qt 6 window container never gets focus)
  local here; here=$(dirname "$(readlink -f "$0")")
  patch -p1 < "$here/calamares-qml-focus.patch"
  # RedNext's own disk page (QML + rednext-disk engine) replaces the kpmcore partition module
  cp -r "$here/../installer/rednextdisk" src/modules/
  # unpackfs/bootloader declare the skipped partition/mount modules as dependencies, which makes
  # Calamares stop with "initialization failed"; rednextdisk sets the same globals they read
  sed -i 's/^requiredModules: \[ mount \]/requiredModules: [ rednextdisk ]/' src/modules/unpackfs/module.desc
  sed -i 's/^requiredModules: \[ "partition" \]/requiredModules: [ "rednextdisk" ]/' src/modules/bootloader/module.desc
  ! grep -qE 'requiredModules:.*(mount|partition)' src/modules/{unpackfs,bootloader}/module.desc ||
    { echo "module.desc deps not patched" >&2; exit 1; }
  cm -DYAMLCPP_DIR="$IS/usr" -DWITH_QT6=ON -DWITH_PYTHON=ON -DWITH_PYBIND11=ON -DINSTALL_CONFIG=OFF -DINSTALL_POLKIT=ON \
     -DWITH_APPSTREAM=OFF -DWITH_PYTHONQT=OFF \
     -DSKIP_MODULES="webview dracut dracutlukscfg initramfs initramfscfg initcpio initcpiocfg mkinitfs \
       partition fsresizer luksbootkeyfile luksopenswaphookcfg openrcdmcryptcfg plymouthcfg packages netinstall \
       tracking zfs zfshostid dummycpp dummyprocess dummypython dummypythonqt rawfs services-openrc \
       license notesqml oemid interactiveterminal"
  # headers/cmake/pkgconfig stay in the stage for rebuilds; mkiso.sh leaves them out of the image
  rm -rf "$IS/usr/share/man" "$IS/usr/share/doc"
  find "$IS" -type f \( -name '*.so*' -o -perm -u+x \) -exec sh -c 'file -b "$1" | grep -q ELF && strip --strip-unneeded "$1"' _ {} \;
  du -sh "$IS"
}

steps=${*:-tools installer}
for s in $steps; do "step_$s"; done
rm -rf "$B"
# nothing in the stages may mention the build user or home
if grep -rlsa -e "$HOME" -e "$(id -un)" "$TS" "$IS"; then echo "WARNING: build-user references above" >&2; fi
say "done"
