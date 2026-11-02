"""批量配音：读 data\\story 下所有带 voice 字段的台词，按说话人映射声线合成日语配音。

输出 assets\\audio\\voice\\<voice_id>.mp3；文本哈希清单在 assets\\audio\\voice_manifest.json。
密钥只从环境变量 FISH_KEY 读取。已有文件且文本哈希未变的条目跳过，失败条目保留在清单里供下次补做。
"""

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed

API_URL = "https://api.fish.audio/v1/tts"
TTS_MODEL = "s2.1-pro-free"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STORY_DIR = os.path.join(ROOT, "data", "story")
VOICE_DIR = os.path.join(ROOT, "assets", "audio", "voice")
MANIFEST_PATH = os.path.join(ROOT, "assets", "audio", "voice_manifest.json")
CAST_PATH = os.path.join(ROOT, "tools", "voice_cast.json")
AUDIO_EXTS = (".mp3", ".ogg", ".wav")
LOUDNESS_TARGET = "I=-16:TP=-1.5:LRA=11"
LOUDNESS_FILTER = "loudnorm=" + LOUDNESS_TARGET
ENCODE_ARGS = ["-ar", "44100", "-ac", "1", "-c:a", "libmp3lame", "-b:a", "160k"]
VALID_VOICE_ID = re.compile(r"^[a-z0-9_]+$")


def normalize_text(text):
    return re.sub(r"\s+", " ", str(text)).strip()


def text_hash(text):
    return hashlib.sha256(normalize_text(text).encode("utf-8")).hexdigest()


def read_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def write_json_atomic(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), suffix=".tmp")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write("\n")
    os.replace(tmp, path)


def collect_lines(story_dir):
    """返回 [(voice_id, speaker, ja_text, 来源)]，来源只用于报错定位。"""
    rows = []
    scenes_files = ["main_scenes.json", "side_scenes.json"]
    for fn in scenes_files:
        path = os.path.join(story_dir, fn)
        if not os.path.exists(path):
            continue
        data = read_json(path)
        scenes = data.get("scenes", {})
        if not isinstance(scenes, dict):
            continue
        for sid, scene in scenes.items():
            if not isinstance(scene, dict):
                continue
            lines = scene.get("lines", [])
            if not isinstance(lines, list):
                continue
            for i, line in enumerate(lines):
                if not isinstance(line, dict):
                    continue
                voice = str(line.get("voice", "")).strip()
                if not voice:
                    continue
                rows.append((voice, str(line.get("speaker", "")).strip(),
                             str(line.get("ja", "")), "%s.%s.lines[%d]" % (fn, sid, i)))
    comms_path = os.path.join(story_dir, "comms.json")
    if os.path.exists(comms_path):
        data = read_json(comms_path)
        for i, item in enumerate(data.get("comms", []) or []):
            if not isinstance(item, dict):
                continue
            voice = str(item.get("voice", "")).strip()
            if not voice:
                continue
            rows.append((voice, str(item.get("speaker", "")).strip(),
                         str(item.get("ja", "")), "comms.json[%d]" % i))
    return rows


def load_cast(path):
    if not os.path.exists(path):
        return {}
    cast = read_json(path)
    return {str(k): str(v) for k, v in cast.items() if str(v).strip()}


def load_manifest(path):
    if not os.path.exists(path):
        return {"version": 1, "entries": {}}
    try:
        data = read_json(path)
    except (OSError, ValueError):
        return {"version": 1, "entries": {}}
    if not isinstance(data, dict) or not isinstance(data.get("entries"), dict):
        return {"version": 1, "entries": {}}
    return data


def existing_audio(out_dir, voice_id):
    """返回已有的配音文件路径；调用方已确认清单哈希与当前文本一致。"""
    for ext in AUDIO_EXTS:
        path = os.path.join(out_dir, voice_id + ext)
        if os.path.exists(path) and os.path.getsize(path) > 1024:
            return path
    return None


class SynthError(Exception):
    def __init__(self, message, retryable=False):
        super().__init__(message)
        self.retryable = retryable


def request_tts(text, reference_id, key, timeout=180):
    body = json.dumps({"text": text, "reference_id": reference_id, "format": "mp3"},
                      ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(
        API_URL, data=body, method="POST",
        headers={"Authorization": "Bearer " + key, "Content-Type": "application/json",
                 "model": TTS_MODEL})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            data = resp.read()
    except urllib.error.HTTPError as exc:
        detail = exc.read()[:300].decode("utf-8", "replace")
        retryable = exc.code == 429 or exc.code >= 500
        raise SynthError("HTTP %d %s" % (exc.code, detail), retryable) from exc
    except (urllib.error.URLError, OSError) as exc:
        raise SynthError("网络错误 %s" % exc, True) from exc
    if len(data) < 1024:
        raise SynthError("返回内容过短（%d 字节）" % len(data), True)
    return data


def ffmpeg_measure(ffmpeg, path):
    proc = subprocess.run(
        [ffmpeg, "-hide_banner", "-nostats", "-i", path,
         "-af", LOUDNESS_FILTER + ":print_format=json", "-f", "null", "-"],
        capture_output=True, text=True, encoding="utf-8", errors="replace")
    match = re.search(r'\{[^{}]*"input_i"[^{}]*\}', proc.stderr, re.S)
    if not match:
        return None
    try:
        return json.loads(match.group(0))
    except ValueError:
        return None


def ffmpeg_encode(ffmpeg, src, dst, audio_filter):
    proc = subprocess.run([ffmpeg, "-y", "-v", "error", "-i", src, "-af", audio_filter] +
                          ENCODE_ARGS + [dst],
                          capture_output=True, text=True, encoding="utf-8", errors="replace")
    if proc.returncode != 0:
        raise SynthError("ffmpeg 失败：%s" % proc.stderr.strip()[-200:], False)


def normalize_loudness(ffmpeg, src, dst):
    """线性增益受峰值限制时，用带限幅的补偿增益把整体响度追到目标值。"""
    measured = ffmpeg_measure(ffmpeg, src)
    if measured:
        af = ("%s:measured_I=%s:measured_TP=%s:measured_LRA=%s:measured_thresh=%s:linear=true"
              % (LOUDNESS_FILTER, measured["input_i"], measured["input_tp"],
                 measured["input_lra"], measured["input_thresh"]))
        ffmpeg_encode(ffmpeg, src, dst, af)
        check = ffmpeg_measure(ffmpeg, dst)
        if check and abs(float(check["input_i"]) + 16.0) <= 0.8:
            return
    gain = 0.0
    for _ in range(3):
        check = ffmpeg_measure(ffmpeg, dst) if os.path.exists(dst) else None
        if check and abs(float(check["input_i"]) + 16.0) <= 0.8:
            return
        gain += (-16.0 - float(check["input_i"])) if check else 6.0
        gain = max(-12.0, min(18.0, gain))
        ffmpeg_encode(ffmpeg, src, dst,
                      "volume=%.2fdB,alimiter=limit=0.841:level=false:attack=5:release=50" % gain)
    if not os.path.exists(dst) or os.path.getsize(dst) < 1024:
        ffmpeg_encode(ffmpeg, src, dst, LOUDNESS_FILTER)


def synth_one(item, out_dir, key, ffmpeg):
    os.makedirs(out_dir, exist_ok=True)
    raw = request_tts(item["text"], item["ref"], key)
    fd, tmp_raw = tempfile.mkstemp(dir=out_dir, suffix=".src.mp3")
    os.close(fd)
    fd, tmp_out = tempfile.mkstemp(dir=out_dir, suffix=".tmp.mp3")
    os.close(fd)
    try:
        with open(tmp_raw, "wb") as f:
            f.write(raw)
        normalize_loudness(ffmpeg, tmp_raw, tmp_out)
        if os.path.getsize(tmp_out) < 1024:
            raise SynthError("转码结果为空", True)
        final_path = os.path.join(out_dir, item["voice"] + ".mp3")
        os.replace(tmp_out, final_path)
    finally:
        for path in (tmp_raw, tmp_out):
            if os.path.exists(path):
                os.remove(path)
    return final_path


def probe_duration(ffprobe, path):
    if not ffprobe:
        return None
    proc = subprocess.run([ffprobe, "-v", "error", "-show_entries", "format=duration",
                           "-of", "csv=p=0", path],
                          capture_output=True, text=True, encoding="utf-8", errors="replace")
    try:
        return round(float(proc.stdout.strip()), 2)
    except ValueError:
        return None


def build_plan(entries, cast, manifest, out_dir):
    plan, issues = [], []
    seen = {}
    for voice, speaker, ja, source in entries:
        if not VALID_VOICE_ID.match(voice):
            issues.append((source, voice, "语音 id 只允许小写字母、数字、下划线"))
            continue
        digest = text_hash(ja)
        if voice in seen:
            if seen[voice] != digest:
                issues.append((source, voice, "同一语音 id 对应不同文本"))
            continue
        seen[voice] = digest
        if not normalize_text(ja):
            issues.append((source, voice, "ja 文本为空"))
            continue
        if speaker not in cast:
            issues.append((source, voice, "说话人未配置声线：%s" % (speaker or "旁白")))
            continue
        entry = manifest["entries"].get(voice) or {}
        if (entry.get("hash") == digest and entry.get("model") == cast[speaker]
                and entry.get("status") == "ok" and existing_audio(out_dir, voice)):
            plan.append({"voice": voice, "speaker": speaker, "text": ja, "ref": cast[speaker],
                         "hash": digest, "action": "skip", "source": source})
        else:
            plan.append({"voice": voice, "speaker": speaker, "text": ja, "ref": cast[speaker],
                         "hash": digest, "action": "synth", "source": source})
    return plan, issues


def record_entry(manifest, item, status, path, error, ffprobe):
    if manifest is None:
        return
    entry = {
        "hash": item["hash"],
        "speaker": item["speaker"],
        "model": item["ref"],
        "status": status,
    }
    if status == "ok":
        entry["file"] = os.path.basename(path)
        entry["duration_sec"] = probe_duration(ffprobe, path)
    else:
        entry["error"] = error
    manifest.setdefault("entries", {})[item["voice"]] = entry


def run_plan(plan, out_dir, key, ffmpeg, concurrency, passes=3,
             manifest=None, manifest_path=None, ffprobe=None):
    results = {}
    pending = [p for p in plan if p["action"] == "synth"]
    done = 0

    def persist():
        if manifest is not None and manifest_path:
            write_json_atomic(manifest_path, manifest)

    try:
        for attempt in range(passes):
            if not pending:
                break
            retry = []
            with ThreadPoolExecutor(max_workers=max(1, concurrency)) as pool:
                futures = {pool.submit(synth_one, item, out_dir, key, ffmpeg): item
                           for item in pending}
                for future in as_completed(futures):
                    item = futures[future]
                    voice = item["voice"]
                    try:
                        path = future.result()
                        results[voice] = ("ok", path, None)
                        record_entry(manifest, item, "ok", path, None, ffprobe)
                        print("[cue] ok %s" % voice, flush=True)
                    except SynthError as exc:
                        results[voice] = ("failed", None, str(exc))
                        record_entry(manifest, item, "failed", None, str(exc), ffprobe)
                        print("[cue] failed %s %s" % (voice, exc), flush=True)
                        if exc.retryable and attempt + 1 < passes:
                            retry.append(item)
                    except Exception as exc:  # 未预料的异常同样记账，不中断整批
                        results[voice] = ("failed", None, repr(exc))
                        record_entry(manifest, item, "failed", None, repr(exc), ffprobe)
                        print("[cue] failed %s %r" % (voice, exc), flush=True)
                    done += 1
                    if done % 5 == 0:
                        persist()
            pending = retry
    finally:
        persist()
    return results


def main(argv=None):
    parser = argparse.ArgumentParser(description="批量合成剧情日语配音")
    parser.add_argument("--dry-run", action="store_true", help="只列出计划，不调用接口")
    parser.add_argument("--only", default="", help="只处理逗号分隔的语音 id")
    parser.add_argument("--concurrency", type=int, default=4)
    parser.add_argument("--data-dir", default=STORY_DIR)
    parser.add_argument("--out-dir", default=VOICE_DIR)
    parser.add_argument("--manifest", default=MANIFEST_PATH)
    parser.add_argument("--cast", default=CAST_PATH)
    args = parser.parse_args(argv)

    key = os.environ.get("FISH_KEY", "").strip()
    if not key and not args.dry_run:
        print("[cue] 缺少环境变量 FISH_KEY", file=sys.stderr)
        return 2
    ffmpeg = os.environ.get("FFMPEG") or shutil.which("ffmpeg")
    ffprobe = shutil.which("ffprobe")
    if not args.dry_run and not ffmpeg:
        print("[cue] 找不到 ffmpeg", file=sys.stderr)
        return 2

    if not args.dry_run and os.path.isdir(args.out_dir):
        for name in os.listdir(args.out_dir):
            if name.endswith((".src.mp3", ".tmp.mp3")):
                try:
                    os.remove(os.path.join(args.out_dir, name))
                except OSError:
                    pass

    entries = collect_lines(args.data_dir)
    cast = load_cast(args.cast)
    manifest = load_manifest(args.manifest)
    if args.only:
        wanted = {x.strip() for x in args.only.split(",") if x.strip()}
        entries = [row for row in entries if row[0] in wanted]
    plan, issues = build_plan(entries, cast, manifest, args.out_dir)

    todo = [p for p in plan if p["action"] == "synth"]
    skipped = len(plan) - len(todo)
    if args.dry_run:
        for item in plan:
            print("[cue] %s %s %s" % (item["action"], item["voice"], item["source"]))
        for source, voice, reason in issues:
            print("[cue] issue %s %s %s" % (voice, source, reason))
        print("[cue] 条目 %d，待合成 %d，跳过 %d，未配置 %d"
              % (len(plan), len(todo), skipped, len(issues)))
        return 0

    results = run_plan(todo, args.out_dir, key, ffmpeg, args.concurrency,
                       manifest=manifest, manifest_path=args.manifest, ffprobe=ffprobe)

    ok = sum(1 for v in results.values() if v[0] == "ok")
    failed = len(results) - ok
    for source, voice, reason in issues:
        print("[cue] issue %s %s %s" % (voice, source, reason))
    print("[cue] 条目 %d，合成 %d，跳过 %d，失败 %d，未配置 %d"
          % (len(plan), ok, skipped, failed, len(issues)))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

