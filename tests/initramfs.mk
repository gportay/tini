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

initramfs.cpio: rootfs 

rootfs rootfs/dev rootfs/proc rootfs/sys rootfs/etc rootfs/root rootfs/var rootfs/tmp:
	mkdir -p $@

rootfs/init rootfs/linuxrc:
	ln -sf /bin/sh $@

rootfs/dev/initrd: | rootfs/dev
	fakeroot -i rootfs.env -s rootfs.env -- mknod -m 400 $@ b 1 250

rootfs/dev/console: | rootfs/dev
	fakeroot -i rootfs.env -s rootfs.env -- mknod -m 622 $@ c 5 1

rootfs/etc/passwd: | rootfs/etc
	echo "root::0:0:root:/root:/bin/sh" >$@
	echo "tini::1000:1000:tini user:/home/tini:/bin/sh" >>$@

rootfs/etc/group: | rootfs/etc
	echo "root:x:0:root" >$@
	echo "tini:x:1000:tini" >>$@

initramfs.cpio.gz:

initramfs.cpio: | rootfs/proc rootfs/sys rootfs/tmp
initramfs.cpio: rootfs/bin/busybox rootfs/dev/console

include tini.mk
include tests.mk

initramfs.cpio: rootfs/etc/passwd rootfs/etc/group | rootfs/root

%.cpio:
	cd $< && find . | \
	fakeroot -i $(CURDIR)/rootfs.env -s $(CURDIR)/rootfs.env -- \
	cpio -H newc -o -R root:root >$(CURDIR)/$@

%.gz: %
	gzip -9 $*

.PHONY: initramfs_clean
initramfs_clean:
	rm -Rf rootfs/ rootfs.env
	rm -f initramfs.cpio

.PHONY: initramfs_mrproper
initramfs_mrproper:

# ex: filetype=make
