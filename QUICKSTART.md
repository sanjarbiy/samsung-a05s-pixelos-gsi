# Quick start — one command

Turn your **own** Samsung stock firmware + a PixelOS GSI into an Odin‑flashable
`AP_PE.tar`. Designed for **SM‑A057F**; works for most A‑only Treble Samsung
devices. ~10–20 min after downloads.

> **Why you build it yourself (and we don't ship a prebuilt):** the output bakes
> in *your* phone's Samsung vendor/product/odm partitions, so a file built for a
> different model/region can **brick** another phone — and Samsung firmware can't
> be legally re‑hosted. Building locally is the safe, legal, universal path.

---

## What's verified — and what isn't (read this)
- ✅ **Verified end‑to‑end** on **SM‑A057F**, stock build **`A057FXXSDDZB3`**, region **OXE**, with the PixelOS GSI `bN-14.0-20240824`. It boots, with Wi‑Fi/data/calls/camera, and roots.
- ⚙️ **Should work but is not individually tested:** other A05s builds/regions and other A‑only Treble Samsung devices. The repack script **auto‑derives** the partition geometry from *your* firmware, so it adapts — but treat the first flash as "verify, don't assume."
- ❌ **Will NOT work:** the **US/Snapdragon `SM‑S`/carrier** A05s variants (different partitions/locking), `aN`/`vndklite`/`slim` GSIs, and any phone whose **bootloader can't be unlocked**.
- ⏳ **Time‑sensitive:** the `play-integrity/` fingerprint can get banned by Google over months (swap a fresh stable print). The GSI link is a community build that may move.
- 🧰 **You need both a Linux box (build) and a Windows PC (Frija + Odin).**

Honest bottom line: if you're on the verified phone and follow the steps in order,
this is reliable. On a *different* device it's very likely but not guaranteed —
the scripts fail **loudly** (preflight tool check, geometry checks, "GSI too big"
guidance) rather than silently, and [Un‑brick](README.md#un-brick--go-back-to-stock-samsung)
gets you back to stock if a flash goes wrong.

## 0. Have ready
- A **Linux** box (or WSL/VM). Dependencies (Debian/Ubuntu):
  ```bash
  sudo apt update && sudo apt install -y git clang binutils lz4 xz-utils android-sdk-libsparse-utils e2fsprogs
  ```
  (`build-flashable.sh` re‑checks these and tells you exactly what's missing.)
- A **Windows** PC with **Odin** (Samsung's flasher) + Samsung USB drivers.
- Phone bootloader **UNLOCKED** — see [README Part 1](README.md#part-1--unlock-the-bootloader).

## 1. Download TWO things
1. **Your stock firmware** with **Frija** (Windows): enter **your exact Model**
   (`SM-A057F`) and **your region/CSC**. You get `AP_…tar.md5`, `BL_…`, `CP_…`,
   `CSC_…`. → [README Part 2](README.md#part-2--download-the-stock-firmware-frija)
   - ⚠️ Use **your own** firmware. Don't flash someone else's region.
2. **PixelOS GSI** — the **arm64 `bN`** (System‑as‑Root, **NON‑vndklite**, non‑slim)
   build, a `.img.xz`. Verified source: **MisterZtr/PixelOS_gsi**
   ([GitHub releases](https://github.com/MisterZtr/PixelOS_gsi/releases) →
   [SourceForge](https://sourceforge.net/projects/misterztr-gsi/files/PixelOS/)).
   File looks like `PixelOS_treble_arm64_bN-14.0-YYYYMMDD.img.xz`
   (the exact one this guide was verified with: `…bN-14.0-20240824.img.xz`).
   - Pick `bN` (not `aN` = legacy, not `*_slim`, not `*_vndklite`).

## 2. Build (one command, on Linux)
```bash
git clone https://github.com/sanjarbiy/samsung-a05s-pixelos-gsi
cd samsung-a05s-pixelos-gsi
./build-flashable.sh  /path/to/AP_*.tar.md5  /path/to/pixelos_*.img.xz
```
→ produces **`work/AP_PE.tar`**.

If it says *"GSI too big"*, it prints the two `e2fsck`/`resize2fs` lines to shrink
the GSI — run them, then re‑run with `RESUME=1` (the script tells you the exact
command). That's the only manual branch.

## 3. Flash (Odin, Windows)
| Odin slot | File |
|---|---|
| **AP** | `work/AP_PE.tar` |
| **CSC** | your stock `CSC_*.tar.md5`  ← **wipes data, required the first time** |
| **BL** | *(leave empty)* |
| **CP** | *(leave empty)* |

Start. → [README Part 6](README.md#part-6--flash-with-odin)

## 4. First boot
You'll land in stock recovery ("Can't load Android / `init_user0_failed`").
Do **Factory data reset** → reboot → PixelOS boots (slow first time).
→ [README Part 7](README.md#part-7--first-boot--the-mandatory-factory-reset)

## 5. (Optional) Root + banking apps
- Root with Magisk → [README Part 8](README.md#part-8--root-with-magisk-optional)
- Pass Play Integrity + hide root → [`play-integrity/`](play-integrity/)

---
Stuck? [Troubleshooting](README.md#troubleshooting) ·
[Un‑brick back to stock](README.md#un-brick--go-back-to-stock-samsung)
