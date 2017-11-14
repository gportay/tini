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

