#!/bin/bash
# Pack the repacked super + an AVB-disabled vbmeta into an Odin-flashable tar.
# KEY: Samsung/Odin require lz4 frames WITH the content-size flag (-B6 --content-size),
# else Odin says "FAIL! LZ4 is invalid".
#
# Usage: 03-pack-odin.sh  <workdir>  <AP_*.tar.md5>
set -e
W="$1"; AP="$2"
[ -z "$W" ] || [ -z "$AP" ] && { echo "Usage: $0 <workdir> <AP_*.tar.md5>"; exit 1; }
W="$(cd "$W" && pwd)"
[ -f "$W/super_new.img" ] || { echo "Run 02-repack.sh first (no super_new.img)"; exit 1; }

echo "[*] lz4 super_new.img -> super.img.lz4 (Samsung format)"
rm -f "$W/super.img.lz4"
lz4 -f -B6 --content-size "$W/super_new.img" "$W/super.img.lz4"

echo "[*] disable AVB in vbmeta (verity + verification)"
[ -f "$W/vbmeta.img.lz4" ] || tar xf "$AP" -C "$W" vbmeta.img.lz4
lz4 -d -f "$W/vbmeta.img.lz4" "$W/vbmeta.img"
printf '\x03' | dd of="$W/vbmeta.img" bs=1 seek=123 count=1 conv=notrunc 2>/dev/null  # flags=0x03
echo -n "    vbmeta flags now: "; od -An -tx1 -j120 -N4 "$W/vbmeta.img"
rm -f "$W/vbmeta.img.lz4"
lz4 -f -B6 --content-size "$W/vbmeta.img" "$W/vbmeta.img.lz4"

echo "[*] build Odin tar"
rm -f "$W/AP_PE.tar"
tar -H ustar -C "$W" -cf "$W/AP_PE.tar" super.img.lz4 vbmeta.img.lz4
echo "[*] done: $W/AP_PE.tar"
tar tf "$W/AP_PE.tar"
echo "    magic (want 04 22 4d 18 6c ..): $(od -An -tx1 -N6 "$W/super.img.lz4")"
echo
echo "Flash in Odin:  AP=AP_PE.tar  CSC=<stock CSC_*.tar.md5 (wipes)>  BL/CP empty"
