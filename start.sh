#!/bin/sh
KERNEL="arch/x86_64/boot/bzImage"
INITRD="initramfs.img"
APPEND="nokaslr console=ttyS0"
GDB_PORT="tcp::1234"
DEBUG_FLAG="-S"

qemu-system-x86_64 \
	-nographic -serial mon:stdio \
	-append "$APPEND" \
	-initrd "$INITRD" \
	-kernel "$KERNEL" \
	-gdb "$GDB_PORT" \
	$DEBUG_FLAG
