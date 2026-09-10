# pk's OS (live session)

Turant yaad rakhne layak commands:

    pk-help     ye file
    pk-info     boot mode, disk, network, modules - sab kuch
    pk-net dhcp IP lo (udhcpc)
    pk-ssh start SSH server (dropbear) - phir network se login
    pk-install  internal disk pe permanent install
    pk-persist  boot USB pe persistence partition banao
    dmesg          kernel log
    vi             text editor (busybox)

## Apps chalana (Linux / Windows)
Base image chhota hai (busybox), isliye "koi bhi app" ke liye **App Runtime**
joda gaya hai: Debian userland ki squashfs jo `/opt/pk` par overlay ke saath mount
hoti hai. Runtime laga ho to:

    pk-run ./binary | ./script.sh | ./app.deb | ./Setup.exe | ./app.jar | ./App.app
    pk-run --info ./file        # sirf type batao (elf/deb/win/apk/mach-o/...)
    pk-run --install ./app.deb  # dpkg ho to wahi, warna extract + launcher
    pk-run --list             # installed apps + runtime ka haal
    pk-shell                    # runtime ke andar shell (apt/dpkg wahan hain)
    pk-get install -y htop wine # net chahiye: pk-net dhcp
    pk-chroot /usr/bin/htop     # ek command runtime ke andar
    pk-x start weston           # GUI apps ke liye display
    pk-vm new win --size=40G    # guest VM (Windows / Android-x86 / macOS)

`.apk` (Android) aur macOS `.app`/Mach-O native nahi chalte — `pk-run` unpe exact
wajah + aage ka raasta batata hai (Waydroid/binderfs, ya `pk-vm` guest). Runtime
na laga ho to `pk-runtime status` aur `pk-info` me dikhaata hai; banane ke liye
host PC par `sudo make runtime` (details: repo ke docs/APPS.md me).

## Live session kaise kaam karta hai
- `live/pk.sqfs` (read-only squashfs) boot medium se loop-mount hota hai.
- Uske upar ek **overlay** lagta hai jiska upper layer tmpfs (RAM) hai.
  Matlab: `/etc`, `/root`, `/home` sab likhne layak hain, par reboot pe sab reset.
- `persistent` boot option se upper layer ek ext4 partition
  (label `PK-PERSIST`) pe chala jaata hai - changes USB pe save rehte hain.
- `toram` se poori image RAM me copy ho jaati hai - phir USB nikaal lo, system chalta rahega.

## Login
- live boot = auto-login (koi password nahi). Prompt dikhe to: `root` / `pk`
- installed boot = login chahiye (password installer me set kiya tha; default `pk`)

## Keyboard / console font
    loadkmap < /path/to/map.kmap        # keymap
    pk-info                          # system report

## Disk pe install
    pk-install --info                # kaunsi disk milegi (kuch nahi chheda)
    pk-install                         # interactive (confirm maangega)
    pk-install --target=/dev/sda --yes # headless (test/automation)

Layouts: `--layout=hybrid` (default: GPT + BIOS + UEFI), `--layout=efi`, `--layout=bios`.
