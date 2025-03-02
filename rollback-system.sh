#!/usr/bin/env bash
set -euo pipefail

MOUNTPOINT=/mnt/btrfs

GREEN='\033[0;32m'
GREEN_BOLD='\033[1;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

cd "$HOME"

print_disks() {
  lsblk -f | awk \
    -v green="${GREEN}" \
    -v green_bold="${GREEN_BOLD}" \
    -v bold="${BOLD}" \
    -v nc="${NC}" \
    '
      NR==1 {i=0; print "    " bold $0 nc; next}
      $2=="btrfs" {i++; print green "[" green_bold i green "] " $0 nc; next}
      {print "    " $0}
    '
}

UUIDS=()
PATHS=()
get_btrfs_partitions() {
  local index=1
  local line
  while IFS= read -r line; do
    if ! awk '$2 == "btrfs" {exit}; {exit 1}' <<<"$line"; then continue; fi
    local uuid
    uuid=$(awk '{for(i=1;i<=NF;i++) if($i ~ /[-0-9a-f]{36}/) print $i}' <<<"$line")
    if [ -z "$uuid" ]; then continue; fi
    UUIDS+=("$uuid")
    PATHS+=("$(awk 'match($1,/\w+/,m) {print m[0]}' <<<"$line")")
    ((index++))
  done < <(lsblk -f)
}

get_btrfs_uuid() {
  local max_index=${#UUIDS[@]}
  local selection
  while true; do
    read >&2 -rp "Choose BTRFS partition (1-$max_index): " selection
    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "$max_index" ]; then
      echo "${UUIDS[$selection - 1]}"
      echo >&2 -e "\nSelected device: ${BLUE}${PATHS[$selection - 1]}${NC}"
      echo >&2 -e "UUID: ${BLUE}${UUIDS[$selection - 1]}${NC}\n"
      return
    else
      echo >&2 "Invalid input. Please select a number between 1 and $max_index."
    fi
  done
}

get_snapshot_number() {
  local input
  while true; do
    read >&2 -rp "Enter the latest possible snapshot number you want to restore: " input
    if [[ "$input" =~ ^[0-9]+$ ]]; then
      echo "$input"
      return
    else
      echo >&2 "Invalid input. Please enter a valid number."
    fi
  done
}

if ! mountpoint -q "$MOUNTPOINT"; then
  print_disks
  get_btrfs_partitions
  echo
  btrfs_uuid=$(get_btrfs_uuid)

  sudo mkdir -p "$MOUNTPOINT"
  sudo mount -t btrfs -o subvol=/ "/dev/disk/by-uuid/$btrfs_uuid" "$MOUNTPOINT"
fi

cd "$MOUNTPOINT"

(
  echo -e "${BOLD}Date\tNum\tType\tDescription\tCleanup$NC"
  sudo bash -c "xq -r '.snapshot | \"\(.date)\t\(.num)\t\(.type)\t\(.description)\t\(.cleanup)\"' @/.snapshots/*/info.xml" \
  | sort \
  | awk \
    -v green="${GREEN}" \
    -v green_bold="${GREEN_BOLD}" \
    -v nc="${NC}" \
    -v today="$(date -I)" \
    '
      BEGIN {FS="\t"; OFS="\t"}
      match($1, today) {
        printf green $1 "\t" green_bold $2 green
        for (i = 3; i <= NF; i++) printf "\t" $i
        print nc
        next
      }
      {print}
    '
) | column -t -s $'\t'
echo
SNAPSHOT_NUMBER=$(get_snapshot_number)

BACKUP="@-backup-$(date -I)"

echo
echo -e "Creating backup in $BLUE$PWD/$BACKUP$NC and"
echo -e "restoring snapshot $BLUE$SNAPSHOT_NUMBER$NC"
echo
echo -en "Press any key to continue"
read -rp " "

sudo mv '@' "$BACKUP"
#sudo btrfs subvolume list "$MOUNTPOINT"
sudo btrfs subvolume snapshot "$BACKUP/.snapshots/$SNAPSHOT_NUMBER/snapshot" '@'
sudo mv "$BACKUP/.snapshots" '@/'

echo
echo -e "${GREEN}All done.$NC Going to reboot."
echo
echo -en "Press any key to reboot"
read -rp " "

reboot
