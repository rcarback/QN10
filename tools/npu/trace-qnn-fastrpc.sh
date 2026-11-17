#!/bin/sh
# Run ON THE QN10 as root: sh trace-qnn-fastrpc.sh
# Arms kretprobes on the mainline FastRPC entry points, runs the QNN HTP
# test, and dumps which calls QNN made to the kernel driver and their
# return values. Compares against the working fastrpc_test path to locate
# where QNN's transport (err 4000) diverges.
set -u
T=/sys/kernel/tracing
R=/home/debian/qairt/qairt/2.44.0.260225
W=/home/debian/qnnwork
cleanup() {
	echo 0 >"$T/tracing_on" 2>/dev/null
	[ -d "$T/events/kprobes" ] && echo 0 >"$T/events/kprobes/enable" 2>/dev/null
	echo >"$T/kprobe_events" 2>/dev/null
}
trap cleanup EXIT
cleanup
echo >"$T/trace"
for f in fastrpc_device_open fastrpc_device_ioctl fastrpc_internal_invoke \
	fastrpc_req_mmap fastrpc_mmap; do
	echo "r:r_$f $f ret=\$retval:s64" >>"$T/kprobe_events" 2>/dev/null ||
		echo "cannot probe $f"
done
[ -d "$T/events/kprobes" ] && echo 1 >"$T/events/kprobes/enable"
echo 1 >"$T/tracing_on"

cd "$W" || exit 1
export LD_LIBRARY_PATH="$R/lib/aarch64-oe-linux-gcc11.2:$W/libs/aarch64-oe-linux-gcc11.2"
export ADSP_LIBRARY_PATH="$R/lib/hexagon-v81/unsigned;/usr/share/hexagon-dsp/glymur/ASUSTeK/QN10/dsp/cdsp"
export LD_PRELOAD="$W/socid-shim.so" QN10_FAKE_SOCID=708
timeout 60 "$R/bin/aarch64-oe-linux-gcc11.2/qnn-net-run" \
	--model "libs/aarch64-oe-linux-gcc11.2/libqnn_model_8bit_quantized.so" \
	--input_list input_list_float.txt \
	--backend "$R/lib/aarch64-oe-linux-gcc11.2/libQnnHtp.so" \
	--config_file backend_ext.json --output_dir out_trace >qnn_trace_run.log 2>&1
echo "=== qnn-net-run errors:"
grep -iE "error|fail|4000" qnn_trace_run.log | head -6
echo "=== kernel fastrpc calls QNN made (by qnn-net-run):"
echo 0 >"$T/tracing_on"
grep -c "r_fastrpc_device_open" "$T/trace"
grep -E "qnn-net-run" "$T/trace" | sed -E 's/^ +//; s/ +/ /g' | cut -d' ' -f5- | sort | uniq -c | head -20
