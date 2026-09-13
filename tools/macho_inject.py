#!/usr/bin/env python3
"""
macho_inject.py - pure-Python Mach-O loader-command editor (stdlib only).

Why this exists
---------------
`inject.sh` used to shell out to `optool` or `insert_dylib`.  Both are macOS-only,
neither is installed by default, and `optool` is known to produce broken arm64
binaries (it writes the ASCII marker 0xdeadbeef where the dylib command's
`timestamp` field belongs, which dyld rejects on arm64 -> the app crashes or the
dylib simply never loads).  Result: "failed to inject ... exited with code 1".

This module implements the two things injection actually needs:

  * `inject`  - add an LC_LOAD_DYLIB load command pointing at @executable_path/<name>
  * `verify`  - list the dylibs / rpaths / encryption state of a binary (the
                equivalent of `otool -L`, without needing macOS)

It works on thin Mach-O images and on fat/universal files (all slices are
patched unless `--arch` is given), never relocates code, never touches
`__TEXT`/`__DATA` content, and always reports exactly what it changed.

Hard rules implemented here (each one was a real crash source):

  1. The new load command is placed in the *header padding* between the end of
     the existing load commands and the first section.  Nothing else moves.
  2. `sizeofcmds`/`ncmds` are updated, the rest of the header area is zeroed.
  3. The load command uses real dylib version fields - no 0xdeadbeef marker.
  4. Modifying a signed binary invalidates the embedded code signature.  A stale
     signature makes iOS refuse to launch the app, so the LC_CODE_SIGNATURE
     command is removed (and the trailing signature blob truncated, when it is
     safe) - which is exactly what `insert_dylib --strip-codesig` does.  The
     bundle still has to be re-signed by the sideloading tool (Sideloadly,
     ESign, TrollStore, ldid) - that is expected and normal.
  5. If the header padding is too small, we fail loudly instead of shuffling
     megabytes of code around (see the error message for the workaround).

CLI
---
    python3 macho_inject.py verify  <file>
    python3 macho_inject.py inject  <file> <dylib-name|@path> [options]

`inject` options:
    --install-name PATH   load-command path (default: @executable_path/<basename>)
    --arch NAME           only patch this slice (arm64, arm64e, x86_64, ...)
    --keep-codesig        keep LC_CODE_SIGNATURE (you then MUST re-sign correctly)
    --no-truncate         remove the LC but leave the dead signature bytes behind
    --dry-run             report what would happen, write nothing
    --backup              write <file>.bak before modifying
"""

from __future__ import annotations

import argparse
import os
import shutil
import struct
import sys

__all__ = [
    "MachOError",
    "MachOImage",
    "inject_dylib",
    "inspect_file",
    "is_macho",
    "arch_name",
]

# --------------------------------------------------------------------------
# constants
# --------------------------------------------------------------------------

# 4-byte file signatures (compared as raw bytes so endianness is unambiguous)
MH_MAGIC_32 = b"\xce\xfa\xed\xfe"
MH_MAGIC_64 = b"\xcf\xfa\xed\xfe"
MH_CIGAM_32 = b"\xfe\xed\xfa\xce"
MH_CIGAM_64 = b"\xfe\xed\xfa\xcf"
FAT_MAGIC = b"\xca\xfe\xba\xbe"
FAT_CIGAM = b"\xbe\xba\xfe\xca"
FAT_MAGIC_64 = b"\xca\xfe\xba\xbf"

# load commands we care about
LC_SEGMENT = 0x01
LC_SYMTAB = 0x02
LC_DYSYMTAB = 0x0B
LC_LOAD_DYLIB = 0x0C
LC_ID_DYLIB = 0x0D
LC_LOAD_DYLINKER = 0x0E
LC_LOAD_WEAK_DYLIB = 0x80000018
LC_SEGMENT_64 = 0x19
LC_UUID = 0x1B
LC_CODE_SIGNATURE = 0x1D
LC_REEXPORT_DYLIB = 0x8000001F
LC_LAZY_LOAD_DYLIB = 0x20
LC_ENCRYPTION_INFO = 0x21
LC_DYLD_INFO = 0x22
LC_DYLD_INFO_ONLY = 0x80000022
LC_VERSION_MIN_IPHONEOS = 0x25
LC_FUNCTION_STARTS = 0x26
LC_DYLD_ENVIRONMENT = 0x27
LC_MAIN = 0x80000028
LC_DATA_IN_CODE = 0x29
LC_SOURCE_VERSION = 0x2A
LC_ENCRYPTION_INFO_64 = 0x2C
LC_LINKER_OPTION = 0x2D
LC_BUILD_VERSION = 0x32
LC_DYLD_EXPORTS_TRIE = 0x80000033
LC_DYLD_CHAINED_FIXUPS = 0x80000034
LC_FILESET_ENTRY = 0x80000035

LINKEDIT_DATA_COMMANDS = {
    LC_CODE_SIGNATURE,
    LC_FUNCTION_STARTS,
    LC_DATA_IN_CODE,
    LC_DYLD_EXPORTS_TRIE,
    LC_DYLD_CHAINED_FIXUPS,
}

FILE_TYPES = {
    0x1: "MH_OBJECT",
    0x2: "MH_EXECUTE",
    0x3: "MH_FVMLIB",
    0x4: "MH_CORE",
    0x5: "MH_PRELOAD",
    0x6: "MH_DYLIB",
    0x7: "MH_DYLINKER",
    0x8: "MH_BUNDLE",
    0x9: "MH_DYLIB_STUB",
    0xA: "MH_DSYM",
    0xB: "MH_KEXT_BUNDLE",
    0xC: "MH_FILESET",
}

# cputype -> readable name
CPU_ARCH_ABI64 = 0x01000000
CPU_TYPE_NAMES = {
    0x00000007: "i386",
    0x0000000C: "arm",
    0x00000012: "powerpc",
    CPU_ARCH_ABI64 | 0x00000007: "x86_64",
    CPU_ARCH_ABI64 | 0x0000000C: "arm64",
}
ARM64_SUBTYPES = {
    0: "arm64",
    1: "arm64v8",
    2: "arm64e",
}


class MachOError(Exception):
    """Raised for anything that makes a file unsafe/impossible to patch."""


def _align(value: int, alignment: int) -> int:
    return (value + alignment - 1) & ~(alignment - 1)


def arch_name(cputype: int, cpusubtype: int) -> str:
    cpusubtype &= 0x00FFFFFF  # strip the CPU_SUBTYPE_LIB64 capability bit
    if cputype == (CPU_ARCH_ABI64 | 0x0000000C):
        return ARM64_SUBTYPES.get(cpusubtype, "arm64")
    return CPU_TYPE_NAMES.get(cputype, "cpu%d" % cputype)


def _cstring(raw: bytes, start: int) -> str:
    end = raw.find(b"\x00", start)
    if end < 0:
        end = len(raw)
    return raw[start:end].decode("utf-8", "replace")


# --------------------------------------------------------------------------
# load command container
# --------------------------------------------------------------------------


class LoadCommand(object):
    __slots__ = ("cmd", "cmdsize", "offset", "raw")

    def __init__(self, cmd, cmdsize, offset, raw):
        self.cmd = cmd
        self.cmdsize = cmdsize
        self.offset = offset  # slice-relative offset of the command
        self.raw = raw

    def __repr__(self):
        return "LoadCommand(cmd=0x%x, cmdsize=%d)" % (self.cmd, self.cmdsize)


# --------------------------------------------------------------------------
# one Mach-O image (thin binary, or a single slice of a fat file)
# --------------------------------------------------------------------------


class MachOImage(object):
    """A single Mach-O image, addressed inside `data` at `offset`..`offset+size`."""

    def __init__(self, data: bytearray, offset: int, size: int, path: str = "<memory>",
                 fat_entry=None):
        self.data = data
        self.offset = offset
        self.size = size
        self.path = path
        # (file offset of the fat_arch entry, endianness, is_fat64) or None
        self.fat_entry = fat_entry

        self.header_offset = None  # slice-relative offset of mach_header
        self.is_64 = None
        self.endian = "<"
        self.cputype = 0
        self.cpusubtype = 0
        self.filetype = 0
        self.ncmds = 0
        self.sizeofcmds = 0
        self.flags = 0
        self.lcs = []
        self._parse()

    # -- parsing ----------------------------------------------------------

    @property
    def header_size(self) -> int:
        return 32 if self.is_64 else 28

    def _parse(self):
        data = self.data
        off = self.offset
        if off + 4 > len(data):
            raise MachOError("truncated file: no room for a Mach-O magic")
        magic = bytes(data[off : off + 4])
        if magic in (MH_MAGIC_64, MH_MAGIC_32):
            self.endian = "<"
            self.is_64 = magic == MH_MAGIC_64
        elif magic in (MH_CIGAM_64, MH_CIGAM_32):
            self.endian = ">"
            self.is_64 = magic == MH_CIGAM_64
        else:
            raise MachOError(
                "not a Mach-O image at offset %d (magic %s)" % (off, magic.hex())
            )

        if self.is_64:
            fmt = self.endian + "IiiIIIII"
            if off + 32 > len(data):
                raise MachOError("truncated 64-bit Mach-O header")
            (magic_i, cputype, cpusubtype, filetype, ncmds, sizeofcmds, flags, _res) = (
                struct.unpack_from(fmt, data, off)
            )
        else:
            fmt = self.endian + "IiiIIII"
            if off + 28 > len(data):
                raise MachOError("truncated 32-bit Mach-O header")
            (magic_i, cputype, cpusubtype, filetype, ncmds, sizeofcmds, flags) = (
                struct.unpack_from(fmt, data, off)
            )

        self.cputype = cputype
        self.cpusubtype = cpusubtype
        self.filetype = filetype
        self.ncmds = ncmds
        self.sizeofcmds = sizeofcmds
        self.flags = flags
        self.header_offset = 0

        if self.header_size + sizeofcmds > self.size:
            raise MachOError(
                "load commands (%d bytes) overrun the image (%d bytes)"
                % (self.header_size + sizeofcmds, self.size)
            )

        # walk the load commands
        pos = self.header_size
        lcs = []
        for _ in range(ncmds):
            if pos + 8 > self.header_size + sizeofcmds:
                raise MachOError("load command %d runs past sizeofcmds" % (len(lcs) + 1))
            cmd, cmdsize = struct.unpack_from(self.endian + "II", data, off + pos)
            if cmdsize < 8 or pos + cmdsize > self.header_size + sizeofcmds:
                raise MachOError(
                    "load command %d has a bogus cmdsize (%d)" % (len(lcs) + 1, cmdsize)
                )
            raw = bytes(data[off + pos : off + pos + cmdsize])
            lcs.append(LoadCommand(cmd, cmdsize, pos, raw))
            pos += cmdsize
        self.lcs = lcs

    # -- views ------------------------------------------------------------

    @property
    def arch(self) -> str:
        return arch_name(self.cputype, self.cpusubtype)

    @property
    def filetype_name(self) -> str:
        return FILE_TYPES.get(self.filetype, "0x%x" % self.filetype)

    def segments(self):
        """Yield (segname, vmaddr, vmsize, fileoff, filesize, nsects, lc)."""
        for lc in self.lcs:
            if lc.cmd == LC_SEGMENT_64 and self.is_64:
                (segname, vmaddr, vmsize, fileoff, filesize, _maxp, _initp, nsects, _fl) = (
                    struct.unpack_from(self.endian + "16sQQQQiiII", lc.raw, 8)
                )
                yield (
                    _cstring(segname, 0),
                    vmaddr,
                    vmsize,
                    fileoff,
                    filesize,
                    nsects,
                    lc,
                )
            elif lc.cmd == LC_SEGMENT and not self.is_64:
                (segname, vmaddr, vmsize, fileoff, filesize, _maxp, _initp, nsects, _fl) = (
                    struct.unpack_from(self.endian + "16sIIIIiiII", lc.raw, 8)
                )
                yield (
                    _cstring(segname, 0),
                    vmaddr,
                    vmsize,
                    fileoff,
                    filesize,
                    nsects,
                    lc,
                )

    def sections(self):
        """Yield (segname, sectname, addr, size, fileoff)."""
        for segname, _vmaddr, _vmsize, _fileoff, _filesize, nsects, lc in self.segments():
            # sections directly follow the segment_command
            base = 72 if self.is_64 else 56
            for i in range(nsects):
                off = base + i * (80 if self.is_64 else 68)
                if off + (80 if self.is_64 else 68) > len(lc.raw):
                    continue
                if self.is_64:
                    sectname, sseg, addr, size, fileoff, _align_v = struct.unpack_from(
                        self.endian + "16s16sQQII", lc.raw, off
                    )
                else:
                    sectname, sseg, addr, size, fileoff, _align_v = struct.unpack_from(
                        self.endian + "16s16sIIII", lc.raw, off
                    )
                yield (
                    _cstring(sseg, 0),
                    _cstring(sectname, 0),
                    addr,
                    size,
                    fileoff,
                )

    def dylibs(self):
        """Yield (kind, install_name) for every dylib-ish load command."""
        kind_by_cmd = {
            LC_LOAD_DYLIB: "load",
            LC_LOAD_WEAK_DYLIB: "weak",
            LC_REEXPORT_DYLIB: "reexport",
            LC_LAZY_LOAD_DYLIB: "lazy",
            LC_ID_DYLIB: "id",
        }
        for lc in self.lcs:
            if lc.cmd in kind_by_cmd:
                if len(lc.raw) < 24:
                    continue
                name_off = struct.unpack_from(self.endian + "I", lc.raw, 8)[0]
                if 24 <= name_off < len(lc.raw):
                    name = _cstring(lc.raw, name_off)
                elif name_off < len(lc.raw):
                    name = _cstring(lc.raw, 24)
                else:
                    continue
                yield kind_by_cmd[lc.cmd], name

    def rpaths(self):
        out = []
        for lc in self.lcs:
            if lc.cmd == 0x8000001C and len(lc.raw) >= 12:  # LC_RPATH
                name_off = struct.unpack_from(self.endian + "I", lc.raw, 8)[0]
                if 12 <= name_off < len(lc.raw):
                    out.append(_cstring(lc.raw, name_off))
        return out

    def code_signature(self):
        for lc in self.lcs:
            if lc.cmd == LC_CODE_SIGNATURE and len(lc.raw) >= 16:
                dataoff, datasize = struct.unpack_from(self.endian + "II", lc.raw, 8)
                return (dataoff, datasize, lc)
        return None

    def encryption_info(self):
        for lc in self.lcs:
            if lc.cmd == LC_ENCRYPTION_INFO_64 and len(lc.raw) >= 24:
                _cryptoff, _cryptsize, cryptid = struct.unpack_from(
                    self.endian + "III", lc.raw, 8
                )
                return ("LC_ENCRYPTION_INFO_64", cryptid)
            if lc.cmd == LC_ENCRYPTION_INFO and len(lc.raw) >= 20:
                _cryptoff, _cryptsize, cryptid = struct.unpack_from(
                    self.endian + "III", lc.raw, 8
                )
                return ("LC_ENCRYPTION_INFO", cryptid)
        return None

    def find_segment(self, name):
        for segname, vmaddr, vmsize, fileoff, filesize, nsects, lc in self.segments():
            if segname == name:
                return {
                    "name": segname,
                    "vmaddr": vmaddr,
                    "vmsize": vmsize,
                    "fileoff": fileoff,
                    "filesize": filesize,
                    "nsects": nsects,
                    "lc": lc,
                }
        return None

    def header_padding(self) -> int:
        """Bytes between the last load command and the first byte of content."""
        lc_end = self.header_size + self.sizeofcmds
        candidates = []
        for _seg, _sn, _addr, size, fileoff, in self.sections():
            if size == 0:
                continue
            if fileoff >= lc_end:
                candidates.append(fileoff)
        for _segname, _vm, _vsz, fileoff, filesize, _ns, _lc in self.segments():
            if filesize and fileoff >= lc_end:
                candidates.append(fileoff)
        if not candidates:
            return 0
        return min(candidates) - lc_end

    # -- mutation ---------------------------------------------------------

    def _build_dylib_command(self, install_name: str) -> bytes:
        name = install_name.encode("utf-8")
        cmdsize = _align(24 + len(name) + 1, 8)
        body = struct.pack(
            self.endian + "IIIIII",
            LC_LOAD_DYLIB,   # cmd
            cmdsize,         # cmdsize
            24,              # dylib.name.offset (right after the fixed part)
            0,               # timestamp        <- NOT 0xdeadbeef
            0,               # current_version  (0.0.0)
            0,               # compatibility_version
        ) + name
        body += b"\x00" * (cmdsize - len(body))
        if len(body) != cmdsize:  # pragma: no cover - defensive
            raise MachOError("internal error: dylib_command size mismatch")
        return body

    def inject_dylib(self, install_name, *, strip_codesig=True, truncate=True,
                     dry_run=False):
        """Add LC_LOAD_DYLIB(install_name). Returns a report dict."""
        report = {
            "offset": self.offset,
            "size": self.size,
            "arch": self.arch,
            "filetype": self.filetype_name,
            "already": False,
            "added": False,
            "header_padding": self.header_padding(),
            "stripped_codesig": 0,
            "truncated": 0,
            "notes": [],
        }

        if self.endian != "<":
            raise MachOError(
                "%s: big-endian Mach-O is not supported" % self.arch
            )
        if self.filetype not in (0x2, 0x6, 0x8):  # execute / dylib / bundle
            report["notes"].append(
                "filetype is %s; injecting anyway" % self.filetype_name
            )

        existing = {name for _kind, name in self.dylibs()}
        if install_name in existing:
            report["already"] = True
            report["notes"].append("LC_LOAD_DYLIB %s already present" % install_name)
            return report

        new_cmd = self._build_dylib_command(install_name)

        removable = []
        sig = self.code_signature()
        if strip_codesig and sig is not None:
            removable.append(sig[2])

        freed = sum(lc.cmdsize for lc in removable)
        needed = len(new_cmd) - freed
        padding = report["header_padding"]
        if needed > padding:
            raise MachOError(
                "no room for the new load command in %s (%s): need %d bytes of "
                "header padding, only %d available. This binary was linked with a "
                "fully packed load-command area.\n"
                "  Workarounds: (1) inject with TrollFools / Azula / Sideloadly "
                "on the device (they grow the header for you), or (2) rebuild the "
                "IPA from a decrypted dump made with a different tool, or "
                "(3) use `insert_dylib --inplace` on macOS."
                % (os.path.basename(self.path), self.arch, needed, padding)
            )

        if dry_run:
            report["notes"].append(
                "dry-run: would add %s (%d bytes) and free %d bytes"
                % (install_name, len(new_cmd), freed)
            )
            return report

        # 1. rebuild the load-command area without the signature command
        blob = b"".join(lc.raw for lc in self.lcs if lc not in removable)
        blob += new_cmd

        # region the new command(s) may live in: the old load-command area plus
        # the header padding in front of the first section
        region_start = self.offset + self.header_size
        region_end = region_start + self.sizeofcmds + padding
        if len(blob) > region_end - region_start:
            raise MachOError(
                "internal error: rebuilt load commands (%d bytes) do not fit in the "
                "available header space (%d bytes)" % (len(blob), region_end - region_start)
            )

        struct.pack_into(
            self.endian + "II",
            self.data,
            self.offset + 16,
            len(self.lcs) - len(removable) + 1,  # ncmds
            len(blob),                            # sizeofcmds
        )

        self.data[region_start:region_end] = blob + b"\x00" * (region_end - region_start - len(blob))

        report["added"] = True

        # 2. deal with the (now stale) code signature payload
        if sig is not None and strip_codesig:
            dataoff, datasize = sig[0], sig[1]
            report["stripped_codesig"] = datasize
            self._shrink_linkedit_after_signature(dataoff, datasize, truncate, report)

        self._refresh_views()
        return report

    def _shrink_linkedit_after_signature(self, dataoff, datasize, truncate, report):
        """Remove the dead signature bytes from __LINKEDIT bookkeeping.

        Only truncates when we can prove nothing else lives past `dataoff` and
        when this image ends the file (never inside a fat container).
        """
        linkedit = self.find_segment("__LINKEDIT")
        if linkedit is None:
            return

        can_truncate = truncate and (self.offset + self.size) == len(self.data)
        if can_truncate:
            # every other __LINKEDIT-ish payload must sit before the signature
            for lc in self.lcs:
                if lc.cmd in LINKEDIT_DATA_COMMANDS and lc.cmd != LC_CODE_SIGNATURE:
                    if len(lc.raw) >= 16:
                        off, sz = struct.unpack_from(self.endian + "II", lc.raw, 8)
                        if sz and off + sz > dataoff:
                            can_truncate = False
                            report["notes"].append(
                                "kept the dead signature bytes: %s payload overlaps "
                                "the signature" % hex(lc.cmd)
                            )
                            break
        new_filesize = dataoff - linkedit["fileoff"]
        if new_filesize < 0:
            return

        if can_truncate and self._truncate_to(dataoff):
            report["truncated"] = datasize

        # __LINKEDIT filesize shrinks either way; vmsize is left alone (it is a
        # page-rounded mapping size and shrinking it is never required).
        lc = linkedit["lc"]
        struct.pack_into(self.endian + "Q", self.data, self.offset + lc.offset + 48, new_filesize)

    def _refresh_views(self):
        """Re-parse in place after a mutation (cheap, keeps offsets correct)."""
        self.__init__(self.data, self.offset, self.size, self.path, self.fat_entry)

    # -- truncation -------------------------------------------------------

    def _truncate_to(self, new_size):
        """Drop everything after `new_size` bytes of this image.

        Only safe when this image ends the file; when it is the last slice of a
        fat container the fat header's size field is updated too (otherwise the
        container would describe a slice that is no longer there).
        """
        if self.offset + self.size != len(self.data):
            return False
        del self.data[self.offset + new_size:]
        self.size = new_size
        if self.fat_entry is not None:
            entry_off, endian, is_fat64 = self.fat_entry
            field_off = entry_off + (16 if is_fat64 else 12)
            struct.pack_into(endian + ("Q" if is_fat64 else "I"), self.data,
                             field_off, new_size)
        return True

    # -- report -----------------------------------------------------------

    def describe(self):
        sig = self.code_signature()
        enc = self.encryption_info()
        return {
            "arch": self.arch,
            "filetype": self.filetype_name,
            "ncmds": self.ncmds,
            "sizeofcmds": self.sizeofcmds,
            "header_padding": self.header_padding(),
            "dylibs": [name for _kind, name in self.dylibs()],
            "id": [name for kind, name in self.dylibs() if kind == "id"],
            "rpaths": self.rpaths(),
            "code_signature": None if sig is None else {"offset": sig[0], "size": sig[1]},
            "encryption": None if enc is None else {"command": enc[0], "cryptid": enc[1]},
            "segments": [
                {
                    "name": s[0],
                    "vmaddr": s[1],
                    "vmsize": s[2],
                    "fileoff": s[3],
                    "filesize": s[4],
                }
                for s in self.segments()
            ],
        }


# --------------------------------------------------------------------------
# file level operations
# --------------------------------------------------------------------------


def _read_file(path):
    if not os.path.exists(path):
        raise MachOError("file not found: %s" % path)
    if os.path.isdir(path):
        raise MachOError("%s is a directory (pass the Mach-O executable)" % path)
    with open(path, "rb") as fh:
        return bytearray(fh.read())


def _fat_slices(data):
    """Return [(offset, size, cputype, cpusubtype, is_64)] for a fat file."""
    magic = bytes(data[0:4])
    if magic in (FAT_MAGIC, FAT_CIGAM):
        endian = ">" if magic == FAT_MAGIC else "<"
        (narch,) = struct.unpack_from(endian + "I", data, 4)
        entry = 20
        is_64 = False
    elif magic == FAT_MAGIC_64:
        endian = ">"
        (narch,) = struct.unpack_from(">I", data, 4)
        entry = 32
        is_64 = True
    else:
        return None

    slices = []
    pos = 8
    for _ in range(narch):
        if pos + (entry) > len(data):
            raise MachOError("truncated fat header")
        if is_64:
            cputype, cpusubtype = struct.unpack_from(endian + "ii", data, pos)
            offset, size = struct.unpack_from(endian + "QQ", data, pos + 8)
        else:
            cputype, cpusubtype, offset, size = struct.unpack_from(
                endian + "iiII", data, pos
            )
        if offset + size > len(data):
            raise MachOError("fat slice %d runs past end of file" % len(slices))
        slices.append((offset, size, cputype, cpusubtype, is_64, pos))
        pos += entry
    return slices


def _fat_endian(data):
    return ">" if bytes(data[0:4]) in (FAT_MAGIC, FAT_MAGIC_64) else "<"


def is_macho(data, offset=0):
    return bytes(data[offset : offset + 4]) in (
        MH_MAGIC_32, MH_MAGIC_64, MH_CIGAM_32, MH_CIGAM_64
    )


def images_for_file(path):
    """Load `path` and return (bytearray, [MachOImage, ...], container_kind)."""
    data = _read_file(path)
    slices = _fat_slices(data)
    if slices is None:
        if not is_macho(data, 0):
            raise MachOError(
                "%s is not a Mach-O file (first bytes: %s). If you passed an IPA "
                "or a zip, use inject.sh / tools/inject_ipa.py instead."
                % (path, bytes(data[:8]).hex())
            )
        return data, [MachOImage(data, 0, len(data), path)], "thin"

    images = []
    for offset, size, _cpu, _sub, is_fat64, entry_off in slices:
        if not is_macho(data, offset):
            continue
        images.append(
            MachOImage(data, offset, size, path,
                       fat_entry=(entry_off, ">" if is_fat64 else _fat_endian(data),
                                  is_fat64))
        )
    if not images:
        raise MachOError("fat file has no usable Mach-O slices: %s" % path)
    return data, images, "fat"


def inspect_file(path):
    data, images, kind = images_for_file(path)
    return {
        "path": path,
        "size": len(data),
        "container": kind,
        "slices": [img.describe() for img in images],
    }


def inject_dylib(path, install_name=None, *, strip_codesig=True, truncate=True,
                 arch=None, dry_run=False, backup=False, in_place=True):
    """Patch `path` so that it loads `install_name` at startup.

    Returns a report dict. Writes the file unless `dry_run` (or `in_place=False`,
    in which case the caller gets the patched bytes back via the report).
    """
    if install_name is None:
        raise MachOError("an install name (e.g. @executable_path/libX.dylib) is required")

    data, images, _kind = images_for_file(path)
    wanted = arch.lower() if arch else None
    chosen = [img for img in images if wanted is None or img.arch.lower() == wanted]
    if not chosen:
        raise MachOError(
            "%s has no %s slice (available: %s)"
            % (path, arch, ", ".join(sorted({i.arch for i in images})) or "none")
        )

    reports = []
    for img in chosen:
        reports.append(
            img.inject_dylib(
                install_name,
                strip_codesig=strip_codesig,
                truncate=truncate,
                dry_run=dry_run,
            )
        )

    changed = any(r["added"] for r in reports) and not dry_run
    if changed and in_place:
        if backup:
            shutil.copy2(path, path + ".bak")
        tmp = path + ".macho-inject.tmp"
        with open(tmp, "wb") as fh:
            fh.write(data)
        os.replace(tmp, path)

    return {
        "path": path,
        "install_name": install_name,
        "slices": reports,
        "changed": bool(changed),
        "bytes": bytes(data) if not in_place else None,
    }


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------


def _cmd_verify(args):
    try:
        info = inspect_file(args.file)
    except MachOError as exc:
        print("[!] %s" % exc)
        return 1

    print("[*] %s (%d bytes, %s)" % (info["path"], info["size"], info["container"]))
    rc = 0
    for sl in info["slices"]:
        print("")
        print("  arch            : %s" % sl["arch"])
        print("  filetype        : %s" % sl["filetype"])
        print("  load commands   : %d (%d bytes, %d bytes header padding)"
              % (sl["ncmds"], sl["sizeofcmds"], sl["header_padding"]))
        print("  rpaths          : %s" % (", ".join(sl["rpaths"]) or "-"))
        if sl["code_signature"]:
            print("  code signature  : offset %#x, %d bytes"
                  % (sl["code_signature"]["offset"], sl["code_signature"]["size"]))
        else:
            print("  code signature  : none")
        enc = sl["encryption"]
        if enc and enc["cryptid"]:
            print("  encryption      : %s cryptid=%d  <-- STILL ENCRYPTED"
                  % (enc["command"], enc["cryptid"]))
            rc = 2
        elif enc:
            print("  encryption      : %s cryptid=0 (decrypted)" % enc["command"])
        else:
            print("  encryption      : no LC_ENCRYPTION_INFO (not an app binary?)")
        print("  dylibs (%d):" % len(sl["dylibs"]))
        for name in sl["dylibs"]:
            print("    %s" % name)

    if rc == 2:
        print("")
        print("[!] This binary is FairPlay-encrypted, i.e. it is a copy of the "
              "App Store IPA.\n"
              "    Patching it will not work: use a decrypted dump (TrollStore -> "
              "AppDump)\n"
              "    or inject on-device with TrollFools / Azula.")
    return rc


def _cmd_inject(args):
    install_name = args.install_name
    if install_name is None:
        install_name = "@executable_path/%s" % os.path.basename(args.dylib)
    try:
        report = inject_dylib(
            args.file,
            install_name,
            strip_codesig=not args.keep_codesig,
            truncate=not args.no_truncate,
            arch=args.arch,
            dry_run=args.dry_run,
            backup=args.backup,
        )
    except MachOError as exc:
        print("[!] %s" % exc)
        return 1

    for sl in report["slices"]:
        state = "already injected" if sl["already"] else "injected"
        print("[*] %s %s: %s" % (sl["arch"], sl["filetype"], state))
        if sl["stripped_codesig"]:
            print("    removed stale code signature (%d bytes)" % sl["stripped_codesig"])
        for note in sl["notes"]:
            print("    note: %s" % note)

    if args.dry_run:
        print("[*] dry run - nothing written")
    elif report["changed"]:
        print("[+] %s now loads %s" % (args.file, install_name))
        if not args.keep_codesig:
            print("[*] Re-sign the bundle before installing (Sideloadly/ESign/"
                  "TrollStore/ldid do this automatically).")
    else:
        print("[*] nothing to do")
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="macho_inject.py",
        description="Inspect and inject LC_LOAD_DYLIB commands into Mach-O binaries.",
    )
    sub = parser.add_subparsers(dest="command")

    p_verify = sub.add_parser("verify", help="print dylibs / rpaths / encryption state")
    p_verify.add_argument("file")
    p_verify.set_defaults(func=_cmd_verify)

    p_inject = sub.add_parser("inject", help="add an LC_LOAD_DYLIB load command")
    p_inject.add_argument("file", help="Mach-O executable (app binary or dylib)")
    p_inject.add_argument("dylib", help="dylib path on disk (used for the name)")
    p_inject.add_argument("--install-name", default=None,
                          help="load command path (default @executable_path/<name>)")
    p_inject.add_argument("--arch", default=None, help="only patch this slice")
    p_inject.add_argument("--keep-codesig", action="store_true",
                          help="keep LC_CODE_SIGNATURE (it will be invalid!)")
    p_inject.add_argument("--no-truncate", action="store_true",
                          help="keep the dead signature bytes at the end of file")
    p_inject.add_argument("--dry-run", action="store_true")
    p_inject.add_argument("--backup", action="store_true")
    p_inject.set_defaults(func=_cmd_inject)

    args = parser.parse_args(argv)
    if not getattr(args, "func", None):
        parser.print_help()
        return 2
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
