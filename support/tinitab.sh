#!/bin/sh
sed -e '/^[ \t]*#/d' \
    -e '/^$/d' \
       "$@" | \
while read entry
do
 	# id:runlevels:action:process
	process="$entry"
	id="${process%%:*}"
	process="${process#$id:}"
	runlevels="${process%%:*}"
	process="${process#$runlevels:}"
	action="${process%%:*}"
	process="${process#$action:}"

	# Unique sequence of 1-4 characters which identifies an entry in inittab
	#
	# Warning: This field has a non-traditional meaning for BusyBox init!
	#
	# This field is used by BusyBox init to specify the controlling tty for
	# the specified process to run on. The contents of this field are
	# appended to "/dev/" and used as-is. There is no need for this field to
	# be unique, although if it isn't you may have strange results. If this
	# field is left blank, then the init's stdin/out will be used.
	if [ "${#id}" -gt 4 ] && [ ! -e "/dev/$id" ]
	then
		echo "Warning: $id: Too long id!" >&2
		id="${id:0:4}"
	fi

	# tiny doesn't support multiple runlevels.
	if [ -z "$runlevels_warning" ] && [ -n "$runlevels" ]
	then
		cat <<EOF >&2
Info: The runlevels field is completely ignored by tiny.
      If you want runlevels, use sysvinit.
EOF
		runlevels_warning=1
	fi

	# tiny doesn't support flag + for process.
	if [ "${process:1:1}" = "+" ]
	then
cat <<EOF
Warning: $entry: Flag ${process:1:1} ignored!
EOF
		process="${process:1}"
	fi

	# Busybox non standard behavior
	# See https://git.busybox.net/busybox/tree/examples/inittab and
	# https://git.busybox.net/busybox/tree/init/init.c
	#
	# askfirst
	#
	# askfirst acts just like respawn, but before running the specified
	# process it displays the line "Please press Enter to activate this
	# console." and then waits for the user to press enter before starting
	# the specified process.
	realaction="$action"
	case "$action" in
	askfirst)
		action="respawn"
		;;
	# restart
	#
	# restart is the action taken to restart the init process. By default
	# this should simply run /sbin/init, but can be a script which runs
	# pivot_root or it can do all sorts of other interesting things.
	#
	# shutdown
	#
	# shutdown action specifies the actions to taken when init is told to
	# reboot. Unmounting filesystems and disabling swap is a very good here
	restart|shutdown)
		action="once"
		;;
	esac

	case "$action" in
	# respawn
	#
	# The process will be restarted whenever it terminates (e.g. getty).
	respawn)
	cat <<__EOF
cat <<EOF >"/tmp/$id"
#!/bin/sh
# Automatically generated file; EDIT TO YOUR CONVENIENCE.
# $entry Entry
case "\$1" in
start)
	exec respawn $process
	;;
stop)
	exec assassinate $process
	;;
esac
EOF
chmod +x "/tmp/$id"
mkdir -p /etc/boot.d/
mv "/tmp/$id" /etc/boot.d/
__EOF
		;;
	# wait
	#
	# The process will be started once when the specified runlevel is
	# entered and init will wait for its termination.
	#
	# once
	#
	# The process will be executed once when the specified runlevel is
	# entered.
	#
	# boot
	#
	# The process will be executed during system boot. The runlevels field
	# is ignored.
	#
	# bootwait
	#
	# The process will be executed during system boot, while init waits for
	# its termination (e.g. /etc/rc). The runlevels field is ignored.
	#
	# ondemand
	#
	# A process marked with an ondemand runlevel will be executed whenever
	# the specified ondemand runlevel is called. However, no runlevel change
	# will occur (ondemand runlevels are ‘a’, ‘b’, and ‘c’).
	wait|once|boot|bootwait|ondemand)
	cat <<__EOF
cat <<EOF >"/tmp/$id"
#!/bin/sh
# Automatically generated file; EDIT TO YOUR CONVENIENCE.
# $entry Entry
case "\$1" in
start)
	exec spawn $process
	;;
esac
EOF
chmod +x "/tmp/$id"
mkdir -p /etc/boot.d/
mv "/tmp/$id" /etc/boot.d/
__EOF
		;;
	# off
	#
	# This does nothing.
	off)
		;;
	# initdefault
	#
	# An initdefault entry specifies the runlevel which should be entered
	# after system boot. If none exists, init will ask for a runlevel on the
	# console. The process field is ignored.
	#
	# sysinit
	#
	# The process will be executed during system boot. It will be executed
	# before any boot or bootwait entries. The runlevels field is ignored.
	#
	# powerwait
	#
	# The process will be executed when the power goes down. Init is usually
	# informed about this by a process talking to a UPS connected to the
	# computer. Init will wait for the process to finish before continuing.
	#
	# powerfail
	#
	# As for powerwait, except that init does not wait for the process’s
	# completion.
	#
	# powerokwait
	#
	# This process will be executed as soon as init is informormed that the
	# power has been restored.
	#
	# powerfailnow
	#
	# This process will be executed when init is told that the battery of
	# the external UPS is almost empty and the power is failing (provided
	# that the external UPS and the monitoring process are able to detect
	# this condition).
	#
	# ctrlaltdel
	#
	# The process will be executed when init receives the SIGINT signal.
	# This means that someone on the system console has pressed the
	# CTRL−ALT−DEL key combination. Typically one wants to execute some sort
	# of shutdown either to get into single−user level or to reboot the
	# machine.
	#
	# kbrequest
	#
	# The process will be executed when init receives a signal from the
	# keyboard handler that a special key combination was pressed on the
	# console keyboard.
	#
	# The documentation for this function is not complete yet; more
	# documentation can be found in the kbd-x.xx packages (most recent was
	# kbd-0.94 at the time of this writing). Basically you want to map some
	# keyboard combination to the "KeyboardSignal" action. For example, to
	# map Alt-Uparrow for this purpose use the following in your keymaps
	# file:
	#
	# alt keycode 103 = KeyboardSignal
	initdefault|sysinit|powerwait|powerfail|powerokwait|powerfailnow|ctrlaltdel|kbrequest)
		cat <<EOF >&2
Warning: $entry: Action $realaction ignored!
EOF
		;;
	*)
		echo "Warning: $realaction: Invalid action!" >&2
		;;
	esac
done
