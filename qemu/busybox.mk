#
#  Copyright (C) 2017-2018 Savoir-Faire Linux Inc.
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

# Enable ELF binary format support
LINUX_CONFIGS	+= CONFIG_BINFMT_ELF=y

.PHONY: all
all:

.PHONY: download
download: busybox_download

.PHONY: clean
clean: busybox_clean

.PHONY: mrproper
mrproper: busybox_mrproper

.PHONY: busybox
busybox: busybox/busybox

.SILENT: busybox/busybox
busybox/busybox: busybox/.config
	echo "Compiling busybox..."
	$(MAKE) -C busybox CONFIG_STATIC=y

.SILENT: busybox/.config
busybox/.config: busybox/Makefile
	echo "Configuring busybox..."
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

.SILENT: ramfs/bin/busybox
ramfs/bin/busybox: busybox/busybox
	echo "Installing busybox..."
	$(MAKE) -C busybox install CONFIG_STATIC=y CONFIG_PREFIX=$(CURDIR)/ramfs/

.PHONY: busybox_clean
busybox_clean:

.PHONY: busybox_mrproper
busybox_mrproper:
	-$(MAKE) -C busybox distclean

busybox_menuconfig:
busybox_%:
	$(MAKE) -C busybox $*

