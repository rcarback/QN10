#!/bin/sh
# systemd-sleep hook: reload the ath12k Wi-Fi module around suspend.
# Install as /usr/lib/systemd/system-sleep/qn10-wifi.
#
# The WCN7850 (ath12k_wifi7_pci, 0004:01:00.0) firmware does not survive
# s2idle on the QN10: after resume it fails with "failed to enable PMF QOS:
# -108" / "fail to start mac operations ... ret -108" and never comes back,
# taking the box off the network. Removing the PCI-glue module before
# suspend and re-probing it after forces a clean firmware download on
# resume; NetworkManager then re-associates on its own.
#
# systemd runs this with: $1 = pre|post, $2 = suspend|hibernate|...
set -u
MOD=ath12k_wifi7
STAMP=/run/qn10-wifi-was-loaded

case "$1/$2" in
pre/*)
	if lsmod | grep -q "^${MOD} "; then
		touch "$STAMP"
		modprobe -r "$MOD" 2>/dev/null ||
			logger -t qn10-wifi "failed to remove $MOD before $2"
	fi
	;;
post/*)
	if [ -e "$STAMP" ]; then
		rm -f "$STAMP"
		modprobe "$MOD" 2>/dev/null ||
			logger -t qn10-wifi "failed to reload $MOD after $2"
	fi
	;;
esac
