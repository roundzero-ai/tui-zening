#!/usr/bin/env bash
# Outputs RAM as "used/totalGB" — works on macOS and Linux

if [[ "$(uname)" == "Darwin" ]]; then
  stats="$(vm_stat)"
  page_size=$(echo "$stats" | grep "page size of" | grep -oE '[0-9]+ bytes' | grep -oE '[0-9]+')
  [ -z "$page_size" ] && page_size=16384
  total=$(sysctl -n hw.memsize)
  free_pages=$(echo "$stats" | awk '/Pages free/ { gsub(/\./, "", $NF); print $NF + 0 }')
  free=$(( free_pages * page_size ))
  used=$(( total - free ))
else
  total=$(awk '/MemTotal/  { print $2 * 1024 }' /proc/meminfo)
  avail=$(awk '/MemAvailable/ { print $2 * 1024 }' /proc/meminfo)
  used=$(( total - avail ))
fi

awk -v u="$used" -v t="$total" 'BEGIN { printf "%.1f/%.0fGB", u/1073741824, t/1073741824 }'
