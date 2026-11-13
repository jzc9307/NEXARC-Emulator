#!/usr/bin/env python3
"""Assemble ARM64 code and wrap it in a tiny, unencrypted Switch NRO.

Clang produces a Mach-O object on macOS. We extract only its __text bytes;
there are no external symbols or relocations in this self-contained program.
"""
from pathlib import Path
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="nexarc-asm-") as temp:
    obj = Path(temp) / "guest.o"
    subprocess.run(["xcrun", "clang", "-target", "arm64-apple-macos14", "-c", str(ROOT/"Homebrew/first-light.s"), "-o", str(obj)], check=True)
    data = obj.read_bytes()
    magic, _, _, _, ncmds, _, _, _ = struct.unpack_from("<8I", data)
    assert magic == 0xFEEDFACF
    cursor = 32
    code = None
    for _ in range(ncmds):
        cmd, size = struct.unpack_from("<II", data, cursor)
        if cmd == 0x19:  # LC_SEGMENT_64
            count = struct.unpack_from("<I", data, cursor+64)[0]
            for i in range(count):
                section = cursor+72+i*80
                if data[section:section+16].rstrip(b"\0") == b"__text":
                    length = struct.unpack_from("<Q", data, section+40)[0]
                    offset, _, _, nreloc = struct.unpack_from("<IIII", data, section+48)
                    assert nreloc == 0, "Guest program must be position independent"
                    code = data[offset:offset+length]
        cursor += size
    assert code
    nro = bytearray(0x3000)
    # Branch over the 0x80-byte header to our first instruction.
    struct.pack_into("<I", nro, 0, 0x14000020)
    nro[0x10:0x14] = b"NRO0"
    struct.pack_into("<III", nro, 0x14, 0, len(nro), 0)
    # Text, read-only data, writable data; one page each. Plus a BSS page.
    struct.pack_into("<7I", nro, 0x20, 0, 0x1000, 0x1000, 0x1000, 0x2000, 0x1000, 0x1000)
    assert len(code) < 0xF80
    nro[0x80:0x80+len(code)] = code
    target = ROOT/"Resources/Homebrew"
    target.mkdir(parents=True, exist_ok=True)
    # An empty asset table makes the optional icon/NACP/RomFS explicitly absent.
    # Some core versions expect a readable table even for a code-only NRO.
    nro.extend(b"ASET" + struct.pack("<I6Q", 0, 0, 0, 0, 0, 0, 0))
    (target/"first-light.nro").write_bytes(nro)
    print(f"Built First Light: {len(code)} bytes of ARM64, {len(nro)} bytes NRO")
