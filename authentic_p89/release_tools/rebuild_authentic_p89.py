#!/usr/bin/env python3
"""Rebuild the *exact*, previously compiled authentic restricted P89 APK.

Uses the public v0.2 APK solely as a source of unchanged Godot/Android binary
streams. Every other byte comes from an audited P89 patch. The resulting APK
must match the original signed P89 SHA-256, or the process aborts.

This is release packaging, not a substitute game implementation or compilation.
"""
import argparse
import base64
import hashlib
import json
import lzma
import struct
import zipfile
from pathlib import Path

EXPECTED_BASE_SHA256 = "2579cf4aa824f9cc1b4338374cbaad10abbeb160dd3d83ef4f8e88056e4ec27c"
EXPECTED_PATCH_SHA256 = "bf796a4d09b6854974fd2a3de47c107909ff29fcf155f8cf65cf4961ccc58038"
EXPECTED_TARGET_SHA256 = "022076a4fd1058aafa45a3a11be32b61e6604b8a9eec11b5b811d728fea9ba02"
PART_COUNT = 85

def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def compressed_zip_members(data: bytes) -> dict[str, bytes]:
    from io import BytesIO
    result: dict[str, bytes] = {}
    with zipfile.ZipFile(BytesIO(data)) as archive:
        assert archive.testzip() is None, "Invalid base APK ZIP entries"
        for item in archive.infolist():
            offset = item.header_offset
            if data[offset : offset + 4] != b"PK\x03\x04":
                raise ValueError("Invalid member header: " + item.filename)
            name_size, extra_size = struct.unpack_from("<HH", data, offset + 26)
            cstart = offset + 30 + name_size + extra_size
            result[item.filename] = data[cstart : cstart + item.compress_size]
    return result

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", type=Path, required=True)
    parser.add_argument("--parts", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    base = args.base.read_bytes()
    if sha(base) != EXPECTED_BASE_SHA256:
        raise SystemExit("Base public v0.2 APK SHA-256 mismatch")
    base_members = compressed_zip_members(base)
    strings = []
    for n in range(PART_COUNT):
        part = args.parts / f"part{n:03d}.b64"
        if not part.exists():
            raise SystemExit(f"Missing patch part {n:03d}")
        s = part.read_text(encoding="ascii").strip()
        if not s or len(s) > 64000 or (n < PART_COUNT - 1 and len(s) != 64000):
            raise SystemExit(f"Invalid patch part size {n:03d}")
        strings.append(s)
    compressed_patch = base64.b64decode("".join(strings), validate=True)
    if sha(compressed_patch) != EXPECTED_PATCH_SHA256:
        raise SystemExit("P89 patch checksum mismatch")
    patch = json.loads(lzma.decompress(compressed_patch))
    if patch.get("format") != "VEYRA-RAW-APK-DIFF-2" or patch.get("target_sha256") != EXPECTED_TARGET_SHA256 or patch.get("base_sha256") != EXPECTED_BASE_SHA256:
        raise SystemExit("P89 patch manifest invalid")
    payload = base64.b85decode(patch["payload"].encode("ascii"))
    position = 0
    result = bytearray()
    for row in patch["entries"]:
        if row[0] == 0:
            _, name, header_size, post_size = row
            if name not in base_members:
                raise SystemExit(f"Missing base member: {name}")
            result.extend(payload[position : position + header_size]); position += header_size
            result.extend(base_members[name])
            result.extend(payload[position : position + post_size]); position += post_size
        elif row[0] == 1:
            _, name, header_size, compressed_size, post_size = row
            length = header_size + compressed_size + post_size
            result.extend(payload[position : position + length]); position += length
        else:
            raise SystemExit("Unexpected patch record")
    if position + patch["tail_size"] != len(payload):
        raise SystemExit("Patch payload length mismatch")
    result.extend(payload[position:])
    if sha(result) != EXPECTED_TARGET_SHA256:
        raise SystemExit("Authentic P89 signed APK SHA-256 mismatch; refusing to publish")
    with zipfile.ZipFile(__import__("io").BytesIO(result)) as z:
        if z.testzip() is not None:
            raise SystemExit("Reconstructed APK ZIP integrity failed")
    if args.out.exists():
        raise SystemExit("Output already exists: will not overwrite an existing APK")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_bytes(result)
    print("Authentic P89 signed Android APK verified:", args.out)
    print("Size:", len(result), "SHA-256:", sha(result))

if __name__ == "__main__":
    main()