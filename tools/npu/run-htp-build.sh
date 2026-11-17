#!/bin/sh
# Build the QNN example quantized model into an aarch64 .so ON THE QN10.
# Prereq: QAIRT SDK extracted at ~/qairt/qairt/<ver> (local only, vendor
# binaries; never publish). Native aarch64 g++ is used as the "cross"
# compiler by pointing the sysroot var at /.
# Follow with run-htp-netrun.sh to run it on the HTP (Hexagon V81).
set -u
R=$HOME/qairt/qairt/2.44.0.260225
W=/tmp/qnnmodel2
M=$R/examples/QNN/converter/models
mkdir -p "$W"
cp "$M/input_list_float.txt" "$W/"
cp -r "$M/input_data_float" "$W/" 2>/dev/null || true
export QNN_SDK_ROOT="$R" QNN_AARCH64_UBUNTU_GCC_94=/
cd "$W" || exit 1
python3 "$R/bin/x86_64-linux-clang/qnn-model-lib-generator" \
	-c "$M/qnn_model_8bit_quantized.cpp" \
	-b "$M/qnn_model_8bit_quantized.bin" \
	-o ./libs -t aarch64-ubuntu-gcc9.4
find libs -name "*.so"
