# pk's OS · iOS aur Android apps — kya chalta hai, kyun, aur kaam kaise nikalein

Chhota jawab:
* **Android `.apk`** — *possible* hai, par apne kernel + waydroid ke saath (abhi default me band).
* **iOS (`.ipa`)** — native **impossible** hai; 3 practical raaste hain (web wrapper,
  macOS guest + Xcode Simulator, Darling sirf macOS binaries ke liye).
  `pk-run` isliye `.ipa` par crash/hang nahi karta — reason + route print karta hai.

---

## 1. iOS apps kyun nahi chalti (technical, 3 line)

| layer | iOS app ko kya chahiye | Linux par |
|---|---|---|
| binary format | Mach-O arm64, XNU kernel loader | Linux kernel Mach-O load nahi karta (binfmt aur `Darwin` translation layer ke bina) |
| frameworks | UIKit / SwiftUI / CoreAnimation / Foundation (closed source) | inka koi open port nahi; Darling me bhi UIKit nahi hai |
| runtime contract | codesign + entitlements + sandbox, `libsystem`, mach ports | Apple ka signing chain ke bina iOS khud bhi install nahi karta |

Search/koi shortcut se ye nahi badalta: 2026 tak Linux par **iOS app runtime** exist nahi
karta (Simulator bhi macOS ka hissa hai — `Xcode.app` Apple EULA ke tehat sirf Apple hardware).

## 2. `pk-ios` — jo kaam karta hai wahi, ek command me

```sh
pk-ios why                     # ye page ka saar (terminal me)
pk-ios doctor                  # machine me kya-kya hai (runtime, unzip, browser, qemu, kvm, darling)
pk-ios info ./App.ipa          # .ipa khol ke: bundle id, display name, executable, arch, min iOS
pk-ios extract ./App.ipa ~/apps # Payload/*.app nikaal do (icons/nibs/documents padhne ke liye)
pk-ios web https://icloud.com [naam]   # iOS-only *service* ko desktop app bana do
pk-ios mac-guest [--run]              # QEMU macOS guest + Xcode Simulator recipe likhta/chalata hai
pk-ios darling [--setup]              # macOS (x86_64/arm64) console binaries; iOS NAHI
```

### 2a. Web wrapper (sabse practical)
`pk-ios web <url> [name]` → `/opt/pk/apps/bin/<name>` launcher + `.desktop` banata hai jo
browser ko kiosk me us URL par kholta hai (firefox-esr/epiphany/chromium/surf me se jo ho).
iCloud/Netflix-banking-jaisi "iOS-only" cheezein isi se chal jaati hain; browser na ho to
`pk-get install -y firefox-esr` bol deta hai (rc 73, hang nahi karta).

### 2b. macOS guest + Xcode Simulator (asli iOS runtime chahiye to)
```sh
pk-ios mac-guest                     # /root/pk-ios-mac.sh banata hai
sh /root/pk-ios-mac-guest… --run <macOS.iso>    # ya: pk-vm run macos --cdrom=… --uefi --vnc=:1
```
Zarooratein: runtime me `qemu-system-x86` + `ovmf` (`pk-get install -y qemu-system-x86 ovmf`),
disk 60-80 GB, RAM 8 GB, aur legal macOS image (Apple license: Apple hardware par hi allowed).
Guest ke andar Xcode → Settings → Platforms → iOS Simulator; `.ipa`/project wahan run hota hai.
Recipe ka maintained source: `github.com/kholia/OSX-KVM`.
**Status:** is repo me helper + script hai, par sandbox me macOS guest boot karke test
nahi kiya gaya (legal image + 8 GB RAM + KVM chahiye; yahan KVM nahi hai).

### 2c. Darling (aur jo nahi karta)
Darling = Linux par macOS userspace translator. Console/small GUI **macOS** binaries
chala sakta hai; **iOS/.ipa nahi** (UIKit/CoreAnimation usme bhi nahi hain). Linux kernel
module (`darwin.ko`) chahiye → `make kernel` + build (~ghanton ka compile).
`pk-ios darling --setup` dependencies install karta hai; build steps print karta hai.
**Status:** untested here (by design; honest flag ke saath).

## 3. Android: `pk-android`

```sh
pk-android doctor        # binderfs/ashmem/kvm/waydroid/runtime ka haal + blockers
pk-android enable        # /dev/binderfs mount karne ki try (kernel support ho to)
pk-android install x.apk  # extract + (ready ho to) waydroid app install
pk-android list          # extracts + waydroid status
pk-android kernel-frag    # make kernel me ye config lines add karo
```

Blocker (is machine pe): shipped kernel me `CONFIG_ANDROID_BINDERFS` nahi →
`pk-android doctor` exactly yehi kehta hai. Do raaste:
1. **apna kernel**: `make kernel` (docs/KERNEL.md) + `pk-android kernel-frag` ki lines, phir
   `make clean-rootfs && make iso PK_KERNEL=… PK_MODULES=…` → `pk-android enable` mount ho jaayega.
2. **guest**: Android-x86 / Waydroid-ka-apna-container — `pk-vm new droid --size=20G` +
   Android-x86 ISO (guest ke andar sab chal jaata hai, host kernel par depend nahi karta).

## 4. Test/QA me kya prove hai

| cheez | kaise | status |
|---|---|---|
| `.ipa` pe honest dispatch (crash nahi) | `pk-run --selftest` → `### PK: APP-IOS-DIAG-OK ###` | ✅ QA (stage 7) |
| `.apk` pe honest dispatch | `APP-APK-DIAG-OK` | ✅ QA |
| `.exe`/`.msi` → Wine | `APP-EXE-OK` (tiny: stub wine; real runtime: **wine-8.0** se dispatch) | ✅ QA (stage 7, dono modes) |
| AppImage extract+AppRun | `APP-APPIMAGE-OK` (selftest sample khud banata hai) | ✅ QA |
| `.jar` (JRE ho to) | `APP-JAR-OK` | ✅ QA (stub java); real JRE = `pk-get install -y default-jre-headless` |
| `.rpm` | `APP-RPM-DIAG-OK` | ✅ QA |
| `pk-check` | stage 8 me `CHECK-OK` (0 fail) | ✅ QA |
| desktop session (Xvfb fallback + xterm round-trip) | `DESKTOP-OK`, `GUI-X-OK`, `GUI-XCLIENT-OK`, `GUI-APP-OK` | ✅ QA stage 8 (`make gui-test`) |
| Android waydroid / binderfs | — | ❌ is sandbox me kernel rebuild possible nahi (30-90 min, phir bhi nested VM me binder test flaky) |
| macOS guest / iOS Simulator | — | ❌ test nahi kiya (legal image + KVM + 8 GB chahiye) |
| Darling | — | ❌ test nahi kiya |

## 5. Filhaal ka "best" combo (aapke pendrive test ke liye)

```
pkos-1.0-apps.iso  →  Linux apps (apt) + Wine se Windows apps        ✓ boot + apps ready
pk-desktop         →  weston (KMS) ya Xvfb fallback; xterm/htop/firefox --gui
iOS                →  pk-ios info file.ipa / pk-ios web <url> / pk-ios mac-guest
Android            →  pk-android doctor  (kernel me binderfs na ho to "blocked" saaf dikhega, hang nahi)
```
