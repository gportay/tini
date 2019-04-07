#
#  Copyright (C) 2018-2019 Gaël PORTAY
#                2017-2018 Savoir-Faire Linux Inc.
#
# SPDX-License-Identifier: LGPL-2.1-or-later
#

# Enable initramfs/initrd support
LINUX_CONFIGS	+= CONFIG_BLK_DEV_INITRD=y
LINUX_CONFIGS	+= CONFIG_BLK_DEV_RAM=y

# /proc file system support
LINUX_CONFIGS	+= CONFIG_PROC_FS=y

# Posix Clocks & timers
LINUX_CONFIGS	+= CONFIG_POSIX_TIMERS=y

.PHONY: all
all:

.PHONY: clean
clean: initramfs_clean

.PHONY: mrproper
mrproper: initramfs_mrproper

include busybox.mk

initramfs.cpio: ramfs

ramfs ramfs/dev ramfs/proc ramfs/sys ramfs/etc ramfs/root ramfs/var:
	mkdir -p $@

ramfs/init ramfs/linuxrc:
	ln -sf /bin/sh $@

ramfs/dev/initrd: | ramfs/dev
	fakeroot -i ramfs.env -s ramfs.env -- mknod -m 400 $@ b 1 250

ramfs/dev/console: | ramfs/dev
	fakeroot -i ramfs.env -s ramfs.env -- mknod -m 622 $@ c 5 1

ramfs/etc/passwd: | ramfs/etc
	echo "root::0:0:root:/root:/bin/sh" >$@
	echo "tini::1000:1000:tini user:/home/tini:/bin/sh" >>$@

ramfs/etc/group: | ramfs/etc
	echo "root:x:0:root" >$@
	echo "tini:x:1000:tini" >>$@

initramfs.cpio.gz:

initramfs.cpio: | ramfs/proc ramfs/sys
initramfs.cpio: ramfs/bin/busybox ramfs/dev/console

include tini.mk
include tests.mk

initramfs.cpio: ramfs/etc/passwd ramfs/etc/group | ramfs/root

%.cpio:
	cd $< && find . | \
	fakeroot -i $(CURDIR)/ramfs.env -s $(CURDIR)/ramfs.env -- \
	cpio -H newc -o -R root:root >$(CURDIR)/$@

%.gz: %
	gzip -9 $*

.PHONY: initramfs_clean
initramfs_clean:
	rm -Rf ramfs/ ramfs.env
	rm -f initramfs.cpio

.PHONY: initramfs_mrproper
initramfs_mrproper:

# ex: filetype=make
