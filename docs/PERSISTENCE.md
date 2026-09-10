# pk's OS · PERSISTENCE — live USB pe changes bachana

Live mode design-by-design bhulakkad hai: squashfs read-only + **overlayfs ka upper
directory tmpfs (RAM) me** → reboot pe sab reset. Teen options:

| tareeka | kahan save | kis liye |
|---|---|---|
| **A. `persistent` partition on the same USB** | USB ka extra ext4 partition | ek hi pendrive, ghar/office dono machine |
| **B. permanent install** | internal disk | jo machine primary ho, wahi use karte ho |
| **C. `toram`** | kuch nahi (bas media nikaal sakte ho) | speed / ek hi USB se kai machines |

---

## A. Persistence partition (recommended, USB ke saath)

### A.1 Live session me helper se (sabse aasan)

```sh
pk-persist            # boot media ki disk ke end me PK-PERSIST ext4 banata hai
# ya explicitly:
pk-persist /dev/sdb
```

wo karta kya hai: partition table ke baad ek ext4 partition (label `PK-PERSIST`)
banata hai + usme `pk-persist/{upper,work}` directories. **Reboot ke baad GRUB
menu me `pk's OS (live, persistent)` chuno** (ya kernel cmdline me `persistent`).

> Partition table modify hoti hai — agar USB pe koi aur data hai to pehle soch lo.
> ISO `dd` ki hui disk pe naya partition banane ke baad **reboot zaroori** hai
> (kernel ko naya partition table reload karna hai: `partprobe` se bhi kabhi-kabhi
> nahi hota).

### A.2 Host se manually (Windows ke baad, ya script me daalne ke liye)

```sh
# /dev/sdb = USB. Last partition ke baad 4G ka ext4 partition banao
sudo parted -s /dev/sdb -- mkpart persist ext4 100MiB 4GiB
sudo partprobe /dev/sdb
sudo mkfs.ext4 -F -L PK-PERSIST /dev/sdb2
sudo mkdir -p /mnt/p && sudo mount /dev/sdb2 /mnt/p
sudo mkdir -p /mnt/p/pk-persist/upper /mnt/p/pk-persist/work
sudo umount /mnt/p
```

### A.3 Kaise kaam karta hai (init me ~15 line)

`persistent` cmdline dekhkar `/init`:
1. har disk/partition ko **rw** mount karke label `PK-PERSIST` dhoondhta hai
   (boot media khud skip — uspe overlay ke liye rw nahi kar sakte),
2. usme `pk-persist/upper` + `work` confirm karta hai,
3. overlay ko `lowerdir=/ro upperdir=/mnt/persist/pk-persist/upper` deta hai —
   squashfs base wahi, writes ab USB pe.

`persistent=MYLABEL` se apna label bhi de sakte ho (init `PERSISTLABEL` use karta hai).

Yeh poora flow `make test` ke **stage 6** me test hota hai: ek 512 MB ext4 image
(label `PK-PERSIST`) VM me do baar boot hoti hai — pehli boot `/root/.pk-persist-marker`
likhti hai (`PK: PERSIST-WROTE`), host usse image file ke andar se padhkar verify karta
hai, aur dusri boot usse wapas padh kar `PK: PERSIST-KEPT` print karti hai.

Check (boot ke baad):
```sh
findmnt / -o SOURCE,FSTYPE,OPTIONS     # upperdir=/mnt/persist/... dikhna chahiye
cat /run/pk-persist-on              # persistence ON ka flag
pk-info | grep -i persist
reboot karke bhi /root/meri-file bachi rahe ✓
```

### A.4 Persistence ki seemaen (jaan lo)

- **Full / ka overlay** hai — `/etc` bhi badal sakte ho, par `apt` nahi (package
  manager is OS me jaan bujhkar nahi hai; dekho "software add karna" neeche).
- squashfs base **same rehna chahiye**: ISO dobara flash karke purana persist
  partition use karo to upper/work ka mismatch (`EBADMSG`) aa sakta hai → tab
  `pk-persist` se partition reformat karo (changes kho jaayenge).
- USB 2.0 pe boot slow lagega (ext4 journal + small writes) — `data=writeback` mount
  option dijaaye to tez; abhi default hai.
- Ek persist partition ko **do alag pk's OS versions ke saath mat use karo**.

## B. Software add karna (is OS me apt nahi hai)

Chhote OS ka trade-off: static/dynamic binaries drop karo, ya `/usr/local` me rakho:

```sh
# persistence/installed dono me /usr/local rw hai
sudo mkdir -p /usr/local/bin
sudo cp ~/usb/stress-ng /usr/local/bin/           # static binary sabse aasan
# ya source build karo live me hi (busybox me cc nahi hai — dekho note)
```

Options:
1. **static binaries** (musl/gcc-built) — sabse simple, `file` se confirm karo `statically linked`.
2. **host pe build karke copy** — same glibc version ka build host chahiye (Debian 13 →
   pk's OS bhi host ki libs use karta hai, isliye matching host pe `apt download <pkg>`
   karke `dpkg -x pkg.deb /mnt/persist/rootfs` se extract bhi kar sakte ho:
   ```sh
   dpkg-deb -x somepkg_1.0_amd64.deb /tmp/x
   cp -a /tmp/x/usr/bin/* /usr/local/bin/
   ```
   note: `/lib/x86_64-linux-gnu` ki libs bhi chahiye ho to copy karo (live image me
   already host ki common libs maujood hain — `collect-bins` isi liye closure copy karta hai).
3. **Build me add karo** (proper tarika): `config/live-bins.txt` me naam daalo →
   `make iso` → wahi tool squashfs me aaa jaayega, sab machines pe. Agar tool ki
   libs missing hon to `scripts/collect-bins` unka `ldd` closure bhi uthaata hai ✓
4. **Flatpak/AppImage**: AppImage chalta hai (FUSE ke bina bhi: `--appimage-extract`),
   flatpak ko systemd/chroot overhead chahiye — is OS ke design se contradict karta hai.

## C. Toram

```
pk's OS (toram)        # ya cmdline: toram
```
init `live/pk.sqfs` ko `/run/toram/` me copy karta hai (tmpfs), uske baad
**USB nikaal lo** — system chalta rahega. 2 GB RAM wali machine pe 77 MiB ISO ke liye
kaafi hai. Reboot pe sab reset (persistence nahi).

## D. Installed system me "reset to factory"

```sh
# installed root ka matlab hai /persistent nahi; reset ke liye do route:
pk-info                       # installed mode me /live-base nahi hoga
# 1) reinstall: live USB se boot → pk-install --target=auto --yes
# 2) sirf /etc reset: /etc pk-installed me snapshot hai (future feature)
```
Filhaal simplest: reinstall (30-60 second, image chhota hai).
