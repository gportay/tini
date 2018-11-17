#!/bin/sh
#
#  Copyright (C) 2018 Gaël PORTAY
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

if [ $# -lt 2 ]
then
	cat <<EOF
Usage: ${0} EVENT start|stop
EOF
	exit 1
fi >&2

if ! [ -d "/lib/tini/event/$1" ]
then
	echo "$1: No such event"
	exit
fi >&2

/bin/run-parts --exit-on-error --arg "$2" "/lib/tini/event/$1"
