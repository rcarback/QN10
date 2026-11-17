#!/bin/sh
# Run ON THE QN10 (detached, as root): validates the suspend hook's core
# action -- removing ath12k before suspend and reloading it after -- without
# an actual suspend cycle, which would need a physical wake. Removes the
# Wi-Fi module, reloads it, and waits for NetworkManager to reconnect. If
# Wi-Fi does not return within the timeout, REBOOTS so the box self-recovers
# to a known-good state (never left stranded offline).
# Result is written to /var/log/qn10-wifi-reload.log (survives the reboot).
set -u
MOD=ath12k_wifi7
LOG=/var/log/qn10-wifi-reload.log
{
	date
	echo "before: $(nmcli -t -f STATE g 2>/dev/null)  ip=$(ip -4 -o addr show wlP4p1s0 2>/dev/null | awk '{print $4}')"
	echo "removing $MOD..."
	modprobe -r "$MOD" 2>&1 || echo "rmmod failed"
	echo "removed; module present now: $(lsmod | grep -c "^${MOD}")"
	sleep 4
	echo "reloading $MOD..."
	modprobe "$MOD" 2>&1 || echo "modprobe failed"
	# wait up to 75s for reconnect
	ok=0
	i=0
	while [ "$i" -lt 25 ]; do
		i=$((i + 1))
		state=$(nmcli -t -f STATE g 2>/dev/null)
		ip=$(ip -4 -o addr show wlP4p1s0 2>/dev/null | awk '{print $4}')
		if [ "$state" = "connected" ] && [ -n "$ip" ]; then
			ok=1
			echo "RECONNECTED after ${i}x3s: ip=$ip"
			break
		fi
		sleep 3
	done
	if [ "$ok" -eq 1 ]; then
		echo "RESULT: wifi module reload RESTORES connectivity -- suspend hook mechanism is sound"
	else
		echo "RESULT: reload did NOT restore wifi; rebooting to recover"
		sync
		sleep 2
		systemctl reboot
	fi
} >"$LOG" 2>&1
sync
