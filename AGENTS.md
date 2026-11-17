<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# AGENTS.md — QN10 quick start and USB image deployment

This file guides a person or an agent from a stock ASUS Ascent QN10 to a
booting Debian system with the patched kernel. Read it top to bottom the
first time.

## Device facts

- Platform: Qualcomm "Glymur", SoC SC8480XP (Snapdragon X2 Elite Extreme),
  soc_id 698, Hexagon DSP arch v81.
- Firmware: UEFI with ACPI and a device tree path. Linux boots through the
  Boot Loader Specification (systemd-boot) with a device tree.
- The machine runs Linux at EL2 (no hypervisor). This matters for firmware
  loading: see the PAS and zap notes in STATUS.md.

## Safety rules

1. **Never write to the Windows drive.** The stock Windows install is on one
   NVMe or eMMC. Install Linux to a different disk, or to a USB stick. Pick
   the target device by model and size with `lsblk` before writing.
2. **Do not use EDL, QDL, or `rawprogram*.xml`** against the device. They are
   not needed and can brick a locked unit.
3. Keep a copy of the firmware you extract. You cannot re-download it.

## Prerequisites

- A build host with an aarch64 cross toolchain or a native aarch64 Linux box
  (Debian trixie or newer). The kernel is built as Debian packages.
- A QN10 with a USB keyboard and a display on HDMI.
- A USB stick of 16 GB or more for the install image.
- The device's own Windows firmware (see "Extract firmware").

## 1. Get the kernel and apply the patches

Use the companion fork, which already has the patches on the `qn10` branch:

```sh
git clone --branch qn10 https://github.com/rcarback/QN10-kernel.git
```

Or apply the series in `patches/` to a fresh qcom-next 7.4-rc1 tree:

```sh
git clone --depth 1 --branch qcom-next-7.4-rc1-20261116 \
    https://github.com/qualcomm-linux/kernel.git
cd kernel
for p in /path/to/QN10/patches/0*.patch; do git apply "$p"; done
```

The device tree in `dts/glymur-asus-ascent-qn10.dts` is standalone; it
includes the in-tree `glymur.dtsi`. Place it under
`arch/arm64/boot/dts/qcom/` or compile it against the tree's includes.

## 2. Build the kernel and the device tree

`tools/kernel/` holds the build scripts used during bring-up:

- `build-kernel.sh` — builds Debian packages from a configured tree.
- `qn10-native-setup.sh` / `qn10-native-build.sh` — build on the QN10 itself.
- `qn10-install-kernel.sh` — install the package and the device tree, and add
  the boot entry (run on the QN10).

Minimum manual build:

```sh
make defconfig        # start from the running kernel's config in practice
make -j"$(nproc)" bindeb-pkg
# compile the device tree against the tree includes:
cpp -nostdinc -Iinclude -Iarch/arm64/boot/dts/qcom -undef -D__DTS__ \
    -x assembler-with-cpp dts/glymur-asus-ascent-qn10.dts | \
    dtc -O dtb -o glymur-asus-ascent-qn10.dtb -
```

## 3. Extract firmware from Windows

The QN10 needs signed Qualcomm/ASUS firmware that is not redistributable.
Copy it from the device's own Windows partition (`Windows/System32/
DriverStore/FileRepository/`). The names Linux expects, and the directory
layout, are documented in:

- `tools/kernel/` comments (ADSP, CDSP, iris video, GPU, Wi-Fi board data).
- `tools/npu/stage-dsp-libs.sh` (Hexagon DSP user libraries for the NPU).

Install the files under `/lib/firmware/qcom/glymur/ASUSTeK/QN10/` on the
target, matching the names the drivers request (watch `dmesg` for
"Direct firmware load for ... failed" lines).

## 4. Build and deploy a USB install image

The install image is a normal Debian aarch64 root filesystem plus the
patched kernel, the device tree, and the extracted firmware. Build it on the
host, then write it to the USB stick.

1. **Make a Debian aarch64 root filesystem** with `mmdebstrap` or
   `debootstrap`:

   ```sh
   sudo mmdebstrap --architecture=arm64 trixie ./rootfs \
       http://deb.debian.org/debian
   ```

2. **Add the kernel, the device tree, and the firmware** into the rootfs:

   ```sh
   sudo dpkg --root=./rootfs -i linux-image-*-qn10+_*.deb
   sudo install -D -m0644 glymur-asus-ascent-qn10.dtb \
       ./rootfs/boot/dtb/qcom/glymur-asus-ascent-qn10.dtb
   sudo cp -r firmware/qcom ./rootfs/lib/firmware/
   ```

3. **Set up the ESP and the boot entry.** Create a FAT32 EFI system
   partition, install `systemd-boot`, and add a type-1 entry that points at
   the kernel and `devicetree /dtb/qcom/glymur-asus-ascent-qn10.dtb`. Use
   `efi=noruntime` on the kernel command line. `tools/kernel/
   qn10-install-kernel.sh` shows the entry format.

4. **Write the image to the USB stick.** Pick the stick by model and size:

   ```sh
   lsblk -dno NAME,MODEL,SIZE          # identify the USB device, e.g. sdX
   sudo dd if=qn10-usb.img of=/dev/sdX bs=4M status=progress conv=fsync
   ```

   Double-check the target. Writing to the wrong device destroys data.

## 5. Boot and verify

1. Insert the USB stick, power on, and open the UEFI boot menu (usually
   `Esc` or `F2` at power-on). Choose the USB entry.
2. At first boot, check `dmesg` for firmware-load failures and fix any
   missing files. The kernel command line needs `efi=noruntime`.
3. Quick checks:

   ```sh
   vulkaninfo --summary | grep -m1 deviceName   # expect Adreno (TM) X2-85
   ls /dev/video0 /dev/video1                   # iris decoder/encoder
   nmcli general status                         # Wi-Fi
   cat /sys/class/thermal/thermal_zone0/temp    # thermal
   ```

## 6. Optional: enable the NPU AI accelerator (HTP)

The Hexagon V81 HTP runs neural-network inference through the Qualcomm AI
Runtime (QAIRT), with one workaround: QAIRT 2.44 does not know soc_id 698, so
`libQnnHtp.so` aborts with "No Snapdragon SOC detected". The recipe is in
`tools/npu/`:

1. Build `socid-shim.c` and preload it to remap the SoC id to a recognized
   v81 part (660 = SM8850).
2. Use the `aarch64-oe-linux-gcc11.2` QAIRT target (the only Linux target
   with the v81 host stub).
3. Create the `libcdsprpc.so` symlink and point `ADSP_LIBRARY_PATH` at the
   v81 skel plus the device DSP libraries.

`tools/npu/htp-enable-test.sh` runs the full build-and-infer test. See the
NPU section of STATUS.md for the details and the evidence.

## Where to look when something fails

- Boot stops or the screen is blank: check the device tree path in the boot
  entry and `efi=noruntime`.
- A device is missing: watch `dmesg` for firmware-load failures; the firmware
  file is probably missing or misnamed.
- Wi-Fi does not return after suspend: `tools/power/qn10-wifi-sleep.sh`
  reloads the module around suspend.
- The machine powers off when you wake it: apply
  `tools/power/logind.conf.d/10-qn10-powerkey.conf` so the power button only
  wakes.
