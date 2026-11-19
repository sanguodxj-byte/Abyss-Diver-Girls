#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
通过 build-music 技能（本地 AIStudio2API http://127.0.0.1:2048，固定模型 lyria-3.5）
生成全部 13 首 BGM（对应 14 个音乐槽，bayport_explore 共用 greyport_explore.ogg）。
严格遵守「所有音频禁止任何后处理」铁律：lyria-3.5 生成的原始音频不加任何滤波、EQ、压缩、限幅、
loudnorm、响度缩放或人工淡入淡出裁切，仅做纯容器直转（MP3 -> OGG）原样输出至 assets\\audio\\music\\。
用法：
  python tools\\music_gen.py [--force] [--raw-copy-only] [槽 id ...]
"""
import argparse
import base64
import concurrent.futures
import json
import os
import re
import subprocess
import sys
import threading
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.dont_write_bytecode = True

API_URL = "http://127.0.0.1:2048/v1/chat/completions"
STATUS_URL = "http://127.0.0.1:2048/api/status"
MODEL_ID = "lyria-3.5"

RAW_DIR = os.path.join(ROOT, "build", "bgm_lyria_raw")
OUT_DIR = os.path.join(ROOT, "assets", "audio", "music")
DATA_URI_RE = re.compile(r"data:(audio/[a-zA-Z0-9.+_-]+);base64,([A-Za-z0-9+/=\s]+)")

CUES = [
    (
        "menu",
        "一段平缓宁静的高空飞空艇舷窗环境背景纯音乐，D大调，66 BPM，温暖柔和的模拟合成器长音铺底与微弱弦乐和声，极简克制、低存在感，带自然淡入淡出与舒缓留白，无钢琴独奏、无八音盒、无鼓点，纯器乐，30秒",
    ),
    (
        "hangar",
        "一段平缓沉稳的飞空艇机库整备背景纯音乐，A多利亚调式，70 BPM，温暖低频模拟贝斯长音与柔和暗调风琴铺底，安静安全、极低存在感，带自然淡入淡出与舒缓留白，无八音盒、无钢片琴、无主奏旋律、无鼓点，纯器乐，30秒",
    ),
    (
        "greyport_explore",
        "一段阴雨废墟河港探索的极简暗黑环境氛围纯音乐，升F小调，60 BPM，平缓深沉的合成器低频长音与空旷雾气泛音，极低存在感、带自然淡入淡出与长时间留白，无钢琴、无八音盒、无鼓点，纯器乐，30秒",
    ),
    (
        "ironbelt_explore",
        "一段冷峻废弃重工业钢厂探索的极简环境纯音乐，C小调，62 BPM，平缓克制的低频模拟合成器持续铺底与深邃空间共鸣，极低存在感、带自然淡入淡出与长时间留白，无打击乐、无节奏鼓点、无主旋律，纯器乐，30秒",
    ),
    (
        "dustfield_explore",
        "一段荒凉辽阔尘土平原探索的极简环境纯音乐，D小调，58 BPM，平缓温暖的低音大提琴长音与空旷荒野合成器铺底，孤独安静、极低存在感、带自然淡入淡出与长时间留白，无钢琴、无拨弦主旋律、无鼓点，纯器乐，30秒",
    ),
    (
        "redlake_explore",
        "一段迷雾赤湖探索的极简暗调环境纯音乐，升G小调，60 BPM，平缓柔和的水下感玻璃合成器长音与深沉低频铺底，平静神秘、极低存在感、带自然淡入淡出与长时间留白，无八音盒、无钢琴、无鼓点，纯器乐，30秒",
    ),
    (
        "canyon_explore",
        "一段幽深地下裂谷矿区探索的极简暗黑环境纯音乐，E小调，56 BPM，平缓深邃的岩洞低频共鸣合成器长音铺底，安静空旷、极低存在感、带自然淡入淡出与长时间留白，无钢琴、无八音盒、无鼓点，纯器乐，30秒",
    ),
    (
        "abyss_maw_explore",
        "一段超深钻探竖井深渊探索的极简暗黑环境纯音乐，升G洛克里亚调式，54 BPM，缓慢呼吸的深渊超低频合成器铺底与微弱空间泛音，极低存在感、带自然淡入淡出与长时间留白，无钢琴、无鼓点，纯器乐，30秒",
    ),
    (
        "combat",
        "一段克制低存在感的废土战术交战背景铺底纯音乐，E弗里吉亚调式，92 BPM，平缓深沉的低频电子脉冲与暗调模拟合成器持续张力，不刺耳、无失真电吉他、无喧闹军鼓，纯器乐，30秒",
    ),
    (
        "extract",
        "一段克制低存在感的撤离等待倒计时背景纯音乐，D小调，96 BPM，平缓低沉的脉冲低音与暗调悬疑合成器长音铺底，紧张但柔和克制，无刺耳高频、无喧闹鼓组，纯器乐，30秒",
    ),
    (
        "result_success",
        "一段温柔释然的任务完成结算环境纯音乐，D大调，66 BPM，平缓温暖的模拟合成器与柔和弦乐和弦缓慢消散，安静舒缓、低存在感，无八音盒、无鼓点，自然收尾，纯器乐，30秒",
    ),
    (
        "result_fail",
        "一段低沉克制的行动失败结算环境纯音乐，D小调，58 BPM，平缓空寂的暗调合成器低音和弦缓慢衰减至寂静，哀而不煽、低存在感，无八音盒、无鼓点，自然收尾，纯器乐，30秒",
    ),
    (
        "boss",
        "一段极具压迫感的重工业巨兽Boss战斗纯音乐，升C弗里吉亚调式，86 BPM，厚重震撼的超低频工业合成器轰鸣、沉重金属战鼓与暗黑不协和低音铜管群，威慑力强，纯器乐，30秒",
    ),
]


def check_service() -> dict:
    req = urllib.request.Request(STATUS_URL)
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.loads(resp.read().decode("utf-8"))


def fetch_lyria_clip(cue_id: str, prompt: str, out_raw_path: str, max_retries: int = 4) -> float:
    os.makedirs(os.path.dirname(out_raw_path), exist_ok=True)
    payload = {
        "model": MODEL_ID,
        "messages": [{"role": "user", "content": prompt}],
    }
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")

    last_err = None
    for attempt in range(max_retries):
        req = urllib.request.Request(
            API_URL,
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=300) as resp:
                raw_json = resp.read().decode("utf-8", errors="replace")
            data = json.loads(raw_json)
            content = data["choices"][0]["message"]["content"]
            m = DATA_URI_RE.search(content)
            if not m:
                raise RuntimeError(f"lyria-3.5 响应未包含 data:audio URI: {content[:200]}")
            audio_bytes = base64.b64decode(m.group(2))
            if len(audio_bytes) < 4096:
                raise RuntimeError(f"lyria-3.5 音频过小 ({len(audio_bytes)} bytes)")
            tmp_path = out_raw_path + f".tmp.{threading.get_ident()}"
            with open(tmp_path, "wb") as f:
                f.write(audio_bytes)
            os.replace(tmp_path, out_raw_path)

            probe = subprocess.run(
                [
                    "ffprobe", "-v", "error",
                    "-show_entries", "format=duration",
                    "-of", "default=noprint_wrappers=1:nokey=1",
                    out_raw_path,
                ],
                capture_output=True,
                text=True,
                timeout=30,
            )
            return float((probe.stdout or "0").strip() or 0.0)
        except Exception as e:
            last_err = e
            if attempt + 1 < max_retries:
                time.sleep(2.0 * (attempt + 1))
                continue
            raise last_err from e
    raise last_err  # pragma: no cover


def raw_to_ogg_unmodified(raw_path: str, ogg_path: str) -> float:
    """将原始音频直接封装/转码为 OGG，禁止添加任何 -af 音频滤镜或后处理。"""
    os.makedirs(os.path.dirname(ogg_path), exist_ok=True)
    tmp_ogg = ogg_path + f".tmp.{threading.get_ident()}.ogg"
    cmd = [
        "ffmpeg", "-y", "-loglevel", "error",
        "-i", raw_path,
        "-c:a", "libvorbis", "-q:a", "6",
        tmp_ogg,
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
    if proc.returncode != 0 or not os.path.exists(tmp_ogg):
        raise RuntimeError(f"直转 OGG 失败: {proc.stderr}")
    os.replace(tmp_ogg, ogg_path)
    probe = subprocess.run(
        [
            "ffprobe", "-v", "error",
            "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1",
            ogg_path,
        ],
        capture_output=True,
        text=True,
        timeout=30,
    )
    return float((probe.stdout or "0").strip() or 0.0)


def process_one(row: tuple, raw_copy_only: bool, force: bool) -> tuple[str, float, int]:
    cue_id, prompt = row[0], row[1]
    raw_p = os.path.join(RAW_DIR, f"{cue_id}.mp3")
    if force or not os.path.exists(raw_p) or os.path.getsize(raw_p) < 10000:
        if raw_copy_only:
            raise FileNotFoundError(f"缺少 lyria-3.5 原始音频: {raw_p}")
        fetch_lyria_clip(cue_id, prompt, raw_p)

    ogg_p = os.path.join(OUT_DIR, f"{cue_id}.ogg")
    dur = raw_to_ogg_unmodified(raw_p, ogg_p)
    return cue_id, dur, os.path.getsize(ogg_p)


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="通过 build-music (lyria-3.5) 生成 BGM（无任何后处理，原样直出）")
    ap.add_argument("cues", nargs="*", help="指定音乐槽 ID（留空则处理全部 13 首）")
    ap.add_argument("--workers", type=int, default=2, help="并发数")
    ap.add_argument("--raw-copy-only", action="store_true", help="直接将已下载的 lyria-3.5 原始音频无损直转为 OGG，不附加任何后处理")
    ap.add_argument("--force", action="store_true", help="强制重新调用 lyria-3.5 生成")
    args = ap.parse_args(argv)

    if not args.raw_copy_only:
        st = check_service()
        print(f"[build-music] status={st.get('state')} accounts={st.get('accounts')}", flush=True)

    want = set(args.cues)
    todo = [r for r in CUES if not want or r[0] in want]
    t0 = time.time()
    errors = []

    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, args.workers)) as pool:
        futs = {pool.submit(process_one, r, args.raw_copy_only, args.force): r[0] for r in todo}
        for fut in concurrent.futures.as_completed(futs):
            cid = futs[fut]
            try:
                cue_id, dur, sz = fut.result()
                print(f"[lyria-3.5-raw] {cue_id:<20} dur={dur:5.1f}s size={sz // 1024}KB (zero post-processing)", flush=True)
            except Exception as e:
                errors.append((cid, str(e)))
                print(f"[lyria-3.5-raw] FAIL {cid}: {e}", flush=True)

    print(f"[music_gen] 原样直出 {len(todo) - len(errors)}/{len(todo)} 首，耗时 {time.time() - t0:.1f}s", flush=True)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
