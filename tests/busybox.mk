#
#  Copyright (C) 2019,2021 Gaël PORTAY
#                2017-2018 Savoir-Faire Linux Inc.
#
# SPDX-License-Identifier: LGPL-2.1-or-later
#

# Enable ELF binary format support
LINUX_CONFIGS	+= CONFIG_BINFMT_ELF=y

.PHONY: all
all:

.PHONY: download
download: busybox_download

.PHONY: sources
sources: busybox_source

.PHONY: clean
clean: busybox_clean

.PHONY: mrproper
mrproper: busybox_mrproper

.PHONY: busybox
busybox: busybox/busybox

.SILENT: busybox/busybox
busybox/busybox: busybox/.config
	$(MAKE) -C busybox CONFIG_STATIC=y CC=musl-gcc LD=musl-gcc

.SILENT: busybox/.config
busybox/.config: busybox/Makefile
	yes "" | $(MAKE) -C busybox oldconfig

.SILENT: busybox/Makefile
busybox/Makefile:
	echo "You need to provide your own busybox sources into the $(CURDIR)/$(@D) directory!" >&2
	echo "Have a look at https://busybox.net! or run one of the commands below:" >&2
	echo "$$ git clone git://git.busybox.net/busybox.git $(CURDIR)/$(@D)" >&2
	echo "or" >&2
	echo "$$ $(MAKE) $(@D)_download" >&2
	exit 1

.SILENT: busybox_download
busybox_download:
	wget -qO- https://www.busybox.net | \
	sed -n '/<li><b>.* -- BusyBox .* (stable)<\/b>/,/<\/li>/{/<p>/s,.*<a.*href="\(.*\)">BusyBox \(.*\)</a>.*,wget -qO- \1 | tar xvj \&\& ln -sf busybox-\2 busybox,p}' | \
	head -n 1 | \
	$(SHELL)

.PHONY: busybox_source
busybox_source:
	git clone --single-branch git://git.busybox.net/busybox.git busybox

.SILENT: rootfs/bin/busybox
rootfs/bin/busybox: busybox/busybox
	$(MAKE) -C busybox install CONFIG_STATIC=y CC=musl-gcc LD=musl-gcc CONFIG_PREFIX=$(CURDIR)/rootfs/

.PHONY: busybox_clean
busybox_clean:

.PHONY: busybox_mrproper
busybox_mrproper:
	-$(MAKE) -C busybox distclean

busybox_menuconfig:
busybox_%:
	$(MAKE) -C busybox $*

# ex: filetype=make
