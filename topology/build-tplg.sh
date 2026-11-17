#!/bin/sh
# Build the QN10 AudioReach topology. Run inside the Linux build VM:
#   orb -m qn10-build -u root sh build-tplg.sh SRC OUTDIR
#   SRC     checkout of https://github.com/linux-msm/audioreach-topology
#   OUTDIR  gets GLYMUR-ASUS-Ascent-QN10-tplg.bin
# Install on the QN10 as /lib/firmware/qcom/glymur/GLYMUR-ASUS-Ascent-QN10-tplg.bin.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$1 OUT=$2
if ! command -v alsatplg >/dev/null || ! command -v m4 >/dev/null; then
	DEBIAN_FRONTEND=noninteractive apt-get install -y -qq m4 alsa-utils >/dev/null
fi
mkdir -p "$OUT"
m4 -I "$SRC" "$HERE/GLYMUR-ASUS-Ascent-QN10.m4" >"$OUT/GLYMUR-ASUS-Ascent-QN10.conf"
alsatplg -c "$OUT/GLYMUR-ASUS-Ascent-QN10.conf" -o "$OUT/GLYMUR-ASUS-Ascent-QN10-tplg.bin"
sha256sum "$OUT/GLYMUR-ASUS-Ascent-QN10-tplg.bin"
