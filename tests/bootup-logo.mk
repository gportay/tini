#
#  Copyright (C)      2019 Gaël PORTAY
#                2017-2018 Savoir-Faire Linux Inc.
#
# SPDX-License-Identifier: LGPL-2.1-or-later
#

S ?= linux
O ?= $(S)

.NOTPARALLEL:

.PHONY: all
all: $(S)/drivers/video/logo/logo_custom_mono.pbm \
     $(S)/drivers/video/logo/logo_custom_vga16.ppm \
     $(S)/drivers/video/logo/logo_custom_clut224.ppm \
     $(S)/drivers/video/logo/logo_custom_gray256.pgm \
     bootup-logo_clean
	sed -e '/obj-$$(CONFIG_LOGO)/aobj-$$(CONFIG_LOGO_CUSTOM_MONO)\t\t+= logo_custom_mono.o' \
	    -e '/obj-$$(CONFIG_LOGO)/aobj-$$(CONFIG_LOGO_CUSTOM_VGA16)\t\t+= logo_custom_vga16.o' \
	    -e '/obj-$$(CONFIG_LOGO)/aobj-$$(CONFIG_LOGO_CUSTOM_CLUT224)\t+= logo_custom_clut224.o' \
	    -e '/obj-$$(CONFIG_LOGO)/aobj-$$(CONFIG_LOGO_CUSTOM_GRAY256)\t+= logo_custom_gray256.o' \
	    -i $(S)/drivers/video/logo/Makefile
	sed -e '/endif # LOGO/iconfig LOGO_CUSTOM_MONO\n\tbool "Custom black and white logo"\n\tdefault y\n' \
	    -e '/endif # LOGO/iconfig LOGO_CUSTOM_VGA16\n\tbool "Custom 16-color logo"\n\tdefault y\n' \
	    -e '/endif # LOGO/iconfig LOGO_CUSTOM_CLUT224\n\tbool "Custom 224-color logo"\n\tdefault y if FB_VESA\n' \
	    -e '/endif # LOGO/iconfig LOGO_CUSTOM_GRAY256\n\tbool "Custom gray logo"\n\tdefault y if FB_VESA\n' \
	    -i $(S)/drivers/video/logo/Kconfig
	sed -e '/if (depth >= 1)/a#ifdef CONFIG_LOGO_CUSTOM_MONO\n\t\t/* Custom logo */\n\t\tlogo = &logo_custom_mono;\n#endif' \
	    -e '/if (depth >= 4)/a#ifdef CONFIG_LOGO_CUSTOM_VGA16\n\t\t/* Custom logo */\n\t\tlogo = &logo_custom_vga16;\n#endif' \
	    -e '/if (depth >= 8)/a#ifdef CONFIG_LOGO_CUSTOM_CLUT224\n\t\t/* Custom logo */\n\t\tlogo = &logo_custom_clut224;\n#endif' \
	    -e '/if (depth >= 8)/a#ifdef CONFIG_LOGO_CUSTOM_GRAY256\n\t\t/* Custom logo */\n\t\tlogo = &logo_custom_gray256;\n#endif' \
	    -i $(S)/drivers/video/logo/logo.c
	sed -e '/^#endif \/\* _LINUX_LINUX_LOGO_H \*\/$$/iextern const struct linux_logo logo_custom_mono;' \
	    -e '/^#endif \/\* _LINUX_LINUX_LOGO_H \*\/$$/iextern const struct linux_logo logo_custom_vga16;' \
	    -e '/^#endif \/\* _LINUX_LINUX_LOGO_H \*\/$$/iextern const struct linux_logo logo_custom_clut224;' \
	    -e '/^#endif \/\* _LINUX_LINUX_LOGO_H \*\/$$/iextern const struct linux_logo logo_custom_gray256;' \
	    -i $(S)/include/linux/linux_logo.h
	$(MAKE) -f $(lastword $(MAKEFILE_LIST)) bootup-logo_reconfig

custom.png:
	wget "https://avatars0.githubusercontent.com/u/4499761?s=200&v=4" -O $@

custom.ppm: custom.png
	convert -resize 80x80 $< $@

$(S)/drivers/video/logo/logo_%_mono.pbm: %_mono.pbm
	cp $< $@

$(S)/drivers/video/logo/logo_%_vga16.ppm: %_vga16.ppm
	cp $< $@

$(S)/drivers/video/logo/logo_%_clut224.ppm: %_clut224.ppm
	cp $< $@

$(S)/drivers/video/logo/logo_%_gray256.pgm: %_gray256.pgm
	cp $< $@

%_mono.pbm: %.ppm
	pgmtopbm $< | \
	pnmquant 2 - | \
	pnmnoraw >$@

%_vga16.ppm: %.ppm
	pnmquant 16 $< | \
	pnmremap -mapfile $(S)/drivers/video/logo/clut_vga16.ppm | \
	pnmnoraw >$@

%_clut224.ppm: %.ppm
	pnmquant 224 $< | \
	pnmnoraw >$@

%_gray256.pgm: %.ppm
	ppmtopgm $< | \
	pnmquant 256 - | \
	pnmnoraw >$@

%.pbm: %.ppm
	pgmtopbm $< >$@

%.pgm: %.ppm
	ppmtopgm $< >$@

.PHONY: bootup-logo_clean
bootup-logo_clean:
	sed -e '/^obj-\$$(CONFIG_LOGO_CUSTOM_.*)/d' \
	    -i $(S)/drivers/video/logo/Makefile
	sed -e '/config LOGO_CUSTOM_.*/,/^$$/d' \
	    -i $(S)/drivers/video/logo/Kconfig
	sed -e '/^#ifdef CONFIG_LOGO_CUSTOM_.*$$/,/#endif/d' \
	    -i $(S)/drivers/video/logo/logo.c
	sed -e '/^extern const struct linux_logo logo_custom_.*$$/d' \
	    -i $(S)/include/linux/linux_logo.h
	rm -f *.[bp]pm
	$(MAKE) -f $(lastword $(MAKEFILE_LIST)) bootup-logo_reconfig

.PHONY: bootup-logo_reconfig
bootup-logo_reconfig:
	if test -e $(O)/.config; then \
		touch $(O)/.config; \
	fi

.PHONY: clean
clean: bootup-logo_clean
	rm -f custom*.p[bpg]m $(S)/drivers/video/logo/logo_custom_*.*

# ex: filetype=make
