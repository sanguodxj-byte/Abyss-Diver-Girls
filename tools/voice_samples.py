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
    "nao": ["comm_seen_generic_02", "side_captain_lv2_001", "main_ch4_encounter_003"],
    "rei": ["main_ch3_encounter_002", "comm_poi_relay_01", "side_rei_lv4_001"],
    "kurumi": ["comm_ext_start_trans_02", "side_kurumi_lv4_005", "main_ch4_boss_in_002"],
    "lina": ["comm_deploy_lina_01", "comm_emerg_in_lina_01", "side_lina_lv2_004"],
    "laojiao": ["comm_pick_crystal_01", "side_kurumi_lv5_003", "main_ch5_intro_003"],
    "ajin": ["side_ajin_lv3_001", "comm_emerg_in_ajin_01", "comm_pick_food_01"],
    "xiaoman": ["comm_ext_done_xiaoman_01", "side_xiaoman_lv5_003", "main_ch7_boss_out_003"],
    "captain": ["comm_pick_coffee_01", "side_captain_lv4_003", "main_ch3_outro_003"],
    "shiori": ["side_shiori_lv1_003", "comm_poi_well_01", "main_ch6_poi_001"],
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
