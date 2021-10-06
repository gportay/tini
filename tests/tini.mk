#
#  Copyright (C) 2018-2019 Gaël PORTAY
#                2017-2018 Savoir-Faire Linux Inc.
#
# SPDX-License-Identifier: LGPL-2.1-or-later
#

# Kernel support for scripts starting with #!
LINUX_CONFIGS	+= CONFIG_BINFMT_SCRIPT=y

# Automount devtmpfs at /dev, after the kernel mounted the rootfs
LINUX_CONFIGS	+= CONFIG_DEVTMPFS=y
LINUX_CONFIGS	+= CONFIG_DEVTMPFS_MOUNT=y

# Unix domain sockets
LINUX_CONFIGS	+= CONFIG_NET=y
LINUX_CONFIGS	+= CONFIG_WIRELESS=n
LINUX_CONFIGS	+= CONFIG_UNIX=y

# sysfs file system support
LINUX_CONFIGS	+= CONFIG_SYSFS=y

# Multiple users, groups and capabilities support
LINUX_CONFIGS	+= CONFIG_MULTIUSER=y

.PHONY: all
all:

rootfs/lib/tini/uevent/script: uevent.sh
	install -D -m 755 $< $@

initramfs.cpio: rootfs/lib/tini/uevent/script

rootfs/run rootfs/lib/tini/scripts rootfs/lib/tini/event/rcS:
	mkdir -p $@

rootfs/var/run: | rootfs/run rootfs/var
	ln -sf /run $@

rootfs/etc/init.d: | rootfs/etc rootfs/lib/tini/scripts
	ln -sf /lib/tini/scripts $@

rootfs/lib/tini/scripts/%: %.tini | rootfs/lib/tini/scripts
	install -D -m 755 $< $@

rootfs/lib/tini/event/rcS/30syslogd: rootfs/lib/tini/scripts/syslogd
	ln -sf /lib/tini/scripts/$(<F) $@

rootfs/lib/tini/event/rcS/35klogd: rootfs/lib/tini/scripts/klogd
	ln -sf /lib/tini/scripts/$(<F) $@

rootfs/lib/tini/event/rcS/%: %.rcS
	install -D -m 755 $< $@

rootfs/lib/tini/uevent/devname/console/sh: rootfs/lib/tini/scripts/sh
	mkdir -p $(@D)
	ln -sf /lib/tini/scripts/sh $@

rootfs/lib/tini/uevent/devname/tty%/sh: rootfs/lib/tini/scripts/sh
	mkdir -p $(@D)
	ln -sf /lib/tini/scripts/sh $@

initramfs.cpio: rootfs/lib/tini/event/rcS/05mount
initramfs.cpio: rootfs/lib/tini/event/rcS/10coldplug
initramfs.cpio: rootfs/lib/tini/event/rcS/20hostname
initramfs.cpio: rootfs/lib/tini/event/rcS/30syslogd
initramfs.cpio: rootfs/lib/tini/event/rcS/35klogd
initramfs.cpio: rootfs/lib/tini/uevent/devname/console/sh
initramfs.cpio: rootfs/lib/tini/uevent/devname/tty2/sh rootfs/lib/tini/uevent/devname/tty3/sh rootfs/lib/tini/uevent/devname/tty4/sh
initramfs.cpio: rootfs/lib/tini/scripts/rcS
initramfs.cpio: rootfs/lib/tini/scripts/service
initramfs.cpio: rootfs/lib/tini/scripts/respawn
initramfs.cpio: rootfs/lib/tini/scripts/start-stop-daemon
initramfs.cpio: rootfs/lib/tini/scripts/sh
initramfs.cpio: rootfs/lib/tini/scripts/sleep
initramfs.cpio: rootfs/lib/tini/scripts/crond
initramfs.cpio: rootfs/lib/tini/scripts/syslogd
initramfs.cpio: rootfs/lib/tini/scripts/klogd
initramfs.cpio: rootfs/etc/init.d

initramfs.cpio: rootfs/var/run rootfs/lib/tini/event/rcS
initramfs.cpio: rootfs/bin/raise
initramfs.cpio: rootfs/sbin/tini
initramfs.cpio: rootfs/sbin/halt rootfs/sbin/poweroff rootfs/sbin/reboot
initramfs.cpio: rootfs/sbin/spawn rootfs/sbin/respawn rootfs/sbin/assassinate rootfs/sbin/status rootfs/sbin/zombize rootfs/sbin/re-exec

tini: override CFLAGS+=-Wall -Wextra -Werror
tini: override LDFLAGS+=-static

rootfs/bin/raise: raise.sh | rootfs/bin
	install -D -m 755 $< $@

rootfs/sbin/tini: tini | rootfs/sbin
	install -D -m 755 $< $@

rootfs/sbin/halt rootfs/sbin/poweroff rootfs/sbin/reboot: rootfs/sbin/tini | rootfs/sbin
	ln -sf $(<F) $@

rootfs/sbin/spawn rootfs/sbin/respawn rootfs/sbin/assassinate rootfs/sbin/status rootfs/sbin/zombize rootfs/sbin/re-exec: rootfs/sbin/tini | rootfs/sbin
	ln -sf $(<F) $@

# ex: filetype=make
