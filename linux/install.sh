#!/usr/bin/env bash
# Install the complete extracted bundle and launcher for the current user.
set -euo pipefail
bundle_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
if [[ "$data_home" != /* ]]; then
  echo 'XDG_DATA_HOME must be an absolute path.' >&2
  exit 1
fi
install_dir="$data_home/smartstock"
for required in smartstock_flutter lib data/icons/smartstock.svg data/icons/smartstock-256.png data/icons/smartstock-512.png; do
  test -e "$bundle_dir/$required" || { echo "Missing bundle file: $required" >&2; exit 1; }
done
mkdir -p "$install_dir" "$data_home/applications"
if [[ "$bundle_dir" != "$(cd -- "$install_dir" && pwd -P)" ]]; then
  cp -a -- "$bundle_dir/." "$install_dir/"
fi
for size in 256 512; do
  icon_dir="$data_home/icons/hicolor/${size}x${size}/apps"
  mkdir -p "$icon_dir"
  install -m 644 "$bundle_dir/data/icons/smartstock-$size.png" "$icon_dir/smartstock.png"
done
icon_dir="$data_home/icons/hicolor/scalable/apps"
mkdir -p "$icon_dir"
install -m 644 "$bundle_dir/data/icons/smartstock.svg" "$icon_dir/smartstock.svg"
# Escape both desktop-entry string syntax and Exec argument syntax.
exec_path="$install_dir/smartstock_flutter"
exec_path="${exec_path//\\/\\\\\\\\}"
exec_path="${exec_path//\"/\\\\\"}"
exec_path="${exec_path//\$/\\\\\$}"
exec_path="${exec_path//\`/\\\\\`}"
exec_path="${exec_path//%/%%}"
printf '%s\n' \
  '[Desktop Entry]' 'Type=Application' 'Name=SmartStock' \
  'Comment=Offline inventory management' "Exec=\"$exec_path\"" \
  'Icon=smartstock' 'Terminal=false' 'Categories=Office;' \
  'StartupWMClass=com.smartstock.smartstock_flutter' \
  > "$data_home/applications/com.smartstock.smartstock_flutter.desktop"
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f -t "$data_home/icons/hicolor" >/dev/null 2>&1 || true
fi
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$data_home/applications" || true
fi
printf 'Installed SmartStock in %s\nOpen SmartStock from your application menu.\n' "$install_dir"
