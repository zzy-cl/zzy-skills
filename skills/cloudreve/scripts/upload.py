#!/usr/bin/env python3
"""
Upload a file to Cloudreve v4 (Python version)
More robust than the bash version — better error handling, progress reporting.
Usage: upload.py <CLOUDREVE_URL> <TOKEN> <LOCAL_FILE> [REMOTE_NAME] [REMOTE_DIR]
Docs: https://docs.cloudreve.org/zh/api/upload
"""

import json
import os
import sys
import time

try:
    import requests
except ImportError:
    print("ERROR: 'requests' module required. Install with: pip install requests", file=sys.stderr)
    sys.exit(1)


def log(msg):
    print(msg, file=sys.stderr)


def main():
    if len(sys.argv) < 4:
        print("Usage: upload.py <URL> <TOKEN> <FILE> [NAME] [DIR]", file=sys.stderr)
        sys.exit(1)

    url = sys.argv[1]
    token = sys.argv[2]
    local_file = sys.argv[3]
    remote_name = sys.argv[4] if len(sys.argv) > 4 else os.path.basename(local_file)
    remote_dir = sys.argv[5] if len(sys.argv) > 5 else "cloudreve://my"

    if not os.path.isfile(local_file):
        log(f"ERROR: File not found: {local_file}")
        sys.exit(1)

    file_size = os.path.getsize(local_file)
    target_uri = f"{remote_dir}/{remote_name}"
    headers = {"Authorization": f"Bearer {token}"}

    log(f"Uploading: {local_file} ({file_size} bytes) -> {target_uri}")

    # ── Step 1: Create upload session ──
    def create_session():
        resp = requests.put(
            f"{url}/api/v4/file/upload",
            headers=headers,
            json={"uri": target_uri, "size": file_size}
        )
        return resp.json()

    data = create_session()
    code = data.get("code", -1)

    # Handle "file already exists" (40004) — delete with retry, then re-upload
    if code == 40004:
        log("File exists, attempting to delete and re-upload...")

        del_retries = 3
        del_delay = 3
        del_ok = False

        for del_attempt in range(1, del_retries + 1):
            del_resp = requests.delete(
                f"{url}/api/v4/file",
                headers=headers,
                json={"uris": [target_uri]}
            )
            del_code = del_resp.json().get("code", -1)

            if del_code == 0:
                log("Deleted existing file.")
                del_ok = True
                break
            elif del_code == 40073:
                if del_attempt < del_retries:
                    log(f"WARN: File locked (40073), waiting {del_delay}s... (attempt {del_attempt}/{del_retries})")
                    time.sleep(del_delay)
                    del_delay *= 2
                else:
                    log(f"ERROR: Cannot delete locked file after {del_retries} attempts. Try a different filename.")
                    sys.exit(1)
            else:
                log(f"WARN: Delete returned {del_code}, attempting upload anyway...")
                del_ok = True
                break

        if del_ok:
            log("Creating new upload session...")

        data = create_session()
        code = data.get("code", -1)

    if code != 0:
        log(f"ERROR: Session creation failed (code={code}): {data.get('msg', 'unknown')}")
        sys.exit(1)

    session_id = data["data"]["session_id"]
    chunk_size = data["data"]["chunk_size"]
    log(f"Session: {session_id}, chunk_size: {chunk_size}")

    # ── Step 2: Upload chunks (raw binary, NOT multipart) ──
    chunk_index = 0
    offset = 0

    with open(local_file, "rb") as f:
        while offset < file_size:
            remaining = file_size - offset
            this_chunk = min(remaining, chunk_size)
            chunk_data = f.read(this_chunk)

            log(f"Uploading chunk {chunk_index} ({this_chunk} bytes)...")

            resp = requests.post(
                f"{url}/api/v4/file/upload/{session_id}/{chunk_index}",
                headers=headers,
                data=chunk_data  # raw binary, NOT multipart/form-data
            )
            result = resp.json()
            if result.get("code") != 0:
                log(f"ERROR: Chunk {chunk_index} failed: {result.get('msg', 'unknown')}")
                sys.exit(1)

            offset += this_chunk
            chunk_index += 1

    log(f"OK: Uploaded -> {target_uri} ({chunk_index} chunk(s))")


if __name__ == "__main__":
    main()
