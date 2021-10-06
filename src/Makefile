#
#  Copyright (C) 2021 Gaël PORTAY
#
# SPDX-License-Identifier: LGPL-2.1-or-later
#

.PHONY: all
all: tini

tini: override CFLAGS+=-Wall -Wextra -Werror
tini: override LDFLAGS+=-static

.PHONY: clean
clean:
	rm -f tini *.o
