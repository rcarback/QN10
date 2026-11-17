#!/bin/sh
# Copy the QN10's Windows DriverStore Hexagon DSP libraries (FastRPC shells,
# skels) into build/fw/dsp/ in the layout libfastrpc expects:
#   dsp/adsp/*, dsp/cdsp/*
# Install on the QN10 under /usr/share/hexagon-dsp/glymur/ASUSTeK/QN10/dsp
# and point asus-ascent-qn10.yaml at glymur/ASUSTeK/QN10/dsp.
# LOCAL USE ONLY: Qualcomm/ASUS binaries; never commit or publish them.
set -eu
B=$(cd "$(dirname "$0")/.." && pwd)
D=$B/../qn10-dump-raw/qn10-dump/drivers
out=$B/fw/dsp
mkdir -p "$out/adsp" "$out/cdsp"
cp "$D"/qcsubsys_ext_adsp8480.inf_arm64_*/ADSP/* "$out/adsp/"
cp "$D"/qcnspmcdm8480.inf_arm64_*/CDSP/* "$out/cdsp/"
cp "$D"/qcnspmcdm8480.inf_arm64_*/HTP/* "$out/cdsp/"
(cd "$out" && find . -type f | sort | xargs shasum -a 256 >SHA256SUMS)
wc -l <"$out/SHA256SUMS"
