#!/system/bin/sh
# Hide root from DroidGuard and your apps using Shamiko (blacklist mode).
# Run as ROOT, then REBOOT for Shamiko to apply.
#
# How it works: with "Enforce DenyList" OFF, Magisk does not itself unmount, so
# PlayIntegrityFork (a Zygisk module) can still inject into Google Play Services.
# Shamiko then unmounts root from every package in the DenyList -- including the
# DroidGuard process -- so the integrity check and your apps don't see Magisk.
set -u
command -v magisk >/dev/null 2>&1 || { echo "magisk not in PATH"; exit 1; }

# 1) Enforce DenyList OFF (this is what puts Shamiko in blacklist mode)
magisk --sqlite "UPDATE settings SET value=0 WHERE key='denylist'"
echo "Enforce DenyList = $(magisk --sqlite "SELECT value FROM settings WHERE key='denylist'") (want value=0)"

# 2) Hide root from Play Services (incl. the DroidGuard 'unstable' process) + Play Store
magisk --denylist add com.google.android.gms
magisk --denylist add com.google.android.gms com.google.android.gms.unstable
magisk --denylist add com.android.vending

# 3) Hide from YOUR apps too -- add each bank/finance package, e.g.:
#   magisk --denylist add uz.dunyo.mobile
#   magisk --denylist add com.example.bank
# (find packages with: pm list packages -3)
for PKG in "$@"; do
  magisk --denylist add "$PKG" && echo "added: $PKG"
done

echo "=== DenyList (gms/vending + your apps) ==="
magisk --denylist ls | grep -iE 'gms|vending|bank|pay|click|uzum|anor|dunyo' 2>/dev/null
echo "=== Reboot now so Shamiko applies the hide-list, then re-test. ==="
