#
#  Copyright (C) 2019,2021 Gaël PORTAY
#                2017-2018 Savoir-Faire Linux Inc.
#
# SPDX-License-Identifier: LGPL-2.1-or-later
#

-include custom.mk

.NOTPARALLEL:

.PHONY: all
all:
	$(MAKE) -C src tini

.PHONY: runuml
runuml: override export CMDLINE+=rdinit=/sbin/tini
runuml:
	$(MAKE) -C tests $@

.PHONY: verbose
verbose: override export CMDLINE+=rdinit=/sbin/tini --verbose
verbose: runqemu

.PHONY: debug
debug: override export CMDLINE+=rdinit=/sbin/tini --debug
debug: runqemu

.PHONY: runqemu
runqemu: override export CMDLINE+=rdinit=/sbin/tini vga=0x301
runqemu:
	$(MAKE) -C tests $@

.PHONY: nographic
nographic: override export CMDLINE+=rdinit=/sbin/tini console=ttyS0
nographic: override export QEMUFLAGS+=-nographic -serial mon:stdio
nographic:
	$(MAKE) -C tests runqemu

.PHONY: vga-ask
vga-ask: override export CMDLINE=vga=ask
vga-ask: runqemu

.PHONY: bootup-logo
bootup-logo: S=$(CURDIR)/tests/linux
bootup-logo:
	$(MAKE) -C tests -f $@.mk

.PHONY: menuconfig
menuconfig: tests_linux_menuconfig

tests_%:
	$(MAKE) -C tests $*

.PHONY: doc
doc: tini.1.gz

.PHONY: test
test: override export CMDLINE+=rdinit=/sbin/tini
test:
	$(MAKE) -C tests

.PHONY: clean check
clean check:
	$(MAKE) -C tests $@

%.1: %.1.adoc
	asciidoctor -b manpage -o $@ $<

%.gz: %
	gzip -c $^ >$@

%:
	$(MAKE) -C tests $@

