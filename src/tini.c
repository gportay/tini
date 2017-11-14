/*
 *  Copyright (C) 2017 Savoir-Faire Linux Inc.
 *
 *  Authors:
 *       Gaël PORTAY <gael.portay@savoirfairelinux.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#define _GNU_SOURCE

#ifdef HAVE_CONFIG_H
# include "config.h"
#else
const char VERSION[] = __DATE__ " " __TIME__;
#endif /* HAVE_CONFIG_H */

#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <getopt.h>
#include <signal.h>
#include <sys/wait.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/reboot.h>
#include <fcntl.h>

static char *rcS[] = { "/etc/init.d/rcS", "start", NULL };
static char *sh[] = { "-sh", NULL };

struct options_t {
	int argc;
	char * const *argv;
};

static inline const char *applet(const char *arg0)
{
	char *s = strrchr(arg0, '/');
	if (!s)
		return arg0;

	return s+1;
}

void usage(FILE * f, char * const arg0)
{
	fprintf(f, "Usage: %s [OPTIONS]\n\n"
		   "Options:\n"
		   " -V or --version        Display the version.\n"
		   " -h or --help           Display this message.\n"
		   "", applet(arg0));
}

int run(const char *path, char * const argv[], const char *devname)
{
	pid_t pid = fork();
	if (pid == -1) {
		perror("fork");
		return -1;
	}

	/* Parent */
	if (pid) {
		int status;

		if (waitpid(pid, &status, 0) == -1) {
			perror("waitpid");
			return -1;
		}

		if (WIFEXITED(status))
			status = WEXITSTATUS(status);
		else if (WIFSIGNALED(status))
			fprintf(stderr, "%s\n", strsignal(WTERMSIG(status)));

		return status;
	}

	/* Child */
	if (devname) {
		int fd;

		close(STDIN_FILENO);
		fd = open(devname, O_RDONLY|O_NOCTTY);
		if (fd == -1)
			perror("open");

		close(STDOUT_FILENO);
		fd = open(devname, O_WRONLY|O_NOCTTY);
		if (fd == -1)
			perror("open");

		close(STDERR_FILENO);
		dup2(STDOUT_FILENO, STDERR_FILENO);
	}

	execv(path, argv);
	_exit(127);
}

int spawn(const char *path, char * const argv[], const char *devname)
{
	pid_t pid = fork();
	if (pid == -1) {
		perror("fork");
		return -1;
	}

	/* Parent */
	if (pid) {
		int status;

		if (waitpid(pid, &status, 0) == -1) {
			perror("waitpid");
			return -1;
		}

		if (WIFEXITED(status))
			status = WEXITSTATUS(status);
		else if (WIFSIGNALED(status))
			fprintf(stderr, "%s\n", strsignal(WTERMSIG(status)));

		return status;
	}

	/* Child */
	pid = fork();
	if (pid == -1) {
		perror("fork");
		exit(EXIT_FAILURE);
	} else if (pid) {
		exit(EXIT_SUCCESS);
	}

	/* Daemon */
	if (devname) {
		int fd;

		close(STDIN_FILENO);
		fd = open(devname, O_RDONLY|O_NOCTTY);
		if (fd == -1)
			perror("open");

		close(STDOUT_FILENO);
		fd = open(devname, O_WRONLY|O_NOCTTY);
		if (fd == -1)
			perror("open");

		close(STDERR_FILENO);
		dup2(STDOUT_FILENO, STDERR_FILENO);
	}

	execv(path, argv);
	_exit(127);
}

int parse_arguments(struct options_t *opts, int argc, char * const argv[])
{
	static const struct option long_options[] = {
		{ "version", no_argument,       NULL, 'V' },
		{ "help",    no_argument,       NULL, 'h' },
		{ NULL,      no_argument,       NULL, 0   }
	};

	opterr = 0;
	for (;;) {
		int index;
		int c = getopt_long(argc, argv, "Vh", long_options, &index);
		if (c == -1)
			break;

		switch (c) {
		case 'V':
			printf("%s\n", VERSION);
			exit(EXIT_SUCCESS);
			break;

		case 'h':
			usage(stdout, argv[0]);
			exit(EXIT_SUCCESS);
			break;

		default:
		case '?':
			return -1;
		}
	}

	opts->argc = argc;
	opts->argv = argv;
	return optind;
}

int main(int argc, char * const argv[])
{
	static struct options_t options;
	static sigset_t sigset;
	int sig;

	int argi = parse_arguments(&options, argc, argv);
	if (argi < 0) {
		fprintf(stderr, "Error: %s: Invalid argument!\n",
				argv[optind-1]);
		exit(EXIT_FAILURE);
	} else if (argc - argi >= 1) {
		usage(stdout, argv[0]);
		fprintf(stderr, "Error: Too many arguments!\n");
		exit(EXIT_FAILURE);
	}

	if (sigemptyset(&sigset) == -1) {
		perror("sigemptyset");
		exit(EXIT_FAILURE);
	}

	sig = SIGTERM;
	if (sigaddset(&sigset, sig) == -1) {
		perror("sigaddset");
		exit(EXIT_FAILURE);
	}

	sig = SIGINT;
	if (sigaddset(&sigset, sig) == -1) {
		perror("sigaddset");
		exit(EXIT_FAILURE);
	}

	sig = SIGCHLD;
	if (sigaddset(&sigset, sig) == -1) {
		perror("sigaddset");
		exit(EXIT_FAILURE);
	}

	sig = SIGIO;
	if (sigaddset(&sigset, sig) == -1) {
		perror("perror");
		exit(EXIT_FAILURE);
	}

	if (sigprocmask(SIG_SETMASK, &sigset, NULL) == -1) {
		perror("perror");
		exit(EXIT_FAILURE);
	}

	printf("tini started!\n");

	run("/etc/init.d/rcS", rcS, NULL);
	spawn("/bin/sh", sh, "/dev/console");
	spawn("/bin/sh", sh, "/dev/tty2");
	spawn("/bin/sh", sh, "/dev/tty3");
	spawn("/bin/sh", sh, "/dev/tty4");

	for (;;) {
		siginfo_t siginfo;
		sig = sigwaitinfo(&sigset, &siginfo);
		if (sig == -1) {
			if (errno == EINTR)
				continue;

			perror("sigwaitinfo");
			break;
		}

		/* Reap zombies */
		if (sig == SIGCHLD) {
			while (waitpid(-1, NULL, WNOHANG) > 0);
			continue;
		}

		/* Exit */
		if ((sig == SIGTERM) || (sig == SIGINT))
			break;
	}

	/* Reboot (Ctrl-Alt-Delete) */
	if (sig == SIGINT) {
		sync();
		if (reboot(RB_AUTOBOOT) == -1)
			perror("reboot");
		exit(EXIT_FAILURE);
	}

	/* Power off */
	if (sigprocmask(SIG_UNBLOCK, &sigset, NULL) == -1)
		perror("sigprocmask");

	/* Reap zombies */
	while (waitpid(-1, NULL, WNOHANG) > 0);

	printf("tini stopped!\n");

	sync();
	if (reboot(RB_POWER_OFF) == -1)
		perror("reboot");

	exit(EXIT_FAILURE);
}
