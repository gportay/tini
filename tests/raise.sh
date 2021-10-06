#!/bin/sh
#
#  Copyright (C) 2018-2019 Gaël PORTAY
#
# SPDX-License-Identifier: LGPL-2.1-or-later
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
