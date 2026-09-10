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

## Pendrive / hardware test (ek command me)
    pk-check --save          # net, USB speed, disks, DRM/KMS, KVM, SecureBoot, runtime,
                             # wine, dmesg errors...  report: /run/pk/check.txt
    pk-check --gui           # desktop utha ke X client round-trip bhi test
    pk-check --all           # sab (verbose + save + apps battery + speed)
    pk-run --selftest        # app dispatch battery (ELF/.deb/.exe/AppImage/jar/rpm/iOS/apk)
  Kuch FAIL dikhe to /run/pk/check.txt + `dmesg | grep PK` hi kaafi hai debug ke liye.

## GUI
    pk-desktop               # weston (KMS) -> na ho to Xvfb fallback, + terminal
    pk-desktop app htop      # koi GUI app session me
    pk-x status              # display server ka haal (log: /run/pk/x.log)
    pk-get install -y weston xterm xvfb x11-utils   # runtime me GUI tools

## iOS / Android apps (sach + raaste)
    pk-ios why               # iOS app Linux par native kyun nahi chalti (Mach-O + UIKit)
    pk-ios info ./App.ipa    # .ipa kholke: bundle id, arch, min iOS
    pk-ios web https://...   # iOS-only *service* ko desktop launcher bana do
    pk-ios mac-guest         # QEMU macOS guest + Xcode iOS Simulator ka recipe
    pk-android doctor        # .apk ke liye binderfs/waydroid ka haal
    pk-android kernel-frag   # apne kernel me ye config lines daalo

## Keyboard / console font
    pk-keymap in             # layout: console (loadkmap) + GUI (setxkbmap)
                             # (console maps builder ke /usr/share/keymaps se aate hain;
                             #  na ho to GUI wala hissa hi chalega)
    loadkmap < /path/to/map.kmap        # manually bhi kar sakte ho
    pk-info                  # system report

## Disk pe install
    pk-install --info                # kaunsi disk milegi (kuch nahi chheda)
    pk-install                         # interactive (confirm maangega)
    pk-install --target=/dev/sda --yes # headless (test/automation)
    pk-install --target=auto --user=ramesh --user-password=Secret   # user + home bhi
    # app runtime installed system me copy ho jaati hai (/var/lib/pk) + uski rw image,
    # isliye installed boot par bhi apps + apt + persistence chalti hain

Layouts: `--layout=hybrid` (default: GPT + BIOS + UEFI), `--layout=efi`, `--layout=bios`.
