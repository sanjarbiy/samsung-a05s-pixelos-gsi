# Play Integrity (DEVICE) + root hiding on a rooted Treble GSI

After installing the PixelOS GSI and rooting with Magisk (see the repo root
README), most banking / finance apps still refuse to run, because they call the
**Google Play Integrity API** and/or do their own root detection.

This folder documents a **verified, working** way to:

1. Pass **`MEETS_DEVICE_INTEGRITY`** (and `MEETS_BASIC_INTEGRITY`) on an
   **unlocked-bootloader** GSI, and
2. **Hide root** from the apps that check for it.

It was validated on a Samsung Galaxy A05s running a PixelOS Android 14 ARM64
Treble GSI with Magisk 30.7 (Zygisk), June 2026. It applies to most A‑only
dynamic‑partition Treble devices.

> **Scope / ethics.** This is for running **your own** device — e.g. a rooted
> phone you own and want to keep using for daily apps. Bypassing integrity and
> intercepting your own app traffic for analysis is a normal part of personal
> device control and security research. It is **not** for defeating other
> people's security. Respect each app's Terms of Service; enforcement risk is
> account/app‑level.

---

## TL;DR — what actually works (June 2026)

| Layer | Module | Why |
|---|---|---|
| Device/Build spoof | **PlayIntegrityFork v16** (osm0sis) | Makes Play Integrity see a certified Pixel. Handles BASIC; feeds the DEVICE fingerprint. |
| Key attestation | **TrickyStore v1.4.1** (5ec1cff) | A13+ DEVICE now needs a key‑attestation leaf. Its bundled **AOSP software keybox** + bootloader‑locked spoof = DEVICE (no hardware keybox). |
| Root hiding | **Shamiko v1.2.5** (LSPosed) | Hides Magisk/Zygisk from the apps in the (un‑enforced) DenyList, **including the DroidGuard process**. |

- **STRONG is impossible here** and you should not chase it: an unlocked
  bootloader (orange vbmeta) cannot produce hardware‑rooted attestation, a
  tripped Knox bit poisons Samsung's key path, and the Apr‑2026 RKP root
  rotation (RSA‑2048 → ECDSA P‑384) retired the leaked‑hardware‑keybox shortcut
  on RKP‑class devices. The software‑keybox **DEVICE** path is unaffected and is
  what almost every bank actually requires.

Sources: <https://github.com/osm0sis/PlayIntegrityFork> ·
<https://github.com/5ec1cff/TrickyStore> ·
Shamiko via <https://github.com/LSPosed/LSPosed.github.io/releases>

---

## The 5 facts that cost the most time (read these)

1. **A Pixel _Beta/Canary_ fingerprint can no longer pass DEVICE** — only STRONG
   (PlayIntegrityFork README). Use a **stable, `release-keys`** Pixel build.
   `autopif4` and the PIF module's **Action button** generate a Canary print —
   **do not run them** for a DEVICE setup, or they will silently overwrite your
   config with a STRONG‑only one.
2. **DEVICE needs `*api_level` < 26** (use **25**) and **`spoofProvider=1`**
   (the module default). `api_level` 26‑32 + `spoofProvider=0` is the **STRONG**
   parameter set and will *fail* DEVICE. (PlayIntegrityFork README, the line
   beginning "To achieve <A13 PI DEVICE integrity…")
3. **The fingerprint must be internally consistent** — every field
   (`MODEL`/`PRODUCT`/`DEVICE`/`FINGERPRINT`/`ID`/`INCREMENTAL`) from **one real
   build**. A "chimera" (e.g. Pixel‑8a model + Pixel‑7 build/incremental) is a
   DEVICE‑fail. Verify against a real dump (tadiphone.dev / dl.google.com OTAs).
4. **Two Xposed frameworks (or any unhidden one) is a DroidGuard tamper signal.**
   If you have both LSPosed and a fork (Vector), remove one. For banking
   integrity, the safest is to **disable Xposed entirely** unless a specific app
   needs a hook module.
5. **`getprop` from a shell still shows the real Samsung props** even when it's
   working — PIF rewrites props **only inside the DroidGuard process at
   read‑time**. Don't judge by static `getprop`; judge by the verdict + the PIF
   injection log.

---

## Steps

Assumes the modules are installed (flash the three zips in the Magisk app or
`magisk --install-module <zip>`, then reboot) and you have a **root shell**
(`adb root` if your GSI allows it, else `su`).

### 1. Configure PlayIntegrityFork for DEVICE
Run [`scripts/01-configure-pif-device.sh`](scripts/01-configure-pif-device.sh).
It writes [`custom.pif.prop.device`](custom.pif.prop.device) to
`/data/adb/modules/playintegrityfix/custom.pif.prop` (a stable Pixel 7 print,
`*api_level=25`, `spoofProvider=1`) and runs `killpi.sh`.

> The bundled print is public and may eventually get Google‑banned. If DEVICE
> fails with it, swap in another **stable** Pixel print (keep `*api_level=25` +
> `spoofProvider=1`).

### 2. TrickyStore — usually no change
- Keep the **default** `/data/adb/tricky_store/keybox.xml` (the AOSP software
  keybox — correct for DEVICE; do **not** drop in a hardware keybox).
- Put the apps that should get spoofed attestation in
  `/data/adb/tricky_store/target.txt` (one per line): `com.android.vending`,
  `com.google.android.gms`, and **your bank app packages**.
- Sanity: `cat /data/adb/tricky_store/tee_status` should say
  `teeBroken=false` (leaf‑hack mode works).

### 3. Hide root from DroidGuard + the bank apps
Run [`scripts/02-hide-root.sh`](scripts/02-hide-root.sh). It turns **Enforce
DenyList OFF** (so Shamiko runs in blacklist mode), then adds Play Services,
the DroidGuard process, and the Play Store to the DenyList so Shamiko unmounts
root there. Add your bank packages too. **Reboot** so Shamiko applies it.

> With Enforce DenyList **off**, the DenyList is just Shamiko's hide‑list — PIF
> still injects into GMS (Zygisk runs before any unmount). This is why adding
> GMS here is safe *only* with Enforce off.

### 4. Verify
Run [`scripts/03-verify.sh`](scripts/03-verify.sh) while a Play Integrity check
runs. You want to see PIF rewriting the model/fingerprint inside
`com.google.android.gms.unstable`, e.g.:

```
PIF/Java:DG: [MODEL]: <real> -> Pixel 7
PIF/Java:DG: [FINGERPRINT]: <real> -> google/panther/panther:14/...
PIF/Native: [ro.board.first_api_level]: 33 -> 25
Spoofing Keystore Provider enabled!
```

Independently confirm TrickyStore with **vvb2060 KeyAttestation**
(<https://github.com/vvb2060/KeyAttestation>): it should report **"Bootloader is
locked"** and **"AOSP software attestation root certificate"**.

For the verdict itself, use a checker that shows the raw JSON. Note the popular
`gr.nikolasspyr.integritycheck` can return all‑`UNEVALUATED` (no
`deviceRecognitionVerdict`) on a fresh device — that is the checker not
completing an evaluation, **not** a device fail. A zero‑config raw‑JSON checker
or a real app is more reliable. A genuine **fail** is an **empty**
`deviceRecognitionVerdict` array; a **pass** lists `MEETS_DEVICE_INTEGRITY` +
`MEETS_BASIC_INTEGRITY`.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| All verdicts fail incl. BASIC | Canary print, or `api_level` 26‑32, or `spoofProvider=0` | Use stable print + `api_level=25` + `spoofProvider=1` (step 1) |
| BASIC fails but PIF log shows it injecting | Root visible to DroidGuard | Step 3 (Enforce off + GMS in DenyList + Shamiko), reboot |
| Was passing, now fails after a reboot/tap | You tapped the PIF **Action** button or reinstalled the zip → Canary restored | Re‑run step 1; never tap Action |
| DEVICE fails, BASIC passes | Print is banned, or TrickyStore not injecting | Swap stable print; check KeyAttestation shows bootloader‑locked; try `pkg!` (force generate) in `target.txt` |
| Checker shows all `UNEVALUATED` | Checker isn't completing a real request | Use a different checker / a real app |

See [`ssl-pinning.md`](ssl-pinning.md) for inspecting your own app traffic
(separate device state — never run a Frida server during real banking; it is
independently detectable).
