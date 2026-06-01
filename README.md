# Samsung Galaxy A05s (SM‑A057F) → PixelOS (Android 14 GSI) + Root

Replace Samsung One UI with a clean **Google/Pixel‑style Android (a GSI)** on the Galaxy A05s, then optionally **root** with Magisk.

The A05s has **no working TWRP and no fastboot**, so the usual "`fastboot flash system`" GSI method is impossible. The only working route is to **repack the stock `super` partition** (put the GSI in as `system`, keep Samsung's drivers) and flash it with **Odin**. This guide documents that end‑to‑end, with the non‑obvious traps solved, plus scripts that automate the hard part.

> ✅ **Verified:** PixelOS `treble_arm64_bN-14.0` boots on **SM‑A057F** (stock build `A057FXXSDDZB3`). Wi‑Fi, mobile data/calls, and camera work (they use the kept Samsung vendor). Magisk root works.

If you follow every step **in order**, you will succeed. Don't skip steps. Read the ⚠️ boxes.

> 🚀 **In a hurry?** [`QUICKSTART.md`](QUICKSTART.md) — download your own firmware + a
> PixelOS GSI, run **one command** ([`build-flashable.sh`](build-flashable.sh)) to
> produce the Odin `AP_PE.tar`, flash, done. (There's no prebuilt download: the
> image contains *your* phone's Samsung blobs, so a foreign prebuilt can brick,
> and Samsung firmware can't be re‑hosted — you build it from your own firmware.)

---

## Table of contents
1. [What you'll end up with](#1-what-youll-end-up-with)
2. [⚠️ Warnings — read before anything](#2-️-warnings--read-before-anything)
3. [Will this work on MY phone?](#3-will-this-work-on-my-phone)
4. [How it works (plain English)](#4-how-it-works-plain-english)
5. [Glossary (if you're new)](#5-glossary-if-youre-new)
6. [What you need (hardware, software, files)](#6-what-you-need)
7. [Part 1 — Unlock the bootloader](#part-1--unlock-the-bootloader)
8. [Part 2 — Download the stock firmware (Frija)](#part-2--download-the-stock-firmware-frija)
9. [Part 3 — Set up the Linux repack machine](#part-3--set-up-the-linux-repack-machine)
10. [Part 4 — Repack `super` (swap in the GSI)](#part-4--repack-super-swap-in-the-gsi)
11. [Part 5 — Build the Odin flash file](#part-5--build-the-odin-flash-file)
12. [Part 6 — Flash with Odin](#part-6--flash-with-odin)
13. [Part 7 — First boot + the mandatory factory reset](#part-7--first-boot--the-mandatory-factory-reset)
14. [Part 8 — Root with Magisk (optional)](#part-8--root-with-magisk-optional)
15. [Part 9 — Play Integrity + root hiding (for banking apps)](#part-9--play-integrity--root-hiding-for-banking-apps)
16. [Verify success](#verify-success)
16. [Troubleshooting (every error we hit)](#troubleshooting)
17. [Un‑brick / go back to stock Samsung](#un-brick--go-back-to-stock-samsung)
18. [FAQ](#faq) · [Credits](#credits) · [License](#license)

---

## 1. What you'll end up with
- **Stock Google Android 14 (PixelOS)** — Pixel launcher, Google apps, no One UI / Bixby / Samsung apps.
- Working hardware (Wi‑Fi, calls, data, Bluetooth, GPS, camera) via the kept Samsung drivers.
- Optional **Magisk root**.

---

## 2. ⚠️ Warnings — read before anything
- **All data is erased.** Back up first.
- **Knox is permanently tripped** (`warranty_bit 0 → 1`). Samsung Pay, Secure Folder, some banking features and the warranty are gone **forever** (e‑fuse, not reversible).
- Banking apps may refuse to run (Play Integrity fails on a custom ROM) — see [FAQ](#faq).
- **You cannot hard‑brick** with this method — we never flash the bootloader or modem, so **Download mode always survives** and you can re‑flash stock (see [Un‑brick](#un-brick--go-back-to-stock-samsung)). Worst case is a bootloop. **But you do everything at your own risk. Nobody is responsible for your device but you.**

---

## 3. Will this work on MY phone?
- **Model must be `SM‑A057F`** (international). Check: Settings → About phone → Model number.
- Other A05s variants (`SM‑A057M`, `SM‑A057G`) likely work too (same `a05s` platform) — but use **their own** firmware.
- **US Snapdragon / carrier models: NO.** Those have **no OEM‑unlock toggle** → you can't unlock → stop here.
- Quick test: if Developer options has an **"OEM unlocking"** switch that you can turn on, you're good.

---

## 4. How it works (plain English)
A "GSI" is **only the operating system** (`system` partition: the UI + Google apps). It contains **no drivers** for your specific phone. On the A05s, the OS **and** the drivers (`vendor`, `product`, `odm`, …) all live together inside **one big partition called `super`** (these are "dynamic / logical partitions").

There's no tool on the A05s to flash just `system`. So we do a **transplant**:

```
stock super.img                          new super.img (what we build)
┌───────────────────────┐                ┌───────────────────────┐
│ system   (Samsung OS) │  ──remove──►   │ system   (PixelOS GSI)│ ◄─ swapped
│ vendor   (drivers)    │  ──keep────►   │ vendor   (drivers)    │
│ product  (Samsung)    │  ──keep────►   │ product  (Samsung)    │
│ odm / *_dlkm / …      │  ──keep────►   │ odm / *_dlkm / …      │
└───────────────────────┘                └───────────────────────┘
        then: disable AVB (vbmeta) ──► flash new super + vbmeta with Odin ──► wipe data
```

We keep Samsung's drivers so hardware keeps working; we only replace the OS.

---

## 5. Glossary (if you're new)
- **GSI** – Generic System Image: one Android system image meant to run on any "Treble" device.
- **super** – the single physical partition that holds the logical partitions (system, vendor, …).
- **lpunpack / lpmake** – tools to unpack / rebuild a `super` image.
- **lpdump** – prints a `super` image's layout (sizes, groups, partitions).
- **vbmeta / AVB** – "Android Verified Boot". It cryptographically checks system/vendor. We **disable** it so the phone accepts our modified `super`.
- **Odin** – Samsung's Windows flashing tool. Slots: **BL** (bootloader), **AP** (system/super/etc.), **CP** (modem), **CSC** (carrier + data wipe), **HOME_CSC** (carrier, keeps data).
- **Download mode** – Samsung's flash mode that Odin talks to.
- **`.tar.md5`** – a plain tar with an MD5 appended; what Odin flashes.
- **`.lz4`** – Samsung compresses each image inside the tar with LZ4.

---

## 6. What you need

**Hardware**
- The Galaxy A05s (battery > 50%).
- A USB cable + a **Windows PC** (for Odin).
- A **Linux machine** (native, VM, or WSL2) for the repack — needs **~40 GB free disk**.

**Software**
- **Windows:** [Odin3 v3.13.x or newer](https://odindownload.com/) + Samsung USB driver, and [Frija](https://github.com/SlackingVeteran/frija) (firmware downloader).
- **Linux:** `clang lz4 android-sdk-libsparse-utils e2fsprogs git python3` (install command in Part 3).
- **`adb`** ([Android platform‑tools](https://developer.android.com/tools/releases/platform-tools)) on whichever PC is plugged into the phone — used for the verification checkpoints and `adb reboot download`.

**Files** (download yourself — not in this repo, for copyright/size reasons)
- **Stock firmware** for your exact model (Part 2).
- **The GSI:** [PixelOS GSI by MisterZtr](https://sourceforge.net/projects/misterztr-gsi/files/PixelOS/Android%2014/) → pick `PixelOS_treble_arm64_bN-14.0-*.img.xz`.
  - **`arm64` `_bN`** is mandatory: **`b`** = System‑as‑Root (the A05s needs this; `a` is legacy and won't boot). **Not** the `vndklite` build (it bootloops).
  - Any phh/TrebleDroid **`arm64 b`** GSI works the same way.

**Get this repo**
```bash
git clone https://github.com/sanjarbiy/samsung-a05s-pixelos-gsi
cd samsung-a05s-pixelos-gsi
```

---

## Part 1 — Unlock the bootloader
> Erases the phone. This is unavoidable.

1. Insert a SIM, connect Wi‑Fi, sign into a **Google account** + **Samsung account** once (lets the OEM‑unlock toggle appear, sometimes after a wait / a few reboots).
2. Settings → **About phone → Software information** → tap **Build number 7×** (enables Developer options).
3. Settings → **Developer options** → turn **ON**: **OEM unlocking** and **USB debugging**.
4. Power **off**. Hold **Volume Up + Volume Down together**, then **plug the USB cable into the PC** (keep holding) → a blue **unlock warning** appears.
5. **Long‑press Volume Up** → screen changes → press **Volume Up** to confirm **Unlock bootloader** → it wipes and reboots.
6. Finish setup, then **re‑enable Developer options → USB debugging** (and OEM unlocking stays on).

**Checkpoint** (on the PC, phone in OS with USB debugging, `adb` installed):
```bash
adb shell getprop ro.boot.flash.locked        # expect: 0
adb shell getprop ro.boot.verifiedbootstate    # expect: orange
```
If `flash.locked` is `0` and state is `orange`, the bootloader is unlocked. ✅

---

## Part 2 — Download the stock firmware (Frija)
You need the stock `super` (for the drivers) and the stock `vbmeta` (to disable). Frija downloads the exact official firmware.

1. On Windows, run **Frija** → **Manual** tab.
2. Enter **Model** = your model (e.g. `SM-A057F`), **CSC** = your region code, **IMEI/Serial** = your phone's (dial `*#06#` for IMEI).
3. **Check Update** → **Download**. You get a zip containing 4–5 `.tar.md5` files:
   - `BL_…` (bootloader), `AP_…` (the big one, ~7 GB, contains `super.img.lz4`), `CP_…` (modem), `CSC_…` and `HOME_CSC_…`.
4. Copy the **`AP_…tar.md5`** and the **`CSC_…tar.md5`** to your Linux machine.

> ⚠️ Get firmware matching the build **already on your phone** (or newer). Check yours: `adb shell getprop ro.bootloader` (e.g. `A057FXXSDDZB3`).

---

## Part 3 — Set up the Linux repack machine
```bash
# 1. dependencies
sudo apt-get update
sudo apt-get install -y git clang binutils lz4 xz-utils android-sdk-libsparse-utils e2fsprogs
# clang→clang/clang++ · binutils→ar/strip · lz4 (Odin format) · xz-utils (.img.xz GSI)
# android-sdk-libsparse-utils→simg2img/img2simg · e2fsprogs→e2fsck/resize2fs (GSI shrink)

# 2. build lpunpack / lpmake / lpdump (the repo's script handles a compile fix)
./scripts/01-build-tools.sh
```
**Expected:** ends with `Built:` and paths to `lpmake`, `lpunpack`, `lpdump`. ✅

---

## Part 4 — Repack `super` (swap in the GSI)
```bash
./scripts/02-repack.sh  /path/to/AP_…tar.md5  /path/to/PixelOS_treble_arm64_bN-14.0-….img.xz  ./work
```
This: extracts the stock `super`, **reads its exact layout with `lpdump`**, `lpunpack`s it, drops in the GSI as `system`, and `lpmake`s a new `super.img`. **All sizes are auto‑derived** — nothing hardcoded.

**Expected output (real A05s example — yours should look like this):**
```
[*] read stock layout (lpdump)
    device-size=9017753600  metadata-slots=2  metadata-size=65536  group=qti_dynamic_partitions:9013559296
    partitions: system odm product system_dlkm system_ext vendor vendor_dlkm
...
    total=8150614016  group-max=9013559296
    OK, headroom=862945280
[*] lpmake -> super_new.img (sparse)
[*] done: ./work/super_new.img
./work/super_new.img: Android sparse image, version: 1.0, ...
```
- `metadata-slots=2` and the exact `device-size` are **read from your phone's firmware** — that's the point (the textbook value "1" is wrong here).
- **`Invalid sparse file format at header magic` printed several times is HARMLESS** — `lpmake` is just reading the raw partition images. It succeeded if you see `done: …/super_new.img` and `Android sparse image` at the end.
- If you see **`GSI too big`**: the GSI doesn't fit the group. Shrink `system.img` in place, then re‑run with `RESUME=1` (skips re‑extraction so the shrink is kept):
  ```bash
  e2fsck -y -E unshare_blocks ./work/parts/system.img
  resize2fs -M ./work/parts/system.img
  RESUME=1 ./scripts/02-repack.sh  AP_…tar.md5  -  ./work
  ```
  (PixelOS `bN` normally fits with headroom, so you usually won't need this.)

---

## Part 5 — Build the Odin flash file
```bash
./scripts/03-pack-odin.sh  ./work  /path/to/AP_…tar.md5
```
This LZ4‑compresses the new `super` **in Samsung's exact format**, disables AVB in `vbmeta`, and tars both for Odin.

**Expected output:**
```
    vbmeta flags now:  00 00 00 03          ← AVB disabled (verity+verification)
[*] done: ./work/AP_PE.tar
super.img.lz4
vbmeta.img.lz4
    magic (want 04 22 4d 18 6c ..): 04 22 4d 18 6c 60     ← MUST start 04 22 4d 18 6c
```
> ⚠️ If the magic does **not** start `04 22 4d 18 6c`, Odin will say **"LZ4 is invalid"**. The `6c` = the `--content-size` flag Samsung requires (the script sets it). Don't compress with plain `lz4`.

Copy **`./work/AP_PE.tar`** and your stock **`CSC_…tar.md5`** to the Windows PC.

---

## Part 6 — Flash with Odin
1. Put the phone in **Download mode**: with it on, run `adb reboot download` (or: power off → Vol Up + Vol Down + plug USB → press Vol Up to **continue** to the download screen — *not* the unlock prompt).
2. Open **Odin3 as Administrator**. When the phone connects, the **ID:COM** box turns **blue** (driver OK). If it stays grey, install the Samsung USB driver.
3. Load slots:
   | Odin slot | File |
   |---|---|
   | **AP** | `AP_PE.tar` |
   | **CSC** | your stock **`CSC_…tar.md5`** (the **CSC**, *not* HOME_CSC → this wipes data, required) |
   | **BL** | *(empty)* |
   | **CP** | *(empty)* |
4. **Options** tab: leave defaults (**Auto Reboot** ✓, **F. Reset Time** ✓). **Do NOT** tick **Re‑Partition** or **Nand Erase**.
5. Click **Start**.

**Expected:** Odin logs `super.img` (this is the big one — **several minutes, the log looks frozen, that's normal — do not unplug**), then `vbmeta.img`, then CSC, then a green **`PASS!`**. The phone reboots.

---

## Part 7 — First boot + the mandatory factory reset
On the first reboot the phone lands in **Samsung stock recovery** with:
> *"Can't load Android system. Your data may be corrupt."* and the reboot reason **`init_user0_failed`**.

**This is expected, not a failure** — the new OS can't read the old encrypted `/data`. Fix it:
1. In recovery, use **Volume** keys to highlight **"Factory data reset"**, **Power** to select.
2. Confirm (highlight **Factory data reset / Yes**, **Power**).
3. Back at the menu → **"Reboot system now"** → **Power**.

Now it boots PixelOS. **The first boot is slow (5–10 min)** — Google logo, then "optimizing". Be patient. Then the **Pixel setup wizard** appears. 🎉

---

## Part 8 — Root with Magisk (optional)
We patch the **stock `init_boot`** (the boot ramdisk) — `super`/PixelOS stay untouched.

1. On Linux, extract the stock init_boot:
   ```bash
   cd work
   tar xf /path/to/AP_…tar.md5 init_boot.img.lz4
   lz4 -d init_boot.img.lz4 init_boot.img
   ```
2. Copy `work/init_boot.img` to the phone (`adb push work/init_boot.img /sdcard/Download/`).
3. Install the **[Magisk APK](https://github.com/topjohnwu/Magisk/releases)** on PixelOS → open Magisk → **Install** → **"Select and Patch a File"** → pick `init_boot.img` → it creates **`magisk_patched-XXXXX.img`** in `Download/`.
4. Pull it back + pack for Odin:
   ```bash
   adb pull /sdcard/Download/magisk_patched-XXXXX.img ./work/
   ./scripts/04-pack-initboot.sh  ./work  ./work/magisk_patched-XXXXX.img
   ```
5. Odin: **AP = `work/AP_root.tar`**, **all other slots EMPTY** (no wipe). Start → reboot.
6. Open Magisk → it shows **Installed**. Rooted. ✅

---

## Part 9 — Play Integrity + root hiding (for banking apps)
Most banking / finance apps refuse to run on a rooted device until you pass the
**Play Integrity** `DEVICE` check and hide root. That's a separate topic with
its own verified module stack (PlayIntegrityFork + TrickyStore + Shamiko),
exact config, and gotchas (Canary fingerprints fail DEVICE, `api_level<26`,
hiding root from DroidGuard, why STRONG is impossible on an unlocked bootloader).

➡️ See **[`play-integrity/`](play-integrity/)** for the full guide, ready‑to‑run
device scripts, a DEVICE `custom.pif.prop` template, and
[SSL‑pinning notes](play-integrity/ssl-pinning.md) for analysing your own
app traffic.

---

## Verify success
On the PC (`adb`), after PixelOS boots:
```bash
adb shell getprop ro.modversion          # PixelOS_treble_arm64_bN-14.0-...   (you're on PixelOS)
adb shell getprop ro.build.version.release  # 14
adb shell magisk -V                       # 30700 (or your version) → root installed
```

---

## Troubleshooting
Every problem we actually hit, and the fix:

| Symptom | Cause | Fix |
|---|---|---|
| Odin: **`FAIL! LZ4 is invalid`** | `.lz4` lacks the content‑size header Odin requires | Pack with `lz4 -B6 --content-size` (magic `04 22 4d 18 6c …`). `03-pack-odin.sh` does this. Don't use plain `lz4`. |
| After flash: recovery loop, **`init_user0_failed`** / "data may be corrupt" | New OS can't read old encrypted `/data` | **Factory data reset** in stock recovery (Part 7). |
| Boots to dm‑verity / "verification failed" / won't boot | AVB still on | Flash the **vbmeta with flags `00 00 00 03`** (script does it). Confirm in Part 5 output. |
| `lpmake` made a `super` that won't boot | Used `--metadata-slots 1` | Must match stock (**2** on A05s). `02-repack.sh` reads it from `lpdump` automatically. |
| GSI bootloops at logo | Wrong GSI variant | Use **`arm64 _bN`** (System‑as‑Root), **non‑vndklite**. |
| `02-repack.sh` says **GSI too big** | PixelOS `system` > free space in the group | Shrink with `e2fsck -E unshare_blocks` + `resize2fs -M` (commands in Part 4), re‑run. |
| `01-build-tools.sh` compile error about `std::find` | New libstdc++ needs `<algorithm>` | The script auto‑patches the liblp sources; just re‑run it. |
| Frija "no firmware" / wrong region | CSC mismatch | Try a region your phone supports; any region's **same AP build** works for `super`. |
| Odin **ID:COM** stays grey | No Samsung USB driver / not in Download mode | Install Samsung USB driver; re‑enter Download mode. |
| Camera app crashes / SIM2 can't receive calls | Known minor GSI quirks | Use a different camera app; usually only SIM2 receive is affected — calls/data otherwise fine. |

---

## Un‑brick / go back to stock Samsung
You can always return to 100% stock (this is why it can't hard‑brick):
1. Download full stock firmware with Frija (Part 2) — keep all 4 files.
2. Download mode → Odin → **BL** = `BL_…`, **AP** = `AP_…`, **CP** = `CP_…`, **CSC** = `CSC_…` (full CSC = wipe).
3. Start → wait for PASS → reboots into stock One UI.
(Knox stays tripped — that's permanent — but the phone is fully functional Samsung again.)

---

## FAQ
- **Will banking apps / Google Pay work?** Maybe. They use **Play Integrity**, which fails on a rooted/custom‑ROM/unlocked device by default. You can often pass **BASIC + DEVICE** integrity with **Magisk + Zygisk + [PlayIntegrityFork](https://github.com/osm0sis/PlayIntegrityFork)** + DenyList (+ `Shamiko` to hide root). **STRONG** integrity (some strict banks) needs hardware attestation and is very hard on an unlocked bootloader. *(Setup not covered here yet.)*
- **Is it rooted after the GSI flash?** No — the GSI ≠ root. Do Part 8 (Magisk).
- **Can I keep my data?** No. The flash wipes (encryption is incompatible).
- **Does this need TWRP?** No — TWRP doesn't work on the A05s. Everything is Odin + scripts.
- **OTA updates?** No Samsung OTAs. Update by flashing a newer GSI (repeat Parts 4–7).

## Credits
- [PixelOS GSI — MisterZtr](https://github.com/MisterZtr/PixelOS_gsi) · [TrebleDroid](https://github.com/TrebleDroid/treble_experimentations) · [phhusson](https://github.com/phhusson/treble_experimentations)
- [lpunpack_and_lpmake — LonelyFool](https://github.com/LonelyFool/lpunpack_and_lpmake)
- [Magisk — topjohnwu](https://github.com/topjohnwu/Magisk) · [PlayIntegrityFork — osm0sis](https://github.com/osm0sis/PlayIntegrityFork)
- The XDA Galaxy A05s community.

## License
[MIT](LICENSE). Provided **as‑is** — flashing modifies firmware and carries real risk (data loss, permanent Knox trip). **You are solely responsible for your device.**
