#!/bin/sh
# pk's OS :: ISO -> USB pendrive (hybrid dd)
#
#   tools/write-usb.sh /dev/sdX [iso]
#   make usb USB=/dev/sdX
#
# kya hota hai:
#   - ISO hybrid hai (isohybrid MBR + protective GPT + El Torito) -> same file
#     BIOS aur UEFI dono se boot karti hai, aur dd se seedha USB pe likhi jaati hai.
#   - USB ka purana data MIT jaata hai. Isliye pehle confirm + safety checks.
#   - persistence chahiye to baad me 'pk-persist' (live system me) ya
#     docs/PERSISTENCE.md wale commands use karo - likhne ke baad extra partition.
# shellcheck shell=sh disable=SC3030,SC2086
set -eu

log()  { printf '\033[1;36m[usb]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[usb warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[usb FAIL]\033[0m %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

PK_ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEV=${1:-}
ISO=${2:-$PK_ROOT/build/pkos.iso}
FORCE=0
[ "${PK_USB_FORCE:-0}" = 1 ] && FORCE=1

case "$DEV" in
  "") echo "usage: $0 /dev/sdX [iso]     (ya: make usb USB=/dev/sdX)"; exit 2 ;;
  /dev/*) : ;;
  *) die "device /dev/.. hona chahiye (jaise /dev/sdb). Partition nahi - /dev/sdb1 NAHI." ;;
esac
[ -b "$DEV" ] || die "$DEV block device nahi hai. 'lsblk' se sahi naam dekho."
[ -f "$ISO" ] || die "ISO nahi mila: $ISO  (make iso chalao)"

# --- safety: root chahiye (ya sudo)
if [ "$(id -u)" != 0 ] && ! have sudo; then
  die "root ya sudo chahiye (disk pe likhne ke liye). Try: sudo $0 $DEV $ISO"
fi

# --- safety: system disk pe likh rahe ho?
REAL=$(readlink -f "$DEV")
NAME=${REAL##*/}
HINT=$(cat "/sys/block/$NAME/device/model" 2>/dev/null || true)
SZGiB=$(( $(cat "/sys/block/$NAME/size") / 2097152 ))
MOUNTS=$( (findmnt -rn -o TARGET "$DEV" 2>/dev/null || grep "^/dev/$NAME" /proc/mounts) | tr '\n' ' ' || true)
CHILDMOUNTS=""
for p in /sys/block/$NAME/${NAME}*; do
  [ -b "/dev/${p##*/}" ] || continue
  m=$(grep "^/dev/${p##*/} " /proc/mounts 2>/dev/null | awk '{print $2}' | tr '\n' ' ' || true)
  [ -n "$m" ] && CHILDMOUNTS="$CHILDMOUNTS /dev/${p##*/}:$m"
done
if [ -n "$MOUNTS" ] || [ -n "$CHILDMOUNTS" ]; then
  die "$DEV (ya uska partition) mounted hai: ${MOUNTS}${CHILDMOUNTS}
   Pehle unmount karo: sudo umount -R $DEV   (APNI disk pe write karne se pehle ruk jao)"
fi
if grep -q " $REAL" /etc/crypttab 2>/dev/null || ls /sys/block/$NAME/slaves >/dev/null 2>&1; then
  [ "$FORCE" = 1 ] || die "$DEV kisi md/lvm/crypto ka hissa lag raha hai. Sure ho to PK_USB_FORCE=1 do."
fi
if [ "$SZGiB" -gt 0 ] && [ "$SZGiB" -lt 1 ] && [ "$FORCE" != 1 ]; then
  die "$DEV ka size ${SZGiB}GiB - 1GB se chhota, ye card-reader/card lagta hai. Sure ho to PK_USB_FORCE=1"
fi

echo
echo "  device : $DEV ($REAL)  ${SZGiB}GiB  ${HINT:-model?}"
echo "  iso    : $ISO ($(du -h "$ISO" | cut -f1))"
echo "  !! $DEV ka maujooda data delete ho jaayega (poora disk)."
echo
if [ -t 0 ] && [ "$FORCE" != 1 ]; then
  printf "  likhne ke liye  YES  type karo: "; read -r ans
  [ "$ans" = "YES" ] || die "cancel kiya (kuch nahi likha)"
fi

# --- unmount (agar kuch toot-futa mounted ho) & write
for p in /sys/block/$NAME/${NAME}*; do
  [ -b "/dev/${p##*/}" ] && umount "/dev/${p##*/}" 2>/dev/null || true
done
umount "$DEV" 2>/dev/null || true

log "dd chal raha hai (bs=4M, sync) - ${SZGiB}GiB disk pe 1-3 min lag sakte hain"
if have sudo && [ "$(id -u)" != 0 ]; then
  sudo dd if="$ISO" of="$REAL" bs=4M status=progress oflag=sync || die "dd fail"
else
  dd if="$ISO" of="$REAL" bs=4M status=progress oflag=sync || \
    dd if="$ISO" of="$REAL" bs=4M conv=fsync || die "dd fail"
fi
sync
if have blockdev; then blockdev --flushbufs "$REAL" 2>/dev/null || true; fi
# read-back bhi usi privilege se karo jo write me use hui (warna /dev/sdX padhne par
# permission denied -> "match nahi hua" ka jhootha warning)
rd() { # <bytes-KiB> <file> -> us size ka sha256
  if [ "$(id -u)" != 0 ] && have sudo; then
    sudo dd if="$2" bs=1024 count="$1" 2>/dev/null | sha256sum | cut -d" " -f1
  else
    dd if="$2" bs=1024 count="$1" 2>/dev/null | sha256sum | cut -d" " -f1
  fi
}
log "verify: ISO ka pehla 64KB disk se match karna chahiye"
a=$(rd 64 "$ISO"); b=$(rd 64 "$REAL")
if [ "$a" = "$b" ]; then
  log "OK - 64KB header match ✓ (boot record sahi jaaga pe hai)"
else
  warn "header match nahi hua - USB boot na kare. Dobara likho ya doosra USB try karo."
fi
echo
log "tayyar. Boot karne ke liye:"
log "  1) PC reset karo, boot menu (F12/F8/F2 ya Esc) se USB select karo"
log "  2) Secure Boot ON ho to pehle OFF karo (pk's OS signed nahi hai)"
log "  3) Live login: root / pk   (permanent install: pk-install --target=auto)"
log "persistence: docs/PERSISTENCE.md"
