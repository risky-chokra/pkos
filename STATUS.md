# pk's OS · STATUS (aaj kya hua, kahaan tak pahunche)

> Ek-file recap. Detail chahiye to `README.md` + `docs/` (khaas kar
> **docs/PENDRIVE.md** — aapke real pendrive test ka sheet).

## 1. Kya bana

Apna chhota Linux OS jo **x86_64 PC pe live USB se boot hota hai aur permanent install
bhi ho jaata hai** — koi distro installer nahi, sab isi repo se build.

```
busybox-static + squashfs (read-only /) + overlayfs (upper = RAM / PK-PERSIST partition)
+ custom initramfs /init (boot media khud dhoondhta hai)
+ hybrid ISO (grub-mkrescue: BIOS + UEFI, dd-able)
+ /sbin/pk-install  (GPT: bios_grub + ESP + ext4, GRUB i386-pc + x86_64-efi, fstab by UUID,
                     non-root user, app runtime copy)
+ App Runtime       (/opt/pk = Debian squashfs + rw overlay -> apt/dpkg/Wine/GUI apps)
+ pk-run dispatcher (ELF · script · .deb · .rpm · AppImage · .jar · .exe/.msi[Wine] · .ipa · .apk)
+ live kit          (pk-check · pk-desktop · pk-keymap · pk-wifi · pk-ios · pk-android)
+ boot hooks        (net+DHCP, dropbear SSH, persistence, runtime, keymap, check, desktop)
```

## 2. Aaj ka round (iOS + "sab add karo sahi se")

| cheez | status |
|---|---|
| `make doctor` | sab ready (0 missing) |
| `make iso` | `build/pkos.iso` = **87 629 824 bytes (84 MiB)** |
| `make test` (QEMU, **8 stages**) | **QA PASS 62 checks ok**, rc=0 |
| `make gui-test` (stage 8 + desktop) | **QA PASS 19 checks ok** — GUI bhi asli verify |
| `make apps-iso` | `build/pkos-apps.iso` = **700 MiB** (App Runtime + apt + Wine + weston/Xvfb andar) |
| `make iso REPRODUCIBLE=1` | do alag builds ke `/live/pk.sqfs` + `/boot/pk-initrd` **sha256 same** ✓ |
| git | **3 commits** (sandbox reset ke baad dobara init), **78 files tracked**, tree clean |
| aapke liye files | `/home/user/pkos-1.0.iso`, `pkos-1.0-apps.iso`, `pkos-1.0*.manifest.txt`, `pkos-1.0.bundle`, `pkos-1.0-src.tar.gz`, `pkos-1.0.iso.sha256` — sab `sha256sum -c` se **OK** |
| is round me naya | `pk-check`, `pk-desktop`, `pk-keymap`, `pk-wifi`, `pk-ios`, `pk-android`, `tools/verify-usb.sh`, `scripts/manifest.sh`, `tools/restore-from-iso.sh`, QA **stage 8**, `docs/PENDRIVE.md`, `docs/IOS-ANDROID.md` |

### QA stages (sab pass)

| stage | proof |
|---|---|
| 1 live boot | grub → kernel → initrd → squashfs+overlay → init, `DEPS-OK`, base ro, installer tools |
| 2 headless install | `INSTALL-OK`, `INSTALL-DONE rc=0`, installed tree + `root=UUID=` + root hash (sha-5) host se verify, DHCP on |
| 3 installed boot | apne GRUB se boot, `PASSWD-OK`, `LOGIN-REQUIRED` (autologin nahi) |
| 4 toram | image RAM me copy, media reuse ke saath boot |
| 5 UEFI (OVMF) | GPT/ESP path |
| 6 persistence + net + ssh | `PERSIST-WROTE`/`PERSIST-KEPT`, `upperdir=/mnt/persist/…`, `NET-OK (ip)`, `SSH-OK` |
| 7 app runtime | runtime attach, `pk-run` battery (ELF/script/.deb/.exe/.apk/Mach-O/**.ipa**/AppImage/jar/rpm), chroot exec, doosri boot par re-attach, host se rw-img verify — **14 checks** |
| 8 pendrive kit | kit ISO (runtime andar) → `pk-check` **0 FAIL**, `pk-keymap`, headless install with `--user` + runtime copy (`/var/lib/pk`), installed boot par **`mode=rw-image`** persistence — **15 checks**; `PK_TEST_GUI=1` se +4: `DESKTOP-OK`, `GUI-X-OK`, `GUI-APP-OK` (xterm), `GUI-XCLIENT-OK` (xdpyinfo) |

## 3. Is round me jo bug pakde aur fix kiye

1. **pk-x ka jhootha success** — x-env likh dena = "session chal gaya" (weston mar bhi
   gaya ho to bhi). Ab **socket ka wait** (`$RT/run/pk-x/wayland-1` / `/tmp/.X11-unix/X0`)
   aur weston fail hone par **Xvfb fallback** (VM me yahi fallback chala ✓ proof).
2. **XDG_RUNTIME_DIR galat namespace** me export ho raha tha (`/opt/pk/run/pk-x`, host path)
   → chroot ke andar client ko socket mil hi nahi sakta tha (weston-terminal turant marta
   tha). Ab in-chroot path (`/run/pk-x`) + `PK_XDG_RUNTIME_HOST` ✓
3. **busybox `dd` me `conv=sparse` nahi** → installed system ki `pk-runtime-rw.img` kabhi
   banti hi nahi thi (silent). Fix: `mk_sparse()` (truncate, warna 1-byte seek) — ab
   installed boot par `mode=rw-image (/var/lib/pk/pk-runtime-rw.img)` ✓ QA-proved.
4. **`conv=fsync` bhi busybox dd me nahi** → pk-check ka speed test hamesha fail. Fix: alag `sync`.
5. **live image me `libgcc_s.so.1` missing** tha → `mksquashfs` "pthread_exit" par abort;
   isse selftest ka AppImage case fail ho raha tha. Fix: naya `config/live-libs.txt`
   (ldd jo nahi batata wo libs) + `mksquashfs` live image me ✓ ab `APP-APPIMAGE-OK`.
6. **overlay ka `bin/` `/bin` me jaata hai, `/usr/bin` me nahi** — `[ -x /usr/bin/pk-x ]`
   type guards chup-chaap fail (pk-check ka GUI block, pk-boot ka keymap block).
   Fix: `command -v`.
7. **SOURCE_DATE_EPOCH + `-mkfs-time`** → mksquashfs 4.6 "can't be used at the same time"
   se fatal (build hi toot raha tha). Fix: version dekh ke hi flag (4.4+ env khud honor
   karta hai) ✓
8. **live password ka random salt** payload hash ko todta tha → `SOURCE_DATE_EPOCH` ho to
   salt deterministic (`sha256("pk-live-<epoch>")`) ✓ ab squashfs/initrd byte-stable.
9. `pk-check` me disk size ganit galat (`/2048/512`), wifi iface detection (glob me
   `/wireless` suffix nahi), `--apps` rc ignore karta tha — sab fix.
10. **Sandbox workspace reset** (teesri baar): `.git/`, `rootfs/`, badi files gayab.
    Ab `tools/restore-from-iso.sh` se **ek command me restore** (ISO hi backup hai) —
    36 files wapas, `sh -n` + byte-compare se verified.

## 4. iOS / Android — kya kiya (aur imaandaar limit)

* `pk-run` ab `.ipa` **detect** karta hai (zip + `Payload/`) aur crash/hang kiye bina
  3 asli wajah + 3 raaste batata hai → `### PK: APP-IOS-DIAG-OK ###` (QA me pass).
* `pk-ios` : `why` · `doctor` · `info file.ipa` (fat/Mach-O arch + Info.plist keys) ·
  `extract` · `web <url>` (kiosk launcher, iOS-only *service* desktop app ban jaati hai) ·
  `mac-guest` (QEMU macOS + Xcode iOS Simulator recipe likhta hai) · `darling`
  (macOS binaries; **iOS nahi** — UIKit Darling me bhi nahi).
* `pk-android` : `doctor` (binderfs/ashmem/kvm/waydroid ka haal), `enable`, `install x.apk`,
  `kernel-frag` (apne kernel ke liye exact config).
* Limit (unchanged, physics+EULA): iOS app native Linux par **nahi** chal sakti. Is sandbox
  me macOS guest / Darling / binderfs kernel **test nahi** kiye (KVM nahi, 8 GB RAM nahi,
  kernel build 30-90 min). `docs/IOS-ANDROID.md` me poora hisaab.

## 5. Aapke PC pe ab kya karna hai (emulator → pendrive → install)

```sh
sudo apt-get install -y build-essential busybox-static cpio squashfs-tools xorriso mtools \
  grub-pc-bin grub-efi-amd64-bin grub2-common dosfstools parted e2fsprogs util-linux kmod \
  linux-image-amd64 dropbear ovmf qemu-system-x86 kbd
sudo apt-get install -y debootstrap                      # App Runtime ke liye

cd pkos
make doctor && make iso && make test        # ~15 min, 62 checks
sudo make runtime-desktop && make apps-iso # GUI+wine wala runtime, phun 700 MiB ISO
make kit                                    # iso + apps-iso + manifests + bundle (ek saath)

lsblk && sudo dd if=build/pkos-apps.iso of=/dev/sdX bs=4M status=progress oflag=sync
tools/verify-usb.sh /dev/sdX build/manifest-apps.txt     # host se: sahi likha?
```

Pendrive se boot (Secure Boot OFF) → menu me **`k`** = hardware check, **`g`** = desktop.
Live shell me:

```sh
pk-check --save        # report: /run/pk/check.txt  (FAIL 0 hona chahiye)
pk-run --selftest      # apps battery → ### PK: APPS-OK ###
pk-desktop             # weston/Xvfb session + terminal
pk-get install -y htop # (net: pk_net=dhcp) — apt andar se
pk-install --target=auto --user=ramesh --user-password=SomePw   # permanent
```

Fail ho to **bhej dena**: `/run/pk/check.txt`, `dmesg | grep PK`, `build/manifest.txt`.

## 6. Abhi bhi nahi hua (taaki surprise na ho)

- **Real hardware pe boot** — ye sab QEMU me prove hua hai; terahz GPU/KMS/USB stick par
  test aapke haath me hai (isliye `pk-check` bana).
- **Wi-Fi association** — `pk-wifi` likha hai, par yahan wireless hardware nahi, to
  `status` ke alawa kuch test nahi hua (documented experimental).
- **Android**: binderfs wala kernel build + Waydroid end-to-end **not tested** here.
- **macOS guest / Xcode Simulator / Darling**: helper + docs ✓, par asli boot test nahi (license + KVM + RAM chahiye).
- **GUI apps ka asli frame test**: xterm/xdpyinfo round-trip ✓, par weston par
  firefox-chalao-aur-screenshot type ka visual test nahi; `/dev/dri` wale real GPU par hi hoga.
- **LUKS encrypted install** nahi (initramfs me cryptsetup chahiye — alag kaam).
- **Secure Boot signing** nahi (unsigned GRUB; BIOS me OFF).
- **Non-root user ka sudoers**: group me daalte hain, par runtime/`sudoers` file me
  NOPASSWD entry nahi (busybox `sudo` package runtime me aayega to `pk-get install -y sudo`).
- Console keymaps: builder par Debian `kbd` me `/usr/share/keymaps` nahi hai → `pk-keymap`
  ka console part skip (GUI `setxkbmap` chalta hai). Jo distro kmaps degi, wo auto-copy ho jaate hain.
- **`pk-vm` se guest boot** abhi tak kabhi chala ke nahi dekha (helper + docs only).
- Git history (reset se pehle ke 12 commits) wapas nahi aa sakti; ab 3 clean commits.
