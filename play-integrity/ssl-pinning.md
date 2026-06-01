# SSL / TLS pinning bypass (for analysing your OWN app traffic)

To inspect the HTTPS traffic of an app on your own rooted device (debugging,
security research), you need to (1) get your proxy's CA trusted as a **system**
CA, and (2) defeat the app's certificate **pinning**. Tools, current as of
June 2026:

> **Keep this a separate device state.** A running `frida-server`, an injected
> CA, and re-signed APKs are each independently detectable by banking RASP
> (Talsec/freeRASP/Appdome) **even when Play Integrity passes**. Never run
> interception during real banking, and prefer a throwaway/secondary account
> for analysis.

## 1. Trust your proxy CA as a system CA (Android 14)
On Android 14 the system CA store lives in the immutable Conscrypt **APEX**, so
the old `/system/etc/security/cacerts` push no longer works. Use a Magisk module
that bind‑mounts your user CA into the APEX store:

- **MoveCertificate** — <https://github.com/ys1231/MoveCertificate> (freshest, A7–16)
- or **AlwaysTrustUserCerts** — <https://github.com/NVISOsecurity/AlwaysTrustUserCerts>
- or **cert-fixer** — <https://github.com/pwnlogs/cert-fixer>

Install your proxy CA (Burp / mitmproxy / HTTP Toolkit) as a *user* cert first,
then the module promotes it to system.

## 2. Defeat pinning at runtime with Frida
- Run `frida-server` on the device. The easiest persistence is the
  **magisk-frida** module — <https://github.com/ViRb3/magisk-frida> (match its
  version to your host `frida`/`objection`). **Rename the server binary** and use
  a non‑default port — RASP detects the default `frida-server` name.
- Use the **HTTP Toolkit unpinning script suite** (the current gold standard;
  covers OkHttp, Java + GMS Conscrypt, native BoringSSL, certificate
  transparency): <https://github.com/httptoolkit/frida-interception-and-unpinning>
  Spawn the app so hooks land before pinning runs:
  `frida -U -f <pkg> -l <scripts...> --no-pause`
- Quick first try: **objection** — <https://github.com/sensepost/objection> —
  `objection -g <pkg> explore` then `android sslpinning disable`.
  Match objection's Frida major to the server. Note Frida 17.x broke
  `objection patchapk`; pin the gadget (`--gadget-version 16.7.19`) if you use it.

## 3. Flutter apps (a lot of fintech is Flutter)
Generic unpinning fails on Flutter/Dio because pinning is in statically‑linked
BoringSSL (`ssl_verify`). Use the dedicated script:
- **disable-flutter-tls-verification** — <https://github.com/NVISOsecurity/disable-flutter-tls-verification>

## What to avoid
- **JustTrustMe / TrustMeAlready** (Xposed): stale/archived, no A14 hooks.
  `hang666/JustTrustMePro` is a maintained successor for soft OkHttp pinning, but
  Frida is more reliable on hardened apps.
- **apk-mitm / `objection patchapk`** for the *real* app you depend on: they
  re‑sign the APK (new signature) which breaks Play‑Store updates and trips
  signature checks. Fine for a one‑off analysis copy; keep the original APK.

## Dead end to know about
You generally **cannot** run active Frida‑MitM against the same app at the same
time you want it to pass integrity / behave normally — treat "inspect" and
"use normally" as two separate sessions.
