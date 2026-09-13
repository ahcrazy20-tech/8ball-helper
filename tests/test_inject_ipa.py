#!/usr/bin/env python3
"""End-to-end tests for tools/inject_ipa.py and the inject.sh wrapper."""

from __future__ import annotations

import os
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
TOOLS = os.path.join(ROOT, "tools")
sys.path.insert(0, TOOLS)
sys.path.insert(0, HERE)

import macho_inject as mi  # noqa: E402
import machofactory as mf  # noqa: E402

TOOL = os.path.join(TOOLS, "inject_ipa.py")
SH = os.path.join(ROOT, "inject.sh")

APP_DIR = "Payload/8 Ball Pool.app"          # note the space, like the real game
EXE_NAME = "8BallPool"                        # deliberately different from the folder
BUNDLE_ID = "com.miniclip.8ballpoolmult"
DEFAULT_INSTALL_NAME = "@executable_path/libUnityGraphics.dylib"


def make_ipa(path, *, exe_blob=None, encrypted=False, arch="arm64",
             extra_entries=True, exe_name=EXE_NAME, bundle_id=BUNDLE_ID):
    if exe_blob is None:
        exe_blob = mf.build_app_binary(arch, encrypted=encrypted)
    info = {
        "CFBundleExecutable": exe_name,
        "CFBundleIdentifier": bundle_id,
        "CFBundleShortVersionString": "56.29.1",
        "CFBundleVersion": "56.29.1",
        "CFBundleName": "8 Ball Pool",
    }
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.writestr(APP_DIR + "/Info.plist", plistlib.dumps(info))
        zf.writestr("%s/%s" % (APP_DIR, exe_name), exe_blob)
        zf.writestr(APP_DIR + "/PkgInfo", b"APPL????")
        zf.writestr(APP_DIR + "/Assets.car", b"fake assets")
        zf.writestr(APP_DIR + "/Frameworks/keepme.txt", b"untouched")
        if extra_entries:
            zf.writestr("Payload/", b"")
            zf.writestr("META-INF/com.apple.ZipMetadata.plist", b"meta")
    return path


class IpaCase(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp(prefix="ipa-test-")
        self.ipa = make_ipa(os.path.join(self.dir, "8BallPool.ipa"))
        self.dylib = os.path.join(self.dir, "PoolHelper.dylib")
        with open(self.dylib, "wb") as fh:
            fh.write(mf.build_dylib())

    def tearDown(self):
        shutil.rmtree(self.dir, ignore_errors=True)

    def out(self, name="patched.ipa"):
        return os.path.join(self.dir, name)

    def run_tool(self, *args):
        cmd = [sys.executable, TOOL, args[0], args[1]] + list(args[2:])
        return subprocess.run(cmd, capture_output=True, text=True)

    def exe_from_ipa(self, path, exe_name=EXE_NAME):
        """Extract the app binary from an IPA into a temp file and parse it."""
        with zipfile.ZipFile(path) as zf:
            blob = zf.read("%s/%s" % (APP_DIR, exe_name))
        tmp = os.path.join(self.dir, "extracted_binary")
        with open(tmp, "wb") as fh:
            fh.write(blob)
        return tmp, mi.inspect_file(tmp)


class TestInjectIpa(IpaCase):
    def test_happy_path(self):
        out = self.out()
        proc = self.run_tool(self.ipa, self.dylib, "-o", out)
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertTrue(os.path.exists(out))

        with zipfile.ZipFile(out) as zf:
            names = set(zf.namelist())
            # the dylib was renamed on the way in (PoolHelper is too obvious)
            self.assertIn("%s/libUnityGraphics.dylib" % APP_DIR, names)
            self.assertNotIn("%s/PoolHelper.dylib" % APP_DIR, names)
            # unrelated entries survive byte for byte
            self.assertEqual(zf.read(APP_DIR + "/Frameworks/keepme.txt"), b"untouched")
            self.assertEqual(zf.read(APP_DIR + "/Assets.car"), b"fake assets")
            self.assertEqual(zf.read(APP_DIR + "/PkgInfo"), b"APPL????")
            self.assertEqual(
                plistlib.loads(zf.read(APP_DIR + "/Info.plist"))["CFBundleIdentifier"],
                BUNDLE_ID,
            )
            # the copied dylib is the real one
            self.assertEqual(
                len(zf.read("%s/libUnityGraphics.dylib" % APP_DIR)),
                os.path.getsize(self.dylib),
            )

        _path, info = self.exe_from_ipa(out)
        self.assertIn(DEFAULT_INSTALL_NAME, info["slices"][0]["dylibs"])
        self.assertIsNone(info["slices"][0]["code_signature"])

    def test_input_ipa_is_not_modified(self):
        with open(self.ipa, "rb") as fh:
            before = fh.read()
        self.run_tool(self.ipa, self.dylib, "-o", self.out())
        with open(self.ipa, "rb") as fh:
            self.assertEqual(fh.read(), before)

    def test_default_output_name(self):
        proc = self.run_tool(self.ipa, self.dylib)
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertTrue(os.path.exists(os.path.join(self.dir, "8BallPool-patched.ipa")))

    def test_refuses_to_overwrite_input(self):
        proc = self.run_tool(self.ipa, self.dylib, "-o", self.ipa)
        self.assertEqual(proc.returncode, 1)
        self.assertIn("refusing to overwrite", proc.stderr)

    def test_refuses_encrypted_app_store_ipa(self):
        enc = make_ipa(os.path.join(self.dir, "encrypted.ipa"), encrypted=True)
        proc = self.run_tool(enc, self.dylib, "-o", self.out("enc-patched.ipa"))
        self.assertEqual(proc.returncode, 1)
        self.assertIn("encrypted", proc.stderr)
        self.assertIn("AppDump", proc.stderr)
        self.assertFalse(os.path.exists(self.out("enc-patched.ipa")))

        proc = self.run_tool(enc, self.dylib, "-o", self.out("enc-patched.ipa"),
                             "--allow-encrypted")
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)

    def test_arch_mismatch(self):
        x86 = os.path.join(self.dir, "x86.dylib")
        with open(x86, "wb") as fh:
            fh.write(mf.build_dylib(arch="x86_64"))
        proc = self.run_tool(self.ipa, x86, "-o", self.out("mismatch.ipa"))
        self.assertEqual(proc.returncode, 1)
        self.assertIn("architecture mismatch", proc.stderr)

    def test_custom_name_and_install_name(self):
        out = self.out("custom.ipa")
        proc = self.run_tool(self.ipa, self.dylib, "-o", out,
                             "--name", "libSwiftyPlugin.dylib",
                             "--install-name", "@executable_path/libSwiftyPlugin.dylib")
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        with zipfile.ZipFile(out) as zf:
            self.assertIn("%s/libSwiftyPlugin.dylib" % APP_DIR, set(zf.namelist()))
        _path, info = self.exe_from_ipa(out)
        self.assertIn("@executable_path/libSwiftyPlugin.dylib", info["slices"][0]["dylibs"])

    def test_dry_run_writes_nothing(self):
        out = self.out("dry.ipa")
        proc = self.run_tool(self.ipa, self.dylib, "-o", out, "--dry-run")
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertIn("dry run", proc.stdout)
        self.assertFalse(os.path.exists(out))

    def test_rejects_non_macho_dylib(self):
        bad = os.path.join(self.dir, "nope.dylib")
        with open(bad, "wb") as fh:
            fh.write(b"not a dylib")
        proc = self.run_tool(self.ipa, bad, "-o", self.out("bad.ipa"))
        self.assertEqual(proc.returncode, 1)
        self.assertIn("bad dylib", proc.stderr)

    def test_rejects_non_ipa(self):
        fake = os.path.join(self.dir, "fake.ipa")
        with zipfile.ZipFile(fake, "w") as zf:
            zf.writestr("hello.txt", b"hi")
        proc = self.run_tool(fake, self.dylib, "-o", self.out("fake-patched.ipa"))
        self.assertEqual(proc.returncode, 1)
        self.assertIn("Payload", proc.stderr)

    def test_finds_executable_when_plist_is_wrong(self):
        weird = make_ipa(os.path.join(self.dir, "weird.ipa"), exe_name="DifferentName")
        proc = self.run_tool(weird, self.dylib, "-o", self.out("weird-patched.ipa"))
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        _path, info = self.exe_from_ipa(self.out("weird-patched.ipa"),
                                        exe_name="DifferentName")
        self.assertIn(DEFAULT_INSTALL_NAME, info["slices"][0]["dylibs"])


@unittest.skipUnless(shutil.which("bash"), "bash not available")
class TestInjectSh(IpaCase):
    def test_wrapper_end_to_end(self):
        out = self.out("wrapper.ipa")
        proc = subprocess.run(["bash", SH, self.ipa, self.dylib, "-o", out],
                              capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertIn("Done:", proc.stdout)
        _path, info = self.exe_from_ipa(out)
        self.assertIn(DEFAULT_INSTALL_NAME, info["slices"][0]["dylibs"])

    def test_wrapper_usage_message(self):
        proc = subprocess.run(["bash", SH], capture_output=True, text=True)
        self.assertEqual(proc.returncode, 1)
        self.assertIn("Usage:", proc.stdout)

    def test_wrapper_help(self):
        proc = subprocess.run(["bash", SH, "--help"], capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertIn("--allow-encrypted", proc.stdout)

    def test_wrapper_reports_missing_python(self):
        bash = shutil.which("bash")
        # a PATH with the usual shell helpers but deliberately no python
        fakebin = os.path.join(self.dir, "fakebin")
        os.makedirs(fakebin, exist_ok=True)
        for tool in ("dirname", "cat"):
            src = shutil.which(tool)
            if src:
                os.symlink(src, os.path.join(fakebin, tool))
        proc = subprocess.run(
            [bash, SH, self.ipa, self.dylib],
            capture_output=True, text=True,
            env={"PATH": fakebin, "PYTHON": "", "HOME": self.dir},
        )
        self.assertEqual(proc.returncode, 1)
        self.assertIn("No Python 3.7+ found", proc.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
