#!/bin/sh
# Run the QNN HTP model with soc_id spoofed to 660 (SM8850 = Hexagon V81),
# the recognized V81 part matching the QN10's real V81 DSP. Writes the full
# result to ~/qnnwork/run660.log. Paths hardcoded for systemd-run use.
set -u
R=/home/debian/qairt/qairt/2.44.0.260225
W=/home/debian/qnnwork
LOG=$W/run660.log
T=aarch64-oe-linux-gcc11.2
{
	cd "$W" || exit 1
	export LD_LIBRARY_PATH="$R/lib/$T:$W/libs/$T"
	export ADSP_LIBRARY_PATH="$R/lib/hexagon-v81/unsigned;/usr/share/hexagon-dsp/glymur/ASUSTeK/QN10/dsp/cdsp"
	export LD_PRELOAD="$W/socid-shim.so" QN10_FAKE_SOCID=660
	"$R/bin/$T/qnn-net-run" \
		--model "libs/$T/libqnn_model_8bit_quantized.so" \
		--input_list input_list_float.txt \
		--backend "$R/lib/$T/libQnnHtp.so" \
		--config_file backend_ext.json --output_dir out_660 --log_level info
	echo "NETRUN_EXIT=$?"
	echo "== outputs:"; ls -la out_660 2>/dev/null
} >"$LOG" 2>&1
