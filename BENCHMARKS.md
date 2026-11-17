<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# QN10 benchmarks and comparison

Measured on the ASUS Ascent QN10 running Debian with the kernel in this
repository (qcom-next 7.4-rc1). This is a preview/engineering unit; retail
Snapdragon X2 parts may clock higher.

All "measured" numbers below were produced on this Linux system. Numbers
labelled "published" come from the cited third-party reviews and vendor
specifications, and are included for context. Raw CPU scores on Linux and the
Geekbench/Cinebench scores reviewers publish on Windows are different tests;
do not read across the two as if they were the same metric.

## Test system (as measured)

| Item | Value |
|------|-------|
| SoC | Qualcomm Snapdragon X2 (Glymur, SC8480XP, soc_id 698) |
| CPU | 18 Oryon cores: 6 up to 3.42 GHz, 12 up to 4.72 GHz |
| GPU | Adreno X2-85 at 1.70 GHz (turnip Vulkan 1.4, freedreno GL ES 3.2) |
| NPU | Hexagon, 80 TOPS INT8 (Qualcomm spec) |
| RAM | 30 GiB LPDDR5x; ~81 GB/s single-thread read measured |
| OS | Debian, kernel 7.4.0-rc1 (qcom-next) |

## CPU, measured on Linux

| Benchmark | Result |
|-----------|--------|
| 7-zip `7z b` combined rating (18 threads) | ~133,500 MIPS |
| sysbench cpu, 1 thread | 5,692 events/s |
| sysbench cpu, 18 threads | 81,621 events/s (14.3x scaling) |
| OpenSSL AES-256-GCM (ARMv8 crypto) | 7.68 GB/s |
| OpenSSL SHA-256 | 3.50 GB/s |
| sysbench memory read, 1 thread | ~81 GB/s |

The 7-zip combined rating of about 133,500 MIPS is in the range of high-end
16-core desktop processors. Single-thread throughput is high, as expected
from Oryon cores near 4.7 GHz. Multi-thread scaling across 18 cores is good.

## CPU, published standardized scores (context)

These are reviewer numbers for the top retail part (X2E-96-100, 18 cores up
to 5.0 GHz) on Windows, not measurements from this unit. They show where the
silicon family sits against current laptop competitors.

| CPU | Geekbench 6 single | Geekbench 6 multi |
|-----|--------------------|-------------------|
| Snapdragon X2 Elite Extreme (X2E-96-100) | ~4,080 | ~23,400 |
| Apple M4 Max (16-core) | ~3,900 | ~25,000+ |
| AMD Ryzen AI 9 HX 375 | ~2,842 | ~15,030 |
| Intel Core Ultra 7 258V | ~2,724 | ~11,003 |

Sources: [XDA](https://www.xda-developers.com/snapdragon-x2-elite-extreme-benchmarks/),
[cpu-monkey](https://www.cpu-monkey.com/en/cpu-qualcomm_snapdragon_x2_elite_extreme_x2e_96_100),
[Windows Central](https://www.windowscentral.com/hardware/qualcomm/snapdragon-x2-elite-extreme-vs-apple-m4-pro-max).
The X2 family leads current Intel and AMD laptop parts in both single and
multi-core, wins single-core against the M4 Max, and trails the M4 Max in
multi-core.

## GPU, measured on Linux

| Benchmark | Result |
|-----------|--------|
| glmark2 (es2-drm, 3840x2160, full suite) | Score 484 |
| glmark2 jellyfish | 1,010 FPS |
| glmark2 terrain | 177 FPS |
| glmark2 refract | 269 FPS |
| Clock under sustained load | 1,700 MHz held, no throttle |
| GPU temperature under load | 45 C idle to ~57 C steady |

The GPU runs on the open `turnip` Vulkan driver and `freedreno` OpenGL
driver. Under a sustained heavy run it holds its full clock with no thermal
throttling.

## GPU versus other GPUs

The Adreno X2-85 is an integrated mobile GPU inside a roughly 15 to 50 W
system-on-chip. The fair peers are other top integrated GPUs and entry
discrete cards, not a 350 to 575 W flagship.

| GPU | FP32 TFLOPS | Class | Power basis |
|-----|------------:|-------|-------------|
| Adreno X2-85 (QN10) | ~6.0 (est., nanoreview) | integrated | part of ~15-50 W SoC |
| AMD Radeon 890M | 5.94 | integrated | 15 W cTDP |
| Intel Arc 140V | 4.1 | integrated | 15 W cTDP |
| RTX 3050 | 6.77 | entry discrete | 70 W |
| RTX 3090 | 35.6 | flagship | 350 W |
| RTX 5090 | 104.8 | flagship | 575 W |

The Adreno X2-85 is on par with the Radeon 890M and an entry RTX 3050, ahead
of the Arc 140V. Qualcomm does not publish an FP32 figure; the ~6 TFLOPS is a
community estimate. On compute per watt (FP32 divided by the power basis
above) the integrated GPUs lead at about 0.27 to 0.40 TFLOPS/W, the 5090 is
the most efficient discrete card at about 0.18, and the 3090 and 3050 are near
0.10. The flagships still win raw throughput by a wide margin; the Adreno's
argument is efficiency and integration. Sources: nanoreview, cpu-monkey,
TechPowerUp, club386.

## NPU versus desktop tensor throughput

The on-device AI accelerator is the fairer point of comparison for machine
learning, because it is the part built for inference. This repository shows
it running real inference under Linux (see the NPU section of STATUS.md).

| Accelerator | INT8 (dense) | Power class |
|-------------|--------------|-------------|
| Hexagon NPU (QN10) | 80 TOPS | part of a ~15-50 W SoC |
| RTX 3090 tensor | ~284 TOPS | 350 W |
| RTX 5090 tensor | ~838 TOPS | 575 W |

NPU figure: Qualcomm spec, 80 TOPS INT8
([Tom's Hardware](https://www.tomshardware.com/pc-components/cpus/qualcomms-new-snapdragon-x2-elite-extreme-and-elite-chips-for-pcs-stretch-up-to-a-record-5-ghz-3nm-arm-chips-sport-new-oryon-prime-cores)).
In INT8 the NPU is roughly 28 percent of a 3090 and 10 percent of a 5090, at
a small fraction of the power and always on the die. Qualcomm calls it the
fastest NPU in a laptop. For on-device, low-power inference it is strong; for
training or large-batch server inference the discrete cards are the tool.

## Virtualization

Because Linux runs at EL2 on this platform, the kernel ships with KVM and it
works.

| Capability | State |
|------------|-------|
| KVM hardware acceleration | Works (`/dev/kvm`, `kvm-ok` passes) |
| Nested virtualization trap handlers | Loaded by KVM at boot |
| Docker / isolated containers | Works (Docker 26.1.5, cgroup v2) |
| Firecracker microVMs | Supported (aarch64 + working KVM) |
| Full VMs (QEMU/KVM, libvirt) | Supported |

Interrupt virtualization is software-assisted on this unit (GICv4 disabled,
no GICV resource), so very I/O-heavy guests carry a little more overhead than
on a GICv4 host. Container, microVM, and general VM workloads run fine.

## How to reproduce

```sh
sudo apt-get install -y p7zip-full sysbench stress-ng glmark2-es2 cpu-checker
7z b                                             # CPU compression rating
sysbench cpu --cpu-max-prime=20000 --threads=1 --time=15 run
sysbench cpu --cpu-max-prime=20000 --threads="$(nproc)" --time=15 run
openssl speed -evp aes-256-gcm                   # crypto
glmark2-es2-drm                                  # GPU (renders on HDMI)
kvm-ok                                           # virtualization check
```

## Summary

- **CPU:** competitive with the best current laptop processors and high-end
  desktop chips; a genuine strength of this machine.
- **GPU:** a capable integrated mobile GPU, not a discrete-card competitor.
  It is orders of magnitude below an RTX 3090 or 5090 in raw throughput, at
  orders of magnitude less power.
- **NPU:** 80 TOPS INT8, meaningful for on-device AI, a fraction of a
  discrete GPU's tensor throughput at far lower power.
- **Virtualization:** full KVM, container, microVM, and VM support.
