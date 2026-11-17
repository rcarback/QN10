/*
 * socid-shim: LD_PRELOAD that makes QNN's libQnnHtp.so see a recognized
 * SoC ID. The QN10 reports soc_id 698 (Snapdragon X2 Elite Extreme), which
 * QAIRT 2.44's HTP runtime does not know, so it aborts with "No Snapdragon
 * SOC detected". We redirect reads of /sys/devices/soc0/soc_id (and the
 * alternate id path) to a file holding a recognized V81 SoC id (default
 * 660 = SM8850 (shares the X2 V81 DSP arch)), so the HTP backend selects the V81 DSP path.
 *
 *   gcc -shared -fPIC -O2 -o socid-shim.so socid-shim.c -ldl
 *   export QN10_FAKE_SOCID=660           # optional, default 660
 *   LD_PRELOAD=/path/socid-shim.so qnn-net-run ...
 *
 * No vendor binary is modified; this only changes what the library reads.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <fcntl.h>
#include <unistd.h>

static const char *TARGETS[] = {
	"/sys/devices/soc0/soc_id",
	"/sys/devices/system/soc/soc0/id",
	NULL,
};

static int is_target(const char *path)
{
	if (!path)
		return 0;
	for (int i = 0; TARGETS[i]; i++)
		if (strcmp(path, TARGETS[i]) == 0)
			return 1;
	return 0;
}

/* Write the spoofed id to a temp file and return its path (static buffer). */
static const char *fake_file(void)
{
	static char path[64];
	static int ready;
	if (ready)
		return path;
	const char *id = getenv("QN10_FAKE_SOCID");
	if (!id || !*id)
		id = "660";
	snprintf(path, sizeof(path), "/tmp/.qn10_socid_%d", getpid());
	FILE *f = fopen(path, "w");
	if (f) {
		fprintf(f, "%s\n", id);
		fclose(f);
		ready = 1;
	}
	return path;
}

static int (*real_open)(const char *, int, ...);
static int (*real_openat)(int, const char *, int, ...);
static FILE *(*real_fopen)(const char *, const char *);

int open(const char *path, int flags, ...)
{
	if (!real_open)
		real_open = dlsym(RTLD_NEXT, "open");
	mode_t mode = 0;
	if (flags & O_CREAT) {
		va_list ap; va_start(ap, flags);
		mode = va_arg(ap, int); va_end(ap);
	}
	if (is_target(path))
		return real_open(fake_file(), O_RDONLY);
	return real_open(path, flags, mode);
}

int openat(int dirfd, const char *path, int flags, ...)
{
	if (!real_openat)
		real_openat = dlsym(RTLD_NEXT, "openat");
	mode_t mode = 0;
	if (flags & O_CREAT) {
		va_list ap; va_start(ap, flags);
		mode = va_arg(ap, int); va_end(ap);
	}
	if (is_target(path))
		return real_openat(AT_FDCWD, fake_file(), O_RDONLY);
	return real_openat(dirfd, path, flags, mode);
}

FILE *fopen(const char *path, const char *mode)
{
	if (!real_fopen)
		real_fopen = dlsym(RTLD_NEXT, "fopen");
	if (is_target(path))
		return real_fopen(fake_file(), "r");
	return real_fopen(path, mode);
}

/* 64-bit variants alias the same implementations. */
int open64(const char *p, int f, ...) __attribute__((alias("open")));
int openat64(int d, const char *p, int f, ...) __attribute__((alias("openat")));
FILE *fopen64(const char *p, const char *m) __attribute__((alias("fopen")));
