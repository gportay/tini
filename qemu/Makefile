#
#  Copyright (C)      2019 Gaël PORTAY
#                2017-2018 Savoir-Faire Linux Inc.
#
#  Authors:
#      Gaël PORTAY <gael.portay@savoirfairelinux.com>
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
	shellcheck --exclude=SC2039 *.sh *.tini *.rcS

include runqemu.mk

all: kernel initramfs.cpio

# ex: filetype=makefile
