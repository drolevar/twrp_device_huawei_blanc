#!/system/bin/sh
# One-shot read-only diagnostic collector for BLA-L29 TWRP recovery sessions.
# Never modifies block devices, /data, /metadata, /cache, /vendor, or /system.
# Invoke via `adb shell /sbin/blanc-diag-dump.sh [output_dir]` so pstore ramoops
# files (restricted from u:r:recovery:s0 by coredomain.te pstorefs neverallow)
# remain readable in the adb shell domain.
set -u

OUT_ROOT=""
if [ "$#" -ge 1 ] && [ -n "$1" ]; then
	OUT_ROOT="$1"
else
	for candidate in /usb_otg /usb_otg_hisi /usb_otg_hifi; do
		if [ -d "$candidate" ] && grep -qs " $candidate " /proc/mounts 2>/dev/null && [ -w "$candidate" ]; then
			OUT_ROOT="$candidate"
			break
		fi
	done
fi

if [ -z "$OUT_ROOT" ]; then
	OUT_ROOT="/tmp"
fi

if ! mkdir -p "$OUT_ROOT" 2>/dev/null; then
	printf '%s\n' "blanc-diag-dump: cannot create output dir: $OUT_ROOT" >&2
	exit 1
fi

TS="$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null || printf 'unknown')"
BUNDLE_NAME="blanc-diag-$TS"
STAGE="$OUT_ROOT/$BUNDLE_NAME"
ARCHIVE="$OUT_ROOT/$BUNDLE_NAME.tar.gz"
SHA_FILE="$ARCHIVE.sha256"

mkdir -p "$STAGE"

uname -a > "$STAGE/uname.txt" 2>&1 || true
if [ -r /proc/cmdline ]; then
	cp -f /proc/cmdline "$STAGE/cmdline.txt" 2>/dev/null || true
fi
if [ -r /proc/mounts ]; then
	cp -f /proc/mounts "$STAGE/mounts.txt" 2>/dev/null || true
fi
if [ -r /proc/partitions ]; then
	cp -f /proc/partitions "$STAGE/partitions.txt" 2>/dev/null || true
fi

if command -v getprop >/dev/null 2>&1; then
	getprop > "$STAGE/getprop.txt" 2>&1 || true
fi
if command -v dmesg >/dev/null 2>&1; then
	dmesg > "$STAGE/dmesg.txt" 2>&1 || true
fi
if [ -r /tmp/recovery.log ]; then
	cp -f /tmp/recovery.log "$STAGE/recovery.log" 2>/dev/null || true
fi

ls -la /dev/block /dev/block/by-name /dev/block/bootdevice/by-name /dev/block/mapper > "$STAGE/block-links.txt" 2>&1 || true

if command -v lptools >/dev/null 2>&1; then
	lptools free > "$STAGE/lptools-free.txt" 2>&1 || true
fi
if command -v dmctl >/dev/null 2>&1; then
	dmctl list devices > "$STAGE/dmctl-devices.txt" 2>&1 || true
fi

if [ -d /sys/fs/pstore ]; then
	mkdir -p "$STAGE/pstore"
	pstore_copied=0
	for pfile in /sys/fs/pstore/*; do
		[ -e "$pfile" ] || continue
		if [ -r "$pfile" ] && cp -f "$pfile" "$STAGE/pstore/" 2>/dev/null; then
			pstore_copied=1
		fi
	done
	if [ "$pstore_copied" -eq 0 ]; then
		printf '%s\n' "pstore empty or unreadable in current SELinux domain (expected in u:r:recovery:s0; run via adb shell u:r:su:s0 to collect ramoops)" > "$STAGE/pstore/README.txt"
	fi
fi

HASH_LOG="$STAGE/partition-sha256.txt"
: > "$HASH_LOG"
for part in kernel ramdisk recovery_ramdisk recovery_vendor vbmeta; do
	blk=""
	for base in /dev/block/bootdevice/by-name /dev/block/by-name; do
		if [ -e "$base/$part" ]; then
			blk="$base/$part"
			break
		fi
	done
	if [ -z "$blk" ]; then
		printf '%s  MISSING  0\n' "$part" >> "$HASH_LOG"
		continue
	fi
	if [ -r "$blk" ]; then
		size_bytes="unknown"
		if command -v blockdev >/dev/null 2>&1; then
			size_bytes="$(blockdev --getsize64 "$blk" 2>/dev/null || printf 'unknown')"
		fi
		if [ "$size_bytes" = "unknown" ]; then
			size_bytes="$(wc -c < "$blk" 2>/dev/null || printf 'unknown')"
		fi
		sum_val="$(sha256sum "$blk" 2>/dev/null | awk '{print $1}')"
		[ -n "$sum_val" ] || sum_val="UNREADABLE"
		printf '%s  %s  %s  (%s)\n' "$part" "$sum_val" "$size_bytes" "$blk" >> "$HASH_LOG"
	else
		printf '%s  UNREADABLE  0  (%s)\n' "$part" "$blk" >> "$HASH_LOG"
	fi
done

tar -czf "$ARCHIVE" -C "$OUT_ROOT" "$BUNDLE_NAME"
(cd "$OUT_ROOT" && sha256sum "$BUNDLE_NAME.tar.gz" > "$BUNDLE_NAME.tar.gz.sha256")
rm -rf "$STAGE"

printf '%s\n' "$ARCHIVE"
