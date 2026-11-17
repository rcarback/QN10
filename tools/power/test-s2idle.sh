#!/bin/sh
# Run ON THE QN10 as root: sh test-s2idle.sh [freeze|mem]
# Records device state, suspends (default s2idle), and after a manual wake
# (keyboard or power button) writes the resume log and a before/after
# comparison to /var/log/qn10-s2idle.log. No RTC can wake the QN10, so
# someone must be at the machine.
set -u
MODE=${1:-freeze}
LOG=/var/log/qn10-s2idle.log
snap() {
	echo "== $1"
	lsusb | sort
	ls /dev/video* /dev/fastrpc* 2>/dev/null
	cat /proc/asound/cards
	ip -br addr | grep -v '^lo'
	for d in /sys/bus/pci/devices/*; do
		echo "${d##*/} $(cat "$d/current_link_speed" 2>/dev/null)"
	done
	for r in /sys/class/remoteproc/*; do echo "$(cat "$r/name") $(cat "$r/state")"; done
	cat /sys/class/drm/card*-*/status 2>/dev/null | tr '\n' ' '
	echo
}
{
	date
	echo "mode=$MODE mem_sleep=$(cat /sys/power/mem_sleep)"
	snap before
	dmesg -c >/dev/null
	sync
	t0=$(date +%s)
	rc=0
	printf '%s' "$MODE" >/sys/power/state || rc=$?
	echo "state write returned $rc after $(($(date +%s) - t0)) s"
	sleep 8
	snap after
	echo "== resume dmesg"
	dmesg
	echo "== suspend stats"
	grep -r . /sys/power/suspend_stats/ 2>/dev/null
} >"$LOG" 2>&1
sync
