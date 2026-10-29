# The original blanc workaround removed the modprobe applet symlink because its
# presence was reported to crash this device. Modern build/make invokes this
# hook after ramdisk assembly and before cpio/compression. Keep the workaround
# for both historical and modern applet locations without replacing image rules.
# Removal is restricted to symlinks; no kernel modules or binaries are removed.
# Regenerate sorted inventories after removal: upstream find order is unspecified.
define BOARD_RECOVERY_IMAGE_PREPARE
    if [ -L "$(TARGET_RECOVERY_ROOT_OUT)/sbin/modprobe" ]; then \
        rm -f "$(TARGET_RECOVERY_ROOT_OUT)/sbin/modprobe"; \
    fi; \
    if [ -L "$(TARGET_RECOVERY_ROOT_OUT)/system/bin/modprobe" ]; then \
        rm -f "$(TARGET_RECOVERY_ROOT_OUT)/system/bin/modprobe"; \
    fi; \
    if [ -f "$(TARGET_OUT_SHARED_LIBRARIES)/libminuitwrp.so" ]; then \
        cp -f "$(TARGET_OUT_SHARED_LIBRARIES)/libminuitwrp.so" "$(TARGET_RECOVERY_ROOT_OUT)/system/lib64/libminuitwrp.so"; \
    fi; \
    mkdir -p \
        "$(TARGET_RECOVERY_ROOT_OUT)/cache" \
        "$(TARGET_RECOVERY_ROOT_OUT)/cust" \
        "$(TARGET_RECOVERY_ROOT_OUT)/preas" \
        "$(TARGET_RECOVERY_ROOT_OUT)/preavs" \
        "$(TARGET_RECOVERY_ROOT_OUT)/system_root"; \
    ln -sf /tmp/fstab "$(TARGET_RECOVERY_ROOT_OUT)/system/etc/fstab"; \
    cd "$(TARGET_RECOVERY_ROOT_OUT)" && \
    find . -print | LC_ALL=C sort | sed 's|^\./||; /lib\/modules\//d' > ramdisk-files.txt && \
    find . -type f ! -path './ramdisk-files.sha256sum' ! -path '*/lib/modules/*' ! -name 'prop.default' -print0 | LC_ALL=C sort -z | xargs -0 -r sha256sum > ramdisk-files.sha256sum
endef
