#
#  Copyright (C) 2021 Gaël PORTAY
#
# SPDX-License-Identifier: LGPL-2.1-or-later
#

CMDLINE	?=
UMLFLAGS ?=

.PHONY: all
all:

.PHONY: runuml
runuml: UMLFLAGS+=initrd=initramfs.cpio
runuml: initramfs.cpio

ifneq (,$(CMDLINE))
runuml: UMLFLAGS+=$(CMDLINE)
endif

runuml: UMLFLAGS+=mem=256M console=tty0 con0=fd:0,fd:1 con=none
runuml:
	vmlinux $(UMLFLAGS)

# ex: filetype=make
