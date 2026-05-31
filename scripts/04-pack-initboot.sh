#!/bin/bash
# Pack a Magisk-patched init_boot into an Odin AP tar (for root).
# First: extract stock init_boot, copy to phone, patch with the Magisk app
# ("Select and Patch a File"), pull magisk_patched-*.img back, then run this.
#
# Usage:
#   # get the stock init_boot to patch:
#   tar xf AP_*.tar.md5 init_boot.img.lz4 && lz4 -d init_boot.img.lz4 init_boot.img
#   # ...patch init_boot.img with Magisk on the phone -> magisk_patched-XXXXX.img...
#   04-pack-initboot.sh  <workdir>  <magisk_patched-XXXXX.img>
set -e
W="$1"; PATCHED="$2"
[ -z "$W" ] || [ -z "$PATCHED" ] && { echo "Usage: $0 <workdir> <magisk_patched.img>"; exit 1; }
W="$(cd "$W" && pwd)"
echo "[*] lz4 (Samsung format) -> init_boot.img.lz4"
rm -f "$W/init_boot.img.lz4"
lz4 -f -B6 --content-size "$PATCHED" "$W/init_boot.img.lz4"
echo "[*] build Odin AP_root.tar"
rm -f "$W/AP_root.tar"
tar -H ustar -C "$W" -cf "$W/AP_root.tar" init_boot.img.lz4
echo "[*] done: $W/AP_root.tar"
echo "Flash in Odin:  AP=AP_root.tar  (BL/CP/CSC EMPTY — no wipe).  Reboot -> rooted."
