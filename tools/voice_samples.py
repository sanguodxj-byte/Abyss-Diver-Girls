"""按角色合成试音片段：取三句剧情原句，用选定声线合成、统一响度后拼接。

输出 review\\voice_<角色id>_sample.mp3；声线来自 tools\\voice_cast.json，密钥只读环境变量 FISH_KEY。
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voice_batch as vb

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REVIEW_DIR = os.path.join(ROOT, "review")
GAP_SEC = 0.35

PICKS = {
    "nao": ["radio_combat_out", "radio_kill_nao", "radio_dmg_nao"],
    "rei": ["radio_combat_in", "radio_kill_rei", "radio_energy_rei"],
    "kurumi": ["radio_kill_kurumi", "radio_over_in", "radio_boss_def_king"],
    "lina": ["radio_combat_in", "radio_dmg_lina", "radio_boss_king"],
    "mia": ["radio_land_ironbelt", "radio_part_arm", "radio_use_repair"],
    "ajin": ["radio_pick_coffee", "radio_pick_food"],
    "xiaoman": ["radio_box_mil", "radio_pick_gold"],
    "shiori": ["radio_boss_phase_queen", "radio_poi_institute"],
}


def make_silence(ffmpeg, path):
    proc = subprocess.run(
        [ffmpeg, "-y", "-v", "error", "-f", "lavfi", "-i",
         "anullsrc=r=44100:cl=mono", "-t", str(GAP_SEC), "-c:a", "libmp3lame",
         "-b:a", "160k", path],
        capture_output=True, text=True, encoding="utf-8", errors="replace")
    if proc.returncode != 0:
        raise RuntimeError("静音段生成失败：%s" % proc.stderr.strip()[-200:])


def concat_tracks(ffmpeg, parts, out_path, work_dir):
    list_path = os.path.join(work_dir, "concat.txt")
    with open(list_path, "w", encoding="utf-8") as f:
        for part in parts:
            f.write("file '%s'\n" % part.replace("\\", "/").replace("'", "'\\''"))
    proc = subprocess.run(
        [ffmpeg, "-y", "-v", "error", "-f", "concat", "-safe", "0", "-i", list_path,
         "-ar", "44100", "-ac", "1", "-c:a", "libmp3lame", "-b:a", "160k", out_path],
        capture_output=True, text=True, encoding="utf-8", errors="replace")
    if proc.returncode != 0:
        raise RuntimeError("拼接失败：%s" % proc.stderr.strip()[-200:])


def synth_line(char_id, ref, text, key, ffmpeg, work_dir, index):
    start = time.time()
    raw = vb.request_tts(text, ref, key)
    api_sec = round(time.time() - start, 2)
    src = os.path.join(work_dir, "%s_%02d.src.mp3" % (char_id, index))
    dst = os.path.join(work_dir, "%s_%02d.mp3" % (char_id, index))
    with open(src, "wb") as f:
        f.write(raw)
    norm_start = time.time()
    vb.normalize_loudness(ffmpeg, src, dst)
    if not os.path.exists(dst) or os.path.getsize(dst) < 1024:
        raise RuntimeError("响度处理结果为空")
    return {"char": char_id, "index": index, "path": dst, "api_sec": api_sec,
            "norm_sec": round(time.time() - norm_start, 2)}


def main(argv=None):
    parser = argparse.ArgumentParser(description="合成角色试音片段")
    parser.add_argument("--data-dir", default=vb.STORY_DIR)
    parser.add_argument("--cast", default=vb.CAST_PATH)
    parser.add_argument("--out-dir", default=REVIEW_DIR)
    parser.add_argument("--only", default="")
    parser.add_argument("--concurrency", type=int, default=4)
    args = parser.parse_args(argv)

    key = os.environ.get("FISH_KEY", "").strip()
    if not key:
        print("[sample] 缺少环境变量 FISH_KEY", file=sys.stderr)
        return 2
    ffmpeg = os.environ.get("FFMPEG") or shutil.which("ffmpeg")
    ffprobe = shutil.which("ffprobe")
    if not ffmpeg:
        print("[sample] 找不到 ffmpeg", file=sys.stderr)
        return 2

    cast = vb.load_cast(args.cast)
    lines = {}
    for voice, speaker, ja, source in vb.collect_lines(args.data_dir):
        lines[voice] = (speaker, ja, source)

    wanted = [c for c in PICKS if c in cast]
    if args.only:
        wanted = [c for c in wanted if c in {x.strip() for x in args.only.split(",")}]

    tasks = []
    for char_id in wanted:
        for index, voice in enumerate(PICKS[char_id]):
            if voice not in lines:
                print("[sample] %s 的语音 id %s 不存在" % (char_id, voice), file=sys.stderr)
                return 2
            speaker, text, source = lines[voice]
            if speaker != char_id:
                print("[sample] %s 的语音 id %s 属于 %s" % (char_id, voice, speaker),
                      file=sys.stderr)
                return 2
            tasks.append({"char": char_id, "index": index, "voice": voice,
                          "text": text, "ref": cast[char_id], "source": source})

    work_dir = tempfile.mkdtemp(prefix="voice_samples_")
    os.makedirs(args.out_dir, exist_ok=True)
    os.makedirs(work_dir, exist_ok=True)
    results = []
    timings = []
    try:
        silence = os.path.join(work_dir, "silence.mp3")
        make_silence(ffmpeg, silence)
        with ThreadPoolExecutor(max_workers=max(1, min(5, args.concurrency))) as pool:
            futures = {}
            for task in tasks:
                start = time.time()
                future = pool.submit(synth_line, task["char"], task["ref"], task["text"],
                                     key, ffmpeg, work_dir, task["index"])
                futures[future] = (task, start)
            for future in as_completed(futures):
                task, start = futures[future]
                try:
                    row = future.result()
                except Exception as exc:
                    print("[sample] failed %s %s %r" % (task["char"], task["voice"], exc),
                          flush=True)
                    return 1
                row.update(task)
                row["wall_sec"] = round(time.time() - start, 2)
                timings.append(row["api_sec"])
                results.append(row)
                print("[sample] ok %s %s api %.2fs wall %.2fs" % (
                    task["char"], task["voice"], row["api_sec"], row["wall_sec"]), flush=True)

        by_char = {}
        for row in results:
            by_char.setdefault(row["char"], []).append(row)
        for char_id in wanted:
            rows = sorted(by_char.get(char_id, []), key=lambda r: r["index"])
            parts = []
            for i, row in enumerate(rows):
                if i:
                    parts.append(silence)
                parts.append(row["path"])
            out_path = os.path.join(args.out_dir, "voice_%s_sample.mp3" % char_id)
            concat_tracks(ffmpeg, parts, out_path, work_dir)
            duration = vb.probe_duration(ffprobe, out_path)
            print("[sample] %s -> %s %.2fs" % (char_id, os.path.basename(out_path),
                                               duration or 0.0))
        if timings:
            timings.sort()
            print("[sample] 单句耗时 最短 %.2fs 中位 %.2fs 最长 %.2fs 共 %d 句"
                  % (timings[0], timings[len(timings) // 2], timings[-1], len(timings)))
    finally:
        shutil.rmtree(work_dir, ignore_errors=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
