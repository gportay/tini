#!/bin/sh
#
#  Copyright (C) 2018 Savoir-Faire Linux Inc.
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

set -e

if [ "$ACTION" = "remove" ]
then
	set -- --exit-on-error --arg "stop"
else
	set -- --exit-on-error --arg "start"
fi

if [ -n "$DEVNAME" ] && [ -d "/lib/tini/uevent/devname/$DEVNAME" ]
then
	run-parts "$@" "/lib/tini/uevent/devname/$DEVNAME"
elif [ -n "$INTERFACE" ] && [ -d "/lib/tini/uevent/devname/$INTERFACE" ]
then
	run-parts "$@" "/lib/tini/uevent/devname/$INTERFACE"
else
	exit 0
fi
