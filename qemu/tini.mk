#
#  Copyright (C)      2018 Gaël PORTAY
#                2017-2018 Savoir-Faire Linux Inc.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 2.1 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
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

.PHONY: all
all:

ramfs/lib/tini/uevent/script: uevent.sh
	install -D -m 755 $< $@

initramfs.cpio: ramfs/lib/tini/uevent/script

ramfs/run ramfs/lib/tini/scripts:
	mkdir -p $@

ramfs/etc/init.d: | ramfs/etc ramfs/lib/tini/scripts
	ln -sf /lib/tini/scripts $@

ramfs/lib/tini/scripts/service: service.tini | ramfs/lib/tini/scripts
	install -D -m 644 $< $@

ramfs/lib/tini/scripts/%: %.tini | ramfs/lib/tini/scripts
	install -D -m 755 $< $@

ramfs/lib/tini/uevent/devname/console/sh: sh.tini
	install -D -m 755 $< $@

ramfs/lib/tini/uevent/devname/tty%/sh: sh.tini
	install -D -m 755 $< $@

initramfs.cpio: ramfs/lib/tini/uevent/devname/console/sh
initramfs.cpio: ramfs/lib/tini/uevent/devname/tty2/sh ramfs/lib/tini/uevent/devname/tty3/sh ramfs/lib/tini/uevent/devname/tty4/sh
initramfs.cpio: ramfs/lib/tini/scripts/rcS
initramfs.cpio: ramfs/lib/tini/scripts/service
initramfs.cpio: ramfs/lib/tini/scripts/sh
initramfs.cpio: ramfs/lib/tini/scripts/sleep
initramfs.cpio: ramfs/etc/init.d

initramfs.cpio: ramfs/run
initramfs.cpio: ramfs/sbin/tini
initramfs.cpio: ramfs/sbin/halt ramfs/sbin/poweroff ramfs/sbin/reboot
initramfs.cpio: ramfs/sbin/spawn ramfs/sbin/respawn ramfs/sbin/assassinate ramfs/sbin/zombize ramfs/sbin/re-exec

tini: override CFLAGS+=-Wall -Wextra -Werror
tini: override LDFLAGS+=-static

ramfs/sbin/tini: tini | ramfs/sbin
	install -D -m 755 $< $@

ramfs/sbin/halt ramfs/sbin/poweroff ramfs/sbin/reboot: ramfs/sbin/tini | ramfs/sbin
	ln -sf $(<F) $@

ramfs/sbin/spawn ramfs/sbin/respawn ramfs/sbin/assassinate ramfs/sbin/zombize ramfs/sbin/re-exec: ramfs/sbin/tini | ramfs/sbin
	ln -sf $(<F) $@

# ex: filetype=makefile
