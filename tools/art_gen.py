"""文生图：SDXL 底模 + 可选 LoRA 与高清修复，单张或按任务清单批量出图。

要透明底的素材出图后交给 art_cutout：服务端的原生透明层节点与当前采样核心不兼容，
注入补丁不生效，解码出的是错形张量。

每张图的生成参数写进 PNG 文本块，并在标准输出打印一行 JSON（路径、种子、耗时）。
"""
import argparse
import json
import os
import sys

sys.dont_write_bytecode = True  # 工具目录只放源码，同目录模块互相导入时不生成缓存
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art_comfy as ac  # noqa: E402

DEFAULTS = {
    "size": "portrait", "ckpt": ac.DEFAULT_CKPT, "lora": list(ac.DEFAULT_LORAS), "steps": 28, "cfg": 5.5,
    "sampler": "euler_ancestral", "scheduler": "normal", "seed": None, "count": 1,
    "neg": "", "neg_base": "default", "quality": True, "style": True, "clip_skip": 0,
    "hires": 0.0, "hires_denoise": 0.4, "hires_steps": 18, "upscaler": "",
}


def build(client, job, seed):
    g = ac.Graph(client)
    loras = ac.parse_loras(client, job["lora"])
    ckpt = ac.ckpt_name(client, job["ckpt"])
    model, clip, vae = ac.load_sdxl(g, ckpt, loras, job["clip_skip"])
    pos_text = ac.pos_prompt(job["prompt"], job["quality"], job.get("style", True))
    neg_text = ac.neg_prompt(job["neg"], ac.BASE_NEG if job["neg_base"] == "default" else "", job.get("style", True))
    pos, neg = ac.encode(g, clip, pos_text), ac.encode(g, clip, neg_text)
    w, h = ac.parse_size(job["size"])
    lat = g.add("EmptyLatentImage", width=w, height=h, batch_size=1)[0]
    lat = ac.ksample(g, model, pos, neg, lat, seed, job["steps"], job["cfg"], job["sampler"], job["scheduler"])
    img = ac.vae_decode(g, vae, lat)
    if job["hires"] and job["hires"] > 1.0:
        # 像素空间放大后低噪声重采样，比潜空间放大更少糊边
        tw, th = int(w * job["hires"]) // 8 * 8, int(h * job["hires"]) // 8 * 8
        if job["upscaler"]:
            names = client.choices("UpscaleModelLoader", "model_name")
            um = g.add("UpscaleModelLoader", model_name=ac.resolve(names, job["upscaler"], "放大模型"))[0]
            img = g.add("ImageUpscaleWithModel", upscale_model=um, image=img)[0]
        img = g.add("ImageScale", image=img, upscale_method="lanczos", width=tw, height=th, crop="disabled")[0]
        lat = ac.vae_encode(g, vae, img)
        lat = ac.ksample(g, model, pos, neg, lat, seed + 1, job["hires_steps"], job["cfg"], job["sampler"],
                         job["scheduler"], denoise=job["hires_denoise"])
        img = ac.vae_decode(g, vae, lat)
    out = g.add("SaveImage", images=img, filename_prefix="art_tools/gen")
    meta = {
        "tool": "art_gen", "prompt": job["prompt"], "positive": pos_text, "negative": neg_text,
        "ckpt": ckpt, "loras": loras, "size": [w, h], "steps": job["steps"], "cfg": job["cfg"],
        "sampler": job["sampler"], "scheduler": job["scheduler"], "seed": seed, "clip_skip": job["clip_skip"],
        "hires": job["hires"], "hires_denoise": job["hires_denoise"], "upscaler": job["upscaler"],
    }
    return g, out, meta


def run_job(client, job):
    if not job.get("prompt") or not job.get("out"):
        raise ac.ComfyError("任务缺 prompt 或 out：%s" % json.dumps(job, ensure_ascii=False))
    base_seed = job["seed"] if job["seed"] is not None else ac.new_seed()
    n = max(1, int(job["count"]))
    for i in range(n):
        seed = base_seed + i
        g, out, meta = build(client, job, seed)
        res = client.run(g)
        imgs = res.images(out)
        if not imgs:
            raise ac.ComfyError("任务完成但没有取到输出图")
        path = ac.numbered(job["out"], i, n)
        ac.save_png(imgs[0], path, meta)
        print(json.dumps({"out": os.path.abspath(path), "seed": seed, "size": list(imgs[0].size),
                          "mode": imgs[0].mode, "wall_s": round(res.wall, 1), "run_s": round(res.run, 1)},
                         ensure_ascii=False), flush=True)


def main():
    ac.stdout_utf8()
    p = argparse.ArgumentParser(description="SDXL 文生图")
    p.add_argument("--prompt", help="正面提示词；画质标签与全年龄分级标签自动前置")
    p.add_argument("--out", help="输出 PNG 路径；--count 大于 1 时自动加 _01 序号")
    p.add_argument("--jobs", help="JSON 任务清单：对象数组，键名同本命令的长参数名（下划线形式）")
    p.add_argument("--size", help="portrait/bust/square/landscape/wide/tall 或 WxH，默认 portrait")
    p.add_argument("--ckpt", help="底模文件名或其唯一子串，默认 " + ac.DEFAULT_CKPT)
    p.add_argument("--lora", action="append", help="名字:权重，可重复；未指定时默认挂载全作锁定 LoRA 组")
    p.add_argument("--no-lora", dest="no_lora", action="store_true", help="不挂载默认 LoRA")
    p.add_argument("--steps", type=int)
    p.add_argument("--cfg", type=float)
    p.add_argument("--sampler")
    p.add_argument("--scheduler")
    p.add_argument("--seed", type=int, help="缺省随机；--count 大于 1 时逐张加一")
    p.add_argument("--count", type=int)
    p.add_argument("--neg", help="追加的负面提示词；全年龄负面词总是追加")
    p.add_argument("--neg-base", dest="neg_base", choices=["default", "none"],
                   help="none 时去掉通用画质负面词（其中含 text），字样类素材用")
    p.add_argument("--no-quality", dest="quality", action="store_const", const=False, help="不前置画质标签")
    p.add_argument("--no-style", dest="style", action="store_const", const=False, help="不前置画风标签")
    p.add_argument("--clip-skip", dest="clip_skip", type=int)
    p.add_argument("--hires", type=float, help="高清修复倍率，例如 1.5；0 关闭")
    p.add_argument("--hires-denoise", dest="hires_denoise", type=float)
    p.add_argument("--hires-steps", dest="hires_steps", type=int)
    p.add_argument("--upscaler", help="高清修复前先过的放大模型，例如 AnimeSharp")
    a = p.parse_args()
    cli = {k: v for k, v in vars(a).items() if v is not None and k not in ("jobs", "no_lora")}
    if a.no_lora:
        cli["lora"] = []
    client = ac.Client()
    if not client.online():
        print("生图服务 %s 不在线" % client.host, file=sys.stderr)
        return 2
    if a.jobs:
        with open(a.jobs, encoding="utf-8") as f:
            items = json.load(f)
    else:
        items = [{}]
    for item in items:
        job = dict(DEFAULTS)
        job.update(cli)
        job.update(item)
        run_job(client, job)
    return 0


if __name__ == "__main__":
    sys.exit(main())
