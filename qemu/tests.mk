#
#  Copyright (C)      2019 Gaël PORTAY
#                2017-2018 Savoir-Faire Linux Inc.
#
# SPDX-License-Identifier: LGPL-2.1-or-later
#

.PHONY: all
all:

.PHONY: clean
clean: initramfs_clean

.PHONY: mrproper
mrproper: initramfs_mrproper

include cukinia.mk

initramfs.cpio: ramfs/etc/cukinia/cukinia.conf ramfs/usr/bin/cukinia

ramfs/etc/cukinia/cukinia.conf: cukinia.conf
	install -D -m 644 $< $@

ramfs/usr/bin/cukinia: cukinia/cukinia
	install -D -m 755 $< $@

# ex: filetype=make
