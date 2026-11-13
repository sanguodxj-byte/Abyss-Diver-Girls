# -*- coding: utf-8 -*-
import json
import urllib.request
import urllib.parse
import os
import sys

BASE_URL_FILE = r"D:\123\qianyuanshaonv\tools\art_host.txt"

def get_base_url():
    with open(BASE_URL_FILE, "r", encoding="utf-8") as f:
        return f.read().strip()

def probe_and_fetch(prompt_id, output_path):
    base = get_base_url()
    try:
        req = urllib.request.Request(f"{base}/history/{prompt_id}")
        with urllib.request.urlopen(req, timeout=30) as r:
            data = json.loads(r.read().decode())
    except Exception as e:
        print(f"ERROR: failed to fetch history: {e}")
        return False

    if prompt_id not in data:
        # Check queue
        try:
            with urllib.request.urlopen(f"{base}/queue", timeout=30) as qr:
                qdata = json.loads(qr.read().decode())
            running = [item[1] for item in qdata.get("queue_running", [])]
            pending = [item[1] for item in qdata.get("queue_pending", [])]
            if prompt_id in running:
                print("STATUS:RUNNING")
                return False
            elif prompt_id in pending:
                print("STATUS:PENDING")
                return False
            else:
                print("STATUS:NOT_FOUND")
                return False
        except Exception:
            print("STATUS:UNKNOWN")
            return False

    record = data[prompt_id]
    outputs = record.get("outputs", {})
    save_node = outputs.get("10", {})
    images = save_node.get("images", [])
    if not images:
        print("STATUS:NO_IMAGES")
        return False

    img_info = images[0]
    filename = img_info.get("filename")
    subfolder = img_info.get("subfolder", "")
    img_type = img_info.get("type", "output")

    params = urllib.parse.urlencode({"filename": filename, "subfolder": subfolder, "type": img_type})
    view_url = f"{base}/view?{params}"

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    try:
        with urllib.request.urlopen(view_url, timeout=60) as r, open(output_path, "wb") as out_f:
            out_f.write(r.read())
        print(f"STATUS:DONE:{output_path}")
        return True
    except Exception as e:
        print(f"ERROR: failed to download: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python probe_and_download.py <prompt_id> <output_path>")
        sys.exit(1)
    pid = sys.argv[1]
    out = sys.argv[2]
    probe_and_fetch(pid, out)
