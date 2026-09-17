#!/usr/bin/env bash
# wallfetch: pull top wallpapers from wallhaven, classify dark/light by mean
# brightness, center-crop to exact output size. Anonymous API (no key needed,
# well within the rate limit at one call per run).
set -euo pipefail

DIR="/var/lib/wallpapers"
COUNT=8
QUERY="mountains landscape"
WIDTH=1920
HEIGHT=1080

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) DIR="$2"; shift 2 ;;
    --count) COUNT="$2"; shift 2 ;;
    --query) QUERY="$2"; shift 2 ;;
    --size)
      WIDTH="${2%x*}"
      HEIGHT="${2#*x}"
      shift 2
      ;;
    *)
      echo "unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

mkdir -p "$DIR/dark" "$DIR/light"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

API="https://wallhaven.cc/api/v1/search"
q=$(printf '%s' "$QUERY" | jq -sRr @uri)
curl -fsSL \
  "$API?q=$q&categories=111&purity=100&atleast=${WIDTH}x${HEIGHT}&ratios=landscape&sorting=toplist&order=desc" \
  -o "$TMP/list.json"

mapfile -t rows < <(jq -r '.data[] | "\(.id) \(.path)"' "$TMP/list.json")
((${#rows[@]} > 0)) || {
  echo "wallfetch: no results" >&2
  exit 1
}

for row in "${rows[@]}"; do
  id="${row%% *}"
  url="${row#* }"
  [[ -n "$id" && -n "$url" ]] || continue
  raw="$TMP/$id.img"
  curl -fsSL "$url" -o "$raw" || continue
  is_light=$(magick "$raw" -colorspace Gray -format "%[fx:mean>0.55?1:0]" info:) || continue
  bucket="dark"
  [[ "$is_light" == "1" ]] && bucket="light"
  magick "$raw" -resize "${WIDTH}x${HEIGHT}^" -gravity center -extent "${WIDTH}x${HEIGHT}" \
    "$DIR/$bucket/wh-$id.jpg" || continue
  rm -f "$raw"
done

for bucket in dark light; do
  # Prune to COUNT newest, then point current-<bucket>.jpg at the newest.
  (cd "$DIR/$bucket" && ls -t wh-*.jpg 2>/dev/null | tail -n "+$((COUNT + 1))" | xargs -r rm --)
  newest=$(cd "$DIR/$bucket" && ls -t wh-*.jpg 2>/dev/null | head -n 1 || true)
  [[ -n "$newest" ]] && cp -f "$DIR/$bucket/$newest" "$DIR/current-$bucket.jpg"
done

echo "wallfetch: $(ls "$DIR/dark"/wh-*.jpg 2>/dev/null | wc -l) dark, $(ls "$DIR/light"/wh-*.jpg 2>/dev/null | wc -l) light in $DIR"
