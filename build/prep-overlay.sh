#!/bin/bash
# Collect the RedNext look (configs, fonts, cursors, wallpaper, Caelestia CLI, helper
# scripts) from the build user's home into overlay/, which mkiso.sh copies over the rootfs.
# Runs as the normal user; only config is copied, never personal data.
set -euo pipefail
H=${SRC_HOME:-$HOME}
W=${W:-$HOME/apps/dl/rednext-iso}
O=$W/overlay
rm -rf "$O"; mkdir -p "$O"
S=$O/etc/skel
PY=$(python3 -c 'import sys; print(f"python{sys.version_info[0]}.{sys.version_info[1]}")')

# --- /etc/skel: configs only
mkdir -p "$S/.config" "$S/.local/state"
for c in hypr caelestia quickshell fish foot fuzzel btop cava fastfetch gtk-3.0 gtk-4.0 Kvantum xsettingsd mpv \
         kdeglobals Kvantum.kvconfig gtkrc gtkrc-2.0 mimeapps.list dolphinrc konsolerc kwinrc starship.toml; do
  [ -e "$H/.config/$c" ] && cp -a "$H/.config/$c" "$S/.config/"
done
find "$S" \( -name '*.bak' -o -name '*.bak[0-9]*' -o -name '*.bak-*' -o -name fish_variables -o -name '.git' \) -prune -exec rm -rf {} +
rm -f "$S/.config/fish/conf.d/dotnet-certs.fish"
rm -f "$S/.config/fish/conf.d/java.fish"              # per-user JDK path; the image ships /opt/java instead
# Vim: crimson colour scheme + vimrc (only the theme, not undo/swap/viminfo)
[ -f "$H/.vimrc" ] && cp -a "$H/.vimrc" "$S/"
[ -d "$H/.vim/colors" ] && { mkdir -p "$S/.vim"; cp -a "$H/.vim/colors" "$S/.vim/"; }
# Hyprland calls helpers from ~/.local/bin on the build host; in the image they live in /usr/bin
sed -i 's#os.getenv("HOME") \.\. "/\.local/bin/#"#g' "$S"/.config/hypr/hyprland/*.lua
rm -rf "$S/.config/caelestia/monitors"            # laptop-specific (eDP-1)
mkdir -p "$S/.config/menus"
ln -s /opt/kf6/etc/xdg/menus/plasma-applications.menu "$S/.config/menus/applications.menu"
mkdir -p "$S/Pictures/Screenshots" "$S/Videos"

# Dolphin: same panels as the build user (Places only, no terminal panel) and the same short
# Places list. KF6 keeps both outside ~/.config, so without these Dolphin opens with its
# defaults (terminal panel, long Places list). Only the toolbar/dock layout is taken from
# dolphinstaterc (no "Open with" history, no screen geometry); home paths become @HOME@,
# which /etc/profile.d/10-rednext-home-paths.sh fills in at the user's first login.
mkdir -p "$S/.local/state" "$S/.local/share"
if [ -f "$H/.local/state/dolphinstaterc" ]; then
  { echo "[State]"; grep -E '^State=' "$H/.local/state/dolphinstaterc"; echo "RestorePositionForNextInstance=false"; } \
    > "$S/.local/state/dolphinstaterc"
fi
[ -f "$H/.local/share/user-places.xbel" ] && \
  sed "s#file://$H#file://@HOME@#g" "$H/.local/share/user-places.xbel" > "$S/.local/share/user-places.xbel"

# Caelestia state: colour scheme + wallpaper pointing at the system copy
WP=$(cat "$H/.local/state/caelestia/wallpaper/path.txt")
WPN=rednext-default.${WP##*.}
install -Dm644 "$WP" "$O/usr/share/backgrounds/rednext/$WPN"
cp -a "$H/.local/state/caelestia" "$S/.local/state/"
( cd "$S/.local/state/caelestia" && rm -rf dots dots-state.json apps.sqlite notifs.json lyrics record sequences.txt wallpaper/thumbnail.jpg )
printf '%s' "/usr/share/backgrounds/rednext/$WPN" > "$S/.local/state/caelestia/wallpaper/path.txt"
ln -sfn "/usr/share/backgrounds/rednext/$WPN" "$S/.local/state/caelestia/wallpaper/current"

# Session GIF: point at ~/.config, not /home/<user>
sed -i "s#$H/#~/#g" "$S/.config/caelestia/shell.json" "$S/.config/fastfetch/config.jsonc"
# Any other hard-coded home path left in skel -> fail loudly
if grep -rIl "$H" "$S"; then echo "ERROR: hard-coded $H paths above" >&2; exit 1; fi

# --- system-wide bits
mkdir -p "$O/usr/share/fonts/rednext" "$O/usr/share/icons" "$O/usr/bin" "$O/usr/lib/$PY/site-packages"
cp -a "$H/.local/share/fonts/." "$O/usr/share/fonts/rednext/"
cp -a "$H/.icons/Sweet-cursors" "$O/usr/share/icons/"
for p in caelestia caelestia-*.dist-info materialyoucolor materialyoucolor-*.dist-info PIL pillow-*.dist-info pillow.libs; do
  cp -a "$H/.local/lib/$PY/site-packages/"$p "$O/usr/lib/$PY/site-packages/"
done
# .pyc caches record the source path (/home/<user>/.local/lib/...); Python rebuilds them
find "$O/usr/lib/$PY/site-packages" -name __pycache__ -prune -exec rm -rf {} +
for b in caelestia caelestia-logout screenshot-popup video-wallpaper video-wallpaper-picker; do install -m755 "$H/.local/bin/$b" "$O/usr/bin/$b"; done

# KDE colour scheme used by kdeglobals/dolphinrc (CrimsonCaelestia)
mkdir -p "$O/usr/share/color-schemes"
cp -a "$H/.local/share/color-schemes/." "$O/usr/share/color-schemes/"

# Java: the build user's Temurin JDK, system-wide in /opt/java (JAVA_HOME for bash + fish)
JDK=$(readlink -f "$H/.local/share/java/current")
mkdir -p "$O/opt/java" "$O/etc/profile.d" "$O/etc/fish/conf.d"
cp -a "$JDK" "$O/opt/java/"
ln -sfn "${JDK##*/}" "$O/opt/java/current"
printf '%s\n' '# RedNext: Temurin OpenJDK' 'export JAVA_HOME=/opt/java/current' 'pathappend $JAVA_HOME/bin' > "$O/etc/profile.d/java.sh"
printf '%s\n' '# RedNext: Temurin OpenJDK (same as /etc/profile.d/java.sh)' 'set -gx JAVA_HOME /opt/java/current' 'fish_add_path -gaP $JAVA_HOME/bin' > "$O/etc/fish/conf.d/java.fish"

# Spotify tray-icon libraries: the installer copies them to /opt/spotify/deps when Spotify is
# ticked (they're live-only in the image; scrub-paths.py in mkiso.sh clears their build paths)
mkdir -p "$O/usr/lib/rednext/spotify-deps"
cp -a "$H/apps/spotify/deps/lib/"*.so* "$O/usr/lib/rednext/spotify-deps/"

du -sh "$O"; echo "overlay ready: $O"
