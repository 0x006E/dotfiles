#!/usr/bin/env bash
# rice-toggle: apply day/night desktop polarity without a rebuild.
#   auto          follow the sun over Trivandrum (matches the Noctalia
#                 location setting); no-op unless the polarity changed
#   dark | light  apply a polarity now
#   toggle        flip the last-applied polarity now
# Manual choices are recorded in the state file, so the timer only acts on
# the next day/night edge instead of fighting you.
set -euo pipefail

LAT="8.5241N"
LON="76.9366E"
WALL_DIR="/var/lib/wallpapers"
FALLBACK_WALL="/etc/wallpapers/current"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/rice-toggle"
STATE_FILE="$STATE_DIR/mode"

mode_arg="${1:-auto}"
last="$(cat "$STATE_FILE" 2>/dev/null || true)"
target=""

case "$mode_arg" in
  dark | light) target="$mode_arg" ;;
  toggle)
    [[ "$last" == "light" ]] && target="dark" || target="light"
    ;;
  auto)
    sun_state="$(sunwait poll "$LAT" "$LON" 2>/dev/null | head -n 1 || true)"
    [[ "$sun_state" == "DAY" ]] && target="light" || target="dark"
    ;;
  *)
    echo "usage: rice-toggle [auto|dark|light|toggle]" >&2
    exit 2
    ;;
esac

if [[ "$target" == "$last" ]]; then
  echo "rice-toggle: already $target"
  exit 0
fi

wall="$WALL_DIR/current-$target.jpg"
[[ -f "$wall" ]] || wall="$FALLBACK_WALL"

# Noctalia shell theme + wallpaper (noctalia persists both to settings.toml).
noctalia msg theme-mode-set "$target"
noctalia msg wallpaper-set "$wall"

# GTK dark preference for non-Noctalia apps. Best-effort: needs a session
# bus, which timers may lack. HM/stylix restore the build-time value on
# rebuild; the timer re-applies this.
if [[ "$target" == "dark" ]]; then
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
else
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' 2>/dev/null || true
fi

# Greeter follows at next login. Must not break the toggle (auth-dependent).
noctalia msg greeter-sync 2>&1 || echo "rice-toggle: greeter-sync failed" >&2

mkdir -p "$STATE_DIR"
printf '%s' "$target" > "$STATE_FILE"
if [[ "$target" == "dark" ]]; then
  notify-send "Rice: dark" "Theme, wallpaper and greeter synced." --icon=weather-clear-night-symbolic 2>/dev/null || true
else
  notify-send "Rice: light" "Theme, wallpaper and greeter synced." --icon=weather-clear-symbolic 2>/dev/null || true
fi
echo "rice-toggle: '$last' -> '$target'"
