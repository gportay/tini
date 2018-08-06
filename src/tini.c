/*
 *  Copyright (C) 2017-2018 Savoir-Faire Linux Inc.
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
 * GNU Lesser General Public License for more details.
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
#include <limits.h>
#include <dirent.h>
#include <assert.h>

#include <sys/socket.h>
#include <arpa/inet.h>
#include <asm/types.h>
#include <linux/netlink.h>

static int VERBOSE = 0;
static int DEBUG = 0;
#define verbose(fmt, ...) if (VERBOSE) fprintf(stderr, fmt, ##__VA_ARGS__)
#define debug(fmt, ...) if (DEBUG) fprintf(stderr, fmt, ##__VA_ARGS__)

static char *rcS[] = { "/etc/init.d/rcS", "start", NULL };

#define __strncmp(s1, s2) strncmp(s1, s2, sizeof(s2) - 1)
#define __close(fd) do { \
	int __error = errno; \
	if (close(fd) == -1) \
		perror("close"); \
	errno = __error; \
} while(0)

static inline const char *__getenv(const char *name, const char *undef) {
	const char *env = getenv(name);
	if (!env)
		env = undef;

	return env;
}

static char *CFS = " \t\n"; /* Command-line Field Separator */
char **strtonargv(char *dest[], char *src, int *n);

#ifndef UEVENT_BUFFER_SIZE
#define UEVENT_BUFFER_SIZE 2048
#endif

static int nl_fd;
int netlink_open(struct sockaddr_nl *addr, int signal);
ssize_t netlink_recv(int fd, struct sockaddr_nl *addr);
int netlink_close(int fd);

typedef int uevent_event_cb_t(char *, char *, void *);
typedef int uevent_variable_cb_t(char *, char *, void *);
int uevent_parse_line(char *line,
		      uevent_event_cb_t *evt_cb,
		      uevent_variable_cb_t *var_cb,
		      void *data);

typedef int variable_cb_t(char *, char *, void *);
int variable_parse_line(char *line, variable_cb_t *callback, void *data);

typedef int directory_cb_t(const char *, struct dirent *, void *);
int dir_parse(const char *path, directory_cb_t *callback, void *data);

struct proc {
	char exec[PATH_MAX];
	const char *dev_stdin;
	const char *dev_stdout;
	const char *dev_stderr;
	int counter;
	int oldstatus;
	pid_t oldpid;
};

int spawn(const char *path, char * const argv[], const char *devname);
int respawn(const char *path, char * const argv[], struct proc *proc);

struct options_t {
	int argc;
	char * const *argv;
	int re_exec;
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
	const char *name = applet(arg0);
	fprintf(f, "Usage: %s [OPTIONS]\n"
		   "       %s halt|poweroff|reboot|re-exec\n"
		   "       %s spawn|zombize COMMAND [ARGUMENT...]\n\n"
		   "Options:\n"
		   "       --re-exec        Re-execute.\n"
		   " -v or --verbose        Turn on verbose messages.\n"
		   " -D or --debug          Turn on debug messages.\n"
		   " -V or --version        Display the version.\n"
		   " -h or --help           Display this message.\n"
		   "", name, name, name);
}

int zombize(const char *path, char * const argv[], const char *devname)
{
	pid_t pid = fork();
	if (pid == -1) {
		perror("fork");
		return -1;
	}

	/* Parent */
	if (pid)
		return 0;

	netlink_close(nl_fd);

	/* Child */
	if (devname) {
		int fd;

		if (chdir("/dev") == -1)
			perror("chdir");

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

		if (chdir("/") == -1)
			perror("chdir");
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

	netlink_close(nl_fd);

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

		if (chdir("/dev") == -1)
			perror("chdir");

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

		if (chdir("/") == -1)
			perror("chdir");
	}

	execv(path, argv);
	_exit(127);
}

int respawn(const char *path, char * const argv[], struct proc *proc)
{
	char pidfile[PATH_MAX];
	FILE *f;

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

		if (status == 0)
			proc->counter++;

		return status;
	}

	netlink_close(nl_fd);
	proc->counter++;

	/* Child */
	pid = fork();
	if (pid == -1) {
		perror("fork");
		exit(EXIT_FAILURE);
	} else if (pid) {
		exit(EXIT_SUCCESS);
	}

	/*
	 * TODO: check for fprintf returned values
	 *       serialize in a dedicated function
	 */
	snprintf(pidfile, sizeof(pidfile), "/run/tini/%i", getpid());
	f = fopen(pidfile, "w");
	if (f) {
		char * const *arg = argv;

		fprintf(f, "EXEC=%s%c", path, CFS[0]);
		while (*arg)
			fprintf(f, "%s%c", *arg++, CFS[0]);
		fprintf(f, "\n");

		fprintf(f, "STDIN=%s\n", proc->dev_stdin);
		fprintf(f, "STDOUT=%s\n", proc->dev_stdout);
		fprintf(f, "STDERR=%s\n", proc->dev_stderr);
		fprintf(f, "COUNTER=%i\n", proc->counter);
		if (proc->oldstatus != -1)
			fprintf(f, "OLDSTATUS=%i\n", proc->oldstatus);
		if (proc->oldpid != -1)
			fprintf(f, "OLDPID=%i\n", proc->oldpid);
		arg = argv;

		fclose(f);
		f = NULL;
	}

	/* Daemon */
	if (chdir("/dev") == -1)
		perror("chdir");

	close(STDIN_FILENO);
	if (open(proc->dev_stdin, O_RDONLY|O_NOCTTY) == -1)
		perror("open");

	close(STDOUT_FILENO);
	if (open(proc->dev_stdout, O_WRONLY|O_NOCTTY) == -1)
		perror("open");

	close(STDERR_FILENO);
	dup2(STDOUT_FILENO, STDERR_FILENO);

	if (chdir("/") == -1)
		perror("chdir");

	execv(path, argv);
	_exit(127);
}

int parse_arguments(struct options_t *opts, int argc, char * const argv[])
{
	static const struct option long_options[] = {
		{ "re-exec", no_argument,       NULL, 1   },
		{ "verbose", no_argument,       NULL, 'v' },
		{ "debug",   no_argument,       NULL, 'D' },
		{ "version", no_argument,       NULL, 'V' },
		{ "help",    no_argument,       NULL, 'h' },
		{ NULL,      no_argument,       NULL, 0   }
	};

	opterr = 0;
	for (;;) {
		int index;
		int c = getopt_long(argc, argv, "vDVh", long_options, &index);
		if (c == -1)
			break;

		switch (c) {
		case 1:
			opts->re_exec = 1;
			break;

		case 'v':
			VERBOSE++;
			break;

		case 'D':
			DEBUG++;
			break;

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

int uevent_spawn(const char *path, struct dirent *entry, void *data)
{
	const char *devname = (const char *)data;
	char buf[PATH_MAX];
	int status;

	snprintf(buf, sizeof(buf), "DEVNAME=%s %s/%s %s", devname, path,
		 entry->d_name, "start");
	status = system(buf);
	if (WIFEXITED(status)) {
		status = WEXITSTATUS(status);
		verbose("%s/%s: %i\n", path, entry->d_name, status);
	} else if (WIFSIGNALED(status)) {
		fprintf(stderr, "%s/%s: %s\n", path, entry->d_name,
			strsignal(WTERMSIG(status)));
	}

	return 0;
}

int uevent_event(char *action, char *devpath, void *data)
{
	(void)action;
	(void)devpath;
	(void)data;

	return 0;
}

int uevent_variable(char *variable, char *value, void *data)
{
	struct stat statbuf;
	char dir[PATH_MAX];

	(void)data;
	if (strcmp(variable, "DEVNAME"))
		return 0;

	/* DEVNAME */
	snprintf(dir, sizeof(dir), "/lib/tini/uevent/devname/%s", value);
	if (stat(dir, &statbuf))
		return 0;

	return dir_parse(dir, uevent_spawn, value);
}

int uevent_parse_line(char *line,
		      uevent_event_cb_t *evt_cb,
		      uevent_variable_cb_t *var_cb,
		      void *data)
{
	char *at, *equal;

	/* empty line? */
	if (*line == '\0')
		return 0;

	/* event? */
	at = strchr(line, '@');
	if (at) {
		char *action, *devpath;

		action = line;
		devpath = at + 1;
		*at = '\0';

		if (!evt_cb)
			return 0;

		return evt_cb(action, devpath, data);
	}

	/* variable? */
	equal = strchr(line, '=');
	if (equal) {
		char *variable, *value;

		variable = line;
		value = equal + 1;
		*equal = '\0';

		if (!var_cb)
			return 0;

		return var_cb(variable, value, data);
	}

	fprintf(stderr, "malformated event or variable: \"%s\"."
			" Must be either action@devpath,\n"
			"             or variable=value!\n", line);
	return 1;
}

int setup_signal(int fd, int signal)
{
	int flags;

	if (fcntl(fd, F_SETSIG, signal) == -1) {
		perror("fcntl");
		return -1;
	}

	if (fcntl(fd, F_SETOWN, getpid()) == -1) {
		perror("fcntl");
		return -1;
	}

	flags = fcntl(fd, F_GETFL);
	if (flags == -1) {
		perror("fcntl");
		return -1;
	}

	flags |= (O_ASYNC | O_NONBLOCK | O_CLOEXEC);
	if (fcntl(fd, F_SETFL, flags) == -1) {
		perror("fcntl");
		return -1;
	}

	return 0;
}

int netlink_open(struct sockaddr_nl *addr, int signal)
{
	int fd;

	assert(addr);
	memset(addr, 0, sizeof(*addr));
	addr->nl_family = AF_NETLINK;
	addr->nl_pid = getpid();
	addr->nl_groups = NETLINK_KOBJECT_UEVENT;

	fd = socket(AF_NETLINK, SOCK_RAW, NETLINK_KOBJECT_UEVENT);
	if (fd == -1) {
		perror("socket");
		return -1;
	}

	if (bind(fd, (struct sockaddr *)addr, sizeof(*addr)) == -1) {
		perror("bind");
		goto error;
	}

	if (setup_signal(fd, signal) == -1) {
		__close(fd);
		goto error;
	}

	nl_fd = fd;
	return fd;

error:
	__close(fd);
	return -1;
}

int netlink_close(int fd)
{
	int ret;

	ret = close(fd);
	if (ret == -1)
		perror("close");

	nl_fd = -1;
	return ret;
}

ssize_t netlink_recv(int fd, struct sockaddr_nl *addr)
{
	char buf[UEVENT_BUFFER_SIZE];
	struct iovec iov = {
		.iov_base = buf,
		.iov_len = sizeof(buf),
	};
	struct msghdr msg = {
		.msg_name = addr,
		.msg_namelen = sizeof(*addr),
		.msg_iov = &iov,
		.msg_iovlen = 1,
		.msg_control = NULL,
		.msg_controllen = 0,
		.msg_flags = 0,
	};
	ssize_t len = 0;

	for (;;) {
		char *n, *s;
		ssize_t l;

		l = recvmsg(fd, &msg, 0);
		if (l == -1) {
			if (errno != EAGAIN) {
				perror("recvmsg");
				break;
			}

			break;
		} else if (!l) {
			break;
		}

		buf[l] = 0;
		s = buf;
		s += strlen(s) + 1;

		for (;;) {
			n = strchr(s, '\0');
			if (!n || n == s)
				break;

			if (uevent_parse_line(s, uevent_event, uevent_variable,
					      NULL))
				break;

			s = n + 1;
		}

		len += l;
	}

	return len;
}

int variable_parse_line(char *line, variable_cb_t *callback, void *data)
{
	char *equal;

	/* empty line? */
	if (*line == '\0')
		return 0;

	/* variable? */
	equal = strchr(line, '=');
	if (equal) {
		char *variable, *value;

		variable = line;
		value = equal + 1;
		*equal = '\0';

		if (!callback)
			return 0;

		return callback(variable, value, data);
	}

	fprintf(stderr, "malformated variable: \"%s\"."
			" Must be variable=value!\n", line);
	return 1;
}

ssize_t variable_read(int fd, variable_cb_t cb, void *data)
{
	char buf[BUFSIZ];
	ssize_t len = 0;

	for (;;) {
		char *n, *s;
		ssize_t l;

		l = read(fd, buf, sizeof(buf));
		if (l == -1)
			perror("read");
		else if (!l)
			break;

		buf[l] = 0;
		s = buf;

		for (;;) {
			n = strchr(s, '\n');
			if (!n || n == s)
				break;

			*n = 0;
			if (variable_parse_line(s, cb, data))
				break;

			s = n + 1;
		}

		len += l;
	}

	return len;
}

int pidfile_info(char *variable, char *value, void *data)
{
	struct proc *proc = (struct proc *)data;

	if (!strcmp(variable, "EXEC"))
		strncpy(proc->exec, value, PATH_MAX);
	else if (!strcmp(variable, "STDIN"))
		proc->dev_stdin = value;
	else if (!strcmp(variable, "STDOUT"))
		proc->dev_stdout = value;
	else if (!strcmp(variable, "STDERR"))
		proc->dev_stderr = value;
	else if (!strcmp(variable, "COUNTER"))
		proc->counter = strtol(value, NULL, 0);
	else if (!strcmp(variable, "OLDSTATUS"))
		proc->oldstatus = strtol(value, NULL, 0);
	else if (!strcmp(variable, "OLDPID"))
		proc->oldpid = strtol(value, NULL, 0);

	return 0;
}

int pidfile_parse(const char *pidfile, variable_cb_t *callback, void *data)
{
	int fd, ret;

	fd = open(pidfile, O_RDONLY);
	if (fd == -1) {
		perror("open");
		return -1;
	}

	ret = variable_read(fd, callback, data);

	if (close(fd) == -1)
		perror("close");

	return ret;
}

int pid_respawn(pid_t pid, int status)
{
	struct proc proc;
	char pidfile[PATH_MAX];
	struct stat statbuf;
	int ret;

	/* command not found */
	if (status == 127)
		return 1;

	snprintf(pidfile, sizeof(pidfile), "/run/tini/%i", pid);
	if (stat(pidfile, &statbuf))
		return 1;

	memset(&proc, 0, sizeof(proc));
	proc.oldstatus = -1;
	proc.oldpid = -1;
	ret = pidfile_parse(pidfile, pidfile_info, &proc);

	/* overwrite values */
	proc.oldstatus = status;
	proc.oldpid = pid;
	if (*proc.exec) {
		int argc = 127;

		strtonargv(NULL, proc.exec, &argc);
		if (argc > 0) {
			char *argv[argc];
			if (!strtonargv(argv, proc.exec, &argc)) {
				perror("strtonargv");
				return -1;
			}

			ret = respawn(argv[0], &argv[1], &proc);
		}
	}
	if (unlink(pidfile) == -1)
		perror("unlink");

	return ret;
}

char *strargv(char *buf, size_t bufsize, char * const argv[])
{
	char * const *arg = argv;
	ssize_t size = 0;

	size = snprintf(&buf[size], size - bufsize, "%s", *arg++);
	while (*arg)
		size += snprintf(&buf[size], size - bufsize, " %s", *arg++);

	return buf;
}

char **strtonargv(char *dest[], char *src, int *n)
{
	char **arg = dest;
	char *str = src;
	char *s = NULL;
	int i = 0;

	if (!n || *n < 0) {
		errno = EINVAL;
		return NULL;
	}

	for (;;) {
		if (!*n)
			break;

		s = strchr(str, CFS[0]);
		if (!s)
			break;

		if (arg)
			*s = '\0'; /* CFS[0] <- NUL */
		s++; /* s = next cstring */
		(*n)--;
		i++;
		if (arg)
			*arg++ = str;
		str = s;
	}

	if (arg)
		*arg = NULL;

	*n = i;
	return dest;
}

int pidfile_assassinate(const char *path, struct dirent *entry, void *data)
{
	struct proc proc;
	char pidfile[BUFSIZ];
	pid_t pid;

	snprintf(pidfile, sizeof(pidfile), "%s/%s", path, entry->d_name);

	memset(&proc, 0, sizeof(proc));
	proc.oldstatus = -1;
	proc.oldpid = -1;
	pidfile_parse(pidfile, pidfile_info, &proc);

	if (!strcmp(proc.exec, (const char *)data)) {
		if (unlink(pidfile) == -1)
			perror("unlink");

		pid = strtol(entry->d_name, NULL, 0);
		if (kill(pid, SIGKILL) == -1)
			perror("kill");

		verbose("pid %i assassinated\n", pid);
	}

	return 0;
}

int dir_parse(const char *path, directory_cb_t *callback, void *data)
{
	struct dirent **namelist;
	int n, ret = 0;

	n = scandir(path, &namelist, NULL, alphasort);
	if (n == -1) {
		perror("scandir");
		return -1;
	}

	while (n--) {
		if (strcmp(namelist[n]->d_name, ".") &&
		    strcmp(namelist[n]->d_name, "..")) {
			callback(path, namelist[n], data);
		}
		free(namelist[n]);
	}
	free(namelist);

	return ret;
}

int kill_pid1(int signum)
{
	if (kill(1, signum) == -1) {
		perror("kill");
		return -1;
	}

	return 0;
}

int main_kill(int signum)
{
	if (kill_pid1(signum) == -1)
		return EXIT_FAILURE;

	return EXIT_SUCCESS;
}

int main_spawn(int argc, char * const argv[])
{
	char **arg = (char **)argv;
	int i;

	if (argc < 2) {
		fprintf(stderr, "Usage: %s PATH [ARGV...]\n\n"
				"Error: Too few arguments!\n", argv[0]);
		return EXIT_FAILURE;
	}

	/* Shift arguments to remove first argument (path), and append a NULL
	   pointer (execv) */
	for (i = 0; i < (argc - 1); i++)
		arg[i] = arg[i+1];
	arg[i] = NULL;

	return spawn(argv[0], argv, NULL);
}

int main_respawn(int argc, char * const argv[])
{
	struct proc proc;
	char **arg = (char **)argv;
	int i;

	if (argc < 2) {
		fprintf(stderr, "Usage: %s PATH [ARGV...]\n\n"
				"Error: Too few arguments!\n", argv[0]);
		return EXIT_FAILURE;
	}

	/* Shift arguments to remove first argument (path), and append a NULL
	   pointer (execv) */
	for (i = 0; i < (argc - 1); i++)
		arg[i] = arg[i+1];
	arg[i] = NULL;

	memset(&proc, 0, sizeof(proc));
	proc.dev_stdin = __getenv("STDIN", "null");
	proc.dev_stdout = __getenv("STDOUT", "null");
	proc.dev_stderr = __getenv("STDERR", "null");
	proc.counter = strtol(__getenv("COUNTER", "0"), NULL, 0);
	proc.oldstatus = strtol(__getenv("OLDSTATUS", "-1"), NULL, 0);
	proc.oldpid = strtol(__getenv("OLDPID", "-1"), NULL, 0);

	return respawn(argv[0], argv, &proc);
}

int main_assassinate(int argc, char * const argv[])
{
	char **arg = (char **)argv;
	char execline[BUFSIZ];
	int i;

	if (argc < 2) {
		fprintf(stderr, "Usage: %s PATH [ARGV...]\n\n"
				"Error: Too few arguments!\n", argv[0]);
		return EXIT_FAILURE;
	}

	/* Shift arguments to remove first argument (path), and append a NULL
	   pointer (execv) */
	for (i = 0; i < (argc - 1); i++)
		arg[i] = arg[i+1];
	arg[i] = NULL;

	strargv(execline, sizeof(execline), arg);

	return dir_parse("/run/tini", pidfile_assassinate, execline);
}

int main_zombize(int argc, char * const argv[])
{
	char **arg = (char **)argv;
	int i;

	if (argc < 2) {
		fprintf(stderr, "Usage: %s PATH [ARGV...]\n\n"
				"Error: Too few arguments!\n", argv[0]);
		return EXIT_FAILURE;
	}

	/* Shift arguments to remove first argument (path), and append a NULL
	   pointer (execv) */
	for (i = 0; i < (argc - 1); i++)
		arg[i] = arg[i+1];
	arg[i] = NULL;

	return zombize(argv[0], argv, NULL);
}

int main_applet(int argc, char * const argv[])
{
	const char *app = applet(argv[0]);

	(void)argc;
	if (!strcmp(app, "reboot"))
		return main_kill(SIGINT);
	else if (!strcmp(app, "poweroff"))
		return main_kill(SIGTERM);
	else if (!strcmp(app, "halt"))
		return main_kill(SIGUSR2);
	else if (!strcmp(app, "re-exec"))
		return main_kill(SIGUSR1);
	else if (!strcmp(app, "spawn"))
		return main_spawn(argc, &argv[0]);
	else if (!strcmp(app, "respawn"))
		return main_respawn(argc, &argv[0]);
	else if (!strcmp(app, "assassinate"))
		return main_assassinate(argc, &argv[0]);
	else if (!strcmp(app, "zombize"))
		return main_zombize(argc, &argv[0]);

	return EXIT_FAILURE;
}

int main_tini(int argc, char * const argv[])
{
	static struct options_t options;
	struct sockaddr_nl addr;
	static sigset_t sigset;
	int fd, sig;

	int argi = parse_arguments(&options, argc, argv);
	if (argi < 0) {
		fprintf(stderr, "Error: %s: Invalid argument!\n",
				argv[optind-1]);
		exit(EXIT_FAILURE);
	} else if (argc - argi > 1) {
		usage(stdout, argv[0]);
		fprintf(stderr, "Error: Too many arguments!\n");
		exit(EXIT_FAILURE);
	} else if (argc - argi == 1) {
		if (main_applet(1, &argv[argi]) == 0)
			exit(EXIT_SUCCESS);

		usage(stdout, argv[0]);
		fprintf(stderr, "Error: %s: Invalid applet!\n", argv[argi]);
		exit(EXIT_FAILURE);
	}

	/* Re-execute pid 1 when not pid 1 */
	if (getpid() > 1 && options.re_exec) {
		if (kill_pid1(SIGUSR1) == -1)
			exit(EXIT_FAILURE);

		return EXIT_SUCCESS;
	}

	/* Not supposed to be run when not pid 1 */
	if (getpid() > 1) {
		fprintf(stderr, "Error: Not pid 1!\n");
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

	sig = SIGUSR1;
	if (sigaddset(&sigset, sig) == -1) {
		perror("perror");
		return EXIT_FAILURE;
	}

	sig = SIGUSR2;
	if (sigaddset(&sigset, sig) == -1) {
		perror("perror");
		return EXIT_FAILURE;
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

	if (mkdir("/run/tini", DEFFILEMODE)  == -1)
		perror("mkdir");

	fd = netlink_open(&addr, SIGIO);
	if (fd == -1)
		return EXIT_FAILURE;

	printf("tini started!\n");

	spawn("/etc/init.d/rcS", rcS, NULL);

	for (;;) {
		siginfo_t siginfo;
		sig = sigwaitinfo(&sigset, &siginfo);
		if (sig == -1) {
			if (errno == EINTR)
				continue;

			perror("sigwaitinfo");
			break;
		}

		debug("sigwaitinfo(): %s\n", strsignal(sig));

		/* Reap zombies */
		if (sig == SIGCHLD) {
			verbose("pid %i exited with status %i\n",
				siginfo.si_pid, siginfo.si_status);

			pid_respawn(siginfo.si_pid, siginfo.si_status);
			while (waitpid(-1, NULL, WNOHANG) > 0);
			continue;
		}

		/* Netlink uevent */
		if (sig == SIGIO) {
			netlink_recv(fd, &addr);
			continue;
		}

		/* Exit */
		if ((sig == SIGTERM) || (sig == SIGINT) ||
		    (sig == SIGUSR1) || (sig == SIGUSR2))
			break;
	}

	/* Reap zombies */
	while (waitpid(-1, NULL, WNOHANG) > 0);

	netlink_close(fd);
	fd = -1;

	if (sigprocmask(SIG_UNBLOCK, &sigset, NULL) == -1)
		perror("sigprocmask");

	/* Re-execute itself */
	if (sig == SIGUSR1) {
		execv(argv[0], argv);
		exit(EXIT_FAILURE);
	}

	/* Halt */
	if (sig == SIGUSR2) {
		if (reboot(RB_HALT_SYSTEM) == -1)
			perror("reboot");
		exit(EXIT_FAILURE);
	}

	/* Reboot (Ctrl-Alt-Delete) */
	if (sig == SIGINT) {
		sync();
		if (reboot(RB_AUTOBOOT) == -1)
			perror("reboot");
		exit(EXIT_FAILURE);
	}

	/* Power off */
	printf("tini stopped!\n");

	sync();
	if (reboot(RB_POWER_OFF) == -1)
		perror("reboot");

	exit(EXIT_FAILURE);
}

int main(int argc, char * const argv[])
{
	const char *app = applet(argv[0]);

	if (!strcmp(app, "tini"))
		return main_tini(argc, argv);

	return main_applet(argc, argv);
}
