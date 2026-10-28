# Huawei blanc recovery-only configuration, derived from TeamWin android-8.1.
# The installed kernel and eRecovery are separate from recovery_ramdisk.
DEVICE_PATH := device/huawei/blanc

# Bootloader
TARGET_BOOTLOADER_BOARD_NAME := KIRIN
TARGET_NO_BOOTLOADER := true

# Platform
TARGET_BOARD_PLATFORM := generic
TARGET_BOARD_PLATFORM_GPU := kirin

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv7-a-neon
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := generic

BOARD_KERNEL_CMDLINE :=

# Preserve the original blanc header layout pending an exact known-good image.
BOARD_BOOT_HEADER_VERSION := 0
BOARD_KERNEL_BASE := 0x10000000
BOARD_KERNEL_PAGESIZE := 2048
BOARD_MKBOOTIMG_ARGS := --header_version $(BOARD_BOOT_HEADER_VERSION) \
    --kernel_offset 0x00008000 --ramdisk_offset 0x01000000 --tags_offset 0x00000100
BOARD_RECOVERY_MKBOOTIMG_ARGS := $(BOARD_MKBOOTIMG_ARGS)
BOARD_RAMDISK_USE_LZ4 := false
BOARD_RAMDISK_USE_XZ := false
BOARD_RAMDISK_USE_LZMA := false

# phony empty kernel to satisfy build system, but this device does not
# include a kernel in the recovery image -- flash to recovery_ramdisk
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/dummykernel
# No kernel source/config is selected. The empty upstream file is a build input,
# not a replacement for the handset's separate kernel partition.

# Measured .342 capacities, in bytes. No conventional boot partition was found.
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 33554432
BOARD_SYSTEMIMAGE_PARTITION_SIZE := 2608857088
BOARD_USERDATAIMAGE_PARTITION_SIZE := 119663493120
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs
BOARD_USES_FULL_RECOVERY_IMAGE := true

# These select recovery filesystem utilities, not the stock system's format.
# The EROFS stock mounts and system-as-root paths are described by recovery.fstab.
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery.fstab

# Only the reviewed modern overlay is copied into the ramdisk. The historical
# recovery/root directory contains unreviewed sepolicy/TEE binaries.
TARGET_RECOVERY_DEVICE_DIRS := $(DEVICE_PATH)/recovery-modern
TARGET_RECOVERY_INITRC := $(DEVICE_PATH)/recovery-modern/init.rc

TW_THEME := portrait_hdpi
RECOVERY_SDCARD_ON_DATA := true
TW_EXCLUDE_DEFAULT_USB_INIT := true
TW_BRIGHTNESS_PATH := /sys/class/leds/lcd_backlight0/brightness
TW_MAX_BRIGHTNESS := 1023
TW_DEFAULT_BRIGHTNESS := 512
TW_NO_SCREEN_BLANK := true
TW_CUSTOM_BATTERY_PATH := /sys/class/power_supply/Battery

# Initial scope retains the original MTP exclusion and has no Huawei FBE claim.
# Leave TW_INCLUDE_CRYPTO unset: 'false' is nonempty in several upstream tests.
TW_EXCLUDE_MTP := true
TW_NO_USB_STORAGE := true

# The current build system provides a ramdisk prepare hook. Use the stock image
# rule and its size checks rather than overriding recovery/boot image recipes.
include $(DEVICE_PATH)/custombootimg.mk
