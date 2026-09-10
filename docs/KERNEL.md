# pk's OS · KERNEL — apna kernel banao aur use karo

Default me pk's OS **host ka kernel** use karta hai (`/boot/vmlinuz-<ver>` +
`/usr/lib/modules/<ver>`) — ye jaan bujhkar choice hai: driver coverage guaranteed,
build seconds me, aur ISO chhoti. Apna kernel banana optional step hai (aur sabse
zyada seekh isme milta hai).

## 1. Build

```sh
make kernel                     # scripts/build-kernel
# ya:
PK_KVER=6.12 make -C . kernel
```

`scripts/build-kernel`:
1. `cdn.kernel.org` se `linux-6.12.tar.xz` → `build/dl/` me download, `build/linux-6.12/` me extract
2. `make defconfig` + curated `scripts/config` tweaks (neeche dekho)
3. `make -j$(nproc) bzImage modules` (2 core / 2 GB RAM pe ~40-90 min; log: `build/kernel-build.log`)
4. `make modules_install INSTALL_MOD_PATH=build/kernel-6.12` → `build/kernel-6.12/lib/modules/<ver>/`
5. `build/kernel-6.12/bzImage` + `info` file

## 2. Config philosophy (yo hi important part)

| | kya | kyu |
|---|---|---|
| **built-in `=y`** | `BLK_DEV_LOOP`, `SQUASHFS`(+`ZSTD`,`LZ4`,`XOR`), `OVERLAY_FS`, `EXT4_FS`, `ISO9660_FS`, `VFAT_FS`, `PARTITION_ADVANCED`, `VT`/`VT_CONSOLE`/`SERIAL_8250_CONSOLE`, `TMPFS` | root mount karne wale features — agar inhe module banaya to initramfs me manually load karne padte hain aur ek bhi miss ho gaya to `BOOT FAIL` |
| **module `=m`** | NIC/Wi-Fi/GPU/sound, exotic FS (`btrfs`, `xfs`, `ntfs3`, `exfat`, `f2fs`), extra storage (`mmc`, `ufs`, `aacraid`…) | hardware-specific — live `/lib/modules` me rehte hain, on-demand load |
| **off** | `DEBUG_INFO`, `DEBUG_INFO_BTF`, `KASAN`, `LOCKUP_DETECTOR` | build 3x tez, kernel chhota |
| `MODULE_COMPRESS_XZ` + `MODULE_DECOMPRESS` | modules `.ko.xz` | image size ~40% kam |

Customize: `scripts/build-kernel` me `CFG_ENABLE` / `CFG_DISABLE` lists hain.
Interactive config ke liye:

```sh
cd build/linux-6.12 && make nconfig     # phir scripts/build-kernel dobara (make -j..)
```

Ek cheez ka dhyaan: **`scripts/config` ke unknown symbol silently skip** ho jaate hain
(is script me per-option `|| true` hai), isliye naya option add karne ke baad check karo:

```sh
grep CONFIG_SQUASHFS= build/linux-6.12/.config          # =y chahiye
```

## 3. ISO me apna kernel daalna

```sh
make clean-rootfs                    # host kernel ke modules cache se hatao
make iso PK_KERNEL=build/kernel-6.12/bzImage \
         PK_MODULES=build/kernel-6.12/lib/modules/6.12.0
```

- `PK_MODULES` ka **basename hi `/lib/modules/<ver>` ka naam banta hai** — wo kernel ke
  `uname -r` se match karna chahiye, warna live me `modprobe` kuch load nahi karega.
  (`build/kernel-*/info` me version likha aata hai.)
- initramfs ke modules `init/kernel-modules` list se aate hain; `build-kernel` un features
  ko built-in bana deta hai, isliye `/mods` almost khaali rahega ✓ (ye expected hai).
- Firmware chahiye (Wi-Fi/GPU) to host pe `firmware-misc-nonfree` install karke
  `make iso PK_FIRMWARE=1`.

## 4. Verify

```sh
make test                                        # pura QA (apne kernel ke saath)
# ya boot ke baad guest me:
uname -r                # apna version aana chahiye
pk-info              # kernel=<uname -r> line
lsmod | head
dmesg | grep -iE 'error|warn' | head
```

Boot fail ho to sabse common reason: kernel ne console register hi nahi kiya
(`CONFIG_VT_CONSOLE` / `CONFIG_SERIAL_8250_CONSOLE` off) — screen black aur serial khaali.
Recover: GRUB me `e` dabakar `linux` line me `console=tty0 console=ttyS0,115200` add karo.

## 5. Kernel command line knobs (pk's OS wale)

| param | kaam |
|---|---|
| `quiet loglevel=3` | default (config/live.conf → `KERNEL_CMDLINE`) |
| `pk_debug` | init + pk-boot verbose (`set -x`) |
| `break=mount` | root mount se pehle initramfs shell |
| `single` | single-user (no getty spawn) |
| `toram` | image RAM me copy, fir media nikaal lo |
| `persistent[=LABEL]` | changes `PK-PERSIST` partition pe (QA: stage 6) |
| `pk_media=/dev/sdb` | live image sirf is device pe dhoondo |
| `pk_install=auto\|/dev/vdb\|ask` | install at boot |
| `pk_silent` | installer output file me (`/run/pk-install.log`) |
| `pk_halt` | install ke baad poweroff |
| `pk_net=dhcp` | boot pe NIC driver modprobe + DHCP (`pk-net` log: `/var/log/pk-net.log`) |
| `pk_ssh=on\|off` | boot pe dropbear :22 chalu/band (live me default off) |
| `pk_autologin` | installed system me bhi autologin (kiosk/testing) |
| `pk_rootpw=...` | install ka root password |
| `pk_selftest` | boot ke baad self test + markers |
| `pk_poweroff` | self test ke baad turant poweroff (QA ke liye) |
| `root=UUID=...` | **installed** mode (init khud resolve karta hai — `root=UUID=` ko kernel akela nahi samajhta jab initramfs ho) |

## 6. Real kernel + QEMU (fast iteration)

```sh
K=$PWD/build/kernel-6.12/bzImage; I=$PWD/build/work/iso/boot/pk-initrd
qemu-system-x86_64 -machine q35 -accel kvm -m 2048 -smp 2 \
  -kernel $K -initrd $I \
  -append "console=ttyS0 loglevel=7 pk_debug" \
  -drive file=$PWD/build/pkos.iso,if=virtio,readonly=on \
  -nographic
```
Direct kernel boot me GRUB skip hota hai — initramfs/init debug karne ki sabse tez
raasta. (Initrd me `/init` update karne ke baad `make initrd` phir se chalana.)
