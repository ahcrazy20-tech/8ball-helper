#!/usr/bin/env python3
"""
machofactory.py - build small but realistic Mach-O images for the test suite.

Everything here is hand-assembled with `struct`, so the tests need no Xcode, no
macOS and no SDK.  The generated files are structurally complete enough that
LIEF (when installed) parses them, which gives an independent second opinion on
whatever `tools/macho_inject.py` writes.
"""

from __future__ import annotations

import struct

# ---- basic constants ------------------------------------------------------

MH_MAGIC_64 = 0xFEEDFACF
FAT_MAGIC = 0xCAFEBABE
FAT_MAGIC_64 = 0xCAFEBABF

CPU_TYPE_ARM64 = 0x0100000C
CPU_TYPE_X86_64 = 0x01000007
CPU_SUBTYPE_ARM64_ALL = 0
CPU_SUBTYPE_ARM64E = 2

MH_EXECUTE = 0x2
MH_DYLIB = 0x6

LC_SEGMENT_64 = 0x19
LC_SYMTAB = 0x02
LC_DYSYMTAB = 0x0B
LC_LOAD_DYLIB = 0x0C
LC_ID_DYLIB = 0x0D
LC_LOAD_DYLINKER = 0x0E
LC_UUID = 0x1B
LC_CODE_SIGNATURE = 0x1D
LC_ENCRYPTION_INFO_64 = 0x2C
LC_DYLD_INFO_ONLY = 0x80000022
LC_FUNCTION_STARTS = 0x26
LC_MAIN = 0x80000028
LC_DATA_IN_CODE = 0x29
LC_SOURCE_VERSION = 0x2A
LC_BUILD_VERSION = 0x32
LC_DYLD_EXPORTS_TRIE = 0x80000033
LC_DYLD_CHAINED_FIXUPS = 0x80000034
LC_RPATH = 0x8000001C

PLATFORM_IOS = 2
PAGE = 0x4000


def align(value, alignment):
    return (value + alignment - 1) & ~(alignment - 1)


def _pad_to(data, size):
    return data + b"\x00" * (size - len(data))


# ---- load command builders ------------------------------------------------


def segment64(segname, vmaddr, vmsize, fileoff, filesize, sections=(),
              maxprot=7, initprot=5, flags=0):
    body = struct.pack(
        "<16sQQQQiiII",
        segname.encode().ljust(16, b"\x00"),
        vmaddr,
        vmsize,
        fileoff,
        filesize,
        maxprot,
        initprot,
        len(sections),
        flags,
    )
    for (sectname, ssegname, addr, size, offset, align_v, reloff, nreloc, sflags) in sections:
        body += struct.pack(
            "<16s16sQQIIIIIIII",
            sectname.encode().ljust(16, b"\x00"),
            ssegname.encode().ljust(16, b"\x00"),
            addr,
            size,
            offset,
            align_v,
            reloff,
            nreloc,
            sflags,
            0,
            0,
            0,
        )
    cmdsize = 8 + len(body)
    return struct.pack("<II", LC_SEGMENT_64, cmdsize) + body


def dylib_command(cmd, name, timestamp=0, current=0, compat=0):
    raw_name = name.encode() + b"\x00"
    cmdsize = align(24 + len(raw_name), 8)
    body = struct.pack("<IIIIII", cmd, cmdsize, 24, timestamp, current, compat) + raw_name
    return _pad_to(body, cmdsize)


def rpath_command(path):
    raw = path.encode() + b"\x00"
    cmdsize = align(12 + len(raw), 8)
    return _pad_to(struct.pack("<III", LC_RPATH, cmdsize, 12) + raw, cmdsize)


def linkedit_data(cmd, dataoff, datasize):
    return struct.pack("<IIII", cmd, 16, dataoff, datasize)


def symtab_command(symoff, nsyms, stroff, strsize):
    return struct.pack("<IIIIII", LC_SYMTAB, 24, symoff, nsyms, stroff, strsize)


def dysymtab_command(indirectsymoff, nindirectsyms):
    return struct.pack(
        "<II" + "I" * 18,
        LC_DYSYMTAB, 80,
        0, 0,            # ilocalsym, nlocalsym
        0, 0,            # iextdefsym, nextdefsym
        0, 0,            # iundefsym, nundefsym
        0, 0,            # tocoff, ntoc
        0, 0,            # modtaboff, nmodtab
        0, 0,            # extrefsymoff, nextrefsyms
        indirectsymoff, nindirectsyms,
        0, 0, 0, 0,      # extreloff, nextrel, locreloff, nlocrel
    )


def dyld_info_only():
    return struct.pack(
        "<II" + "I" * 10,
        LC_DYLD_INFO_ONLY, 48,
        0x10000, 0x10,   # rebase
        0x10010, 0x10,   # bind
        0x10020, 0x00,   # weak bind
        0x10020, 0x08,   # lazy bind
        0x10028, 0x18,   # export
    )


def uuid_command(seed="A"):
    return struct.pack("<II", LC_UUID, 24) + (seed.encode() * 16)[:16]


def build_version_command(mintool=1):
    tool = struct.pack("<II", 3, 0x0F0000)  # TOOL_LD, 15.0
    return struct.pack("<IIIIII", LC_BUILD_VERSION, 24 + len(tool), PLATFORM_IOS,
                       0x0F0000, 0x0F0400, 1) + tool


def source_version_command():
    return struct.pack("<IIQ", LC_SOURCE_VERSION, 16, 0)


def main_command(entryoff):
    return struct.pack("<IIQQ", LC_MAIN, 24, entryoff, 0)


def encryption_info_64(cryptid=1, cryptoff=0x4000, cryptsize=0x8000):
    return struct.pack("<IIIIII", LC_ENCRYPTION_INFO_64, 24, cryptoff, cryptsize,
                       cryptid, 0)


def load_dylinker(path="15.0.0"):
    raw = ("/usr/lib/dyld" + path).encode() + b"\x00"
    cmdsize = align(12 + len(raw), 8)
    return _pad_to(struct.pack("<III", LC_LOAD_DYLINKER, cmdsize, 12) + raw, cmdsize)


# ---- code signature blob --------------------------------------------------


def code_signature_blob(identifier=b"com.test.app", code_limit=0x13800, size=0x800):
    """A structurally valid ad-hoc SuperBlob (all fields big-endian)."""
    cd_ident = identifier + b"\x00"
    cd_header_size = 44  # CodeDirectory v0x20400 fixed part
    hash_offset = align(cd_header_size, 8)
    ident_offset = hash_offset + 32  # 1 code slot hash (SHA-256)
    cd_len = align(ident_offset + len(cd_ident), 16)

    cd = struct.pack(
        ">IIIIIIIII" "BBBB" "I",
        0xFADE0C02, cd_len, 0x20400, 0,   # magic, length, version, flags
        hash_offset, ident_offset, 0, 1,  # hashOffset, identOffset, nSpecial, nCode
        code_limit,                       # codeLimit
        32, 2, 0, 12,                     # hashSize, hashType, platform, pageSize
        0,                                # spare2
    )
    cd += b"\x00" * (hash_offset - len(cd))          # padding to hashOffset
    cd += b"\x11" * 32                               # one code-slot hash
    cd = _pad_to(cd, ident_offset)
    cd += cd_ident
    cd = _pad_to(cd, cd_len)

    index_entry = struct.pack(">II", 0, 20)          # CS_SLOT / CSSLOT_CODEDIRECTORY
    blob = struct.pack(">III", 0xFADE0CC0, 20 + len(index_entry) + len(cd), 1)
    blob += index_entry + cd
    blob = _pad_to(blob, size)
    return blob


# ---- whole images ---------------------------------------------------------


def _arch_consts(arch):
    if arch == "arm64":
        return CPU_TYPE_ARM64, CPU_SUBTYPE_ARM64_ALL
    if arch == "arm64e":
        return CPU_TYPE_ARM64, CPU_SUBTYPE_ARM64E
    if arch == "x86_64":
        return CPU_TYPE_X86_64, 3
    raise ValueError("unsupported test arch: %r" % arch)


def build_app_binary(arch="arm64", *, text_offset=None, code_signature=True,
                     encrypted=False, dylibs=None, rpath="@executable_path/Frameworks",
                     chained_fixups=False):
    """Build a small but realistic arm64 iOS app executable.

    `text_offset="tight"` produces a binary whose first section starts exactly
    where the load commands end, i.e. zero header padding.
    """
    cputype, cpusubtype = _arch_consts(arch)
    if dylibs is None:
        dylibs = [
            "/System/Library/Frameworks/UIKit.framework/UIKit",
            "/System/Library/Frameworks/Foundation.framework/Foundation",
            "/usr/lib/libobjc.A.dylib",
        ]

    text_data_off = 0x4000
    cstring_off = text_data_off + 0x2400
    text_end = cstring_off + 0x200
    text_filesize = align(text_end, PAGE)
    data_const_off = text_filesize
    data_off = data_const_off + PAGE
    linkedit_off = data_off + PAGE
    linkedit_filesize = PAGE
    file_size = linkedit_off + linkedit_filesize

    sig_off = 0x13800
    sig_size = file_size - sig_off
    base_vmaddr = 0x100000000

    symoff, nsyms, stroff, strsize = 0x10100, 2, 0x10120, 0x20
    indirectsymoff = 0x10140
    function_starts = (0x10150, 0x8)
    data_in_code = (0x10158, 0x8)
    chained = (0x10160, 0x40)
    exports = (0x10190, 0x20)

    def build_lcs(text_off):
        lcs = [
            segment64("__PAGEZERO", 0, 0x100000000, 0, 0),
            segment64(
                "__TEXT", base_vmaddr, text_filesize, 0, text_filesize,
                sections=[
                    ("__text", "__TEXT", base_vmaddr + text_off, 0x2400, text_off, 2, 0, 0, 0x80000400),
                    ("__cstring", "__TEXT", base_vmaddr + cstring_off, 0x200, cstring_off, 0, 0, 0, 0x2),
                ],
            ),
            segment64(
                "__DATA_CONST", base_vmaddr + data_const_off, PAGE, data_const_off, PAGE,
                maxprot=3, initprot=3,
                sections=[("__got", "__DATA_CONST", base_vmaddr + data_const_off, 0x200,
                           data_const_off, 3, 0, 0, 0x6)],
            ),
            segment64(
                "__DATA", base_vmaddr + data_off, PAGE, data_off, PAGE,
                maxprot=3, initprot=3,
                sections=[("__data", "__DATA", base_vmaddr + data_off, 0x400,
                           data_off, 3, 0, 0, 0x0)],
            ),
            segment64("__LINKEDIT", base_vmaddr + linkedit_off, linkedit_filesize,
                      linkedit_off, linkedit_filesize, maxprot=1, initprot=1),
            dyld_info_only(),
            symtab_command(symoff, nsyms, stroff, strsize),
            dysymtab_command(indirectsymoff, 0),
            uuid_command("B"),
            build_version_command(),
            source_version_command(),
            main_command(text_off + 0x100),
            linkedit_data(LC_FUNCTION_STARTS, *function_starts),
            linkedit_data(LC_DATA_IN_CODE, *data_in_code),
        ]
        if chained_fixups:
            lcs.append(linkedit_data(LC_DYLD_CHAINED_FIXUPS, *chained))
            lcs.append(linkedit_data(LC_DYLD_EXPORTS_TRIE, *exports))
        lcs.append(load_dylinker())
        for name in dylibs:
            lcs.append(dylib_command(LC_LOAD_DYLIB, name, current=0x0F0000))
        if rpath:
            lcs.append(rpath_command(rpath))
        if encrypted:
            lcs.append(encryption_info_64(cryptid=1))
        if code_signature:
            lcs.append(linkedit_data(LC_CODE_SIGNATURE, sig_off, sig_size))
        return b"".join(lcs)

    probe_off = 0x4000
    probe = build_lcs(probe_off)
    header_end = 32 + len(probe)

    if text_offset == "tight":
        text_off = header_end
    elif isinstance(text_offset, int):
        text_off = text_offset
    else:
        text_off = probe_off
    if text_off < header_end:
        text_off = header_end

    lcs = build_lcs(text_off)
    sizeofcmds = len(lcs)
    ncmds = _count_commands(lcs)

    header = struct.pack("<IiiIIIII", MH_MAGIC_64, cputype, cpusubtype, MH_EXECUTE,
                         ncmds, sizeofcmds, 0x00200085, 0)

    out = bytearray(header + lcs)
    out = bytearray(_pad_to(bytes(out), text_off))
    out[text_off:text_off + 0x2400] = bytes([0x90]) * 0x2400       # "code"
    out = bytearray(_pad_to(bytes(out), cstring_off))
    out[cstring_off:cstring_off + 0x200] = b"hello from the test binary".ljust(0x200, b"\x00")
    out = bytearray(_pad_to(bytes(out), data_const_off))
    out[data_const_off:data_const_off + 0x200] = b"\x07" * 0x200
    out = bytearray(_pad_to(bytes(out), data_off))
    out[data_off:data_off + 0x400] = b"\x08" * 0x400
    out = bytearray(_pad_to(bytes(out), linkedit_off))
    # minimal __LINKEDIT payload
    payload = bytearray(linkedit_filesize)
    payload[0x00:0x10] = b"\x11" * 0x10
    payload[0x10:0x20] = b"\x22" * 0x10
    payload[0x20:0x28] = b"\x33" * 0x08
    payload[0x28:0x40] = b"\x44" * 0x18
    payload[0x100:symoff - linkedit_off + 32] = b"\x55" * 32
    payload[stroff - linkedit_off:stroff - linkedit_off + 0x20] = b"\x00" * 0x20
    if chained_fixups:
        # dyld_chained_fixups_header (version 0) + empty starts-in-image
        # seg_count must match the number of segments in the image
        seg_count = 5  # __PAGEZERO, __TEXT, __DATA_CONST, __DATA, __LINKEDIT
        fixups = struct.pack("<IIIIIII", 0, 0x20, 0, 0, 0, 0, 0)
        fixups += struct.pack("<I", seg_count)
        fixups += struct.pack("<%dI" % seg_count, *([0] * seg_count))
        off = chained[0] - linkedit_off
        payload[off:off + len(fixups)] = fixups
    if code_signature:
        blob = code_signature_blob(code_limit=sig_off, size=sig_size)
        payload[sig_off - linkedit_off:sig_off - linkedit_off + len(blob)] = blob
    out = bytearray(_pad_to(bytes(out), linkedit_off))
    out = bytearray(_pad_to(bytes(out) + bytes(payload), file_size))
    return bytes(out[:file_size])


def build_dylib(install_name="libUnityGraphics.dylib", arch="arm64", code_signature=True):
    cputype, cpusubtype = _arch_consts(arch)
    text_off = 0x4000
    text_size = 0x400
    linkedit_off = 0x8000
    linkedit_size = PAGE
    file_size = linkedit_off + linkedit_size
    sig_off = 0xB000
    sig_size = file_size - sig_off

    def build_lcs():
        lcs = [
            segment64("__TEXT", 0, text_off + text_size, 0, text_off + text_size,
                      sections=[("__text", "__TEXT", text_off, text_size, text_off, 2, 0, 0, 0x80000400)]),
            segment64("__LINKEDIT", align(text_off + text_size, PAGE), linkedit_size,
                      linkedit_off, linkedit_size, maxprot=1, initprot=1),
            dylib_command(LC_ID_DYLIB, install_name, current=0x00010000),
            dylib_command(LC_LOAD_DYLIB, "/usr/lib/libSystem.B.dylib", current=0x0F0000),
            build_version_command(),
            uuid_command("C"),
        ]
        if code_signature:
            lcs.append(linkedit_data(LC_CODE_SIGNATURE, sig_off, sig_size))
        return b"".join(lcs)

    lcs = build_lcs()
    header = struct.pack("<IiiIIIII", MH_MAGIC_64, cputype, cpusubtype, MH_DYLIB,
                         _count_commands(lcs), len(lcs), 0x00100085, 0)
    out = bytearray(_pad_to(header + lcs, text_off))
    out[text_off:text_off + text_size] = bytes([0xC0]) * text_size
    out = bytearray(_pad_to(bytes(out), linkedit_off))
    payload = bytearray(linkedit_size)
    if code_signature:
        blob = code_signature_blob(b"libtest.dylib", code_limit=sig_off, size=sig_size)
        payload[sig_off - linkedit_off:sig_off - linkedit_off + len(blob)] = blob
    out = bytearray(_pad_to(bytes(out) + bytes(payload), file_size))
    return bytes(out[:file_size])


def build_fat(images, *, fat64=False, trailing_pad=True):
    """images: list of (bytes, cputype, cpusubtype)."""
    if fat64:
        magic = FAT_MAGIC_64
        entry_size = 32
        header_size = 8 + entry_size * len(images)
    else:
        magic = FAT_MAGIC
        entry_size = 20
        header_size = 8 + entry_size * len(images)

    offset = align(header_size, PAGE)
    header = struct.pack(">II", magic, len(images))
    body = b""
    for blob, cputype, cpusubtype in images:
        if fat64:
            header += struct.pack(">iiQQII", cputype, cpusubtype, offset, len(blob), 14, 0)
        else:
            header += struct.pack(">iiIII", cputype, cpusubtype, offset, len(blob), 14)
        body += b"\x00" * (offset - (header_size + len(body))) + blob
        offset += align(len(blob), PAGE) if trailing_pad else len(blob)

    return header + body


def _count_commands(lcs):
    """Count the load commands inside a blob of concatenated commands."""
    count = 0
    pos = 0
    while pos < len(lcs):
        cmdsize = struct.unpack_from("<I", lcs, pos + 4)[0]
        pos += cmdsize
        count += 1
    return count


def build_big_endian_64():
    """A 64-bit Mach-O in big-endian byte order (must be rejected)."""
    header = bytearray(struct.pack(">IiiIIIII", MH_MAGIC_64, CPU_TYPE_ARM64,
                                   CPU_SUBTYPE_ARM64_ALL, MH_EXECUTE, 0, 0, 0, 0))
    header[0:4] = b"\xfe\xed\xfa\xcf"
    return bytes(header) + b"\x00" * 0x1000
