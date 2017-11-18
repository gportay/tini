#
#  Copyright (C) 2017 Savoir-Faire Linux Inc.
#
#  Authors:
#      Gaël PORTAY <gael.portay@savoirfairelinux.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 2.1 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

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

ramfs/sys:
	mkdir -p $@

initramfs.cpio: ramfs/sys
initramfs.cpio: ramfs/sbin/tini
initramfs.cpio: ramfs/sbin/halt ramfs/sbin/poweroff ramfs/sbin/reboot
initramfs.cpio: ramfs/sbin/spawn ramfs/sbin/zombize ramfs/sbin/re-exec

tini: override CFLAGS+=-Wall -Wextra -Werror
tini: override LDFLAGS+=-static

ramfs/sbin/tini: tini | ramfs/sbin
	install -D -m 755 $< $@

ramfs/sbin/halt ramfs/sbin/poweroff ramfs/sbin/reboot: ramfs/sbin/tini | ramfs/sbin
	ln -sf $(<F) $@

ramfs/sbin/spawn ramfs/sbin/zombize ramfs/sbin/re-exec: ramfs/sbin/tini | ramfs/sbin
	ln -sf $(<F) $@

