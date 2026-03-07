#!/bin/bash
set -euo pipefail

PASS=0
FAIL=0
BINARY="./thermal-watchdog"

fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }
pass() { echo "PASS: $1"; PASS=$((PASS+1)); }

cleanup() { rm -rf "$FAKE_BASE"; }

FAKE_BASE="$(mktemp -d /tmp/thermal-watchdog-test.XXXXXX)"
trap cleanup EXIT

OUTFILE="$FAKE_BASE/output"

# --- Helper: create a fake hwmon device ---
make_hwmon() {
	local base="$1" name="$2" idx="$3"
	local dir="$base/hwmon${idx}"
	mkdir -p "$dir"
	echo "$name" > "$dir/name"
}

make_sensor() {
	local dir="$1" num="$2" label="$3" temp="$4"
	echo "$label" > "$dir/temp${num}_label"
	echo "$temp"  > "$dir/temp${num}_input"
}

# ============================================================
# Test 1: Discovery — finds k10temp among multiple hwmon dirs
# ============================================================
echo "--- Test 1: Discovery ---"
T1="$FAKE_BASE/t1"
mkdir -p "$T1"
make_hwmon "$T1" "acpitz" 0
make_hwmon "$T1" "nvme" 1
make_hwmon "$T1" "k10temp" 5
make_sensor "$T1/hwmon5" 1 "Tctl" 45000

"$BINARY" -t "$T1" >"$OUTFILE" 2>&1 &
PID=$!
sleep 1
kill "$PID" 2>/dev/null
wait "$PID" 2>/dev/null || true

if grep -q "k10temp found" "$OUTFILE"; then
	pass "discovery"
else
	fail "discovery — expected 'k10temp found' in output"
	cat "$OUTFILE"
fi

# ============================================================
# Test 2: Normal operation — stays alive at safe temp
# ============================================================
echo "--- Test 2: Normal operation ---"
T2="$FAKE_BASE/t2"
mkdir -p "$T2"
make_hwmon "$T2" "k10temp" 0
make_sensor "$T2/hwmon0" 1 "Tctl" 60000
make_sensor "$T2/hwmon0" 3 "Tccd1" 58000

"$BINARY" -t "$T2" >/dev/null 2>&1 &
PID=$!
sleep 3
if kill -0 "$PID" 2>/dev/null; then
	kill "$PID"
	wait "$PID" 2>/dev/null || true
	pass "normal operation (stayed alive at 60C)"
else
	wait "$PID" 2>/dev/null || true
	fail "normal operation — process died unexpectedly"
fi

# ============================================================
# Test 3: Warning at 86°C
# ============================================================
echo "--- Test 3: Warning ---"
T3="$FAKE_BASE/t3"
mkdir -p "$T3"
make_hwmon "$T3" "k10temp" 0
make_sensor "$T3/hwmon0" 1 "Tctl" 86000

"$BINARY" -t "$T3" >"$OUTFILE" 2>&1 &
PID=$!
sleep 3
kill "$PID" 2>/dev/null
wait "$PID" 2>/dev/null || true

if grep -qi "warning" "$OUTFILE"; then
	pass "warning at 86C"
else
	fail "warning — expected WARNING in output"
	cat "$OUTFILE"
fi

# ============================================================
# Test 4: Critical reboot at 93°C — exits with code 99
# ============================================================
echo "--- Test 4: Critical reboot ---"
T4="$FAKE_BASE/t4"
mkdir -p "$T4"
make_hwmon "$T4" "k10temp" 0
make_sensor "$T4/hwmon0" 1 "Tctl" 93000

set +e
"$BINARY" -t "$T4" 2>/dev/null
RC=$?
set -e

if [ "$RC" -eq 99 ]; then
	pass "critical reboot (exit code 99 at 93C)"
else
	fail "critical reboot — expected exit 99, got $RC"
fi

# ============================================================
# Test 5: No k10temp sensor — graceful error
# ============================================================
echo "--- Test 5: No sensor ---"
T5="$FAKE_BASE/t5"
mkdir -p "$T5"
make_hwmon "$T5" "acpitz" 0

set +e
"$BINARY" -t "$T5" 2>/dev/null
RC=$?
set -e

if [ "$RC" -eq 2 ]; then
	pass "no sensor (exit code 2)"
else
	fail "no sensor — expected exit 2, got $RC"
fi

# ============================================================
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
