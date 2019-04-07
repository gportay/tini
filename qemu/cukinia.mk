#
#  Copyright (C)      2019 Gaël PORTAY
#                2017-2018 Savoir-Faire Linux Inc.
#
#  Authors:
#      Gaël PORTAY <gael.portay@savoirfairelinux.com>
#
# SPDX-License-Identifier: LGPL-2.1-or-later
#

.PHONY: all
all:

.PHONY: download
download: cukinia_download

.PHONY: clean
clean: cukinia_clean

.PHONY: mrproper
mrproper: cukinia_mrproper

.SILENT: cukinia/cukinia
cukinia/cukinia:
	echo "You need to provide your own cukinia sources into the $(CURDIR)/$(@D) directory!" >&2
	echo "Have a look at https://github.com/savoirfairelinux/cukinia! or run one of the commands below:" >&2
	echo "$$ git clone git@github.com:savoirfairelinux/cukinia.git $(CURDIR)/$(@D)" >&2
	exit 1

.PHONY: cukinia_download
cukinia_download:
	git clone git@github.com:savoirfairelinux/cukinia.git

.PHONY: cukinia_clean
cukinia_clean:

.PHONY: cukinia_mrproper
cukinia_mrproper: cukinia_clean

# ex: filetype=make
