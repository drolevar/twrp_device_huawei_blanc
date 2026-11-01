# Recovery product configuration for the measured BLA-L29/.342 layout.
# These flags control build outputs, not the filesystems installed on the phone.
PRODUCT_SHIPPING_API_LEVEL := 26
PRODUCT_BUILD_RECOVERY_IMAGE := true
PRODUCT_BUILD_BOOT_IMAGE := false
PRODUCT_BUILD_INIT_BOOT_IMAGE := false
PRODUCT_BUILD_VENDOR_BOOT_IMAGE := false
PRODUCT_BUILD_VENDOR_KERNEL_BOOT_IMAGE := false
PRODUCT_BUILD_DEBUG_BOOT_IMAGE := false
PRODUCT_BUILD_DEBUG_VENDOR_BOOT_IMAGE := false
PRODUCT_BUILD_SYSTEM_IMAGE := false
PRODUCT_BUILD_SYSTEM_OTHER_IMAGE := false
PRODUCT_BUILD_SYSTEM_EXT_IMAGE := false
PRODUCT_BUILD_VENDOR_IMAGE := false
PRODUCT_BUILD_PRODUCT_IMAGE := false
PRODUCT_BUILD_ODM_IMAGE := false
PRODUCT_BUILD_VENDOR_DLKM_IMAGE := false
PRODUCT_BUILD_ODM_DLKM_IMAGE := false
PRODUCT_BUILD_SYSTEM_DLKM_IMAGE := false
PRODUCT_BUILD_USERDATA_IMAGE := false
PRODUCT_BUILD_CACHE_IMAGE := false
PRODUCT_BUILD_VBMETA_IMAGE := false
PRODUCT_BUILD_SUPER_EMPTY_IMAGE := false
PRODUCT_BUILD_GENERIC_OTA_PACKAGE := false
PRODUCT_USE_DYNAMIC_PARTITIONS := false

# USB identity. The curated AOSP recovery init.rc (recovery-modern/.../init.rc)
# binds the gadget and writes idProduct from ro.recovery.usb.adb.pid *before*
# init.recovery.usb.rc and the vendor init.hisi.usb.rc actions for the same
# trigger run, so these defaults decide the identity the host enumerates.
# Use the Huawei ADB identity enumerated by the working TWRP 3.3.1 (12d1:103a).
# The AOSP default PID D001 produced a mixed 12d1:d001 identity on the hardened
# image; the Windows ADB failure with it is attributed to this mismatch
# (hypothesis, untested on Windows). Linux does not depend on the identity.
PRODUCT_VENDOR_PROPERTIES += \
    ro.recovery.usb.vid=12D1 \
    ro.recovery.usb.adb.pid=103A
