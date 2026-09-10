# pk's OS · Apps kaise chalate hain (App Runtime)

Chhota version: **base ISO jan-boojh ke chhota hai** (busybox + kernel modules, ~78 MiB).
“koi bhi app” chalane ke liye usme ek **App Runtime** jodte hain — ek Debian
userland squashfs, jo boot par `/opt/pk` par **writable overlay** ke saath mount hota
hai. Uske baad `pk-run` sab kuch dispatch kar deta hai, aur `pk-get` se koi bhi
Linux package install ho jaata hai.

```
base ISO (busybox, ~78 MiB)  +  pk-runtime.sqfs (Debian minbase, ~37 MiB)
                                  └─ overlay upper = pk-runtime-rw.img (installed apps + apt state)
```

---

## 1. Runtime banao

```sh
sudo make runtime                     # lean: hello, vim-tiny, htop, wget, ca-certs
sudo make runtime-desktop             # + weston, xterm, Xvfb, x11-utils, mesa, wine (GUI)
sudo make runtime VARIANT=full        # + apt-utils, curl, less, file, man, sudo, locales
sudo make runtime VARIANT=dev         # + build-essential, git, make, pkg-config
sudo make runtime PKGS=wine,gnumeric,firefox-esr   # apni pasand ke packages
```

Output: `build/pk-runtime.sqfs` (+ `build/pk-runtime-rw.img` — writable overlay, sparse).

Direct script bhi chalega: `scripts/make-runtime [--variant=lean|full|dev] [--pkgs=a,b]
[--dist=bookworm] [--mirror=URL] [--out=FILE] [--rw-mb=N] [--no-rw] [--tiny]`.

> `--tiny` QA ka mode hai: debootstrap ke bina busybox-based nakli runtime, taaki
> mount/overlay/chroot/dispatch ka poora flow 1 MB me test ho jaaye.

## 2. Runtime kahaan rakho (3 raaste)

| raasta | kaise | kab theek |
|---|---|---|
| **A. ISO me daal do** | `make iso WITH_RUNTIME=1` → `/live/pk-runtime.sqfs` ISO ke andar | ek hi file carry karni ho, USB/pendrive single-image |
| **B. Alag partition** | 1–2 GiB ext4 partition label `PK-RUNTIME`, usme `pk-runtime.sqfs` + `pk-runtime-rw.img` (boot karke: `pk-runtime --setup /path/to/pk-runtime.sqfs /dev/sda3`) | ISO chhota rakhna ho, runtime upgrade karna ho bina ISO badle |
| **C. Kisi bhi partition ki root me** | `pk-runtime.sqfs` (aur optional `pk-runtime-rw.img`) kisi ext4/vfat partition ke top level par | installed system ke `/home` me rakhna ho |
| **D. Kuch mat rakho (installed system)** | `pk-runtime --setup` na karo; runtime file installed `/var/lib/pk/` me | rw image khud ban jaati hai (apps persist) |

Boot par discovery order: `pk_runtime=<...>` option → ISO ka `/live/pk-runtime.sqfs` →
label `PK-RUNTIME` → har mountable partition ki root. Mil gaya to:

```
squashfs -> /mnt/pk-rt/pk-runtime.sqfs   (read-only base)
rw img   -> /mnt/pk-rw/pk-runtime        (writable upper; touch-proof kiya hua)
overlay  -> /opt/pk                       (merged view, yehi runtime hai)
```

`pk-runtime status` sab dikhaata hai; marker:
`### PK: RUNTIME-OK src=pk-runtime.sqfs upper=/mnt/pk-rw/pk-runtime mode=rw-image (...) ###`

**Boot options**

| option | matlab |
|---|---|
| (kuch nahi) | `pk_runtime=auto` — dhoondo, na mile to base OS me chalao |
| `pk_runtime=off` | runtime mat mount karo |
| `pk_runtime=/dev/sdb3` | is partition se lo (label ya `PARTUUID=` bhi chalega) |
| `pk_runtime=/dev/sdb3:/live/pk-runtime.sqfs` | partition + path |
| `pk_runtime=/data/pk-runtime.sqfs` | boot se pehle file directly |

`mode=tmpfs` / `mode=read-only bind` ka matlab rw image use nahi ho payi (RAM overlay —
reboot par installed apps udd jayenge). `RUNTIME-WARN rw image read-only lagi` serial par
aata hai, chhupaata nahi.

rw image kahaan mil/banti hai (pehla match):

1. sqfs ke bagal me `pk-runtime-rw.img`  (option B/C ka normal setup)
2. `/mnt/persist/pk-runtime-rw.img`      (live + `persistent` boot option)
3. `/var/lib/pk/pk-runtime-rw.img`       (**installed system** — yahan ban bhi jaati hai)

live mode (persistence OFF) me `/var/lib/pk` RAM overlay par hota hai, isliye wahan
image **nahi** banate (2 GB ki image RAM me = OOM) — `pk-runtime` bolke RAM upper par
chhod deta hai: `live mode (persistence off): rw image RAM me nahi banayenge`.

## 3. Commands (image me maujood)

```sh
pk-info                          # runtime laga hai ya nahi, kya-kya mil gaya
pk-run ./app                     # kuch bhi chalao — type pehchan ke dispatch
pk-run --info ./file             # sirf pehchan: elf/script/dos-exec/zip(apk)/mach-o/deb/iso…
pk-run --install ./foo.deb       # .deb install (dpkg ho to wahi, warna ar+tar extract + launcher)
pk-run ./Setup.msi               # Wine msiexec /i se install (.exe bhi isi se)
pk-run --list                    # installed apps
pk-run --gui xterm               # GUI app (X/Wayland dhoondh ke, na ho to Xvfb try)
pk-shell                         # runtime ke andar root shell (`pk-shell -c "cmd"` bhi)
pk-run --selftest                # 7-check battery (QA isi ko dekhta hai)
pk-get install -y vim            # apt (runtime ke andar) — network ho to
pk-get update
pk-chroot /usr/bin/htop -y       # runtime me chroot (binds: /proc /sys /dev /tmp /run)
pk-chroot --umount               # binds hatao
pk-x start | pk-x status         # display server (weston -> Xorg -> Xvfb), pk-desktop session
pk-wifi status|scan|connect      # Wi-Fi (experimental; wpa_supplicant runtime me)
pk-vm new win --size=40G         # QEMU guest (Windows / Android-x86 / macOS raasta)
pk-vm run win --cdrom=win.iso --ram=4096 --vnc=:1
pk-vm list
```

Sab `root` se (live me autologin `root`/`pk`; installed system me apna password).

## 4. “Har tarah ke app” — honestly kya chalta hai

| app type | status | kaise |
|---|---|---|
| **Linux** native ELF, shell/python/perl script | ✅ chalta hai | `pk-run ./binary` (loader path `/opt/pk/lib64/ld-linux…` fix ho jaata hai) |
| **Linux** `.rpm` | ⚠️ runtime + `alien` chahiye | `pk-run --install pkg.rpm` → `pk-chroot alien -i`; na ho to message: `pk-get install -y rpm` karke `pk-chroot rpm -Uvh` |
| **Linux** `.deb` | ✅ | `pk-run --install pkg.deb` → runtime me `dpkg` ho to wahi, warna in-house `ar` reader + tar pipe (QA-proved, dono path) |
| **Linux** apt repo ka kuch bhi (vim, htop, curl, firefox-esr…) | ✅ | `pk-get install -y <pkg>` — network + DNS chahiye (DHCP: `pk_net=dhcp`); lists na hon to `pk-get` khud `apt-get update` karta hai |
| **Linux** static binaries / AppImage | ✅ mostly | AppImage ko `pk-run` extract karke andar ka `.desktop`/binary chalata hai; FUSE zaroori nahi |
| **Windows** `.exe` / `.msi` | ✅ **Wine ke through** | `pk-get install -y wine` (ya runtime banate waqt `VARIANT=full`/`PKGS=wine`) → `pk-run ./setup.exe`, `pk-run --install ./Setup.msi`. Wine ke bina `pk-run` “install wine” bolke saaf diagnostic deta hai (rc 64), crash nahi |
| Java `.jar` | ⚠️ JRE chahiye | `pk-get install -y default-jre-headless` → `pk-run ./app.jar` |
| **Android** `.apk` | ❌ direct nahi | Android app ko Android runtime chahiye (binder + `/dev/binderfs`, apna kernel). `pk-run` ise pehchan kar **waydroid** ka raasta batata hai. Poora raasta: §5 |
| **macOS** `.app` / `.dmg` / Mach-O binary | ❌ | Mach-O ko Linux kernel execute nahi kar sakta — Darwin kernel chahiye. Raasta: macOS ko **guest** me chalao (§5). `pk-run` honest error deta hai: “Darwin kernel required” |
| Flatpak / Snap | ⚠️ runtime ke andar | `pk-get install -y flatpak` → `flatpak install …` (bubblewrap ko user namespaces chahiye; live OS me `root` se chal jaata hai) |
| GUI apps (X11/Wayland) | ⚠️ optional | base ISO me X server nahi hai. `VARIANT=full` me weston aa jaata hai; warna runtime me `pk-get install -y weston xterm`. Phir: `pk-x start weston` |

## 5. Windows / Android / macOS — guest-based raasta

`pk-run` dispatch ka maqsad **native** execution hai jo possible hai (Linux + Wine).
Jo possible nahi, unke liye `pk-vm` (QEMU inside the live system) ka raasta hai:

* **Windows**: `pk-vm new win --size=40G` → `pk-vm run win --cdrom=win.iso --vnc=:1`. QEMU + KVM
  (real PC par `/dev/kvm` milega; VM ke andar TCG).
* **Android**: `pk-runtime` me `waydroid` install karo, aur **apna kernel** banao jisme
  `CONFIG_ANDROID_BINDERFS=y` + `CONFIG_ASHMEM` ho (`make kernel`, `docs/KERNEL.md`).
  Host kernel pe binderfs na mile to `pk-run` ye exact wajah batata hai.
* **macOS**: legally Apple hardware par hi chalta hai; QEMU guest + `pk-vm run` se test
  sakte ho (license Apple hardware maangti hai). `.app` files us *guest* ke andar
  chalenge, OS ke andar nahi — ye limitation kernel ki hai, hamari nahi.

## 6. Persistence (apps reboot ke baad bhi)

`pk-runtime-rw.img` (ya `persistent=`/installed system ka `/opt/pk`) overlay upper
 rakhta hai: `pk-get install`, `pk-run --install` se aaye apps, apt state — sab **reboot
ke baad bhi** rehte hain. QA stage 7 ise do boot me verify karta hai (host side
`pk-runtime-rw.img` ke andar installed file dhoondh ke).

RAM-only fallback (`mode=tmpfs`) me sab udd jaayega — isliye `pk-runtime` rw image ko
mount karne ke baad us par **sach me `touch`** karke check karta hai; fail hone par
`RUNTIME-WARN` print hota hai.

## 7. Test / prove

```sh
make test-apps                                   # tiny runtime, 14 checks (~50 s)
PK_TEST_REAL_RUNTIME=1 make test-apps            # asli Debian runtime se same battery
PK_TEST_REAL_RUNTIME=1 PK_TEST_WINE=1 make test-apps   # + apt se wine install + 'wine --version'
```

Boot-time manual check (koi script nahi):

```
GRUB → 'e' karke append:  pk_net=dhcp pk_apps_get=sl pk_apps_get=wine:--version
```
`pk_apps_get=<pkg>[:args]` runtime me apt se package install karta hai (lists na hon to
pehle `apt-get update` khud) aur `<pkg>` chala ke serial par marker deta hai — asli
Debian runtime me QA ne yahi dekha:

```
### PK: APPS-GET-OK (sl)   pk-run: type: elf (/opt/pk/usr/games/sl)|<ASCII train> ###
### PK: APPS-GET-OK (wine) pk-run: type: runtime-bin (/opt/pk/usr/bin/wine)|wine-8.0 ... ###
```

multiple specs do sakte ho: `pk_apps_get=sl pk_apps_get=wine:--version`

`pk-run --selftest` ke markers QA check karta hai:

```
APP-ELF-OK  APP-SCRIPT-OK  APP-DEB-OK (dpkg path|extract path)  APP-EXE-OK|APP-EXE-NO-WINE
APP-APK-DIAG-OK  APP-MACHO-DIAG-OK  RUNTIME-EXEC-OK  APPS-OK
```

## 8. Troubleshooting

| lakshan | kaam |
|---|---|
| `RUNTIME-NONE` | runtime file kahaan hai? `pk-runtime find`; ISO me `WITH_RUNTIME=1` se rebuild kiya? |
| `RUNTIME-WARN rw image read-only lagi` | backing partition ro mount hai ya file root-owned — `pk-runtime --setup` root se chalao |
| `mode=tmpfs` | installed apps reboot ke baad nahi rahenge (upar dekho) |
| `pk-get install` fail “Temporary failure resolving” | `pk_net=dhcp` (ya `pk-net dhcp`) karo; marker me `NET-OK (ip)` hona chahiye |
| `E: Unable to locate package ...` | apt ki index lists nahi hain — `pk-get install` khud `apt-get update` chalata hai (network chahiye); `pk-get update` pehle chalao to confirm ho jaata hai |
| `pk-get install` 5-10 min chal raha hai (QEMU me) | normal hai jab lists image me na hon: 320 MB VM me apt ka poora bookworm index parse karna bhaari hai. `sudo make runtime` default me lists **rakhta** hai (`RUNTIME_KEEP_LISTS=0` se hata sakte ho) |
| `.exe` pe “wine nahi” (rc 72, `APP-EXE-NO-WINE`) | `pk-get install -y wine` (ya `VARIANT=full` se runtime dobara banao) |
| `.deb` extract pe “short read” | fix ho chuka: `data.tar.*` ko pipe se tar me daala jaata hai (busybox/GNU dono me) — purani ISO ho to rebuild |
| GUI app connect fail | `pk-x start weston` (ya `pk-x status`), phir `pk-run --gui xterm` |
| `pk-run --list` me package dikhe par launcher na | `.deb` dpkg se install hua tha (apps/ me launcher nahi banta) — binary runtime ke `/usr/bin` me hai, seedha `pk-run <naam>` |
| kya chal raha hai dekho | `dmesg | grep PK` , `cat /run/pk/boot.env`, `pk-info`, `tail /run/pk/apps-get.log` |

## 9. Size ka hisaab

| cheez | size |
|---|---|
| base ISO | ~78 MiB |
| `pk-runtime.sqfs` (lean, Debian minbase + hello/vim/htop/wget) | ~37 MiB |
| runtime ka merged view (RAM ke baad) | ~125 MiB |
| `VARIANT=full` + wine + weston | ~600 MiB–1 GiB (mirror speed pe) |
| `pk-runtime-rw.img` | jitna do (`--rw-mb=`, default 1024, sparse) |

RAM: runtime mount `tmpfs` nahi rakhta (squashfs + loop page cache chhota hai), par
`pk_apps_get`/apt chalane ke liye QEMU me `PK_QEMU_MEM=1024` Behtar.

Speed note: runtime **ISO ke andar** ho (option A) to apt ka package index emulated
CD-ROM se padha jaata hai — pehla `pk-get install`/me `pk_apps_get` USB/partition wale
option B se kaafi slow lag sakta hai (QEMU me ~3-5 min dekha). Fast chahiye to runtime
ko ext4 partition par rakho (option B/C): `pk-runtime --setup`.

Do ISO variants (repo se):

```sh
make iso                                   # base, 78 MiB (apps optional)
make iso OUT=build/pkos-apps.iso WITH_RUNTIME=1   # runtime andar, ~349 MiB
```
