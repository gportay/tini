#
#  Copyright (C) 2017 Savoir-Faire Linux Inc.
#
#  Authors:
#      Gaël PORTAY <gael.portay@savoirfairelinux.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 2.1 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

.NOTPARALLEL:

.PHONY: all
all: runqemu

.PHONY: runqemu
runqemu:
	$(MAKE) -C qemu $@

.PHONY: nographic
nographic: override export CMDLINE+=console=ttyS0
nographic: override export QEMUFLAGS+=-nographic -serial mon:stdio
nographic:
	$(MAKE) -C qemu runqemu

.PHONY: clean
clean:
	$(MAKE) -C qemu $@

%:
	$(MAKE) -C qemu $@

