#!/system/bin/sh
# Verify the spoof is live. Run as ROOT.
# Best used right after triggering a Play Integrity check in a checker app.
set -u
M=/data/adb/modules/playintegrityfix

echo "=== modules present ==="
ls /data/adb/modules/ | grep -iE 'playintegrityfix|tricky_store|shamiko'

echo "=== active PIF config (want stable print, *api_level=25, spoofProvider=1) ==="
grep -E 'FINGERPRINT|MODEL|api_level|spoofProvider' "$M/custom.pif.prop" 2>/dev/null

echo "=== Enforce DenyList (want 0 for Shamiko) + zygisk (want 1) ==="
magisk --sqlite "SELECT key,value FROM settings WHERE key IN ('denylist','zygisk')" 2>/dev/null

echo "=== TrickyStore daemon + tee_status ==="
ps -A 2>/dev/null | grep -i tricky | grep -v grep
cat /data/adb/tricky_store/tee_status 2>/dev/null

echo "=== PIF injection log (re-run a check, then look for '-> Pixel ...' / '-> 25') ==="
logcat -d 2>/dev/null | grep -iE 'PIF/Java:DG|PIF/Native' | tail -25

cat <<'EOF'

=== Independent attestation proof ===
Install vvb2060 KeyAttestation (github.com/vvb2060/KeyAttestation) and open it.
A correctly-working TrickyStore DEVICE setup shows:
  * "Bootloader is locked"
  * "AOSP software attestation root certificate"
If it shows the OEM/Knox root or "bootloader unlocked", TrickyStore is not
injecting for that app -- reboot and re-check the daemon.

=== Reading the verdict ===
PASS  : deviceRecognitionVerdict = [MEETS_DEVICE_INTEGRITY, MEETS_BASIC_INTEGRITY]
FAIL  : deviceRecognitionVerdict = []  (empty array)
NOT A REAL RESULT: everything "UNEVALUATED" / no deviceRecognitionVerdict at all
                   -> checker didn't complete a request; use another checker/app.
EOF
