# pk's OS · STATUS (aaj kya hua, kaha tak pahunche)

> (Aapke liye) Ek-file snapshot. Detail chahiye to `README.md` + `docs/`.

## 1. Kya bana

Apna chhota Linux OS jo **x86_64 PC pe live USB se boot hota hai aur permanent install
bhi ho jaata hai**. Koi distro ka installer nahi — sab isi repo se build hota hai.

```
busybox-static + squashfs (read-only /) + overlayfs (upper = RAM ya USB partition)
+ custom initramfs /init (boot media khud dhoondhta hai)
+ hybrid ISO (grub-mkrescue: BIOS + UEFI, dd-able)
+ /sbin/pk-install (GPT: bios_grub + ESP + ext4, GRUB i386-pc + x86_64-efi, fstab by UUID)
+ boot hooks: /etc/pk-boot.d/S*  (net: NIC modprobe + DHCP, ssh: dropbear, persist)
```

## 1b. 2026-09-10: sandbox reset + restore (zaroori padho)

Workspace ke beech me environment reset ho gaya. Snapshot me sirf *chhote, tracked*
files persist hote hain, isliye gayab ho gaye: `.git/` (12 commits ka history),
**`rootfs/overlay/`** (poora live-system layer — pk-boot, pk-run, pk-runtime, pk-get,
inittab, motd, boot hooks…), `build/`, `pkos-1.0-apps.iso`, aur apt se install kiya
hua toolchain (busybox-static, grub, qemu, debootstrap, squashfs-tools…).

Recovery (ho chuki): ISO hi backup ban gayi —
`pkos-1.0.iso` → `xorriso -extract` → `live/pk.sqfs` → `unsquashfs` → 36 hand-written
files wapas `rootfs/overlay/` me. Verify: tracked file count **66** (jitna reset se pehle
tha), sab `pk-*` scripts + `etc/` configs **byte-exact** (ek lauta `etc/shadow` ka salt
alag hai, kyunki wo build par random banta hai), `sh -n` clean. `make iso` phir se chalta
hai aur naye ISO me bhi wahi content hai (extra: ab `/usr/lib/grub/x86_64-efi-signed/*`
bhi copy hota hai — host package me aaya, installer ke liye nuksan nahi).
Scripts ke exec bits bhi reset me ud gaye the → `chmod 755` + commit.

**Restore ke baad dobara chalaya gaya (aaj):** `make doctor` ready · `make iso` 83 MiB ·
full `make test` (7 stages) = **QA PASS 43 checks ok** · `sudo make runtime` se asli
Debian runtime (272 MiB, wine + apt lists) dobara bana · `PK_TEST_REAL_RUNTIME=1
PK_TEST_WINE=1` stage 7 = **QA PASS 17 checks** (asli Wine dispatch + apt se `sl`
download+run) · dono ISO artifacts dobara cut + `sha256sum -c` OK.
Naya toolchain bhi dobara install kiya (busybox-static, grub, qemu, ovmf, debootstrap,
squashfs-tools, xorriso, linux-image-amd64) — sandbox me apt packages persist nahi karte.

Iska matlab: **git history nahi bachī** (content bach gaya). Repo ko dobara `git init`
kiya gaya hai; ek "restore" commit se aage chal rahe ho.

## 2. Kaha tak pahunche — sab green

> Live system ka apna manual bhi apps-layer ke saath update hua: `pk-help`, `/etc/motd`
> aur `/usr/share/doc/pkos/README.md` (section "Apps chalana"). Uske baad stages 1+7
> dobara: **19/19 checks pass**.

| cheez | status |
|---|---|
| `make doctor` | sab ready (0 missing); apps ke liye `debootstrap` optional |
| `make iso` | restored tree se: `build/pkos.iso` = **86 581 248 bytes (83 MiB)** (host grub packages badhne se thoda bada; runtime andar karne par ~350 MiB) |
| andar | rootfs `live/pk.sqfs` 41 MiB (956 kernel modules, NIC/Wi-Fi/GPU drivers), `boot/pk-initrd` 3.3 MiB (44 boot modules, xz) |
| `make test` (QEMU, **7 stages**) | **QA PASS — 43 checks ok**, `SUITE_RC=0` |
| App Runtime (apps layer) | ready: `sudo make runtime` → 37 MiB Debian squashfs; boot par `/opt/pk` overlay; `pk-run`/`pk-get`/`pk-shell`/`pk-x`/`pk-vm` |
| apps QA (stage 7, tiny runtime) | 14/14 — dispatch (.deb/.exe/.apk/Mach-O), chroot exec, doosri boot par re-attach, host se overlay verify |
| apps QA (asli Debian runtime, 272 MiB: wine + apt lists) | `APPS-OK` + `APP-DEB-OK (dpkg path)` + `APP-EXE-OK (wine: wine-8.0 (Debian 8.0~repack-4))` (asli Wine dispatch) + `APPS-GET-OK (sl)` (apt ne net se 20 KB .deb khinch ke chalaya) + `APPS-GET-OK (wine)` · **17/17 checks** |
| git | history reset me gayab (ab 4 commits: restore + STATUS updates), **66 files tracked** = pehle jitne, working tree clean |
| aapke liye ready image | `/home/user/pkos-1.0.iso` **83 MiB** (sha256 `623d7267…`) + `/home/user/pkos-1.0-apps.iso` **354 MiB** (sha256 `4bc2673f…`, App Runtime + Wine + apt andar) + `pkos-1.0.iso.sha256` — dono reset ke baad dobara build/cut, `sha256sum -c` OK |
| repo path | `/home/user/pkos` (rename ho gaya; `make doctor` + full QA is path se dobara green) |
| apps QA (**apps ISO**, runtime ISO ke andar, GRUB/cdrom se boot) | `RUNTIME-OK … mode=tmpfs (ephemeral)` → `APPS-GET-OK (sl)` (apt se download+run) → `APP-EXE-OK (wine: wine-8.0 …)`, `APPS-OK`, VM ne khud power off kiya (`rc=0`) |
| abhi kya chal raha hai | kuch nahi — sab green; aapke next instruction ka wait |

### QA stages (sab pass)

| stage | kya proof karta hai |
|---|---|
| 1 live boot from ISO | grub → kernel → initrd → squashfs+overlay → init, `DEPS-OK`, base read-only, installer tools |
| 2 headless install | `INSTALL-OK target=/dev/vdb root=/dev/vdb3`, `INSTALL-DONE rc=0`, installed tree + `root=UUID=` + root password sha-5 verify (host side), `/etc/default/pk` me DHCP on |
| 3 installed disk ka apna GRUB | `BOOT-OK mode=installed`, `PASSWD-OK`, `LOGIN-REQUIRED` (installed par autologin nahi) |
| 4 `toram` | image RAM me copy, media reuse ke saath boot |
| 5 UEFI (OVMF) | GPT/ESP wala path |
| 6 `persistent` + DHCP + SSH | init ko `PK-PERSIST` disk mili, `upperdir=/mnt/persist/pk-persist/upper`, marker file **host ne image ke andar se padhi**, dusri boot par `PERSIST-KEPT`, `NET-OK (10.0.2.15)`, `SSH-OK (dropbear :22)` |

### Asli serial-log markers (proof, `build/test-logs/`)

```
01-live        BOOT-OK mode=live · SELFTEST-OK · DEPS-OK · PASSWD-OK · LIVE-AUTOLOGIN
02-install     BOOT-OK mode=live · INSTALL-OK · INSTALL-DONE rc=0 · POWER-OFF
03-installed   BOOT-OK mode=installed · SELFTEST-OK · DEPS-OK · PASSWD-OK · LOGIN-REQUIRED
05-uefi        BOOT-OK mode=live (OVMF/UEFI se)
06a-persist    init: "root = squashfs + persistence (/dev/vdb)" · PERSIST-WROTE · NET-OK · SSH-OK
06b-persist    PERSIST-KEPT (reboot ke baad marker file zinda)
07a-apps       RUNTIME-OK src=pk-runtime.sqfs upper=… mode=rw-image · APP-ELF-OK · APP-SCRIPT-OK
               APP-DEB-OK · APP-EXE-OK · APP-APK-DIAG-OK · APP-MACHO-DIAG-OK · RUNTIME-EXEC-OK
               APPS-OK · NET-OK · dusri boot (07b) par bhi RUNTIME-OK + APPS-OK
```

## 3. Ab tak milke fix hue bugs (17)

1. `/init` ne `/proc/cmdline` **/proc mount hone se pehle** padhi → saare `pk_*` options ignore
2. `find_live_image` ka `MEDIATYPE` command-substitution ke subshell me kho jaata tha → `BOOT FAIL`
3. `collect-bins` merged-usr **symlinks recreate** karta tha → `/lib64/ld-linux` dangling →
   live system me `parted`/`blkid`/`lsblk` = "not found"
4. `cp` busybox symlink ke **through** `/bin/busybox` ko overwrite kar sakta tha
5. initrd me **same module 4-5 baar** (dedup nahi) → 11 MB; ab dedupe + xz → **3.3 MB**
6. `build-rootfs` ka module loop `find` ke non-zero exit par `set -e` se mar raha tha → sirf 4 modules
7. installer: silent branch me `--yes` missing, `rc` sed-pipeline se 0, busybox `tar` me `--exclude` nahi
8. `A || B && C` precedence se `/etc/shadow` update par `mv: No such file`
9. `tools/write-usb.sh` ka verify-step bina sudo padh raha tha → jhootha "header match nahi hua"
   (loop-device pe real write test me pakda; ab fix + poora ISO byte-for-byte match ✓)
10. **persistence**: `PERSISTDEV` bhi subshell me kho raha tha → `upperdir` tmpfs par reh jaata,
    persistence silently off. Ab `persist_upper` data *print* karke return karta hai
    (`upper work dev`) aur `/run/pk-persist-on` likha jaata hai ✓ QA stage 6 se proven
11. **DHCP**: `pk-net` busybox `udhcpc` ko `-r <pidfile>` de raha tha — par `-r` ka matlab
    "request this IP" hota hai (pidfile ke liye `-p` chahiye) → kabhi lease apply nahi hoti thi.
    Saath hi NIC drivers live me the hi nahi (`config/live-modules.txt` me sirf e1000/r8169) aur
    `virtio_net` ka dep `net_failover` missing → `modprobe` fail.
    Fix: sahi flags (`-s/-p/-n/-q`), `modules.dep` se **dependency closure auto-expand**,
    NIC + USB-Ethernet drivers list, aur `udhcpc` hook script (`/usr/share/udhcpc/default.script`)
    ko `ip`-first + netmask→prefix handling ke saath rewrite ✓ `NET-OK (10.0.2.15)`
12. boot hooks se **pehle** `PK_DHCP/PK_SSH` export karne padte hain — export hook-loop ke
    baad tha to hooks file-defaults (`no`) par chale jaate the (silent no-op pattern)
13. **app runtime overlay**: `pk-runtime-rw.img` ro backing fs par ho to loop ro milta hai aur
    overlayfs upperdir reject kar deta tha → fallback **silent** tha. Ab mount ke baad image par
    asli `touch` probe hota hai; fail ho to `RUNTIME-WARN rw image read-only lagi` + tmpfs upper
14. `pk-run --selftest` fail ho par nested commands ka output `/dev/null` jaaye → marker me
    kuch nahi dikhta tha (QA ko sirf "APPS-FAIL(1)" milta tha). Ab output `tr '\n' '|'` se
    **ek line** me marker + `/dev/kmsg` me (multi-line dumps serial par aate hi nahi)
15. `.deb` extraction: `tar -C dest -xf data.tar.gz` → `tar: short read` (deb ka archive
    GNU/busybox tar ke end-of-archive padding ko strict padhta hai). Fix: `gzip -dc | tar -xf -`
    (pipe me padding ki zaroorat nahi) + fail tabhi jab `ls -A dest` khali ho ✓ ab dono tar
    chalte hain; `ar` member extract khud kiya (`unpack_ar`) kyunki busybox `ar` me create nahi hota
16. `.deb` install dir ka naam `pkg_ver_arch` se `pkg` kiya (upgrade par same dir reuse) aur
    host-side QA check ko `pk-runtime-rw.img` ke **andar** point karaya (upar wali dir nahi)
17. `scripts/make-runtime` ka tree ek run root se (`debootstrap`) aur dusra user se →
    `Permission denied`. Ab prep+steps ek hi privilege wrapper se, aur user-run ke baad tree
    wapas caller ko chown ho jaati hai

## 3b. App Runtime — "har type ka app" layer (naya)

`pk-run` ek dispatcher hai: file ka type detect karta hai (ELF / script / `.deb` / `.rpm` /
AppImage / `.jar` / PE `.exe`+`.msi` / ZIP `.apk` / Mach-O) aur sahi tareeke se chalata hai.
"asli" apps ke liye optional **App Runtime** (Debian minbase squashfs) `/opt/pk` par
**overlayfs** ke saath mount hota hai — base ISO chhota rehta hai:

```
pk-runtime.sqfs (ro base) + pk-runtime-rw.img (upper: apps + apt state)  ->  /opt/pk
```

* `sudo make runtime` (`VARIANT=lean|full|dev`, `PKGS=...`) → `build/pk-runtime.sqfs` (37 MiB)
* `make iso WITH_RUNTIME=1` se runtime ISO ke andar; ya `pk-runtime --setup` se alag partition
* boot option `pk_runtime=off|auto|/dev/sdXN|/path/file.sqfs` ; marker `RUNTIME-OK/WARN/NONE/FAIL`
* `pk-get install -y <pkg>` (apt, net ke saath), `pk-shell`, `pk-chroot`, `pk-x start weston`, `pk-vm`
* `.exe`/`.msi` → Wine (runtime me ho to `wineboot -u` + `wine`/`msiexec`, warna exact
  command + rc 72); `.apk` → Waydroid/binderfs ki wajah; Mach-O → "Darwin kernel chahiye" + `pk-vm`
* `pk_apps_get=<pkg>[:args]` boot option: install + run, marker me output (`hello` ne
  "Hello, world!" print kiya — proof upar)
* Poora doc: **docs/APPS.md**

## 4. Aapke PC pe ab kya karna hai (aapke order: emulator → pendrive → install)

```sh
# 0) toolchain (ek baar) — Debian/Ubuntu
sudo apt-get install -y build-essential busybox-static cpio squashfs-tools xorriso \
  mtools grub-pc-bin grub-efi-amd64-bin grub2-common dosfstools parted e2fsprogs \
  util-linux kmod linux-image-amd64 dropbear ovmf qemu-system-x86
sudo apt-get install -y debootstrap           # (optional) App Runtime ke liye

cd pkos
make doctor && make iso && make test          # apne machine pe dobara verify (~10 min)

# apps chahiye to (optional, par "koi bhi app" isi se chalta hai):
sudo make runtime                             # build/pk-runtime.sqfs
make iso WITH_RUNTIME=1                       # runtime ISO ke andar
make test-apps                                # apps layer ka QA (14 checks)

# 1) pendrive (poora disk wipe hota hai — tool confirm maangta hai)
lsblk
make usb USB=/dev/sdX

# 2) PC se boot (F12/F8/Esc boot menu; Secure Boot OFF) -> login: root / pk
#    GRUB menu me [n] = network + SSH, [p] = persistent, [a] = headless install

# 3) permanent install
pk-install --info                 # kaunsi disk target hogi
pk-install --target=auto          # ya --target=/dev/sda
```

Sandbox me sirf **asli hardware pe boot** test nahi ho paya (nested KVM/USB yahan nahi).
Net/SSH/persistence sab QEMU me proven hain; real PC par agar boot atke to
`dmesg | grep PK` + `cat /var/log/pk-net.log` bhej dena.

## 5. Bache hue options (aap bolo to karun)

- **A. Real PC triage** — aap boot karo, `dmesg | grep PK` + `pk-info` ka output bhejo
- **B. Features** — Wi-Fi firmware on by default (`PK_FIRMWARE=1` flow ready hai), framebuffer
  TUI desktop, `pk-get` package installer, LUKS encrypted install, installed system me
  `pk_net=off` respect karna
- **C. Apna kernel** — `make kernel` (custom 6.12) + usi pe ISO + QA (dheemi machine pe 30-90 min)
- **D. Kuch nahi** — repo as-is ready hai

## 6. Quick reference

```
make help          sab targets
make run           QEMU live (headless pe serial + direct kernel boot) — root shell milta hai
make run-iso       pura ISO + GRUB boot
make test-live     sirf stage 1 (fast smoke)
make test-apps     sirf stage 7 (apps layer); PK_TEST_REAL_RUNTIME=1 [PK_TEST_WINE=1] make test-apps
sudo make runtime  App Runtime banao;  make iso WITH_RUNTIME=1  -> ISO ke andar
PK_TEST_STAGES=6 make test         persistence + DHCP + SSH only
PK_TEST_STAGES=2,3 make test       install + installed-boot only
build/test-logs/*.log                 har VM ka serial output
```

Boot options (GRUB menu me `e` dabakar bhi de sakte ho):
`toram` · `persistent[=LABEL]` · `pk_media=/dev/sdb` · `pk_install=auto|/dev/sdX|ask` ·
`pk_silent` · `pk_halt` · `pk_net=dhcp` · `pk_ssh=on|off` · `pk_rootpw=...` ·
`pk_autologin` · `pk_debug` · `pk_runtime=off|auto|/dev/sdXN|/path/file.sqfs` ·
`pk_apps_get=<pkg>[:args]` · `break=mount` · `single` · `console=ttyS0,115200n8`
