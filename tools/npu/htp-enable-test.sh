#!/bin/sh
# End-to-end NPU/HTP enablement test on the QN10. Run ON THE QN10:
#   nohup sh htp-enable-test.sh > ~/qnnwork/run.log 2>&1 &
# Uses the aarch64-oe-linux-gcc11.2 QAIRT target, which is the only Linux
# target that ships the V81 host transport stub (libQnnHtpV81Stub.so). The
# soc-id shim spoofs the X2's soc_id 698 to a recognized V81 part (660),
# working around QAIRT 2.44 not knowing 698. Vendor SDK at ~/qairt, local.
set -u
R=$HOME/qairt/qairt/2.44.0.260225
W=$HOME/qnnwork
M=$R/examples/QNN/converter/models
TARGET=aarch64-oe-linux-gcc11.2
BIN=$R/bin/$TARGET
LIB=$R/lib/$TARGET
mkdir -p "$W"
cd "$W" || exit 1
cp "$M/input_list_float.txt" .
cp -r "$M/input_data_float" . 2>/dev/null || true

echo "== build model ($TARGET)"
export QNN_SDK_ROOT="$R" QNN_AARCH64_OE_LINUX_GCC_112=/ QNN_AARCH64_UBUNTU_GCC_94=/
export TARGET_PREFIX=aarch64-linux-gnu- SDKTARGETSYSROOT=/
python3 "$R/bin/x86_64-linux-clang/qnn-model-lib-generator" \
	-c "$M/qnn_model_8bit_quantized.cpp" -b "$M/qnn_model_8bit_quantized.bin" \
	-o ./libs -t "$TARGET" >build.log 2>&1 &&
	echo "  model: $(find libs -name '*.so')" || { echo "  build failed"; tail -5 build.log; }

echo "== compile shim"
gcc -shared -fPIC -O2 -o socid-shim.so "$HOME/socid-shim.c" -ldl && echo "  shim ok"

echo "== configs"
cat > htp_config.json <<JSON
{ "graphs": [{ "graph_names": ["convReluModel"], "O": 3 }],
  "devices": [{ "dsp_arch": "v81", "soc_id": 660, "pd_session": "unsigned",
    "cores": [{ "core_id": 0, "perf_profile": "burst" }] }] }
JSON
cat > backend_ext.json <<JSON
{ "backend_extensions": { "shared_library_path": "libQnnHtpNetRunExtensions.so",
    "config_file_path": "$W/htp_config.json" } }
JSON

echo "== run on HTP (target $TARGET, soc_id spoofed to ${QN10_FAKE_SOCID:-660})"
export LD_LIBRARY_PATH="$LIB:$W/libs/$TARGET"
export ADSP_LIBRARY_PATH="$R/lib/hexagon-v81/unsigned;/usr/share/hexagon-dsp/glymur/ASUSTeK/QN10/dsp/cdsp"
export LD_PRELOAD="$W/socid-shim.so"
export QN10_FAKE_SOCID="${QN10_FAKE_SOCID:-660}"
"$BIN/qnn-net-run" --model "libs/$TARGET/libqnn_model_8bit_quantized.so" \
	--input_list input_list_float.txt --backend "$LIB/libQnnHtp.so" \
	--config_file backend_ext.json --output_dir out_htp
echo "NETRUN_EXIT=$?"
echo "== outputs"; ls -R out_htp 2>/dev/null | head
