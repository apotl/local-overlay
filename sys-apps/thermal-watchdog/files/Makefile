CC ?= gcc
CFLAGS ?= -O2 -Wall -Wextra

thermal-watchdog: thermal-watchdog.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $<

clean:
	rm -f thermal-watchdog

.PHONY: clean
