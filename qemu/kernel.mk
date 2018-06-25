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
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# Enable 64-bits support for x86 target
ifeq (x86_64,$(shell uname -m))
LINUX_CONFIGS	+= CONFIG_64BIT=y
endif

# Enable printk support for traces
LINUX_CONFIGS	+= CONFIG_PRINTK=y
LINUX_CONFIGS	+= CONFIG_EARLY_PRINTK=y

.PHONY: all
all:

.PHONY: download
download: linux_download

.PHONY: clean
clean: kernel_clean

.PHONY: mrproper
mrproper: kernel_mrproper

bzImage: linux/arch/x86/boot/bzImage
	cp $< $@

.SILENT: linux/arch/x86/boot/bzImage
linux/arch/x86/boot/bzImage: linux/.config
	$(MAKE) -C linux $(@F)

.SILENT: linux/.config
linux/.config: linux/Makefile kernel.cfg
	yes | $(MAKE) -C linux tinyconfig
	cd linux && scripts/kconfig/merge_config.sh $(@F) $(CURDIR)/kernel.cfg

.SILENT: linux/Makefile
linux/Makefile:
	echo "You need to provide your own kernel sources into the $(CURDIR)/$(@D) directory!" >&2
	echo "Have a look at https://www.kernel.org! or run one of the commands below:" >&2
	echo "$$ git clone git@github.com:torvalds/linux.git $(CURDIR)/$(@D)" >&2
	echo "or" >&2
	echo "$$ $(MAKE) $(@D)_download" >&2
	exit 1

.SILENT: linux_download
linux_download:
	wget -qO- https://www.kernel.org/index.html | \
	sed -n '/<td id="latest_link"/,/<\/td>/s,.*<a.*href="\(.*\)">\(.*\)</a>.*,wget -qO- \1 | tar xvJ \&\& ln -sf linux-\2 linux,p' | \
	$(SHELL)

.PHONY: linux_source
linux_source:
	git clone --single-branch git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git linux

kernel.cfg:
	for cfg in $(LINUX_CONFIGS); do \
		echo $$cfg; \
	done >$@

.PHONY: kernel_clean
kernel_clean:
	rm -f kernel.cfg bzImage

.PHONY: kernel_mrproper
kernel_mrproper: kernel_clean
	-$(MAKE) -C linux distclean

.PHONY:
kernel: bzImage

linux_menuconfig:
linux_%:
	$(MAKE) -C linux $*

# ex: filetype=makefile
