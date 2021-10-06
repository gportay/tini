# tini

Simple init daemon that spawns processes and reaps zombies

## NAME

[tini(1)] - simple init daemon

## DESCRIPTION

[tini(1)] is a damn small process spawner and zombie reaper.

It runs [/lib/tini/scripts/rcS] _init script_ and then spawns four _askfirst_
*sh(1)* on _console_, _tty2_, _tty3_ and _tty4_.

## DOCUMENTATION

Build the man page using [asciidoctor(1)]

	$ make doc
	asciidoctor -b manpage -o tini.1 tini.1.adoc
	gzip -c tini.1 >tini.1.gz
	rm tini.1

## INSTALL

Run the following command to install [tini(1)]

	$ sudo make install

Traditional variables *DESTDIR* and *PREFIX* can be overridden

	$ sudo make install PREFIX=/opt/tini

or

	$ make install DESTDIR=$PWD/pkg PREFIX=/usr

## TRY IT

Here is a quick example to try [tini(1)] on host using [qemu(1)]

	$ make runqemu                                                                            :(
	make -C tests runqemu
	(...)
	qemu-system-x86_64 -kernel bzImage -initrd initramfs.cpio

Or using [UML]

	$ make runuml
	make -C tests runuml
	(...)
	vmlinux initrd=initramfs.cpio rdinit=/sbin/tini mem=256M console=tty0 con0=fd:0,fd:1 con=none

## BUGS

Report bugs at *https://github.com/gportay/tini/issues*

## AUTHOR

Written by Gaël PORTAY *gael.portay@gmail.com*

## COPYRIGHT

Copyright (C) 2018-2019,2021 Gaël PORTAY
                   2017-2018 Savoir-Faire Linux Inc.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation, either version 2.1 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

[tini(1)]: tini.1.adoc
[asciidoctor(1)]: https://asciidoctor.org/man/asciidoctor/
[qemu(1)]: https://github.com/qemu/qemu
[UML]: https://www.kernel.org/doc/html/latest/virt/uml/user_mode_linux_howto_v2.html
[/lib/tini/scripts/rcS]: tests/rcS
