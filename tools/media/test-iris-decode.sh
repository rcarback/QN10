#!/bin/sh
# Run ON THE QN10 as the debian user: sh test-iris-decode.sh [CLIP W H]
# Decodes a 1080p H.264 Annex-B clip on the iris hardware decoder through
# GStreamer's v4l2h264dec, counts the frames and prints MD5 sums of frames
# 0, 75 and 149 in I420. Compare them with a software decode on another
# machine:
#   ffmpeg -f lavfi -i testsrc2=size=1920x1080:rate=30 -t 5 -c:v libx264 \
#     -pix_fmt yuv420p -bsf:v h264_mp4toannexb -f h264 test-1080p.h264
#   ffmpeg -i test-1080p.h264 -f rawvideo -pix_fmt yuv420p ref.i420
set -eu
CLIP=${1:-$HOME/test-1080p.h264}
W=${2:-1920}
H=${3:-1080}
out=$HOME/iris-decode.i420
trap 'rm -f "$out"' EXIT
v4l2-ctl --list-devices
start=$(date +%s.%N)
gst-launch-1.0 -q filesrc location="$CLIP" ! h264parse ! v4l2h264dec \
	! videoconvert ! video/x-raw,format=I420 ! filesink location="$out"
end=$(date +%s.%N)
echo "seconds: $(echo "$end - $start" | bc)"
python3 -I - "$out" "$W" "$H" <<'EOF'
import hashlib, sys
path, w, h = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
f = w * h * 3 // 2
d = open(path, "rb").read()
n = len(d) // f
print("frames decoded:", n)
for i in (0, n // 2, n - 1):
    print("frame", i, hashlib.md5(d[i * f:(i + 1) * f]).hexdigest())
EOF
