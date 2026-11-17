#!/usr/bin/env python3
"""Host regression tests for BLA-L29 TWRP improvements in device/huawei/blanc."""

from __future__ import annotations

import hashlib
import os
import pathlib
import re
import shlex
import subprocess
import tarfile
import tempfile
import unittest


DEVICE_DIR = pathlib.Path(__file__).resolve().parents[1]
RECOVERY_ROOT = DEVICE_DIR / "recovery-modern" / "recovery" / "root"


def _parse_fstab(path: pathlib.Path) -> tuple[list[dict], list[dict]]:
    v1_rows = []
    v2_rows = []
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("/devices/"):
            parts = shlex.split(line)
            assert len(parts) == 5, f"Expected 5 columns on v2 row in {path}: {raw_line}"
            v2_rows.append(
                {
                    "src": parts[0],
                    "mount_point": parts[1],
                    "fs_type": parts[2],
                    "mnt_flags": parts[3],
                    "tw_flags": parts[4].split(","),
                }
            )
        else:
            before, sep, after = line.partition("flags=")
            assert sep == "flags=", f"Expected flags= on v1 row in {path}: {raw_line}"
            cols = shlex.split(before)
            assert len(cols) == 3, f"Expected 3 columns before flags= on v1 row in {path}: {raw_line}"
            v1_rows.append(
                {
                    "mount_point": cols[0],
                    "fs_type": cols[1],
                    "blk_device": cols[2],
                    "flags": after.strip().split(";"),
                }
            )
    return v1_rows, v2_rows


class TwrpBlancConfigTest(unittest.TestCase):
    def test_fstab_flashimg_and_otg_invariants(self) -> None:
        configs = [
            (DEVICE_DIR / "recovery.fstab", {"/kernel", "/recovery_ramdisk"}),
            (
                RECOVERY_ROOT / "system" / "etc" / "recovery.fstab.super",
                {"/kernel", "/ramdisk", "/recovery_ramdisk"},
            ),
        ]
        for fstab_path, expected_flashimg in configs:
            v1_rows, v2_rows = _parse_fstab(fstab_path)
            by_mp = {row["mount_point"]: row for row in v1_rows}
            if fstab_path.name == "recovery.fstab.super":
                self.assertEqual(by_mp["/kernel"]["blk_device"], "/dev/block/by-name/kernel")
                self.assertEqual(by_mp["/ramdisk"]["blk_device"], "/dev/block/by-name/ramdisk")
            flash_targets = {row["mount_point"] for row in v1_rows if "flashimg=1" in row["flags"]}
            self.assertEqual(flash_targets, expected_flashimg, fstab_path.name)

            for row in v1_rows:
                mp = row["mount_point"]
                flags = row["flags"]
                self.assertIn("wipeingui=0", flags, mp)
                self.assertIn("wipeduringfactoryreset=0", flags, mp)
                self.assertIn("canbewiped=0", flags, mp)
                if mp in expected_flashimg:
                    self.assertIn("backup=1", flags, mp)
                    self.assertNotIn("fsflags=ro", flags, mp)
                    self.assertFalse(any(f.startswith("fsflags=ro,") for f in flags), mp)
                else:
                    self.assertIn("flashimg=0", flags, mp)
                    self.assertTrue(
                        any(f == "fsflags=ro" or f.startswith("fsflags=ro,") for f in flags),
                        f"{fstab_path.name} {mp} must remain read-only: {flags}",
                    )
                if mp == "/data":
                    self.assertIn("storage=0", flags)
                    self.assertIn("settingsstorage=0", flags)

            self.assertEqual(len(v2_rows), 3, fstab_path.name)
            mount_points = {row["mount_point"] for row in v2_rows}
            self.assertEqual(mount_points, {"/usb_otg", "/usb_otg_hisi", "/usb_otg_hifi"})
            for row in v2_rows:
                self.assertEqual(row["fs_type"], "auto")
                self.assertEqual(row["mnt_flags"], "defaults")
                self.assertIn("storage", row["tw_flags"])
                self.assertIn("removable", row["tw_flags"])
                self.assertIn("backup=0", row["tw_flags"])
                self.assertFalse(any(f.startswith("flags=") for f in row["tw_flags"]))

    def test_board_device_usb_and_bootstrap_linker(self) -> None:
        board = (DEVICE_DIR / "BoardConfig.mk").read_text(encoding="utf-8")
        device = (DEVICE_DIR / "device.mk").read_text(encoding="utf-8")
        customboot = (DEVICE_DIR / "custombootimg.mk").read_text(encoding="utf-8")
        init_rc = (RECOVERY_ROOT / "system" / "etc" / "init" / "hw" / "init.rc").read_text(
            encoding="utf-8"
        )
        usb_rc = (RECOVERY_ROOT / "init.recovery.usb.rc").read_text(encoding="utf-8")
        blanc_rc = (RECOVERY_ROOT / "init.recovery.blanc.rc").read_text(encoding="utf-8")
        fixlinks = (RECOVERY_ROOT / "sbin" / "fixlinks.sh").read_text(encoding="utf-8")

        self.assertIn("TW_INCLUDE_FASTBOOTD := true", board)
        self.assertIn("$(TARGET_OUT_EXECUTABLES)/lptools", board)
        self.assertIn("android.hardware.fastboot@1.1.so", board)
        self.assertIn("android.hardware.fastboot-V1-ndk.so", board)
        self.assertIn("android.hardware.health@2.0.so", board)
        self.assertIn("android.hardware.health-V3-ndk.so", board)
        self.assertIn("TW_EXCLUDE_MTP := true", board)
        self.assertIn("TW_NO_USB_STORAGE := true", board)
        self.assertIsNone(re.search(r"^\s*TW_INCLUDE_CRYPTO\s*[:+?]?=", board, re.MULTILINE))

        self.assertIn("ro.recovery.usb.vid=12D1", device)
        self.assertIn("ro.recovery.usb.adb.pid=103A", device)
        self.assertIn("ro.recovery.usb.fastboot.pid=1057", device)
        self.assertIn("fastbootd", device)
        self.assertIn("lptools", device)

        self.assertIn("system/bin/bootstrap", customboot)
        self.assertIn("/system/bin/linker64", customboot)
        self.assertIn("usb_otg_hifi", customboot)
        self.assertIn("system/bin/blanc-diag-dump.sh", customboot)
        self.assertLess(
            customboot.index("rm -f \"$(TARGET_RECOVERY_ROOT_OUT)/sbin/modprobe\""),
            customboot.index("ramdisk-files.txt"),
        )
        self.assertLess(customboot.index("bootstrap/linker64"), customboot.index("ramdisk-files.txt"))
        self.assertLess(customboot.index("system/bin/blanc-diag-dump.sh"), customboot.index("ramdisk-files.txt"))

        self.assertLess(
            init_rc.index("start servicemanager"),
            init_rc.index("on boot"),
        )
        sm_block = re.search(
            r"^service servicemanager /system/bin/servicemanager\n(?:    .+\n)+",
            init_rc,
            re.MULTILINE,
        )
        self.assertIsNotNone(sm_block, "Missing servicemanager service definition in init.rc")
        sm_text = sm_block.group(0)
        for expected in (
            "user system",
            "group system readproc",
            "disabled",
            "file /dev/kmsg w",
            "onrestart setprop servicemanager.ready false",
            "seclabel u:r:servicemanager:s0",
        ):
            self.assertIn(expected, sm_text)

        fb_block = re.search(
            r"^service fastbootd /system/bin/fastbootd\n(?:    .+\n)+",
            init_rc,
            re.MULTILINE,
        )
        self.assertIsNotNone(fb_block, "Missing fastbootd service definition in init.rc")
        self.assertIn("group system shell", fb_block.group(0))
        self.assertIn("seclabel u:r:fastbootd:s0", fb_block.group(0))

        fs_idx = init_rc.index("\non fs\n")
        ffs_mkdir_idx = init_rc.index("mkdir /config/usb_gadget/g1/functions/ffs.fastboot")
        ffs_chmod_idx = init_rc.index("chmod 0755 /dev/usb-ffs", fs_idx)
        ffs_mount_idx = init_rc.index("mount functionfs fastboot /dev/usb-ffs/fastboot")
        self.assertLess(fs_idx, ffs_chmod_idx)
        self.assertLess(ffs_mkdir_idx, ffs_mount_idx)
        self.assertLess(ffs_chmod_idx, ffs_mount_idx)
        self.assertIn("write /sys/devices/virtual/android_usb/android0/port_mode 2", init_rc)

        self.assertIn("0x103a", usb_rc)
        self.assertIn("0x1057", usb_rc)
        self.assertIn("stop fastbootd", usb_rc)
        self.assertIn("start fastbootd", usb_rc)
        self.assertIn("ffs.fastboot", usb_rc)
        self.assertIn("os_desc/use 1", usb_rc)
        usb_fs_idx = usb_rc.index("on fs\n")
        usb_fs_configfs_idx = usb_rc.index("on fs && property:sys.usb.configfs=1")
        self.assertIn("chmod 0755 /dev/usb-ffs", usb_rc[usb_fs_idx:usb_fs_configfs_idx])
        usb_fb_idx = usb_rc.index("on property:sys.usb.config=fastboot && property:sys.usb.configfs=1")
        usb_fb_end_idx = usb_rc.index("start fastbootd", usb_fb_idx)
        self.assertIn("chmod 0755 /dev/usb-ffs", usb_rc[usb_fb_idx:usb_fb_end_idx])

        self.assertIn("service oeminfo_nvm /system/bin/true", blanc_rc)
        self.assertIn("service teecd /system/bin/true", blanc_rc)
        self.assertIn("on property:sys.powerctl=*", blanc_rc)
        self.assertIn("/dev/block/by-name", fixlinks)

    def test_sepolicy_scoping(self) -> None:
        fc = (DEVICE_DIR / "sepolicy" / "file_contexts").read_text(encoding="utf-8")
        recovery_te = (DEVICE_DIR / "sepolicy" / "recovery.te").read_text(encoding="utf-8")
        self.assertIn("kernel(_a)?", fc)
        self.assertIn("ramdisk(_a)?", fc)
        self.assertEqual(fc.count("u:object_r:boot_block_device:s0"), 2)
        self.assertIn("u:object_r:recovery_block_device:s0", fc)
        for forbidden in (
            "xloader",
            "fastboot",
            "dts",
            "dto",
            "oeminfo",
            "recovery_vendor",
            "vbmeta",
            "modemnvm",
        ):
            self.assertNotIn(forbidden, fc)
        self.assertIn("allow init boot_block_device:{ blk_file lnk_file } relabelto;", recovery_te)
        self.assertNotIn("pstorefs", recovery_te)

    def test_shell_scripts_and_diag_dump_archive(self) -> None:
        sbin_dir = RECOVERY_ROOT / "sbin"
        scripts = sorted(sbin_dir.glob("*.sh"))
        self.assertGreaterEqual(len(scripts), 3)
        for script in scripts:
            res = subprocess.run(["sh", "-n", str(script)], capture_output=True, text=True)
            self.assertEqual(res.returncode, 0, f"{script.name}: {res.stderr}")

        diag = sbin_dir / "blanc-diag-dump.sh"
        self.assertTrue(os.access(diag, os.X_OK), "blanc-diag-dump.sh must be executable")
        self.assertIn("lptools free", diag.read_text(encoding="utf-8"))
        self.assertIn("/dev/block/mapper", diag.read_text(encoding="utf-8"))
        with tempfile.TemporaryDirectory() as tmp:
            res = subprocess.run(["sh", str(diag), tmp], capture_output=True, text=True, check=True)
            archive = pathlib.Path(res.stdout.strip().splitlines()[-1])
            self.assertTrue(archive.is_file())
            self.assertEqual(archive.parent, pathlib.Path(tmp))
            sha_file = pathlib.Path(str(archive) + ".sha256")
            self.assertTrue(sha_file.is_file())
            expected_sha = hashlib.sha256(archive.read_bytes()).hexdigest()
            self.assertTrue(sha_file.read_text(encoding="utf-8").startswith(expected_sha + "  "))
            with tarfile.open(archive, "r:gz") as tf:
                members = {m.name.split("/", 1)[1] for m in tf.getmembers() if "/" in m.name}
            self.assertIn("uname.txt", members)
            self.assertIn("mounts.txt", members)
            self.assertIn("partition-sha256.txt", members)


if __name__ == "__main__":
    unittest.main()
