"""用 Flow Music 生成十二个音乐槽，统一响度并转成 ogg。

依赖本机的 flowmusic skill（C:\\Users\\Administrator\\.agents\\skills\\flowmusic）。
流程：逐首调用 CLI 生成 wav → ffmpeg 按目标响度归一并转 ogg → 放进 assets\\audio\\music\\。
已存在且文件大于 20KB 的槽会跳过，方便中途重跑。

用法：python tools\\music_gen.py [槽 id ...]
"""

import json
import os
import subprocess
import sys

SKILL = r"C:\Users\Administrator\.agents\skills\flowmusic"
CLI = r"C:\Users\Administrator\AppData\Roaming\npm\flowmusic.cmd"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "audio", "music")
TMP_DIR = os.path.join(os.environ.get("TEMP", "."), "abyss_music")

# id, 提示词, 时长秒, 目标 LUFS
CUES = [
    ("menu", "Japanese light-novel main theme, 72 bpm, D major, felt piano stating a five-note motif D A F sharp E D, "
             "music box doubling the melody, warm analog pad, muted bass, brushed kick, almost no drums, gentle nostalgic "
             "and hopeful, seamless loop feel, no vocals", 100, -20),
    ("hangar", "warm airship hangar theme, 78 bpm, D major, celesta and round analog bass playing a five-note motif, "
               "brushed shuffle, soft shaker, homely and safe after a mission, instrumental, seamless loop feel", 100, -20),
    ("greyport_explore", "rain-soaked ruined river port ambience, F sharp minor, no intro, the eerie motif is present "
                         "from the very first bar, sparse felt piano slowly playing D A F sharp E D, distant metal groans, "
                         "wind and dripping water, even energy from start to end, no build-up, seamless loop, instrumental", 120, -19),
    ("ironbelt_explore", "cold industrial wasteland groove, C minor, no intro, mechanical percussion and low synth pulse "
                         "present from the very first bar, even energy throughout, no build-up and no drop, distant factory "
                         "clanks, seamless loop, instrumental", 120, -19),
    ("dustfield_explore", "wide open dry plain, D minor, wind and sparse plucked strings, solo cello fragments, lonely "
                          "and vast, no drums, instrumental", 120, -19),
    ("redlake_explore", "calm unsettling lakeside, G sharp minor, watery reverb, soft echoing plucks, music box with "
                        "delay, foggy ambience, no drums, instrumental", 110, -19),
    ("canyon_explore", "claustrophobic deep canyon ambience, 60 bpm, E minor, slowly evolving low drone, rubble echo, "
                       "sparse felt piano far away in reverb clearly playing the five-note motif D A F sharp E D, "
                       "dripping water, distant rock groans, no drums, no resolution, instrumental", 110, -19),
    ("combat", "post-apocalyptic wasteland combat, 100 bpm, E phrygian, distorted electric guitar drone, "
               "scrap metal percussion, marching snare rolls, deep sub drone, radio static swells, desperate and "
               "grim but never heroic, no synth lead, no electronic dance beat, seamless loop feel, instrumental", 90, -16),
    ("boss", "colossal threat theme, 84 bpm, C sharp phrygian, low distorted bass drone, industrial metal hits, "
             "sheet-metal booms like timpani, dissonant string clusters swelling, faint distorted radio voices, "
             "overwhelming and grim, no epic brass fanfare, seamless loop feel, instrumental", 90, -16),
    ("extract", "extraction countdown under a hostile sky, 120 bpm, D phrygian, ticking metallic percussion, low "
                "pulsing drone, sparse distorted guitar chords, rising urgency without resolution, no melodic lead, "
                "seamless loop feel, instrumental", 60, -17),
    ("result_success", "intimate mission success, 70 bpm, D major, solo felt piano clearly stating the five-note motif "
                       "D A F sharp E D, soft ukulele strumming, music box doubling the melody, small warm room reverb, "
                       "quiet relief rather than triumph, no big strings, no orchestra swell, natural ending, instrumental", 45, -17),
    ("result_fail", "mission failure stinger, music box plays a slowed fractured motif, sparse and melancholic, "
                    "fades out naturally, no loop, instrumental", 40, -17),
    ("abyss_maw_explore", "deep abyssal hive descent, G sharp locrian, sub-bass drone with a slow breathing pulse, "
                          "crystalline chimes far away, distant chitin clicks and dripping water, immense cathedral "
                          "reverb, sparse felt piano slowly playing the five-note motif D A F sharp E D, no drums, "
                          "seamless loop, instrumental", 120, -19),
]


def generate(cue_id, prompt, duration):
    """调 flowmusic CLI 生成一首，返回下载到的 wav 路径。"""
    os.makedirs(TMP_DIR, exist_ok=True)
    cmd = [CLI, "gen", prompt, "--instrumental", "--length", str(duration),
           "--title", "abyss_" + cue_id, "--json", "-o", TMP_DIR]
    proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=900)
    if proc.returncode != 0:
        raise RuntimeError("cli 退出码 %d：%s" % (proc.returncode, (proc.stderr or "")[-400:]))
    out = (proc.stdout or "").strip()
    start = out.find("{")
    if start < 0:
        raise RuntimeError("没找到 JSON 输出：" + out[-300:])
    data = json.loads(out[start:])
    songs = data.get("songs") or []
    if not songs:
        raise RuntimeError("没有返回歌曲：" + out[:300])
    path = songs[0].get("file") or songs[0].get("wav_url") or ""
    if not path or not os.path.exists(path):
        raise RuntimeError("返回的路径不存在：" + str(path))
    return path, songs[0]


def to_ogg(src, dst, lufs):
    """按目标响度归一，转 ogg。"""
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    tmp = dst + ".tmp.ogg"
    cmd = ["ffmpeg", "-y", "-i", src,
           "-af", "loudnorm=I=%s:TP=-1.5:LRA=11" % lufs,
           "-c:a", "libvorbis", "-q:a", "6", tmp]
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
    if proc.returncode != 0 or not os.path.exists(tmp):
        raise RuntimeError("转码失败：" + (proc.stderr or "")[-300:])
    os.replace(tmp, dst)


def main(argv):
    want = set(argv)
    done, skipped, failed = [], [], []
    for cue_id, prompt, duration, lufs in CUES:
        if want and cue_id not in want:
            continue
        dst = os.path.join(OUT_DIR, cue_id + ".ogg")
        if os.path.exists(dst) and os.path.getsize(dst) > 20000:
            skipped.append(cue_id)
            print("跳过（已存在）", cue_id, flush=True)
            continue
        try:
            print("生成中", cue_id, flush=True)
            src, meta = generate(cue_id, prompt, duration)
            to_ogg(src, dst, lufs)
            size = os.path.getsize(dst)
            print("完成", cue_id, "%d KB" % (size // 1024), "标题", meta.get("title"), flush=True)
            done.append(cue_id)
        except Exception as e:
            print("失败", cue_id, repr(e)[:300], flush=True)
            failed.append(cue_id)
    print(json.dumps({"done": done, "skipped": skipped, "failed": failed}, ensure_ascii=False))
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
