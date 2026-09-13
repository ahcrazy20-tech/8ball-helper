#!/usr/bin/env python3
"""Tests for tools/macho_inject.py - run with `python3 -m unittest discover tests`
or `python3 tests/test_macho_inject.py` from the repository root."""

from __future__ import annotations

import os
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
TOOLS = os.path.join(ROOT, "tools")
sys.path.insert(0, TOOLS)
sys.path.insert(0, HERE)

import macho_inject as mi  # noqa: E402
import machofactory as mf  # noqa: E402

INSTALL_NAME = "@executable_path/libUnityGraphics.dylib"
CLI = os.path.join(TOOLS, "macho_inject.py")

try:
    import lief  # noqa: F401
    HAVE_LIEF = True
except Exception:  # pragma: no cover
    HAVE_LIEF = False


class Base(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp(prefix="macho-test-")

    def tearDown(self):
        shutil.rmtree(self.dir, ignore_errors=True)

    def write(self, name, blob):
        path = os.path.join(self.dir, name)
        with open(path, "wb") as fh:
            fh.write(blob)
        return path

    def read(self, path):
        with open(path, "rb") as fh:
            return fh.read()

    def image(self, path, index=0):
        _data, images, _kind = mi.images_for_file(path)
        return images[index]

    def dylib_names(self, path, index=0):
        return [n for _k, n in self.image(path, index).dylibs()]


class TestParsing(Base):
    def test_reads_expected_metadata(self):
        path = self.write("app", mf.build_app_binary("arm64"))
        info = mi.inspect_file(path)
        self.assertEqual(info["container"], "thin")
        sl = info["slices"][0]
        self.assertEqual(sl["arch"], "arm64")
        self.assertEqual(sl["filetype"], "MH_EXECUTE")
        self.assertIn("/System/Library/Frameworks/UIKit.framework/UIKit", sl["dylibs"])
        self.assertIsNotNone(sl["code_signature"])
        self.assertGreater(sl["header_padding"], 100)
        self.assertIn("@executable_path/Frameworks", sl["rpaths"])

    def test_reads_fat_container(self):
        fat = mf.build_fat([
            (mf.build_app_binary("arm64"), 0x0100000C, 0),
            (mf.build_app_binary("x86_64"), 0x01000007, 3),
        ])
        path = self.write("fat", fat)
        arches = [s["arch"] for s in mi.inspect_file(path)["slices"]]
        self.assertEqual(arches, ["arm64", "x86_64"])

    def test_rejects_non_macho(self):
        path = self.write("nope", b"MZ\x90\x00 not a mach-o")
        with self.assertRaises(mi.MachOError) as ctx:
            mi.inspect_file(path)
        self.assertIn("not a Mach-O", str(ctx.exception))

    def test_detects_encryption(self):
        path = self.write("enc", mf.build_app_binary("arm64", encrypted=True))
        enc = mi.inspect_file(path)["slices"][0]["encryption"]
        self.assertEqual(enc["cryptid"], 1)

    def test_detects_encryption_cli_exit_code(self):
        path = self.write("enc", mf.build_app_binary("arm64", encrypted=True))
        proc = subprocess.run([sys.executable, CLI, "verify", path],
                              capture_output=True, text=True)
        self.assertEqual(proc.returncode, 2)
        self.assertIn("FairPlay", proc.stdout)


class TestInjection(Base):
    def setUp(self):
        super().setUp()
        self.path = self.write("app", mf.build_app_binary("arm64"))

    def test_adds_load_command_and_drops_stale_signature(self):
        before = self.image(self.path)
        before_lcs = [(lc.cmd, lc.raw) for lc in before.lcs]
        before_size = os.path.getsize(self.path)
        linkedit_before = before.find_segment("__LINKEDIT")
        sig = before.code_signature()

        report = mi.inject_dylib(self.path, INSTALL_NAME)
        self.assertTrue(report["changed"])

        after = self.image(self.path)
        self.assertIn(INSTALL_NAME, self.dylib_names(self.path))
        self.assertIsNone(after.code_signature())
        # one command removed (code signature), one added (the dylib)
        self.assertEqual(after.ncmds, before.ncmds)
        self.assertEqual(after.sizeofcmds,
                         before.sizeofcmds - 16 + self._command_size(after))
        # the dead signature payload is gone from the end of the file
        self.assertEqual(os.path.getsize(self.path), sig[0])
        self.assertEqual(os.path.getsize(self.path), before_size - sig[1])
        # __LINKEDIT bookkeeping follows the truncation
        linkedit_after = after.find_segment("__LINKEDIT")
        self.assertEqual(linkedit_after["filesize"],
                         linkedit_before["filesize"] - sig[1])
        self.assertLessEqual(linkedit_after["filesize"] + linkedit_after["fileoff"],
                             os.path.getsize(self.path))
        # the injected command is appended last; every other load command is
        # byte-identical and keeps its order
        injected = after.lcs[-1]
        self.assertEqual(injected.cmd, mi.LC_LOAD_DYLIB)
        self.assertEqual(self._name_of(injected), INSTALL_NAME)
        remaining = self._norm([lc for lc in after.lcs[:-1]])
        expected = self._norm([lc for cmd, raw_lc in [(c, r) for c, r in before_lcs]
                               if False]) # placeholder
        expected = self._norm([lc for lc in before.lcs if lc.cmd != mi.LC_CODE_SIGNATURE])
        self.assertEqual(remaining, expected)
        # __TEXT / sections untouched
        def seg_fields(img, name):
            seg = dict(img.find_segment(name))
            seg.pop("lc", None)
            return seg
        self.assertEqual(seg_fields(after, "__TEXT"), seg_fields(before, "__TEXT"))
        self.assertEqual(list(after.sections()), list(before.sections()))

    def test_new_command_is_well_formed(self):
        mi.inject_dylib(self.path, INSTALL_NAME)
        img = self.image(self.path)
        lcs = [lc for lc in img.lcs
               if lc.cmd == mi.LC_LOAD_DYLIB
               and self._name_of(lc) == INSTALL_NAME]
        self.assertEqual(len(lcs), 1)
        raw = lcs[0].raw
        name_off = struct.unpack_from("<I", raw, 8)[0]
        self.assertEqual(name_off, 24)
        timestamp, current, compat = struct.unpack_from("<III", raw, 12)
        # optool used to write 0xDEADBEEF here, which dyld rejects on arm64
        self.assertEqual((timestamp, current, compat), (0, 0, 0))
        self.assertNotIn(b"\xef\xbe\xad\xde", raw)
        self.assertEqual(len(raw) % 8, 0)

    def test_injection_is_idempotent(self):
        mi.inject_dylib(self.path, INSTALL_NAME)
        first = self.read(self.path)
        report = mi.inject_dylib(self.path, INSTALL_NAME)
        self.assertFalse(report["changed"])
        self.assertTrue(report["slices"][0]["already"])
        self.assertEqual(self.read(self.path), first)

    def test_load_command_fits_in_header_padding(self):
        img = self.image(self.path)
        lc_end_before = img.header_size + img.sizeofcmds
        mi.inject_dylib(self.path, INSTALL_NAME)
        after = self.image(self.path)
        new_lc = [lc for lc in after.lcs
                  if lc.cmd == mi.LC_LOAD_DYLIB and self._name_of(lc) == INSTALL_NAME][0]
        self.assertGreaterEqual(new_lc.offset, lc_end_before - 32)
        self.assertLessEqual(new_lc.offset + new_lc.cmdsize,
                             after.header_size + after.sizeofcmds)
        # and it must sit in front of the first section's data
        first_section = min(off for _s, _n, _a, size, off in after.sections() if size)
        self.assertLess(after.header_size + after.sizeofcmds, first_section)

    def test_packed_header_gives_actionable_error(self):
        packed = self.write("packed", mf.build_app_binary("arm64", text_offset="tight"))
        original = self.read(packed)
        with self.assertRaises(mi.MachOError) as ctx:
            mi.inject_dylib(packed, INSTALL_NAME)
        message = str(ctx.exception)
        self.assertIn("header padding", message)
        self.assertIn("TrollFools", message)
        self.assertEqual(self.read(packed), original)  # nothing was written

    def test_keep_codesig_leaves_command_in_place(self):
        mi.inject_dylib(self.path, INSTALL_NAME, strip_codesig=False)
        img = self.image(self.path)
        self.assertIsNotNone(img.code_signature())
        self.assertIn(INSTALL_NAME, self.dylib_names(self.path))

    def test_dry_run_writes_nothing(self):
        original = self.read(self.path)
        report = mi.inject_dylib(self.path, INSTALL_NAME, dry_run=True)
        self.assertFalse(report["changed"])
        self.assertEqual(self.read(self.path), original)

    def test_big_endian_is_rejected(self):
        path = self.write("be", mf.build_big_endian_64())
        with self.assertRaises(mi.MachOError) as ctx:
            mi.inject_dylib(path, INSTALL_NAME)
        self.assertIn("big-endian", str(ctx.exception))

    def test_backup_option(self):
        mi.inject_dylib(self.path, INSTALL_NAME, backup=True)
        self.assertTrue(os.path.exists(self.path + ".bak"))

    def test_survives_chained_fixups_binaries(self):
        path = self.write("modern", mf.build_app_binary("arm64", chained_fixups=True))
        mi.inject_dylib(path, INSTALL_NAME)
        self.assertIn(INSTALL_NAME, self.dylib_names(path))
        self.assertIsNone(mi.inspect_file(path)["slices"][0]["code_signature"])

    def test_loads_into_a_dylib_too(self):
        path = self.write("lib", mf.build_dylib())
        mi.inject_dylib(path, INSTALL_NAME)
        self.assertIn(INSTALL_NAME, self.dylib_names(path))

    # helpers ------------------------------------------------------------

    @staticmethod
    def _norm(lcs):
        """Load commands with the (intentionally changed) __LINKEDIT size blanked."""
        out = []
        for lc in lcs:
            raw = lc.raw
            if lc.cmd == mi.LC_SEGMENT_64 and raw[8:24].rstrip(b"\x00") == b"__LINKEDIT":
                raw = raw[:48] + b"\x00" * 8 + raw[56:]
            out.append((lc.cmd, raw))
        return out

    def _command_size(self, img):
        for lc in img.lcs:
            if lc.cmd == mi.LC_LOAD_DYLIB and self._name_of(lc) == INSTALL_NAME:
                return lc.cmdsize
        raise AssertionError("injected command not found")

    @staticmethod
    def _name_of(lc):
        name_off = struct.unpack_from("<I", lc.raw, 8)[0]
        return lc.raw[name_off:].split(b"\x00")[0].decode()


class TestFatInjection(Base):
    def _fat(self):
        return self.write("fat", mf.build_fat([
            (mf.build_app_binary("arm64"), 0x0100000C, 0),
            (mf.build_app_binary("x86_64"), 0x01000007, 3),
        ]))

    def test_patches_every_slice(self):
        path = self._fat()
        report = mi.inject_dylib(path, INSTALL_NAME)
        self.assertEqual(len(report["slices"]), 2)
        for index in (0, 1):
            self.assertIn(INSTALL_NAME, self.dylib_names(path, index))
            self.assertIsNone(mi.inspect_file(path)["slices"][index]["code_signature"])

    def test_arch_filter_patches_only_one_slice(self):
        path = self._fat()
        mi.inject_dylib(path, INSTALL_NAME, arch="x86_64")
        self.assertNotIn(INSTALL_NAME, self.dylib_names(path, 0))
        self.assertIn(INSTALL_NAME, self.dylib_names(path, 1))

    def test_truncation_of_last_slice_updates_the_fat_header(self):
        path = self.write("fat-tight", mf.build_fat([
            (mf.build_app_binary("arm64"), 0x0100000C, 0),
            (mf.build_app_binary("x86_64"), 0x01000007, 3),
        ], trailing_pad=False))
        sig_size = mi.inspect_file(path)["slices"][1]["code_signature"]["size"]
        size_before = os.path.getsize(path)

        mi.inject_dylib(path, INSTALL_NAME)

        # the last slice ends the file, so it was truncated...
        self.assertEqual(os.path.getsize(path), size_before - sig_size)
        # ...and the fat_arch entry was shrunk with it, otherwise the container
        # would describe a slice that is not in the file any more
        _data, _images, _kind = mi.images_for_file(path)
        with open(path, "rb") as fh:
            fat_bytes = fh.read()
        slices = mi._fat_slices(bytearray(fat_bytes))
        self.assertEqual(slices[1][1], 0x14000 - sig_size)
        self.assertEqual(slices[1][0] + slices[1][1], os.path.getsize(path))
        self.assertIn(INSTALL_NAME, self.dylib_names(path, 0))
        self.assertIn(INSTALL_NAME, self.dylib_names(path, 1))

    def test_unknown_arch_reports_available_ones(self):
        path = self._fat()
        with self.assertRaises(mi.MachOError) as ctx:
            mi.inject_dylib(path, INSTALL_NAME, arch="arm64e")
        self.assertIn("arm64", str(ctx.exception))


class TestCli(Base):
    def test_inject_and_verify_roundtrip(self):
        path = self.write("app", mf.build_app_binary("arm64"))
        proc = subprocess.run(
            [sys.executable, CLI, "inject", path, "libUnityGraphics.dylib",
             "--install-name", INSTALL_NAME],
            capture_output=True, text=True,
        )
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertIn("now loads", proc.stdout)

        proc = subprocess.run([sys.executable, CLI, "verify", path],
                              capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertIn(INSTALL_NAME, proc.stdout)
        self.assertIn("code signature  : none", proc.stdout)

    def test_packed_header_exit_code_is_one(self):
        path = self.write("packed", mf.build_app_binary("arm64", text_offset="tight"))
        proc = subprocess.run(
            [sys.executable, CLI, "inject", path, "libUnityGraphics.dylib"],
            capture_output=True, text=True,
        )
        self.assertEqual(proc.returncode, 1)
        self.assertIn("header padding", proc.stdout + proc.stderr)


@unittest.skipUnless(HAVE_LIEF, "python3-lief not installed")
class TestAgainstLief(Base):
    """Cross-check the hand-written Mach-O writer with an independent parser."""

    def test_lief_agrees_before_and_after(self):
        path = self.write("app", mf.build_app_binary("arm64"))
        parsed = lief.MachO.parse(path)
        self.assertIsNotNone(parsed)
        before = parsed.at(0)
        self.assertTrue(before.has_code_signature)

        mi.inject_dylib(path, INSTALL_NAME)

        parsed = lief.MachO.parse(path)
        self.assertIsNotNone(parsed)
        after = parsed.at(0)
        self.assertIn(INSTALL_NAME, [lib.name for lib in after.libraries])
        self.assertFalse(after.has_code_signature)
        self.assertEqual(after.header.nb_cmds, before.header.nb_cmds)
        self.assertEqual(len(after.segments), len(before.segments))
        self.assertEqual([s.name for s in after.segments],
                         [s.name for s in before.segments])
        # every segment must still live inside the (shrunken) file
        size = os.path.getsize(path)
        for seg in after.segments:
            if seg.file_size:
                self.assertLessEqual(seg.file_offset + seg.file_size, size,
                                     "segment %s points outside the file" % seg.name)

    def test_lief_parses_fat_output(self):
        path = self.write("fat", mf.build_fat([
            (mf.build_app_binary("arm64"), 0x0100000C, 0),
            (mf.build_app_binary("x86_64"), 0x01000007, 3),
        ]))
        mi.inject_dylib(path, INSTALL_NAME)
        parsed = lief.MachO.parse(path)
        self.assertIsNotNone(parsed)
        self.assertEqual(len(parsed), 2)
        for binary in parsed:
            self.assertIn(INSTALL_NAME, [lib.name for lib in binary.libraries])


if __name__ == "__main__":
    unittest.main(verbosity=2)
