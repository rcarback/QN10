"""Send USB 3 SetPortFeature(BH_PORT_RESET) to one port of a SuperSpeed hub.

Usage (root): python3 -I ss_warm_reset.py /dev/bus/usb/BBB/DDD PORT
A warm reset makes the hub port restart SuperSpeed link training.
"""
import fcntl
import os
import struct
import sys

# _IOWR('U', 0, struct usbdevfs_ctrltransfer): 24 bytes on 64-bit kernels
USBDEVFS_CONTROL = 0xC0185500
SET_FEATURE = 3
BH_PORT_RESET = 28
REQTYPE = 0x23  # host-to-device, class request, recipient "other" (a port)


def main():
    dev, port = sys.argv[1], int(sys.argv[2])
    fd = os.open(dev, os.O_RDWR)
    try:
        ctrl = struct.pack("=BBHHHI4xQ", REQTYPE, SET_FEATURE, BH_PORT_RESET,
                           port, 0, 1000, 0)
        fcntl.ioctl(fd, USBDEVFS_CONTROL, bytearray(ctrl))
        print(f"BH_PORT_RESET sent to port {port}")
    finally:
        os.close(fd)


if __name__ == "__main__":
    main()
