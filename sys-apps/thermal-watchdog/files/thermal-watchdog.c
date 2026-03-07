#define _GNU_SOURCE
#include <dirent.h>
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <syslog.h>
#include <unistd.h>
#include <linux/reboot.h>
#include <sys/reboot.h>
#include <syscall.h>

#define POLL_INTERVAL 2
#define WARN_TEMP     85000
#define CRIT_TEMP     92000
#define MAX_SENSORS   8
#define PATH_MAX_LEN  512

static volatile sig_atomic_t running = 1;
static int test_mode;

static void handle_signal(int sig) {
	(void)sig;
	running = 0;
}

static int read_int(const char *path) {
	FILE *f = fopen(path, "r");
	if (!f) return -1;
	int val;
	if (fscanf(f, "%d", &val) != 1) val = -1;
	fclose(f);
	return val;
}

static int read_str(const char *path, char *buf, size_t len) {
	FILE *f = fopen(path, "r");
	if (!f) return -1;
	if (!fgets(buf, len, f)) { fclose(f); return -1; }
	fclose(f);
	buf[strcspn(buf, "\n")] = '\0';
	return 0;
}

/* Find the hwmon directory whose "name" file contains "k10temp". */
static int find_k10temp(const char *base, char *out, size_t len) {
	DIR *d = opendir(base);
	if (!d) return -1;
	struct dirent *ent;
	while ((ent = readdir(d))) {
		if (ent->d_name[0] == '.') continue;
		char name_path[PATH_MAX_LEN];
		snprintf(name_path, sizeof(name_path), "%s/%s/name", base, ent->d_name);
		char name[64];
		if (read_str(name_path, name, sizeof(name)) == 0 &&
		    strcmp(name, "k10temp") == 0) {
			snprintf(out, len, "%s/%s", base, ent->d_name);
			closedir(d);
			return 0;
		}
	}
	closedir(d);
	return -1;
}

struct sensor {
	char input_path[PATH_MAX_LEN + 32];
	char label[64];
};

/* Discover all tempN_input files under the hwmon dir. */
static int discover_sensors(const char *hwmon, struct sensor *sensors, int max) {
	int count = 0;
	for (int i = 1; i <= 16 && count < max; i++) {
		char path[PATH_MAX_LEN + 32];
		snprintf(path, sizeof(path), "%s/temp%d_input", hwmon, i);
		if (access(path, R_OK) != 0) continue;

		snprintf(sensors[count].input_path, sizeof(sensors[count].input_path), "%s", path);

		char lpath[PATH_MAX_LEN + 32];
		snprintf(lpath, sizeof(lpath), "%s/temp%d_label", hwmon, i);
		if (read_str(lpath, sensors[count].label, sizeof(sensors[count].label)) != 0)
			snprintf(sensors[count].label, sizeof(sensors[count].label), "temp%d", i);

		syslog(LOG_INFO, "found sensor: %s (%s)", sensors[count].label, path);
		count++;
	}
	return count;
}

static void do_reboot(void) {
	syslog(LOG_EMERG, "CRITICAL: initiating emergency reboot");
	sync();
	if (test_mode)
		_exit(99);
	reboot(LINUX_REBOOT_CMD_RESTART);
	/* fallback — should never reach here */
	syscall(SYS_reboot, LINUX_REBOOT_MAGIC1, LINUX_REBOOT_MAGIC2,
	        LINUX_REBOOT_CMD_RESTART, NULL);
}

int main(int argc, char **argv) {
	const char *base = "/sys/class/hwmon";
	int opt;

	while ((opt = getopt(argc, argv, "t:")) != -1) {
		switch (opt) {
		case 't':
			base = optarg;
			test_mode = 1;
			break;
		default:
			fprintf(stderr, "usage: %s [-t <fake_hwmon_base>]\n", argv[0]);
			return 1;
		}
	}

	openlog("thermal-watchdog", LOG_PID | LOG_PERROR, LOG_DAEMON);

	char hwmon[PATH_MAX_LEN];
	if (find_k10temp(base, hwmon, sizeof(hwmon)) != 0) {
		syslog(LOG_ERR, "k10temp hwmon device not found under %s", base);
		closelog();
		return 2;
	}
	syslog(LOG_INFO, "k10temp found at %s", hwmon);

	struct sensor sensors[MAX_SENSORS];
	int nsensors = discover_sensors(hwmon, sensors, MAX_SENSORS);
	if (nsensors == 0) {
		syslog(LOG_ERR, "no temperature sensors found");
		closelog();
		return 2;
	}

	signal(SIGTERM, handle_signal);
	signal(SIGINT, handle_signal);

	int warned = 0;

	while (running) {
		int max_temp = 0;
		for (int i = 0; i < nsensors; i++) {
			int t = read_int(sensors[i].input_path);
			if (t < 0) continue;
			if (t > max_temp) max_temp = t;
		}

		if (max_temp >= CRIT_TEMP) {
			syslog(LOG_EMERG, "CRITICAL: CPU at %d.%03d C — rebooting!",
			       max_temp / 1000, max_temp % 1000);
			do_reboot();
		}

		if (max_temp >= WARN_TEMP && !warned) {
			syslog(LOG_WARNING, "WARNING: CPU at %d.%03d C",
			       max_temp / 1000, max_temp % 1000);
			warned = 1;
		} else if (max_temp < WARN_TEMP) {
			warned = 0;
		}

		sleep(POLL_INTERVAL);
	}

	syslog(LOG_INFO, "shutting down");
	closelog();
	return 0;
}
