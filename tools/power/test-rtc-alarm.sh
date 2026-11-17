#!/bin/sh
# Run ON THE QN10 as root: sh test-rtc-alarm.sh [SECONDS]
# Arms the RTC wake alarm while the system is awake and reports whether the
# alarm interrupt fired, before relying on it to wake from suspend.
set -u
S=${1:-8}
R=/sys/class/rtc/rtc0
before=$(grep -E 'pmic|rtc|glink' /proc/interrupts | awk '{s=0; for (i=2; i<=NF; i++) if ($i ~ /^[0-9]+$/) s+=$i; print $NF, s}')
echo 0 >"$R/wakealarm"
echo "+$S" >"$R/wakealarm"
echo "armed for $(cat "$R/wakealarm") (now $(cat "$R/since_epoch"))"
sleep $((S + 3))
echo "wakealarm after: '$(cat "$R/wakealarm")'"
grep -iE 'alarm|irq' /proc/driver/rtc 2>/dev/null
echo "before: $before"
grep -E 'pmic|rtc|glink' /proc/interrupts | awk '{s=0; for (i=2; i<=NF; i++) if ($i ~ /^[0-9]+$/) s+=$i; print "after:", $NF, s}'
dmesg | tail -3
