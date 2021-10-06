#
#  Copyright (C) 2019,2021 Gaël PORTAY
#                2017-2018 Savoir-Faire Linux Inc.
#
# SPDX-License-Identifier: LGPL-2.1-or-later
#

.NOTPARALLEL:

.PHONY: all
all:

.PHONY: download
download:

.PHONY: check
check:
	shellcheck --exclude=SC2039 --exclude=SC3037 --exclude=SC3043 --exclude=SC3057 *.sh *.tini *.rcS

include initramfs.mk
include runqemu.mk
include runuml.mk

ifeq ($(shell command -v vmlinux),)
all: runqemu
else
all: runuml
endif
