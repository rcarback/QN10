# USB 3 link training failure on QN10 internal hub: research

Date: 2026-11-16. Method: web search and reading only. No device touched.

## Bottom line

Public sources show no confirmed fix for this exact case (GL3523-class downstream
port stuck in SS Polling behind a USB3 KVM). The searches found no report that
names a Genesys 05e3:0610/0625 quirk, a KVM-specific Linux quirk, or an X1E/X2
report of the same symptom. The ranked list below combines the closest evidence
with testable ideas. Items marked "idea" have no source that confirms they work.

Key reasoning: the stuck link is between the Genesys hub downstream port and the
KVM upstream port. The dwc3 controller trained fine with the Genesys hub (a flash
drive got 5 Gbps on a sibling port). So dwc3 and QMP PHY quirks are the wrong
layer. They do not drive this link. This explains why the dwc3 quirks already
tried had no effect. The levers that remain are: the hub port state machine
(warm reset, terminations, power), the physical channel (cable, tier depth), and
the KVM side.

## Findings by question

### Q1. Reports of hubs or KVMs stuck in Polling, Compliance or Inactive

- Mathias Nyman, "usb: warm reset USB3 ports stuck in polling" (2019-02-14). A
  USB3 card reader stayed in Polling longer than tPollingLFPSTimeout (360 ms).
  Fix: warm reset the port. Details in Q2.
- Julius Werner, 2013 thread on reset-resume of SS hubs: link training can
  deadlock with the device in SS.Inactive and the host port in Polling or
  Recovery. The remedy was a warm reset of the port.
- 01signal write-up: power-cycling a SuperSpeed port with uhubctl left the
  device in Polling and unenumerated. VBUS cycling alone does not retrain.
- wpilibsuite/SystemcoreTesting issue 366: TUSB8041 SS uplink permanently in
  Link:Polling, only USB2 half enumerates. The maintainer attributed it to a
  board hardware issue fixed in a later board revision. This is a precedent for
  a signal-integrity cause that software cannot fix.
- Manjaro forum thread: USB3 hub seen only as USB2. One user reported
  usbcore.autosuspend=-1 helped. Anecdotal, no mechanism given.
- No report found for a Genesys GL3523/GL3590/GL3510 or VIA VL817/VL822 KVM stuck
  in Polling. No fix found for cable length either.

### Q2. Kernel recovery mechanisms (hub.c)

- `hub_port_stuck_in_polling()` (Nyman, 2019). In `port_event()`, the warm reset
  condition is `hub_port_warm_reset_required() || hub_port_stuck_in_polling()`.
  The helper polls the link state every 24 ms (HUB_LFPS_TIME) and returns true
  after 360 ms (HUB_LFPS_TIMEOUT) in Polling. `hub_activate()` also sets the
  port event bit when a SS port is in Polling. Whether it merged is not stated
  on the page I read. Verify in the tree:
  `grep -n hub_port_stuck_in_polling drivers/usb/core/hub.c`.
- Limitation (inference from the patch text): the check runs from `port_event()`
  and `hub_activate()`. A hub that raises no port event for a port that sits in
  Polling would never get the warm reset. Check whether the kernel tries it, see
  workaround 1.
- Kai-Heng Feng, "usb: core: Avoid doing warm reset on disconnect event" (2021):
  skips warm reset when the event looks like a disconnect. Not a fix here, but it
  shows warm reset logic is event-gated and has had regressions (warm reset
  loops, a reset-asserted bit that stays set).
- Jan-Marek Glogowski, "usb: handle warm-reset port requests on hub resume"
  (2019): sets event bits on hub resume so `port_event()` does the warm reset.
- No sysfs knob or usbcore quirk found that forces a warm reset or retries SS
  after USB2 enumeration. The only related per-port sysfs files I know of are
  `disable`, `quirks` (port quirks) and `connect_type`. That list comes from
  memory of the kernel ABI docs and was not confirmed by a source in this search.

### Q3. KVMs with keyboard/mouse emulation plus a USB3 hub behind a hub

No source found that documents this class of failure or a recommended workaround.
Treat as unknown. A speculative factor: a KVM that muxes SS lanes may only
complete Rx detection and LFPS handshake in specific conditions, and a hub in
front of it adds a tier and a lossy channel. The fact that it works in UEFI and
on Windows does not prove it works behind a hub, because those hosts may connect
directly to a controller root port. Confirm which topology those tests used.

### Q4. Genesys GL3523 errata and quirks

- No entry for 05e3:0610 or 05e3:0625 in Linux quirks.c turned up in search.
  Local check is cheap: `rg 05e3 drivers/usb/core/quirks.c` in the tree.
- fwupd has a Genesys plugin that updates GL3521, GL3523, GL3525 and GL3590 hubs
  (https://fwupd.github.io/libfwupdplugin/genesys-README.html). No release notes
  tie any firmware version to KVM compatibility. Updating the QN10 internal hub
  firmware is high risk and not recommended without a recovery path.
- Genesys GL3523 Rev 2.x firmware 9303 exists for Windows (station-drivers.com),
  with no notes.
- Linux has a Genesys hub DT binding and onboard-hub driver (GL3523 on Odroid N2).
  They cover reset and supply handling, not link training.

### Q5. Qualcomm X1E/X2 reports

- Nothing found about USB3 devices behind the internal hub failing to train.
- Related hardware facts from the 2024-12 QCP patch (lkml.iu.edu 2412.0/00577):
  Type-A ports on `usb_mp` use NXP PTN3222 eUSB2 repeaters for HS and dedicated
  QMP PHYs for SS.
- 2025-11 RFC: SS1/SS2 USB combo PHY ref clocks have an extra gate, and PHY init
  failed without clk_ignore_unused on one XPS13. This concerns PHY init, not the
  hub downstream link, so it is unlikely here because other SS devices train.

## Ranked workarounds

Ranking weighs how likely each is to help and how cheap it is to test.

1. Retry SS after the KVM is already up on USB2 (idea, no source).
   Setting `disable`=1 makes the KVM enumerate on USB2. Then re-enable the SS
   terminations:
   `echo 0 > /sys/bus/usb/devices/<hub>:1.0/usb<N>-port<P>/disable`
   (the SS hub's port directory). The KVM hub is already powered and its
   firmware settled, which may allow LFPS to succeed. Run this after USB2
   enumeration completes. A udev or systemd oneshot could automate it. Low
   effort, moderate chance.

2. Send a warm reset to the stuck SS port from userspace (idea, grounded in the
   Nyman patch). Hub class request SetPortFeature BH_PORT_RESET (feature
   selector 28, recipient other, wIndex = port number) on the 05e3:0625 hub via
   a small libusb or python-usb script. This is what the kernel does in
   `hub_port_warm_reset()`. Sources for the mechanism: lkml.iu.edu 1902.1/08046
   and the USB 3 hub class spec. Check first whether usbfs allows the control
   transfer while the hub driver is bound. If not, use a debug patch (item 3).

3. Kernel debug: confirm whether the in-tree stuck-in-polling path fires.
   `echo 'file hub.c +p' > /sys/kernel/debug/dynamic_debug/control` then plug the
   KVM and look for "do warm reset". If it never fires, patch idea: in
   `hub_activate()` or a delayed work, call `hub_port_warm_reset()` on any SS port
   that reads Polling after 360 ms, also on a hub that has been running for a
   while. Retry two or three times, then give up and fall back to `disable`.

4. Remove the extra tier and lossy channel (hardware, no source). Plug the KVM
   into a controller port with no hub in front (a USB-C port if it has its own
   SS lanes, using a Type-C to Type-A adapter), or try a different short, certified
   SS cable between the QN10 and the KVM. If SS trains there, the cause is
   channel margin or hub downstream PHY behavior, and the fix is hardware, as
   in the TUSB8041 report.

5. Test an intermediate powered USB3 hub (hardware). A different vendor hub
   between the Genesys hub and the KVM re-times the link. If SS trains, keep the
   hub in the chain. Cheap to test, moderate chance.

6. Power-cycle the SS port with the KVM bus-powered path interrupted
   (uhubctl). The 01signal report shows this alone left the port in Polling, so
   rank low. Only helps combined with item 2. Needs per-port power switching,
   which the GL hub may not provide.

7. Reduce link power management (low chance): `usbcore.autosuspend=-1` on the
   kernel command line (Manjaro anecdote), and for the KVM hub once it enumerates
   on SS, USB_QUIRK_NO_LPM through `usbcore.quirks=05e3:0610:k`. This cannot
   help while the device never leaves Polling, but it matters after item 1 or 2
   succeeds, if the link then drops to Inactive.

8. dwc3 properties (very low chance, already shown irrelevant to this link):
   `snps,rx_detect_poll_quirk`, `snps,lfps_filter_quirk`, `snps,dis_u3_susphy_quirk`,
   `snps,dis-u1-entry-quirk`. These affect the root port to Genesys hub link only.

9. Genesys hub firmware update via fwupd (high risk, speculative). Only with a
   known recovery path.

Fallback that already works: `disable`=1 on the SS hub port, giving USB2 operation.

## blocked / needs-decision

- Which topology did the UEFI and Windows successes use: directly on a controller
  port, or behind a hub? This decides whether item 4 is informative.
- Is the in-tree kernel carrying `hub_port_stuck_in_polling()`? Needs a grep in
  the qcom-next tree on the host.
- Whether usbfs accepts SetPortFeature(BH_PORT_RESET) on a bound hub is untested.
- Searches covered mainly lore mirrors and forums through a search tool, with no
  deep reading of lore threads on Genesys quirks. A manual lore.kernel.org search
  for "GL3523" and "05e3:0625" is still worth doing.

## Sources

- https://lkml.iu.edu/hypermail/linux/kernel/1902.1/08046.html
- https://www.mail-archive.com/linux-usb@vger.kernel.org/msg111004.html
- https://www.mail-archive.com/linux-usb@vger.kernel.org/msg111002.html
- https://lists.gt.net/linux/kernel/1834724
- https://lkml.rescloud.iu.edu/1312.1/02859.html
- https://patchwork.kernel.org/project/linux-usb/patch/1549025551-4306-1-git-send-email-glogow@fbihome.de/
- https://www.spinics.net/lists/linux-usb/msg175986.html
- https://lore.kernel.org/all/66cb505d-8802-9d4c-fa3f-01c47f9734fc@linux.intel.com/T/
- https://lore.kernel.org/all/YaCEUoB7C7hUiREv@kroah.com/T/
- https://www.spinics.net/lists/linux-usb/msg220654.html
- https://marc.info/?l=linux-usb&m=164087666913374
- https://www.01signal.com/other/usb-device-stuck-reset/
- https://github.com/wpilibsuite/SystemcoreTesting/issues/366
- https://forum.manjaro.org/t/usb-3-0-hub-only-recognized-as-usb-2-0-high-speed-hub/68690
- https://www.kernel.org/doc/html/latest/driver-api/usb/dwc3.html
- https://www.kernel.org/doc/Documentation/devicetree/bindings/usb/dwc3.txt
- https://fwupd.github.io/libfwupdplugin/genesys-README.html
- https://www.station-drivers.com/index.php?option=com_remository&Itemid=353&func=fileinfo&id=4173&lang=en
- https://lore.kernel.org/lkml/20231123-skeletal-smirk-390543e2d6ab@spud/T/
- https://lkml.iu.edu/hypermail/linux/kernel/2412.0/00577.html
- https://ratatoskr.run/linux-arm-msm/2025/11/3279636/t
- https://lkml.iu.edu/hypermail/linux/kernel/1610.0/00561.html
- https://docs.kernel.org/driver-api/usb/power-management.html
