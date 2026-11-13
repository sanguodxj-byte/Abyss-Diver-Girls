# -*- coding: utf-8 -*-
"""
单次驱动：拉取已完成的 DeepSeek 说话动画，并在队列空闲时提交下一条。
不做任何 waiting / 轮询循环，一次调用只推进一格，适合定时任务反复调用。
"""
import json
import os
import urllib.parse
import urllib.request

ROOT = "D:/123/qianyuanshaonv"
OUT = ROOT + "/review"
IDS = ROOT + "/tools/h3_ds_talk_ids.json"

JOBS = [
    ("talk_neutral", 124, 8811001),
    ("talk_smile", 124, 8811002),
    ("talk_serious", 124, 8811003),
    ("talk_sad", 124, 8811004),
    ("talk_tired", 124, 8811005),
]


def load():
    if os.path.exists(IDS):
        with open(IDS, "r", encoding="utf-8") as f:
            return json.load(f)
    return {}


def save(state):
    with open(IDS, "w", encoding="utf-8") as f:
        json.dump(state, f, ensure_ascii=False, indent=2)


def api(base, path):
    with urllib.request.urlopen(base + path, timeout=30) as r:
        return json.loads(r.read().decode())


def main():
    with open(ROOT + "/tools/art_host.txt", "r", encoding="utf-8") as f:
        base = f.read().strip()

    state = load()
    history = api(base, "/history")
    queue = api(base, "/queue")
    busy = len(queue.get("queue_running", [])) > 0 or len(queue.get("queue_pending", [])) > 0

    for job, _length, _seed in JOBS:
        rec = state.get(job)
        if not rec or not rec.get("prompt_id"):
            continue
        dst = os.path.join(OUT, "ds_%s.mp4" % job)
        if os.path.exists(dst):
            continue
        info = None
        entry = history.get(rec["prompt_id"])
        if entry:
            for node_out in entry.get("outputs", {}).values():
                for key in ("images", "videos", "gifs"):
                    for cand in node_out.get(key, []):
                        if cand.get("filename", "").endswith((".mp4", ".webm")):
                            info = cand
                            break
                    if info:
                        break
                if info:
                    break
        if info:
            q = urllib.parse.urlencode({
                "filename": info["filename"],
                "subfolder": info.get("subfolder", ""),
                "type": "output",
            })
            urllib.request.urlretrieve(base + "/view?" + q, dst)
            print("[下载] %s" % job)

    if busy:
        print("队列忙，暂不提交")
        return

    delivered = sum(1 for j, _l, _s in JOBS if os.path.exists(os.path.join(OUT, "ds_%s.mp4" % j)))
    print("已交付 %d/%d" % (delivered, len(JOBS)))

    for job, length, seed in JOBS:
        dst = os.path.join(OUT, "ds_%s.mp4" % job)
        if os.path.exists(dst):
            continue
        rec = state.get(job)
        if rec and rec.get("prompt_id") and rec["prompt_id"] in history:
            continue
        if rec and rec.get("prompt_id"):
            print("%s 已在队列中" % job)
            return
        payload = json.dumps({
            "prompt": build_graph(job, length, seed),
            "client_id": "ds_talk_driver",
        }).encode("utf-8")
        req = urllib.request.Request(base + "/prompt", data=payload,
                                     headers={"Content-Type": "application/json"})
        resp = json.load(urllib.request.urlopen(req, timeout=60))
        state[job] = {"prompt_id": resp.get("prompt_id"), "seed": seed, "length": length}
        save(state)
        print("[提交] %s -> %s" % (job, resp.get("prompt_id")))
        return

    print("全部完成")


def build_graph(job, length, seed):
    with open(ROOT + "/tools/h3_ds_anim.py", "r", encoding="utf-8") as f:
        src = f.read()
    ns = {"__name__": "h3mod"}
    exec(compile(src, "h3_ds_anim.py", "exec"), ns)
    return ns["graph"](job, length, seed)


if __name__ == "__main__":
    main()
