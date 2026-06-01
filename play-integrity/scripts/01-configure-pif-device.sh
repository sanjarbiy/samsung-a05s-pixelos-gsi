#!/system/bin/sh
# Configure PlayIntegrityFork v16 for MEETS_DEVICE_INTEGRITY (not STRONG).
# Run as ROOT on the device:
#   adb push custom.pif.prop.device 01-configure-pif-device.sh /data/local/tmp/
#   adb shell su -c 'sh /data/local/tmp/01-configure-pif-device.sh'
#   (or, if your GSI allows `adb root`: adb shell sh /data/local/tmp/01-...sh)
#
# Expects custom.pif.prop.device to sit next to this script (or in /data/local/tmp).
set -u
M=/data/adb/modules/playintegrityfix
[ -d "$M" ] || { echo "ERROR: PlayIntegrityFork not installed at $M"; exit 1; }

SRC="$(dirname "$0")/custom.pif.prop.device"
[ -f "$SRC" ] || SRC=/data/local/tmp/custom.pif.prop.device
[ -f "$SRC" ] || { echo "ERROR: custom.pif.prop.device not found (push it to /data/local/tmp)"; exit 1; }

cp "$SRC" "$M/custom.pif.prop"
chmod 644 "$M/custom.pif.prop"
[ -x /system/bin/restorecon ] && restorecon "$M/custom.pif.prop" 2>/dev/null

echo "=== wrote $M/custom.pif.prop ==="
grep -E 'FINGERPRINT|MODEL|api_level|spoofProvider|spoofProps|RELEASE' "$M/custom.pif.prop"

# sanity checks
grep -q 'RELEASE=CANARY' "$M/custom.pif.prop" && echo '!! WARNING: CANARY print — will FAIL DEVICE'
A=$(grep -oE '^\*api_level=[0-9]+' "$M/custom.pif.prop" | cut -d= -f2)
[ -n "$A" ] && [ "$A" -ge 26 ] && echo "!! WARNING: *api_level=$A is >=26 (STRONG range) — DEVICE wants <26"
grep -q '^spoofProvider=0' "$M/custom.pif.prop" && echo '!! WARNING: spoofProvider=0 is the STRONG setting — DEVICE wants 1'

# force GMS DroidGuard + Play Store to re-read the config (no reboot needed)
[ -f "$M/killpi.sh" ] && sh "$M/killpi.sh" 2>/dev/null
echo "=== done. Re-run a Play Integrity check. Do NOT tap the PIF Action button (it writes a Canary print). ==="
