#!/usr/bin/env bash
# ONE COMMAND: your stock firmware AP + a PixelOS GSI  ->  Odin-flashable AP_PE.tar
#
# Why build instead of download a prebuilt:
#   * the result contains YOUR phone's Samsung vendor/product/odm blobs, so it
#     must match YOUR exact model + region (a foreign prebuilt can brick), and
#   * Samsung firmware can't be legally redistributed. Building locally avoids both.
#
# Usage:
#   ./build-flashable.sh  <AP_*.tar.md5>  <pixelos_gsi.img|.img.xz>  [workdir]
# After a "GSI too big" message, shrink as instructed then re-run with RESUME=1:
#   RESUME=1 ./build-flashable.sh  <AP_*.tar.md5>  <pixelos_gsi.img|.img.xz>  [workdir]
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
AP="${1:-}"; GSI="${2:-}"; W="${3:-$HERE/work}"
RESUME="${RESUME:-}"

if [ -z "$AP" ] || [ -z "$GSI" ]; then
  cat <<USAGE
Usage: $0 <AP_*.tar.md5> <pixelos_gsi.img[.xz]> [workdir]
  AP  = stock firmware AP_*.tar.md5 from Frija  (YOUR exact model + region/CSC)
  GSI = PixelOS arm64 "bN" GSI (.img or .img.xz), NON-vndklite
See QUICKSTART.md for where to get each.
USAGE
  exit 1
fi
[ -f "$AP" ]  || { echo "ERROR: AP firmware not found: $AP"; exit 1; }
{ [ -f "$GSI" ] || [ "$GSI" = "-" ]; } || { echo "ERROR: GSI not found: $GSI"; exit 1; }

# preflight: fail early + clearly if a host tool is missing (instead of a cryptic mid-run error)
miss=""
for c in git clang lz4 simg2img xz tar awk dd sed stat file e2fsck resize2fs; do
  command -v "$c" >/dev/null 2>&1 || miss="$miss $c"
done
if [ -n "$miss" ]; then
  echo "ERROR: missing required tool(s):$miss"
  echo "Install on Debian/Ubuntu:"
  echo "  sudo apt update && sudo apt install -y git clang binutils lz4 xz-utils android-sdk-libsparse-utils e2fsprogs"
  echo "(clang->clang/clang++, binutils->ar/strip, simg2img->android-sdk-libsparse-utils, xz->xz-utils, e2fsck/resize2fs->e2fsprogs)"
  exit 1
fi

echo "############ 1/3  build lpmake / lpunpack / lpdump ############"
"$HERE/scripts/01-build-tools.sh"

echo "############ 2/3  repack super (swap system -> GSI) ############"
set +e
RESUME="$RESUME" "$HERE/scripts/02-repack.sh" "$AP" "$GSI" "$W"
rc=$?
set -e
if [ "$rc" -eq 2 ]; then
  cat <<SHRINK

>> The GSI is larger than the phone's system slot. Shrink it, then resume:
     e2fsck -y -E unshare_blocks "$W/parts/system.img"
     resize2fs -M "$W/parts/system.img"
     RESUME=1 $0 "$AP" "$GSI" "$W"
SHRINK
  exit 2
elif [ "$rc" -ne 0 ]; then
  echo "02-repack failed (rc=$rc) — see output above."; exit "$rc"
fi

echo "############ 3/3  pack Odin flashable (lz4 + AVB-off vbmeta) ############"
"$HERE/scripts/03-pack-odin.sh" "$W" "$AP"

OUT="$W/AP_PE.tar"
echo
echo "==================================================================="
echo " DONE  ->  $OUT"
[ -f "$OUT" ] && echo "  size: $(du -h "$OUT" | cut -f1)"
cat <<NEXT

 Flash with Odin (Windows) — see README Part 6:
   AP  = $OUT
   CSC = your stock CSC_*.tar.md5     (this WIPES data — required first time)
   BL  = (empty)      CP = (empty)
 First boot lands in stock recovery ("init_user0_failed") ->
   Factory data reset -> reboot -> PixelOS boots (README Part 7).
 Root + banking apps: README Part 8 + play-integrity/.
===================================================================
NEXT
