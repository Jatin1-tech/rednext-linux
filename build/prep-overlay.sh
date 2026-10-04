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
rm -rf "$S/.config/caelestia/monitors"            # laptop-specific (eDP-1)
mkdir -p "$S/.config/menus"
ln -s /opt/kf6/etc/xdg/menus/plasma-applications.menu "$S/.config/menus/applications.menu"
mkdir -p "$S/Pictures/Screenshots" "$S/Videos"

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
for b in caelestia caelestia-logout screenshot-popup video-wallpaper; do install -m755 "$H/.local/bin/$b" "$O/usr/bin/$b"; done

# Spotify tray-icon libraries: the installer copies them to /opt/spotify/deps when Spotify is
# ticked (they're live-only in the image; scrub-paths.py in mkiso.sh clears their build paths)
mkdir -p "$O/usr/lib/rednext/spotify-deps"
cp -a "$H/apps/spotify/deps/lib/"*.so* "$O/usr/lib/rednext/spotify-deps/"

du -sh "$O"; echo "overlay ready: $O"
