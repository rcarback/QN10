#!/bin/sh
# Run the QNN example model on the QN10's HTP (NPU, Hexagon V81) via FastRPC.
# Run ON THE QN10 after building the model .so with run-htp-build.sh:
#   nohup sh run-htp-netrun.sh > /tmp/qnnmodel2/run_htp.log 2>&1 &
# The V81 skel and soc_id 698 are forced via backend_ext.json/htp_config.json
# because QAIRT 2.44's HTP SoC auto-detect predates the X2 Elite.
set -u
R=$HOME/qairt/qairt/2.44.0.260225
W=/tmp/qnnmodel2
cd "$W" || exit 1
export LD_LIBRARY_PATH="$R/lib/aarch64-ubuntu-gcc9.4:$W/libs/aarch64-ubuntu-gcc9.4"
export ADSP_LIBRARY_PATH="$R/lib/hexagon-v81/unsigned;/usr/share/hexagon-dsp/glymur/ASUSTeK/QN10/dsp/cdsp"
"$R/bin/aarch64-ubuntu-gcc9.4/qnn-net-run" \
	--model "libs/aarch64-ubuntu-gcc9.4/libqnn_model_8bit_quantized.so" \
	--input_list input_list_float.txt \
	--backend "$R/lib/aarch64-ubuntu-gcc9.4/libQnnHtp.so" \
	--config_file backend_ext.json \
	--output_dir out_htp2
echo "NETRUN_EXIT=$?"
