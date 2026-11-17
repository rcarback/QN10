#!/bin/sh
# qn10-audio-routes: set the headset-mic capture and HDMI playback routes
# after alsa-restore.
#
# alsactl restore stops at "GE 35 Selected Mode" (the codec owns it while a
# headset is in, -EBUSY), so controls stored after it, including the capture
# route, are never restored. Set the route explicitly instead.
set -u
CARD=${1:-0}
set_ctl() {
	amixer -q -c "$CARD" cset name="$1" "$2" || echo "qn10-audio-routes: cannot set '$1'" >&2
}

# Headset mic: WCD9378 DP2 -> swr2 port 2 -> TX macro SWR_MIC0 -> DEC0/DEC1
# -> TX_AIF1 -> TX_CODEC_DMA_TX_3 -> MultiMedia3 (hw:0,2). Both decimators
# carry the mic so both capture channels have it.
set_ctl "TX SMIC MUX0" "SWR_MIC0"
set_ctl "TX SMIC MUX1" "SWR_MIC0"
set_ctl "TX DEC0 MUX" "SWR_MIC"
set_ctl "TX DEC1 MUX" "SWR_MIC"
set_ctl "TX_AIF1_CAP Mixer DEC0" on
set_ctl "TX_AIF1_CAP Mixer DEC1" on
# +12 dB digital gain (84 = 0 dB); 110 (+26 dB) clipped and hissed
set_ctl "TX_DEC0 Volume" 96
set_ctl "TX_DEC1 Volume" 96
set_ctl "MultiMedia3 Mixer TX_CODEC_DMA_TX_3" on

# Rear HDMI: MultiMedia7 (hw:0,6) -> DISPLAY_PORT_RX_3 -> mdss_dp3.
set_ctl "DISPLAY_PORT_RX_3 Audio Mixer MultiMedia7" on
