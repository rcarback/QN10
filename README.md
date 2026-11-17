<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# QN10: Linux on the ASUS Ascent QN10 (Snapdragon X2 Elite Extreme)

Experimental Debian/Linux hardware enablement for the ASUS Ascent QN10, a
Qualcomm Snapdragon X2 Elite Extreme mini-PC (platform "Glymur", SoC
SC8480XP, soc_id 698).

This repository holds the device tree, kernel patches, audio topology,
scripts, and the build and deployment howto. The matching kernel and audio
topology trees are published as forks:

- **[QN10-kernel](https://github.com/rcarback/QN10-kernel)** — fork of
  `qualcomm-linux/kernel` (qcom-next 7.4-rc1) with the ten QN10 patches and
  the board device tree on the `qn10` branch.
- **[QN10-audioreach-topology](https://github.com/rcarback/QN10-audioreach-topology)**
  — fork of `linux-msm/audioreach-topology` with the QN10 sound topology.

Start with **[AGENTS.md](AGENTS.md)** for a quick start and the USB image
deployment steps. See **[STATUS.md](STATUS.md)** for the full
hardware-by-hardware state and the reasons behind each conclusion.

See **[BENCHMARKS.md](BENCHMARKS.md)** for CPU, GPU, NPU, and
virtualization benchmarks, and how the QN10 compares to other processors and
to discrete GPUs.

## What works

Verified on the running system, kernel qcom-next 7.4-rc1 with the patches in
`patches/` and the device tree in `dts/`:

| Subsystem | State |
|-----------|-------|
| Boot from NVMe (Gen5 slot) | Works |
| Display / HDMI (3840x2160) | Works |
| GPU (Adreno X2-85, turnip/freedreno) | Works; full 1700 MHz under load, no throttle |
| Video decode and encode (iris, H.264) | Works; decode is bit-exact with software |
| NPU — CDSP compute (FastRPC) | Works |
| NPU — HTP AI accelerator (Hexagon V81) | Runs inference; see the socid-shim recipe |
| Audio: headset, speakers, mic | Works |
| Audio: HDMI/DisplayPort out | Works (topology + dai-link) |
| PCIe (NVMe at 16 GT/s) | Works |
| RTC (time of day) | Works |
| Ethernet (r8169) | Works |
| Wi-Fi (ath12k) | Works |
| Thermal sensing and throttling | Works (104 sensors) |
| USB (KVM, storage) | Works at USB 2 on the internal hub |
| Suspend / resume (s2idle) | Works; see the power-key note |

## How the QN10 compares

Full methodology and the measured Linux numbers are in
[BENCHMARKS.md](BENCHMARKS.md). The charts below use published reviewer and
vendor figures for the comparison parts, cited there.

### CPU

![CPU: Geekbench 6 single and multi-core](images/cpu-geekbench.png)

| CPU | Geekbench 6 single | Geekbench 6 multi |
|-----|-------------------:|------------------:|
| Snapdragon X2 Elite Extreme (QN10 family) | ~4,080 | ~23,400 |
| Apple M4 Max (16-core) | ~3,900 | ~25,000 |
| AMD Ryzen AI 9 HX 375 | ~2,842 | ~15,030 |
| Intel Core Ultra 7 258V | ~2,724 | ~11,003 |

The X2 silicon wins single-core broadly, trails the M4 Max in multi-core, and
leads the current Intel and AMD laptop parts in both. On Linux the QN10 also
posts a 7-zip rating near 133,500 MIPS, in high-end desktop 16-core range.

### NPU and AI accelerator

![NPU: INT8 TOPS versus RTX tensor](images/npu-tops.png)

| Accelerator | INT8 TOPS (dense) | Power class |
|-------------|------------------:|-------------|
| QN10 Hexagon NPU | 80 | part of a ~15-50 W SoC |
| RTX 3090 tensor | ~284 | 350 W |
| RTX 5090 tensor | ~838 | 575 W |

In INT8 the NPU is about 28 percent of a 3090 and 10 percent of a 5090, at a
fraction of the power, on-die, and usable from Linux through this work.

### GPU raw compute

![GPU: FP32 TFLOPS](images/gpu-fp32.png)

| GPU | FP32 TFLOPS |
|-----|------------:|
| Adreno X2-85 (QN10) | not published (N/A) |
| RTX 3090 | 35.6 |
| RTX 5090 | 104.8 |

Qualcomm does not publish an FP32 figure for the Adreno X2 and sells it on
performance per watt. It is an integrated mobile GPU, not a discrete-class
part. It renders 4K cleanly and holds full clock with no throttling, but it
is not in the same league as a discrete card for raw throughput.

### GPU power class

![GPU board power](images/gpu-power.png)

| Part | Power |
|------|------:|
| QN10 whole SoC | ~15-50 W |
| RTX 3090 | 350 W |
| RTX 5090 | 575 W |

The discrete GPU alone draws 7 to 11 times the entire QN10's power. The honest
reading: the QN10 is a low-power ARM machine with a strong CPU and a capable
integrated GPU and NPU, not a discrete-GPU workstation.

## What does not work, and why

Each item below is a firmware or platform limitation, not a missing driver.
The reasoning and the evidence are in [STATUS.md](STATUS.md).

- **TPM** — the firmware TPM runs inside the Qualcomm TEE (QTEE). The kernel
  has the `tpm_qcom` QTEE client driver, but QTEE on this unit reports the
  TPM service as "not available" to the non-secure world, so the driver has
  nothing to bind to. No change to a public driver reaches it.
- **Fan control** — the unit has no embedded controller exposed to the OS.
  The fan runs under firmware control based on temperature, the same way
  thermal throttling works.
- **Timer wake from suspend** — the charger firmware refuses the RTC alarm,
  so a timer cannot wake the machine. The power button wakes it.
- **GPU zap shader** — not needed. When Linux runs at EL2 the driver leaves
  secure mode directly, so no zap firmware is involved. The only loss is
  hardware DRM content protection (for example protected 4K streaming).

## Firmware is not included

The QN10 needs several signed Qualcomm/ASUS firmware files (ADSP, CDSP, iris
video, GPU, Wi-Fi board data). These are proprietary and are **not** in this
repository. Extract them from your own device's Windows partition. The
scripts `tools/kernel/` and `tools/npu/stage-dsp-libs.sh` document the file
names and the layout Linux expects. See [AGENTS.md](AGENTS.md).

## Repository layout

```
dts/         board device tree (glymur-asus-ascent-qn10.dts)
patches/     kernel patch series 0001-0010 (apply to qcom-next 7.4-rc1)
topology/    AudioReach sound topology source and build script
tools/
  kernel/    kernel build and install scripts
  audio/     mic/HDMI route service
  power/     suspend hooks, power-key fix, test scripts
  usb/       USB 3 fallback service and research notes
  media/     iris decode test
  gpu/       zap-shader trace tool
  npu/       HTP enablement recipe (socid-shim, build and run scripts)
```

## License

- Kernel patches (`patches/`) and the device tree (`dts/`): GPL-2.0, as in
  the Linux kernel. Each patch and the device tree carry their own
  SPDX headers.
- Topology source (`topology/`): BSD-3-Clause, matching AudioReach.
- Scripts in `tools/`: GPL-2.0-or-later unless a file states otherwise.
- Documentation (this file, `STATUS.md`, `AGENTS.md`): CC-BY-4.0.

This is unofficial community work. It is not endorsed by ASUS or Qualcomm,
and it comes with no warranty.
