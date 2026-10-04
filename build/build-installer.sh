#!/bin/bash
# Build the ISO tools and the Calamares installer stack as the normal user (no sudo).
#   tools/stage      host-side build tools for mkiso.sh (mksquashfs, xorriso, mtools)
#   installer/stage  shipped inside the live image only (calamares, kpmcore, yaml-cpp,
#                    dosfstools, squashfs-tools); never installed on the build host
# Sources are expected in $W/src (see SRC list below). Build trees are deleted afterwards.
# Usage: ./build-installer.sh [tools] [installer] [calamares]   (default: tools installer)
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
  unpack yaml-cpp 'yaml-cpp-*.tar.gz'
  cm -DYAML_BUILD_SHARED_LIBS=ON -DYAML_CPP_BUILD_TESTS=OFF -DYAML_CPP_BUILD_TOOLS=OFF
  unpack kpmcore 'kpmcore-*.tar.xz'
  # plugins go to /usr/lib/plugins, which is on QT_PLUGIN_PATH (profile.d/qt6.sh)
  cm -DKDE_INSTALL_PLUGINDIR=lib/plugins -DKDE_INSTALL_QTPLUGINDIR=lib/plugins
  step_calamares
}

# Calamares alone (needs the yaml-cpp/kpmcore headers still in $IS): ./build-installer.sh calamares
step_calamares() {
  say "calamares -> $IS"
  unpack calamares 'calamares-*.tar.gz'
  # QML pages must take keyboard input (upstream's Qt 6 window container never gets focus)
  patch -p1 < "$(dirname "$(readlink -f "$0")")/calamares-qml-focus.patch"
  cm -DYAMLCPP_DIR="$IS/usr" -DWITH_QT6=ON -DWITH_PYTHON=ON -DWITH_PYBIND11=ON -DINSTALL_CONFIG=OFF -DINSTALL_POLKIT=ON \
     -DWITH_APPSTREAM=OFF -DWITH_PYTHONQT=OFF \
     -DSKIP_MODULES="webview dracut dracutlukscfg initramfs initramfscfg initcpio initcpiocfg mkinitfs \
       luksbootkeyfile luksopenswaphookcfg openrcdmcryptcfg plymouthcfg packages netinstall \
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
