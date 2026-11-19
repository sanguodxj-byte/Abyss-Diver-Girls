#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ElevenLabs Sound Effects V3 批量生成管线（严禁任何音频后处理，原始 WAV 原样落盘）。
1. 调用前必须先向用户提交申请并获得批准。
2. 调用 ElevenLabs V3 生成原始 44.1 kHz WAV，直接原样写入 assets\\audio\\sfx\\（同时备份于 build\\sfx_eleven_raw\\）。
3. 支持 --ids / 前缀过滤、--raw-copy-only（直接将已缓存的原始 WAV 原样同步至 assets\\audio\\sfx\\）、--force、--workers。
"""
import argparse
import concurrent.futures
import json
import os
import shutil
import sys
import threading
import time
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.dont_write_bytecode = True
sys.path.insert(0, HERE)

import sfx_build as B  # noqa: E402
import sfx_dsp as D  # noqa: E402
import sfx_elevenlabs_prompts as P  # noqa: E402

RAW_DIR = os.path.join(ROOT, "build", "sfx_eleven_raw")
API_URL = "https://api.elevenlabs.io/v1/sound-generation?output_format=wav_44100"
USER_URL = "https://api.elevenlabs.io/v1/user"
MODEL_ID = "eleven_text_to_sound_v3"

_PRINT_LOCK = threading.Lock()
_STOP_EVENT = threading.Event()


def _log(msg: str) -> None:
    with _PRINT_LOCK:
        print(msg, flush=True)


def get_elevenlabs_key() -> str:
    try:
        import winreg
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as k:
            val, _ = winreg.QueryValueEx(k, "ELEVENLABS_API_KEY")
            if val:
                return str(val).strip()
    except OSError:
        pass
    return os.environ.get("ELEVENLABS_API_KEY", "").strip()


class QuotaExhaustedError(RuntimeError):
    pass


def fetch_elevenlabs_wav(
    api_key: str,
    text: str,
    duration_seconds: float,
    prompt_influence: float,
    is_loop: bool,
    out_path: str,
    max_retries: int = 4,
) -> int:
    payload = {
        "text": text,
        "duration_seconds": round(max(0.5, min(30.0, float(duration_seconds))), 2),
        "prompt_influence": round(max(0.0, min(1.0, float(prompt_influence))), 2),
        "model_id": MODEL_ID,
    }
    if is_loop:
        payload["loop"] = True
    body = json.dumps(payload).encode("utf-8")

    last_err = None
    for attempt in range(max_retries):
        if _STOP_EVENT.is_set():
            raise QuotaExhaustedError("Aborted due to earlier quota/auth failure.")
        req = urllib.request.Request(
            API_URL,
            data=body,
            headers={
                "xi-api-key": api_key,
                "Content-Type": "application/json",
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                data = resp.read()
                char_cost = int(resp.headers.get("character-cost", "0") or 0)
            if len(data) < 64 or data[:4] != b"RIFF":
                raise RuntimeError(f"Invalid WAV response ({len(data)} bytes)")
            os.makedirs(os.path.dirname(out_path), exist_ok=True)
            tmp_path = out_path + f".tmp.{threading.get_ident()}"
            with open(tmp_path, "wb") as f:
                f.write(data)
            os.replace(tmp_path, out_path)
            return char_cost
        except urllib.error.HTTPError as e:
            err_body = ""
            try:
                err_body = e.read().decode("utf-8", errors="replace")
            except Exception:
                pass
            if e.code in (401, 402) or (
                e.code == 429 and ("quota" in err_body.lower() or "credit" in err_body.lower())
            ):
                _STOP_EVENT.set()
                raise QuotaExhaustedError(f"HTTP {e.code}: {err_body}") from e
            last_err = RuntimeError(f"HTTP {e.code}: {err_body}")
            if e.code in (429, 500, 502, 503, 504) and attempt + 1 < max_retries:
                time.sleep(1.5 * (2 ** attempt))
                continue
            raise last_err from e
        except Exception as e:
            last_err = e
            if attempt + 1 < max_retries:
                time.sleep(1.5 * (2 ** attempt))
                continue
            raise
    raise last_err  # pragma: no cover


def process_one(
    sid: str,
    v: int,
    fname: str,
    api_key: str,
    raw_copy_only: bool,
    force: bool,
) -> tuple[str, int, int]:
    rc = D.RECIPES[sid]
    raw_path = os.path.join(RAW_DIR, fname)
    out_path = os.path.join(B.OUT, fname)
    is_loop = bool(rc["loop"])
    char_cost = 0

    if force or not os.path.exists(raw_path):
        if raw_copy_only:
            raise FileNotFoundError(f"--raw-copy-only 模式下缺少原始缓存: {raw_path}")
        prompt_text, gen_dur, infl = P.prompt_for(sid, v)
        char_cost = fetch_elevenlabs_wav(
            api_key=api_key,
            text=prompt_text,
            duration_seconds=gen_dur,
            prompt_influence=infl,
            is_loop=is_loop,
            out_path=raw_path,
        )

    os.makedirs(B.OUT, exist_ok=True)
    shutil.copyfile(raw_path, out_path)
    return fname, os.path.getsize(out_path), char_cost


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="ElevenLabs V3 SFX 生成管线（无任何后处理，原样落盘）")
    ap.add_argument("prefixes", nargs="*", help="仅处理匹配这些前缀（或精确 ID）的音效")
    ap.add_argument("--ids", type=str, default="", help="逗号分隔的精确音效 ID 列表")
    ap.add_argument("--workers", type=int, default=3, help="并发 API 请求线程数（默认 3）")
    ap.add_argument("--raw-copy-only", action="store_true", help="直接将已有原始缓存原样复制到 assets\\audio\\sfx\\，不调用 API")
    ap.add_argument("--force", action="store_true", help="忽略原始缓存强制重新请求 ElevenLabs")
    args = ap.parse_args(argv)

    api_key = get_elevenlabs_key()
    if not args.raw_copy_only and not api_key:
        print("[sfx_elevenlabs_gen] 错误：未找到 ELEVENLABS_API_KEY", file=sys.stderr)
        return 2

    exact_ids = {s.strip() for s in args.ids.split(",") if s.strip()} if args.ids else set()
    items = B.read_all()
    jobs = []
    for sid, files, _ in items:
        if exact_ids and sid not in exact_ids:
            continue
        if args.prefixes and not any(sid == p or sid.startswith(p) for p in args.prefixes):
            continue
        if sid not in D.RECIPES or sid not in P.PROMPTS:
            continue
        for v, fname in enumerate(files):
            jobs.append((sid, v, fname))

    if not jobs:
        print("[sfx_elevenlabs_gen] 没有匹配的音效任务。")
        return 0

    t0 = time.time()
    done = 0
    total_cost = 0
    errors = []

    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, args.workers)) as pool:
        fut_map = {
            pool.submit(process_one, sid, v, fname, api_key, args.raw_copy_only, args.force): fname
            for sid, v, fname in jobs
        }
        for fut in concurrent.futures.as_completed(fut_map):
            fname = fut_map[fut]
            try:
                fn, sz, cost = fut.result()
                done += 1
                total_cost += cost
                if done % 30 == 0 or done == len(jobs) or len(jobs) <= 20:
                    _log(f"[{done}/{len(jobs)}] {fn:<32} raw_bytes={sz} cost={cost}")
            except Exception as e:
                errors.append((fname, str(e)))
                _log(f"[ERROR] {fname}: {e}")

    _log(f"[sfx_elevenlabs_gen] 原样落盘 {done}/{len(jobs)} 个文件，失败 {len(errors)} 个，headers_sum={total_cost}，耗时 {time.time() - t0:.1f}s")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
