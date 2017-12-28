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

CMDLINE	?=

# Enable console on 8250/16550 and compatible serial port
LINUX_CONFIGS	+= CONFIG_TTY=y
LINUX_CONFIGS	+= CONFIG_SERIAL_8250=y
LINUX_CONFIGS	+= CONFIG_SERIAL_8250_CONSOLE=y

# Enable VGA 16-color graphics support
LINUX_CONFIGS	+= CONFIG_FB=y
LINUX_CONFIGS	+= CONFIG_FB_VGA16=y

# Enable VESA VGA graphics support
LINUX_CONFIGS	+= CONFIG_FB_VESA=y

# Enable framebuffer console support
LINUX_CONFIGS	+= CONFIG_FRAMEBUFFER_CONSOLE=y

# Enable and select frame buffer bootup logos.
LINUX_CONFIGS	+= CONFIG_LOGO=y
LINUX_CONFIGS	+= CONFIG_LOGO_LINUX_MONO=n
LINUX_CONFIGS	+= CONFIG_LOGO_LINUX_VGA16=n
LINUX_CONFIGS	+= CONFIG_LOGO_LINUX_CLUT224=n
LINUX_CONFIGS	+= CONFIG_LOGO_CUSTOM_MONO=y
LINUX_CONFIGS	+= CONFIG_LOGO_CUSTOM_VGA16=y
LINUX_CONFIGS	+= CONFIG_LOGO_CUSTOM_CLUT224=y
LINUX_CONFIGS	+= CONFIG_LOGO_CUSTOM_GRAY256=n

.PHONY: all
all:

include initramfs.mk
include kernel.mk

.PHONY: runqemu
runqemu:

runqemu: KERNELFLAG=-kernel bzImage
runqemu: bzImage

runqemu: INITRDFLAG=-initrd initramfs.cpio
runqemu: initramfs.cpio

ifneq (,$(CMDLINE))
runqemu: APPENDFLAG=-append "$(CMDLINE)"
endif

runqemu: QEMUFLAGS?=-serial stdio
runqemu:
	qemu-system-$(shell uname -m) $(KERNELFLAG) $(INITRDFLAG) $(APPENDFLAG) $(QEMUFLAGS)

