# The original blanc workaround removed the modprobe applet symlink because its
# presence was reported to crash this device. Modern build/make invokes this
# hook after ramdisk assembly and before cpio/compression. Keep the workaround
# for both historical and modern applet locations without replacing image rules.
# Removal is restricted to symlinks; no kernel modules or binaries are removed.
define BOARD_RECOVERY_IMAGE_PREPARE
    if [ -L "$(TARGET_RECOVERY_ROOT_OUT)/sbin/modprobe" ]; then \
        rm -f "$(TARGET_RECOVERY_ROOT_OUT)/sbin/modprobe"; \
    fi; \
    if [ -L "$(TARGET_RECOVERY_ROOT_OUT)/system/bin/modprobe" ]; then \
        rm -f "$(TARGET_RECOVERY_ROOT_OUT)/system/bin/modprobe"; \
    fi
endef
