#!/bin/sh
# pk's OS build helpers (shared).  POSIX sh.
# shellcheck shell=sh
{ set +m 2>/dev/null || true; } 2>/dev/null

if [ -z "${PK_ROOT:-}" ]; then
  PK_ROOT=$(pwd); export PK_ROOT
fi
BUILD=${BUILD:-$PK_ROOT/build}
WORK=${WORK:-$BUILD/work}
LIVE=${LIVE:-$BUILD/live}
OUT=${OUT:-$BUILD/pkos.iso}
export BUILD WORK OUT
if [ -f "$PK_ROOT/config/live.conf" ]; then
  # shellcheck disable=SC1091
  . "$PK_ROOT/config/live.conf"
fi

log()  { printf '[pk] %s\n'  "$*"; }
warn() { printf '[pk warn] %s\n' "$*" >&2; }
die()  { printf '[pk ERROR] %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

SUDO=${SUDO:-sudo}
as_root() {
  if [ "$(id -u)" = 0 ]; then "$@"
  elif have sudo; then $SUDO "$@"
  elif have doas; then doas "$@"
  else die "root chahiye: $* (SUDO=... set kar sakte ho)"
  fi
}

# build tree ke andar hi rm -rf chalega
wipe() {
  case "${1:-}" in
    "") die "wipe: no arg" ;;
    "$BUILD"/*) rm -rf "${1:?}" ;;
    *) die "wipe refused: $1 (outside $BUILD)" ;;
  esac
}

find_host() { # basename -> pehla absolute path
  for d in /usr/bin /bin /usr/sbin /sbin /usr/local/bin /usr/local/sbin; do
    [ -e "$d/$1" ] && { printf '%s/%s\n' "$d" "$1"; return 0; }
  done
  return 1
}

# @TOKEN@ style substitution
subst() { # subst file TOKEN VALUE
  sed -e "s|@$1@|$2|g" "$3" > "$3.tmp" && mv "$3.tmp" "$3"
}

# tar ke liye mtime fix (reproducible image)
normalize_tree() { # dir
  [ -d "$1" ] || return 0
  find "$1" -exec touch -h -d "@0" {} + 2>/dev/null || true
}

# kernel + modules resolve:
#   PK_KERNEL + PK_MODULES do dena padega agar custom kernel use kar rahe ho
#   warna host ka sabse naya /boot/vmlinuz-* + /usr/lib/modules/<ver>
resolve_kernel() {
  if [ -n "${PK_MODULES:-}" ] && [ -n "${PK_KERNEL:-}" ]; then
    KERNEL=$PK_KERNEL
    KVER=$(basename "${PK_MODULES%/}")
    [ -d "$PK_MODULES" ] || die "PK_MODULES nahi hai: $PK_MODULES"
    [ -f "$KERNEL" ] || die "PK_KERNEL nahi hai: $KERNEL"
    export KERNEL KVER
    return 0
  fi
  if [ -n "${PK_MODULES:-}" ]; then
    KVER=$(basename "${PK_MODULES%/}")
    KERNEL=${PK_KERNEL:-}
    [ -n "$KERNEL" ] || KERNEL=$(ls -1 /boot/vmlinuz-"$KVER" 2>/dev/null | head -1)
    [ -n "$KERNEL" ] || die "PK_MODULES diya par kernel nahi mila (PK_KERNEL bhi do)"
    export KERNEL KVER
    return 0
  fi
  k=$(ls -1 /boot/vmlinuz-* 2>/dev/null | sort -V | tail -1)
  [ -n "$k" ] || die "/boot/vmlinuz-* nahi mila. Custom kernel: make kernel, phir PK_KERNEL=/PK_MODULES= do."
  KVER=${k##*/vmlinuz-}
  for m in "/usr/lib/modules/$KVER" "/lib/modules/$KVER"; do
    [ -d "$m" ] && { PK_MODULES=$m; break; }
  done
  [ -n "${PK_MODULES:-}" ] || die "$k ke liye /lib/modules/$KVER nahi mila (linux-headers/modules install karo)"
  KERNEL=$k
  export KERNEL KVER PK_MODULES
}
