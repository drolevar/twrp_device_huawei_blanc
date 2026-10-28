#!/system/bin/sh
# Retain the original TeamWin blanc UFS/eMMC discovery, without replacing an
# existing by-name directory or any measured unsuffixed partition link.
if [ ! -d /dev/block/bootdevice/by-name ]; then
	for controller in /dev/block/platform/ff3c0000.ufs /dev/block/platform/hi_mci.0; do
		if [ -d "$controller/by-name" ]; then
			ln -s "$controller" /dev/block/bootdevice
			break
		fi
	done
fi

# These are aliases only. This does not imply physical A/B slots on blanc.
for node in /dev/block/bootdevice/by-name/*_a; do
	[ -e "$node" ] || continue
	alias="${node%_a}"
	[ -e "$alias" ] || ln -s "$node" "$alias"
done
