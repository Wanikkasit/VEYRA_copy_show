#!/usr/bin/env python3
"""Restore the verified P92 Android APK from original PRIVATE GitHub build parts.
No game source code is created or modified. The result is the FULL original APK,
NOT a limited public release. Requires authenticated GitHub CLI with repo access.
"""
import base64
import hashlib
import json
import shutil
import subprocess
from pathlib import Path

REPOSITORY = "Wanikkasit/Project-VEYRA"
REF = "p92-verified-build-38508505390"
COMMIT = "4c0203798cbbb145e8795c1e108fea5823614223"

def retrieve(path: str) -> bytes:
    value = subprocess.check_output(
        ["gh", "api", f"repos/{REPOSITORY}/contents/{path}?ref={REF}"],
        stderr=subprocess.PIPE, timeout=90
    )
    parsed = json.loads(value)
    return base64.b64decode(parsed["content"].replace("\n", ""))

def main() -> None:
    if not shutil.which("gh"):
        raise SystemExit("Install GitHub CLI first: https://cli.github.com/")
    subprocess.run(["gh", "auth", "status"], check=True, timeout=20)
    manifest = json.loads(retrieve("manifest.json"))
    if manifest.get("source_commit") != COMMIT or manifest.get("version") != "P0-P92":
        raise SystemExit("Unexpected build provenance")
    parts = manifest.get("parts", [])
    if len(parts) != 56 or manifest.get("encoding") != "base85":
        raise SystemExit("Unexpected APK part manifest")
    chunks = bytearray()
    for i, part in enumerate(parts):
        data = retrieve(part["path"])
        if len(data) != part["bytes"] or hashlib.sha256(data).hexdigest() != part["sha256"]:
            raise SystemExit("Integrity check failed on part %d" % i)
        chunks.extend(data)
        print("Verified %d/%d original parts" % (i + 1, len(parts)), flush=True)
    apk = base64.b85decode(bytes(chunks))
    if len(apk) != manifest["bytes"] or hashlib.sha256(apk).hexdigest() != manifest["sha256"]:
        raise SystemExit("Final original APK checksum failed")
    target = Path("VEYRA-P92-ORIGINAL-VERIFIED.apk")
    if target.exists():
        raise SystemExit("Will not overwrite existing file: %s" % target)
    target.write_bytes(apk)
    print("Verified real P92 APK saved: %s" % target.resolve())
    print("PRIVATE TEST ONLY — DO NOT PUBLISH THIS FULL BUILD AS THE LIMITED SHOWCASE.")

if __name__ == "__main__":
    main()
