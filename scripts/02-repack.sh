#!/bin/bash
# Repack the stock super.img: replace `system` with a GSI, keep all other
# (vendor/product/odm/system_ext/*_dlkm) partitions. Auto-derives the super
# geometry (device-size, group, metadata-slots) from lpdump -- no hardcoding,
# so this works for other A-only dynamic-partition Samsung devices too.
#
# Usage:        02-repack.sh  <AP_*.tar.md5>  <gsi.img|.img.xz>  [workdir]
# Re-run after shrinking system.img (RESUME=1 skips extraction/lpunpack):
#               RESUME=1 02-repack.sh  <AP_*.tar.md5>  <ignored>  [workdir]
set -e
AP="$1"; GSI_IN="$2"; W="${3:-./work}"
HERE="$(cd "$(dirname "$0")" && pwd)"
BIN="$(find -L "$HERE/../.tools" -name lpmake -printf '%h\n' 2>/dev/null | head -1)"
[ -z "$BIN" ] && { echo "Build tools first: scripts/01-build-tools.sh"; exit 1; }
{ [ -z "$AP" ] || [ -z "$GSI_IN" ]; } && { echo "Usage: $0 <AP_*.tar.md5> <gsi.img[.xz]> [workdir]"; exit 1; }
mkdir -p "$W"; W="$(cd "$W" && pwd)"
ru(){ echo $(( ( ($1 + 511) / 512 ) * 512 )); }   # round up to 512-byte sector

if [ -z "${RESUME:-}" ]; then
  echo "[*] extract super.img.lz4 from AP"
  tar xf "$AP" -C "$W" super.img.lz4
  echo "[*] decompress + unsparse super -> super.raw"
  lz4 -d -f "$W/super.img.lz4" "$W/super.img"
  simg2img "$W/super.img" "$W/super.raw" || cp "$W/super.img" "$W/super.raw"
  rm -f "$W/super.img"

  echo "[*] lpunpack stock partitions -> parts/"
  rm -rf "$W/parts"; mkdir -p "$W/parts"
  "$BIN/lpunpack" "$W/super.raw" "$W/parts"

  echo "[*] prepare GSI as parts/system.img"
  case "$GSI_IN" in
    *.xz) xz -dc -T0 "$GSI_IN" > "$W/parts/system.img" ;;
    *)    cp "$GSI_IN" "$W/parts/system.img" ;;
  esac
  if file "$W/parts/system.img" | grep -qi sparse; then
    simg2img "$W/parts/system.img" "$W/parts/system.raw"; mv "$W/parts/system.raw" "$W/parts/system.img"
  fi
else
  echo "[*] RESUME=1 -> reusing existing $W/super.raw and $W/parts/ (e.g. after shrinking system.img)"
  [ -f "$W/super.raw" ] && [ -d "$W/parts" ] || { echo "RESUME needs an existing super.raw + parts/ from a prior run"; exit 1; }
fi

echo "[*] read stock layout (lpdump)"
DUMP="$("$BIN/lpdump" "$W/super.raw")"
DEV=$(awk '/Block device table/{b=1} b&&/Size:/{gsub(/[^0-9]/,"",$2);print $2;exit}' <<<"$DUMP")
MSLOTS=$(awk -F': ' '/Metadata slot count/{print $2;exit}' <<<"$DUMP")
MSIZE=$(awk -F': ' '/Metadata max size/{gsub(/[^0-9]/,"",$2);print $2;exit}' <<<"$DUMP")
GROUP=$(awk '/Group table/{g=1} g&&/Name:/{n=$2} g&&/Maximum size:/{s=$3; if(s+0>0){print n; exit}}' <<<"$DUMP")
GMAX=$(awk -v G="$GROUP" '/Group table/{g=1} g&&$2==G{f=1} f&&/Maximum size:/{gsub(/[^0-9]/,"",$3);print $3;exit}' <<<"$DUMP")
PARTS=$(awk '/Partition table/{p=1} /Super partition layout/{p=0} p&&/^ *Name:/{print $2}' <<<"$DUMP" | awk '!seen[$0]++')
[ -z "$DEV" ] || [ -z "$GROUP" ] || [ -z "$PARTS" ] && { echo "ERROR: could not parse lpdump. Run '$BIN/lpdump $W/super.raw' and check."; exit 1; }
echo "    device-size=$DEV  metadata-slots=$MSLOTS  metadata-size=$MSIZE  group=$GROUP:$GMAX"
echo "    partitions: $(echo $PARTS)"

echo "[*] compute sizes + budget"
TOTAL=0; ARGS=()
for p in $PARTS; do
  [ -f "$W/parts/$p.img" ] || { echo "ERROR: missing $W/parts/$p.img"; exit 1; }
  sz=$(ru "$(stat -c %s "$W/parts/$p.img")")
  TOTAL=$((TOTAL+sz))
  ARGS+=(--partition "$p:readonly:$sz:$GROUP" --image "$p=$W/parts/$p.img")
done
echo "    total=$TOTAL  group-max=$GMAX"
if [ "$TOTAL" -gt "$GMAX" ]; then
  echo "[!] GSI too big by $((TOTAL-GMAX)) bytes. Shrink system.img, then RESUME:"
  echo "      e2fsck -y -E unshare_blocks $W/parts/system.img"
  echo "      resize2fs -M $W/parts/system.img"
  echo "      RESUME=1 $0 \"$AP\" - \"$W\""
  exit 2
fi
echo "    OK, headroom=$((GMAX-TOTAL)) bytes"

echo "[*] lpmake -> super_new.img (sparse)"
rm -f "$W/super_new.img"
"$BIN/lpmake" --metadata-size "$MSIZE" --super-name super --metadata-slots "$MSLOTS" \
  --device-size "$DEV" --group "$GROUP:$GMAX" "${ARGS[@]}" --sparse --output "$W/super_new.img"
echo "[*] done: $W/super_new.img"
file "$W/super_new.img"
echo "Next: scripts/03-pack-odin.sh \"$W\" \"$AP\""
