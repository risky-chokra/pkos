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

## 1c. Modern-desktop spec pass (aaj ka doosra round) → `docs/ARCHITECTURE.md`

Aapki 7-section requirement list ko item-by-item map kiya (kaun deliver karta hai + verify
command + status). Code me jo **add** hua:

| spec item | kya bana | QA proof |
|---|---|---|
| 1.3 interactive foreground priority | `pk-tune desktop`: cgroup v2 `pk.slice/apps` = `cpu.weight 200`, `bg` = 20, `sched_autogroup=1`, governor powersave + EPP; `pk-desktop` compositor + `pk-desktop app` clients ko apps slice me daalta hai; manual `pk-tune fg|bg <pid|name>` | `TUNE-REPORT-OK` ✓ |
| 1.4 P/E (heterogeneous) awareness | `pk-tune hybrid`: `cpu_capacity` se big(≥900)/little(≤700) split → `cpuset.cpus` (daemons little par). VM me `uniform` aata hai — expected | ✓ |
| 2.3 dynamic HiDPI + multi-monitor | `pk-desktop outputs` (DRM se modes), `scale 2 [OUT]`, `mode`, `transform`, `arrange`, `restart` → `weston.ini` runtime me likhta hai, reboot nahi | ini-merge test ✓ |
| 3.1 demand paging + swap | `pk-tune swap [MB]` (holes-free swapfile → mkswap → swapon; sparse swapfile valid nahi hota) | ✓ |
| 3.3 journaling | installer `dumpe2fs` se ext4 `has_journal` verify karta hai | `INSTALL-JOURNAL-OK` ✓ (stage 2) |
| 4.2 plug & play drivers | **`S15mdev` hook**: `mdev -s` coldplug + `uevent mdev` netlink listener + `hotplug.sh` me `modprobe $MODALIAS`. Pehla version `/proc/sys/kernel/hotplug` par depend tha aur silent exit karta tha (VM test me pakda) → ab listener wala sahi raasta | `MDEV-OK (uevent listener + coldplug, rc=0)` ✓ VM me verified |
| 5.3 app sandboxing | `pk-run --sandbox` = user/mnt/pid/ipc/net namespaces + tmpfs over `/root /home /mnt/persist` + ro remount try; kernel user-ns na de to `APP-SANDBOX-UNAVAIL` (boot/app kabhi nahi rokta) | `APP-SANDBOX-OK` ✓ (leak assert ke saath) |
| 5.4 root of trust (partial) | `mk-iso` → `/live/pk.sqfs.sha256` + `/live/pk-runtime.sqfs.sha256` + ISO-root `SHA256SUMS`; init `pk_verify=1` par hash match (warn) / `pk_verify=require` par **boot rok deta hai** | `VERIFY-OK` ✓ (stage 1) |
| 6.2 foreign-arch binaries | `pk-binfmt status|register|unregister` (binfmt_misc handlers `pk-aarch64/arm/riscv64/ppc64le/s390x`) + `pk-run` e_machine(offset 18) parse → qemu-user se dispatch; `binfmt_misc`+`cpufreq` modules live image me | `ARCH-DISPATCH-OK` ✓ |
| 7.1/7.2 net + IPC | `pk-tune net` (rmem/wmem 16 MiB, `fq`, BBR, TCP_FASTOPEN, jumbo) + `pk-tune ipc` (`/dev/shm`, POSIX mqueue, `io_uring_disabled=0`) | ✓ |
| security observability | `pk-tune report`: ASLR/`ptrace_scope`/lockdown/CPU-vuln count/TPM device/hotplug/swap/cgroup rows | ✓ |

**Full 8-stage suite: QA PASS 64 checks ok** (stage 2 = 8, stage 7 = 14, stage 8 = 19 ✓) ·
asli 617 MiB desktop runtime ke saath `make gui-test`: **QA PASS 22 checks ok** (GUI + tune +
binfmt + arch sab green) · GitHub release ke 7 assets ke sha256 = local files se **MATCH** ✓.
🚫 jo is design/hardware par possible nahi (reason ke saath doc me): Secure Boot signing +
TPM measured boot ka poora round, VBS (type-1 hypervisor neeche chahiye — alternative:
`pk-vm` se app-in-VM), LSM/RBAC policy, DirectStorage GPU-P2P, kernel EAS integration,
iOS native (Mach-O + closed UIKit). Roadmap: `docs/ARCHITECTURE.md` §9.

## 2. Aaj ka round (iOS + "sab add karo sahi se")

| cheez | status |
|---|---|
| `make doctor` | sab ready (0 missing) |
| `make iso` | `build/pkos.iso` = **87 633 920 bytes (84 MiB)** (delivered `pkos-1.0.iso` isi size ka) |
| `make test` (QEMU, **8 stages**) | **QA PASS 64 checks ok**, rc=0 (+6 is round: verify, mdev, tune, binfmt, journal, sandbox/arch) |
| `make gui-test` (stage 8 + desktop runtime) | **QA PASS 22 checks ok** — GUI + pk-tune + pk-binfmt + foreign-arch ✓ |
| `make apps-iso` | `build/pkos-apps.iso` = **700 MiB** (App Runtime + apt + Wine + weston/Xvfb andar) |
| `make iso REPRODUCIBLE=1` | do alag builds ke `/live/pk.sqfs` + `/boot/pk-initrd` **sha256 same** ✓ |
| git | **3 commits** (sandbox reset ke baad dobara init), **78 files tracked**, tree clean |
| aapke liye files | `/home/user/pkos-1.0.iso` (87 633 920 B, sha256 `f1b5c1f3…`) ✓ persist + verified, `pkos-1.0-manifest.txt` + `pkos-1.0-apps-manifest.txt`, `pkos-1.0-src.tar.gz`, `pkos-1.0.bundle`, `pkos-1.0.iso.sha256` (4 entries, `sha256sum -c` OK). **`pkos-1.0-apps.iso` (700 MiB) size cap se persist nahi hota** -> `sudo make runtime-desktop && make apps-iso` se 6-8 min me dobara |
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

## 2a. GitHub pe push ho gaya ✓

| | |
|---|---|
| repo | https://github.com/risky-chokra/pkos (public, default branch `main`, 78 files) |
| tag | `v1.0.0` -> commit `9af942b` |
| release | https://github.com/risky-chokra/pkos/releases/tag/v1.0.0 |
| assets | `pkos-1.0.iso` (87 633 920 B) + `pkos-1.0-manifest.txt` + `pkos-1.0-apps-manifest.txt` + `pkos-1.0.iso.sha256` + `pkos-1.0-src.tar.gz` + `pkos-1.0.bundle` |
| verify | release se ISO dobara download karke `sha256sum` milaya: `f1b5c1f3…` **byte-identical** ✓ |
| not in release | 700 MiB apps+wala ISO (bada asset) — `sudo make runtime-desktop && make apps-iso` se ban jaata hai |

## 2b. Reset ke baad restore (aapke PC pe bhi wahi 2 command)

```sh
git clone https://github.com/risky-chokra/pkos.git pkos   # (ya bundle se: git clone pkos-1.0.bundle pkos)
cd pkos && make doctor && make iso    # toolchain chahiye: apt list docs/BUILD.md me
sudo make runtime-desktop && make apps-iso   # 700 MiB wala apps+GUI ISO dobara
```
Sandbox me bade files (700 MB ISO, `build/`) persist nahi hote — chhote (src tar,
bundle, manifests, base ISO) persist hote hain, isliye wahi backup hain.

### 2c. Aapke VirtualBox test se nikle 2 asli bug (aaj fix + VM me verify)

| bug | lakshan | fix |
|---|---|---|
| `udhcpc` ka `default.script` git me **644** (exec bit nahi) | `udhcpc rc=0`, lease milta hai, phir bhi `### PK: NET-FAIL ###` — fresh clone se build karne par network toot jaata | `build-rootfs` ab stage karte waqt usse (aur `etc/init.d/pk-boot`) 755 karta hai + index me bhi `+x`; VM me `NET-OK (10.0.2.15)` + `SSH-OK` ✓ |
| `S15mdev` legacy `/proc/sys/kernel/hotplug` sysctl par depend, silent exit | docs me `MDEV-OK` claim, par image me koi marker nahi | busybox `uevent mdev` netlink listener + `mdev -s`; har branch print karta hai → `MDEV-OK (uevent listener + coldplug, rc=0)` ✓ |

(Aapki VM ki asli problem kuch aur thi: VirtualBox me **UEFI + Secure Boot ON** tha — `VBox.log` me
`Firmware type: UEFI / Secure Boot: Enabled`. Hamara GRUB unsigned hai isliye OVMF use load hi
nahi karta. Fix: Settings → System → Motherboard → **Enable Secure Boot untick** (EFI rakhna ho)
ya **Enable EFI untick** kar do (BIOS path QA me verified hai ✓). ISO aapke VM me sahi attach thi:
VBox log ka `LUN#2: CD/DVD sectors=358322` × 2048 = 733 843 456 B = bilkul wahi file ✓)

### 2d. Doosra VM-round: headless ISO + initrd-guard (aur ek panic jo humne khud ko sikhaya)

| kya | kyun | proof |
|---|---|---|
| `make iso PK_SERIAL=1` → `pkos-1.0-serial.iso` (release ka naya asset) | "screen hi nahi aayi" wali halat me bhi poora boot padhne layak: default entry me `console=ttyS0,115200n8` | QEMU `-display none` + `-serial file:` me GRUB menu (12 entries) + `### PK: BOOT-OK … ###` + `login: root / pk` + `pk:/root#` prompt ✓ (`pkos-vm-serial-demo.log`) |
| `scripts/mk-initrd`: **static busybox ka hard check** | is sandbox me ek baar `busybox-static` absent tha → initrd me dynamic busybox gaya → `/bin/sh: libresolv.so.2 … ` + `Kernel panic - not syncing: Attempted to kill init!` = **bilkul khali screen**. Aise me build ab chup-chaap toota ISO banane ke bajaye die karta hai (`PK_ALLOW_DYNAMIC_BUSYBOX=1` do to lib closure copy karke chale bhi deta hai) | `make doctor` me "static busybox: /bin/busybox" row ✓ |

## 2e. Reference-OS audit (Alpine / ArchISO / Fedora-live / Ubuntu-casper / TinyCore / SystemRescue / Ventoy)

Poora table: **docs/COMPARE.md**. Jo kami is comparison se nikli — sab *add* ki, kuch hataaya nahi:

| kami (real-hardware risk) | fix | proof |
|---|---|---|
| initrd me `nls_cp437`/`nls_utf8`/`msdos`/`ntfs3` nahi the (Debian ka `vfat` inhe runtime me maangta hai; `modules.dep` me ye dep nahi, isliye hamara closure bhi nahi laata) → **FAT32/exFAT pendrive partition se image boot hi nahi hoti thi** | modules initrd me add + live-modules me `kernel/fs/unicode`/`fat` | QEMU: `live base: /live/pk.sqfs from /dev/vda1 (fs=vfat)` → `BOOT-OK` ✓ |
| ek hi `mount -t <fs>` attempt → option mismatch par `EINVAL` (yahi upar wala bug chupa hua tha) | `vfat:ro,utf8`, `iocharset=utf8`, `msdos`, aur ant me **auto-detect** fallback | same test ✓ |
| live media ke liye koi retry nahi (retry sirf installed `root=` me tha) → dheeme USB3/mmc reader par "media nahi mila" | `rootdelay=`/`pk_rootdelay=` + retry loop (default 12 s) — Alpine `realroot`/casper `CASPER_TIMEOUT`/`wait=` jaisa | QA me pass ✓ |
| **Frugal boot nahi tha** (ISO file ko partition me rakh ke boot — Ubuntu `iso-scan`, TinyCore/Alpine, Ventoy ka model) | `try_iso_file()`: `pkos*.iso`/`*.iso` auto-scan + `pk_iso=<path|naam>` pin; loop+iso9660 mount | QEMU: `BOOT-OK media=/dev/loop0` ✓ |
| `/dev/mapper/*` (Ventoy dm device) scan me nahi | `list_extra_devs()` + extra live paths (`/boot/live/pk.sqfs`) + `btrfs`/`f2fs` | scan logic ✓ |
| "screen khaali" jaisa bug field me debug karna mushkil | `pk_fsdebug=1` → har mount ka asli error + device size/first-sector + insmod failures | is se hi ye bug pakda ✓ |
| admin tooling (SystemRescue/Alpine parity) | live image me `lsblk`, `findmnt`, `wipefs`, `blkdiscard` | `make iso` ✓ |
| `make usb` sirf dd karta tha | **`tools/write-usb.sh --frugal`**: MBR + FAT32 + ISO file copy (init usse loop-mount karta hai) | tool se bana image QEMU me bootable ✓ |
| QA me media layouts cover nahi | **naya stage `1b`**: FAT32-partition media + frugal ISO-file boot (4 checks) | **`QA PASS 68 checks ok`** ✓ |

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
make doctor && make iso && make test        # ~15-18 min, 64 checks
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
