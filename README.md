# Samsung Galaxy A05s (SM-A057F) → PixelOS (Android 14 GSI) + Root

Install a clean **Google/Pixel-style Android (GSI)** on the Samsung Galaxy A05s, fully replacing One UI — then optionally root with Magisk.

The A05s has **no working TWRP and no fastboot**, so the usual "fastboot flash system" GSI method does **not** work. The only way is to **repack the stock `super` partition** (swap `system` for the GSI, keep the Samsung vendor/product drivers) and flash it with **Odin**. This repo documents that, with the non-obvious gotchas solved, plus scripts that automate the repack.

> Verified working: **PixelOS `treble_arm64_bN-14.0` GSI** boots on **SM-A057F** (build `A057FXXSDDZB3`, Android 15 stock base), hardware (Wi‑Fi / calls / camera) functional via the kept Samsung vendor.

---

## ⚠️ Read this first

- **This wipes all data** and **trips Knox** (`warranty_bit 0 → 1`, permanent — Samsung Pay / Secure Folder / some banking features die, warranty void).
- **Back up first.**
- **You can't hard-brick** this way (we never touch the bootloader/modem) — worst case is a bootloop, recoverable by re‑flashing stock firmware in Odin. But **do this at your own risk.** Not responsible for your device.
- Works on the **international SM‑A057F** (Exynos/Qualcomm intl) where **OEM unlocking** exists. **US Snapdragon carrier models have no OEM unlock → not possible.**

---

## How it works (the transplant)

A GSI is **only the `system`** (the OS/UI + Google apps). It has **no device drivers**. On the A05s, `system` + `vendor` + `product` + `odm` etc. all live inside **one `super` partition** (dynamic/logical partitions).

So we:
1. Take the stock `super` from the firmware,
2. **`lpunpack`** it into its partitions,
3. Replace **only `system`** with the PixelOS GSI (keep `vendor`/`product`/`odm`/`system_ext`/`*_dlkm` → drivers keep working),
4. **`lpmake`** a new `super`,
5. Disable AVB (`vbmeta`) so the bootloader accepts the modified `super`,
6. **Odin-flash** the new `super` + disabled `vbmeta`,
7. Factory reset (so the new OS can format `/data`).

---

## Prerequisites

- The phone, **bootloader unlocked** (see step 1). Battery > 50%.
- **A Linux box** (or WSL/VM) for the repack — needs: `clang`, `lz4`, `simg2img`/`img2simg` (`android-sdk-libsparse-utils`), `e2fsprogs`, `git`, `python3`, ~40 GB free scratch.
- **Windows + [Odin3](https://odindownload.com/)** (v3.13.x+) + Samsung USB driver — for flashing.
- **[Frija](https://github.com/SlackingVeteran/frija)** (Windows) to download the exact stock firmware.
- The GSI: **[PixelOS GSI by MisterZtr](https://sourceforge.net/projects/misterztr-gsi/files/PixelOS/)** — use `arm64_bN` (the **`b`** = System‑as‑Root, correct for A05s), **non‑vndklite** (vndklite bootloops). Or any phh/TrebleDroid `arm64 b` GSI.

> **Do not** download firmware or the GSI from this repo — get them from the official sources above (copyright + size).

---

## Steps

### 1. Unlock the bootloader
1. Add a Google + Samsung account, connect to internet once (so OEM unlock un-greys), wait if needed.
2. Settings → About phone → Software info → tap **Build number** 7× → **Developer options** → enable **OEM unlocking** + **USB debugging**.
3. Power off. Hold **Vol Up + Vol Down**, **plug in USB** (to a PC) → unlock prompt → **long‑press Vol Up** → **Vol Up** to confirm → it wipes + unlocks.
4. Finish setup, re-enable Developer options + USB debugging.
   Verify: `adb shell getprop ro.boot.flash.locked` → `0`, `ro.boot.verifiedbootstate` → `orange`.

### 2. Download stock firmware (Frija, Windows)
- Frija → **Manual** → Model `SM-A057F`, your **CSC/region**, your **IMEI** (or serial) → Check Update → Download.
- You get a zip with `BL_…`, `AP_…`, `CP_…`, `CSC_…`, `HOME_CSC_…` (`.tar.md5`). Copy the **AP** + **CSC** to your Linux box.

### 3. Build the repack tools (Linux)
```bash
sudo apt-get install -y clang lz4 android-sdk-libsparse-utils e2fsprogs git
scripts/01-build-tools.sh      # builds lpunpack + lpmake (+ lpdump)
```

### 4. Repack `super` with the GSI (Linux)
```bash
scripts/02-repack.sh  AP_A057F….tar.md5  PixelOS_treble_arm64_bN-14.0-….img.xz  ./work
```
It extracts the stock `super`, reads the exact layout with `lpdump`, swaps `system` → GSI, and `lpmake`s a new `super.img`. **It auto-derives** device‑size / group / metadata‑slots from the stock super — no hardcoding.

### 5. Build the Odin tar (Linux)
```bash
scripts/03-pack-odin.sh  ./work  AP_A057F….tar.md5
```
Produces **`work/AP_PE.tar`** = `super.img.lz4` (the GSI super) + `vbmeta.img.lz4` (AVB disabled), in **Samsung's exact lz4 format** (`--content-size`, see Gotchas).

### 6. Flash (Odin, Windows)
- Phone in **Download mode** (`adb reboot download`, or Vol Up+Down + USB). Odin **ID:COM** turns blue.
- **AP** = `AP_PE.tar`
- **CSC** = the stock **`CSC_…tar.md5`** (the **CSC**, *not* HOME_CSC → wipes data — required)
- **BL / CP** = leave empty
- Options: defaults. **Start** → wait for **PASS** (AP is ~4.5 GB, takes minutes — don't unplug).

### 7. Factory reset (mandatory)
First boot lands in Samsung recovery: *"Can't load Android system… `init_user0_failed`"* — that's **expected** (old encrypted `/data`). In recovery: **Factory data reset** → confirm → **Reboot system now**. First PixelOS boot is slow (~5–10 min). 🎉

### 8. (Optional) Root with Magisk
```bash
# extract stock init_boot from the AP, patch with Magisk app on the phone, then:
scripts/04-pack-initboot.sh  ./work  magisk_patched-XXXXX.img   # -> work/AP_root.tar
```
- Install **[Magisk](https://github.com/topjohnwu/Magisk/releases)** APK → Install → **Select and Patch a File** → `init_boot.img` → produces `magisk_patched-*.img`.
- Pack it (script above), Odin **AP** = `AP_root.tar`, **all other slots empty** (no wipe), Start → reboot → rooted.

---

## Gotchas / Troubleshooting (the stuff nobody documents)

| Symptom | Cause | Fix |
|---|---|---|
| Odin: **`FAIL! LZ4 is invalid`** | Default `lz4` omits the uncompressed-size header field Odin requires | Compress with **`lz4 -B6 --content-size`** (magic `04 22 4d 18 6c …`). The scripts do this. |
| New `super` won't boot / dm-verity corruption | AVB still enforced | Flash a **`vbmeta` with verity+verification disabled** (byte at offset 123 → `0x03`). Scripts do this. |
| Recovery loop: **`init_user0_failed` / "data may be corrupt"** | New OS can't read old encrypted `/data` | **Factory data reset** in stock recovery. |
| `lpmake` wrong size / no boot | Used textbook `--metadata-slots 1` | A05s stock super uses **`--metadata-slots 2`** — the script reads the real value from `lpdump`. |
| GSI bootloops | Wrong variant | Use **`arm64 b`** (System‑as‑Root), **non‑vndklite**. |
| GSI too big for the group | PixelOS system > free space in `super` group | Shrink the GSI: `e2fsck -E unshare_blocks system.img; resize2fs -M system.img` before `lpmake`. |
| build of lpmake fails (`std::find`) | new libstdc++ needs `<algorithm>` | `01-build-tools.sh` patches the liblp sources. |

---

## Credits
- [PixelOS GSI — MisterZtr](https://github.com/MisterZtr/PixelOS_gsi) · [TrebleDroid](https://github.com/TrebleDroid/treble_experimentations) · [phhusson](https://github.com/phhusson/treble_experimentations)
- [lpunpack_and_lpmake — LonelyFool](https://github.com/LonelyFool/lpunpack_and_lpmake)
- [Magisk — topjohnwu](https://github.com/topjohnwu/Magisk) · [PlayIntegrityFork — osm0sis](https://github.com/osm0sis/PlayIntegrityFork)
- The XDA A05s community.

## License
MIT — see [LICENSE](LICENSE). Provided as-is; you are responsible for your device.
