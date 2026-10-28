#!/system/bin/sh
# Detect the kernel interface rather than guessing a .342 UDC name. This script
# runs only in a future recovery ramdisk; it is never a host preparation command.
if grep -qw configfs /proc/filesystems; then
	setprop sys.usb.configfs 1
	if [ -z "$(getprop sys.usb.controller)" ]; then
		count=0
		controller=
		for udc in /sys/class/udc/*; do
			[ -e "$udc" ] || continue
			count=$((count + 1))
			controller="${udc##*/}"
		done
		if [ "$count" -eq 1 ]; then
			setprop sys.usb.controller "$controller"
		fi
	fi
else
	setprop sys.usb.configfs 0
fi
