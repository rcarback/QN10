<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# QN10 hardware status and findings

Kernel: qcom-next 7.4-rc1 with the ten patches in `patches/`. The QN10 runs
Linux at EL2 with no hypervisor underneath. That single fact drives several
of the results below.

## Working

### Boot, storage, PCIe
- Boots from an NVMe drive in the Gen5 slot. The NVMe link reaches 16 GT/s
  under load. Patch 0002 limits the link-rate switcher to the lower of the
  port and device rates, which removes the need for a speed cap in the
  device tree.
- `efi=noruntime` is required on the kernel command line.

### Display and GPU
- HDMI output works at 3840x2160.
- The GPU (Adreno X2-85) runs on the `turnip` Vulkan driver and `freedreno`
  OpenGL driver. Under a sustained glmark2 stress run at 4K it holds its full
  1700 MHz clock with no thermal throttling, at about 57 C.
- The GPU leaves secure mode by writing the SECVID register directly, because
  at EL2 that register is accessible. No zap shader is used. Patch 0009 makes
  the driver skip the zap at EL2 and drops a misleading warning.

### Video (iris)
- Decode and encode both work. A 1080p H.264 clip decodes bit-exact against
  a software decoder, and the hardware encoder output decodes cleanly.
- At EL2 the iris firmware needs its own IOMMU context: a `video-firmware`
  node with stream id 0x19e2, plus the signed `qcvss8480.mbn` firmware. PAS
  firmware init also needs the metadata to come from TZMem rather than plain
  DMA memory (patch 0008).

### NPU
- **CDSP compute (FastRPC)** works. The Qualcomm `fastrpc_test` calculator and
  multithreading cases run on the Hexagon DSP, using the device's own DSP
  user libraries (extracted from Windows) placed under the Glymur/QN10
  firmware path.
- **HTP AI accelerator (Hexagon v81)** runs real inference through the
  Qualcomm AI Runtime (QAIRT 2.44). `qnn-net-run` finalizes and executes an
  InceptionV3 conv+relu graph with status 0, and writes real output tensors.
  The recipe needed four steps, all in `tools/npu/`:
  1. QAIRT 2.44 does not know soc_id 698, so `libQnnHtp.so` aborts with
     "No Snapdragon SOC detected". `socid-shim.c` is an `LD_PRELOAD` that
     redirects reads of `/sys/devices/soc0/soc_id` to a recognized v81 part
     (660 = SM8850). No vendor binary is modified. QAIRT ignores the config
     soc_id on a real device, so the shim is required.
  2. Only the `aarch64-oe-linux-gcc11.2` QAIRT target ships the v81 host
     transport stub `libQnnHtpV81Stub.so`. The `aarch64-ubuntu-gcc9.4` target
     has only v68.
  3. The Debian `libfastrpc1` package provides every symbol QAIRT needs but
     omits the unversioned `libcdsprpc.so` dev symlink; create it.
  4. The HTP config `graph_names` must be the model's internal graph name,
     not the model library name.

### Audio
- Headset, speakers, and the headset microphone work. The microphone route is
  set at boot by a small service (`tools/audio/`), because `alsactl restore`
  stops at a busy control.
- HDMI/DisplayPort audio works. The rear HDMI is `mdss_dp3`, which maps to
  `DISPLAY_PORT_RX_3`. The stock devkit topology only defined DP 0 and 1, so
  the repository ships a QN10 topology (`topology/`) built from the upstream
  AudioReach source with the third DP graph moved to RX 3.

### Other
- RTC time of day works (patch 0003).
- Ethernet works with the in-tree `r8169` and the `rtl8125bp` firmware.
- Wi-Fi works with `ath12k`.
- Thermal sensing and throttling work: 104 sensors, plus CPU and GPU cooling
  devices.
- SoundWire SDCA interrupts for the class-0 codec need patch 0004; patch 0006
  copies the DPn banks when the master does not switch; patch 0007 stops the
  WCD9378 TX host clock being halved.
- USB works at USB 2 on the internal Genesys hub (KVM keyboard and mouse,
  storage). USB 3 link training on an external KVM is unreliable; a fallback
  service downgrades a stuck port to USB 2 (`tools/usb/`).

### Suspend and resume
- s2idle suspends and resumes. The power button wakes the machine. By default
  systemd-logind treats that same button press as a power-key event and
  powers the machine off right after resume; the drop-in in
  `tools/power/logind.conf.d/` makes a short press wake only. Keyboard and
  mouse are not wake sources on the internal hub.
- Wi-Fi firmware does not survive s2idle. The sleep hook in `tools/power/`
  removes the `ath12k` module before suspend and reloads it after, which
  forces a fresh firmware download on resume. The module reload was verified
  on the running system.

## Not working: firmware or platform limits

These are not missing drivers. Each was investigated to a definite cause.

### TPM
The firmware TPM runs inside the Qualcomm TEE. The kernel has the QTEE client
driver `tpm_qcom`, and the `qcomtee` driver is loaded. The driver never binds
and `/dev/tpm0` never appears. Instrumenting `qtee_register_services` showed
that the client environment object is valid, but `qcomtee_object_get_service`
returns "not available" for both `qcom.tz.tpm` and `qcom.tz.uefisecapp`. So
QTEE on this unit does not expose those service objects to the non-secure
world through the object-invoke interface. UEFI variables still work because
`uefisecapp` has a legacy SCM path; the TPM has none. The firmware TPM is
active (the UEFI event logs are present) and Windows reaches it, but through
an interface QTEE does not offer to Linux here. This is a firmware-surface
decision, not a fixable driver gap.

### Fan control
The unit exposes no embedded controller to Linux: no ACPI EC, no cros_ec, no
i2c EC bus, and it boots with a device tree rather than ACPI. Power and
thermal go through the always-on Qualcomm subsystem. The fan runs under
firmware control based on temperature, like thermal mitigation. There is no
OS-facing fan interface to drive.

### Timer wake from suspend
No clock can wake the machine from suspend. The pmic-glink RTC asks the
charger firmware to arm the alarm, and this unit's firmware refuses the
request (status 0x202). The PMK8850 RTC alarm interrupt is owned by firmware
and returns -EPERM to Linux, which is why every Qualcomm laptop marks it
`qcom,no-alarm`. Patch 0010 makes the glink RTC report the refusal instead of
pretending the alarm is set. A working timer wake needs updated charger
firmware.

### GPU zap shader
Not needed and not used. At EL2 the driver leaves secure mode directly. The
only capability lost is the GPU secure path used for hardware DRM content
protection (for example protected 4K streaming). Normal graphics, compute,
games, and non-protected video are unaffected. Attempting to load the signed
zap image did authenticate under a TZMem path, but the SoC then reset when the
command processor ran `CP_SET_SECURE_MODE`; the generic image is not signed
for this unit. There is no benefit to pursuing it at EL2.

### Can TrustZone be removed to fix the TPM?
No. The secure world is loaded and verified by the boot ROM before UEFI,
against keys fused into the SoC, and the fuses are blown on production units.
It also provides the EL3 secure monitor and PSCI (CPU power-on, idle, SMP),
which Linux depends on, and the PAS service that authenticates the iris, GPU,
and NPU firmware. Removing it would break the hardware that currently works
and would still not provide a TPM. There is no open-source EL3 replacement for
this SoC, and a locked unit will not boot an unsigned one.
