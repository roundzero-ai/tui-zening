#!/usr/bin/env bash
# Outputs RAM as "used/totalGB" on macOS
stats="$(vm_stat)"

# Get page size dynamically from vm_stat header
page_size=$(echo "$stats" | grep "page size of" | grep -oE '[0-9]+ bytes' | grep -oE '[0-9]+')
[ -z "$page_size" ] && page_size=16384

# Total physical RAM from sysctl (authoritative)
total=$(sysctl -n hw.memsize)

# Used = total - free pages
free_pages=$(echo "$stats" | awk '/Pages free/ { gsub(/\./, "", $NF); print $NF + 0 }')
free=$(( free_pages * page_size ))
used=$(( total - free ))

awk -v u="$used" -v t="$total" 'BEGIN { printf "%.1f/%.0fGB", u/1073741824, t/1073741824 }'
