#!/bin/sh
#
#  Copyright (C) 2019 Gaël PORTAY
#                2018 Savoir-Faire Linux Inc.
#
# SPDX-License-Identifier: LGPL-2.1-or-later
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
