#
#  Copyright (C)      2019 Gaël PORTAY
#                2017-2018 Savoir-Faire Linux Inc.
#
# SPDX-License-Identifier: LGPL-2.1-or-later
#

-include custom.mk

.NOTPARALLEL:

.PHONY: all
all: override export CMDLINE+=rdinit=/sbin/tini vga=0x301
all: runqemu

.PHONY: verbose
verbose: override export CMDLINE+=rdinit=/sbin/tini --verbose
verbose: runqemu

.PHONY: debug
debug: override export CMDLINE+=rdinit=/sbin/tini --debug
debug: runqemu

.PHONY: runqemu
runqemu:
	$(MAKE) -C qemu $@

.PHONY: nographic
nographic: override export CMDLINE+=rdinit=/sbin/tini console=ttyS0
nographic: override export QEMUFLAGS+=-nographic -serial mon:stdio
nographic:
	$(MAKE) -C qemu runqemu

.PHONY: bootup-logo
bootup-logo: S=$(CURDIR)/qemu/linux
bootup-logo: 
	$(MAKE) -C qemu -f $@.mk
	echo export CMDLINE += vt.color=0xf0 >>custom.mk

.PHONY: menuconfig
menuconfig: qemu_linux_menuconfig

qemu_%:
	$(MAKE) -C qemu $*

.PHONY: doc
doc: tini.1.gz

.PHONY: clean check
clean check:
	$(MAKE) -C qemu $@

%.1: %.1.adoc
	asciidoctor -b manpage -o $@ $<

%.gz: %
	gzip -c $^ >$@

%:
	$(MAKE) -C qemu $@

