# pk's OS - chhota Linux OS jo live USB se chale aur disk pe install bhi ho jaye.
#
#   make doctor      dependencies check (kya install karna hai wo btayega)
#   make iso         build/pkos.iso banao
#   make run         QEMU (BIOS) me live boot  -> terminal me console
#   make run-efi     QEMU (UEFI/OVMF) me live boot
#   make test        end-to-end auto test: live boot -> disk pe install -> installed boot
#   make usb USB=/dev/sdX   ISO ko pendrive pe likh do (dd)
#   make kernel      apna custom kernel banao (optional, slow)
#   make clean       build/ delete
#
# User se build hota hai; jis step ko root chahiye (losetup/depmod) wo khud sudo leta hai.

SHELL       := /bin/bash
export PK_ROOT := $(CURDIR)
BUILD       := $(PK_ROOT)/build
WORK        := $(BUILD)/work
STAMP       := $(WORK)/.stamps
OUT         ?= $(BUILD)/pkos.iso
export OUT
ISO         := $(OUT)
TESTDISK    := $(BUILD)/testdisk.img

# ---- knobs (command line se override karo) --------------------------------
SUDO          ?= sudo
QEMU          ?= qemu-system-x86_64
PK_KERNEL  ?=
PK_MODULES ?=
PK_BUSYBOX ?=
SQUASH_COMP   ?= auto
KERNEL_CMDLINE?= quiet loglevel=3
PK_QEMU_MEM?= 2048
export SUDO QEMU PK_KERNEL PK_MODULES PK_BUSYBOX SQUASH_COMP KERNEL_CMDLINE PK_QEMU_MEM

SRC := $(shell find $(PK_ROOT)/rootfs $(PK_ROOT)/scripts $(PK_ROOT)/init $(PK_ROOT)/config -type f 2>/dev/null | tr '\n' ' ')

.PHONY: all help doctor live squash initrd iso runtime run run-tty run-iso run-efi test test-live test-apps usb kernel clean clean-rootfs clean-runtime deepclean rootfs

all: iso

help:
	@echo "pk's OS build system - targets:"
	@echo "  make doctor     dependencies check"
	@echo "  make iso        --> $(ISO)"
	@echo "  make run        QEMU me live boot (headless pe serial + direct kernel boot)"
	@echo "  make run-iso    QEMU me pura ISO+GRUB boot (display chahiye)"
	@echo "  make run-efi    QEMU me UEFI live boot"
	@echo "  make test       auto end-to-end test (live + install + installed boot + apps)"
	@echo "  sudo make runtime   # App Runtime (Debian squashfs) -> build/pk-runtime.sqfs"
	@echo "                      # VARIANT=lean|full|dev  PKGS=wine,firefox-esr"
	@echo "  make iso WITH_RUNTIME=1   # runtime ISO ke andar (/live/pk-runtime.sqfs)"
	@echo "  make test-apps    apps layer ka QA (14 checks; REAL_RUNTIME=1 / WINE=1 bhi)"
	@echo "                      # PK_TEST_REAL_RUNTIME=1 make test-apps  (asli Debian se)"
	@echo "                      # boot option: pk_runtime=off|auto|<dev|file>  pk_apps_get=<pkg>"
	@echo "  make usb USB=/dev/sdX    ISO ko USB pe dd"
	@echo "  make kernel     apna kernel banao (build/kernel-<ver>), phir:"
	@echo "                      make clean-rootfs && make iso PK_KERNEL=... PK_MODULES=..."
	@echo "  make clean"

doctor:
	@scripts/doctor.sh

# ---------------------------------------------------------------- stages
rootfs live: $(STAMP)/rootfs

$(STAMP)/rootfs: $(SRC)
	@mkdir -p $(STAMP) $(WORK)
	@scripts/build-rootfs
	@touch $@

squash: $(STAMP)/squash
$(STAMP)/squash: $(STAMP)/rootfs
	@mkdir -p $(STAMP)
	@scripts/mk-squashfs
	@touch $@

initrd: $(STAMP)/initrd
$(STAMP)/initrd: $(STAMP)/rootfs $(PK_ROOT)/init/init $(PK_ROOT)/init/kernel-modules
	@mkdir -p $(STAMP)
	@scripts/mk-initrd
	@touch $@

# app runtime: build/pk-runtime.sqfs (+ rw img) - Linux/Windows apps ke liye
runtime:
	@sh scripts/make-runtime $(if $(strip $(VARIANT)),--variant=$(VARIANT),) $(if $(strip $(PKGS)),--pkgs=$(PKGS),)
clean-runtime:
	@rm -f $(BUILD)/pk-runtime.sqfs $(BUILD)/pk-runtime-rw.img
	@echo "runtime images hataye (make runtime se dobara ban jayenge)"

iso: $(ISO)
$(ISO): $(STAMP)/squash $(STAMP)/initrd
	@scripts/mk-iso
	@touch $@

# rootfs ko refresh karo (config/live.conf ya kernel badalne ke baad)
clean-rootfs:
	@rm -f $(STAMP)/rootfs $(STAMP)/squash $(STAMP)/initrd
	@echo "stamps cleared - agla 'make iso' rootfs dobara banayega"

# ---------------------------------------------------------------- run / test
run: iso
	@scripts/run-qemu.sh -iso $(ISO) -tty -auto

run-tty: iso
	@scripts/run-qemu.sh -iso $(ISO) -tty

run-iso: iso
	@scripts/run-qemu.sh -iso $(ISO) -tty

run-efi: iso
	@scripts/run-qemu.sh -iso $(ISO) -tty -uefi

test-apps: iso
	@PK_TEST_STAGES=7 $(MAKE) test

test: iso
	@scripts/run-test.sh $(ISO) $(TESTDISK)

test-live: iso
	@PK_TEST_SKIP_INSTALL=1 scripts/run-test.sh $(ISO) $(TESTDISK)

# ---------------------------------------------------------------- USB
usb:
	@test -n "$(USB)" || { echo "usage: make usb USB=/dev/sdX  (poora device, partition nahi)"; exit 1; }
	@tools/write-usb.sh $(USB) $(ISO)

# ---------------------------------------------------------------- optional custom kernel
kernel:
	@scripts/build-kernel

clean:
	@rm -rf $(WORK) $(ISO) $(TESTDISK) $(BUILD)/*.log $(BUILD)/test-logs
	@echo "build/work aur build/*.iso delete ho gaye"

deepclean: clean
	@rm -rf $(BUILD)
	@echo "pura build/ delete"
