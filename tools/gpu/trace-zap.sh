#!/bin/sh
# Run ON THE QN10 as root, booted with the zap-shader test DTB:
#   sh trace-zap.sh
# Arms entry and return kprobes on the zap load path, streams every hit to
# /var/log/qn10-zap-trace.log with an fsync per line, then opens the GPU
# (vulkaninfo) to trigger the load. If the SoC resets, read the log after
# the reboot: the last line shows how far the sequence got.
set -u
T=/sys/kernel/tracing
LOG=/var/log/qn10-zap-trace.log
: >"$LOG"
echo 0 >"$T/tracing_on"
echo >"$T/kprobe_events"
echo >"$T/trace"
for f in adreno_zap_shader_load qcom_mdt_pas_load qcom_scm_pas_init_image \
	qcom_tzmem_shm_bridge_create qcom_scm_pas_mem_setup qcom_mdt_load_no_init \
	qcom_scm_pas_prepare_and_auth_reset qcom_scm_pas_auth_and_reset \
	qcom_tzmem_shm_bridge_delete qcom_scm_pas_metadata_release a6xx_flush \
	a8xx_idle a8xx_hw_init; do
	echo "p:p_$f $f" >>"$T/kprobe_events" 2>/dev/null || echo "cannot probe entry $f"
	echo "r:r_$f $f ret=\$retval:s64" >>"$T/kprobe_events" 2>/dev/null ||
		echo "cannot probe return $f"
done
echo 1 >"$T/events/kprobes/enable"
echo 1 >"$T/tracing_on"
# Durable reader: one write and fsync per trace line.
python3 -I - "$T/trace_pipe" "$LOG" <<'EOF' &
import os, sys
src, dst = sys.argv[1], sys.argv[2]
fd = os.open(dst, os.O_WRONLY | os.O_APPEND)
with open(src, "rb", buffering=0) as pipe:
    buf = b""
    while True:
        chunk = pipe.read(4096)
        if not chunk:
            continue
        buf += chunk
        *lines, buf = buf.split(b"\n")
        for line in lines:
            os.write(fd, line + b"\n")
            os.fsync(fd)
EOF
reader=$!
sync
echo "== trigger"
vulkaninfo --summary 2>/dev/null | grep -E 'deviceName|driverName'
echo 0 >"$T/tracing_on"
kill "$reader" 2>/dev/null
cut -c1-160 "$LOG"
dmesg | grep -iE 'zap|authoriz|secure|hw init|gmu' | tail -8
echo 0 >"$T/events/kprobes/enable"
echo >"$T/kprobe_events"
