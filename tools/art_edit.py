"""局部重绘与图生图：表情差分、局部修改、整图重绘。

局部重绘按蒙版裁出局部、放大到采样分辨率重画，再缩回原位融合；蒙版外像素保持原样，
同一张立绘的各个表情差分可以直接互换。底模与 LoRA 缺省沿用源图 PNG 里记录的生成参数，
画风与源图一致。
"""
import argparse
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

sys.dont_write_bytecode = True  # 工具目录只放源码，同目录模块互相导入时不生成缓存
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art_comfy as ac  # noqa: E402


def box_mask(size, box, grow=0.12, shape="ellipse", feather=0.015):
    """框四周按宽高比例外扩后画实心椭圆或矩形，再按短边比例高斯羽化。"""
    w, h = size
    x0, y0, x1, y1 = box
    gx, gy = (x1 - x0) * grow, (y1 - y0) * grow
    m = Image.new("L", size, 0)
    d = ImageDraw.Draw(m)
    rect = (x0 - gx, y0 - gy, x1 + gx, y1 + gy)
    if shape == "ellipse":
        d.ellipse(rect, fill=255)
    else:
        d.rectangle(rect, fill=255)
    r = feather * min(w, h)
    if r >= 1:
        m = m.filter(ImageFilter.GaussianBlur(r))
    return m


def build(client, a, src_name, mask_name, pos_text, neg_text, seed):
    g = ac.Graph(client)
    model, clip, vae = ac.load_sdxl(g, a.ckpt, a.loras, a.clip_skip)
    pos, neg = ac.encode(g, clip, pos_text), ac.encode(g, clip, neg_text)
    li = g.add("LoadImage", image=src_name)
    if a.mode == "inpaint":
        lm = g.add("LoadImageMask", image=mask_name, channel="red")
        crop = g.add("InpaintCropImproved", image=li[0], mask=lm[0], downscale_algorithm="bilinear",
                     upscale_algorithm="bicubic", preresize=False, mask_fill_holes=True, mask_expand_pixels=0,
                     mask_invert=False, mask_blend_pixels=a.blend, mask_hipass_filter=0.1,
                     extend_for_outpainting=False, context_from_mask_extend_factor=a.context,
                     output_resize_to_target_size=True, output_target_width=a.crop, output_target_height=a.crop,
                     output_padding="32", device_mode="cpu (compatible)")
        # 软蒙版逐步收缩重绘范围，分块编码避免整图 VAE 占满显存
        dm = g.add("DifferentialDiffusion", model=model)[0]
        lat = ac.vae_encode(g, vae, crop[1])
        lat = g.add("SetLatentNoiseMask", samples=lat, mask=crop[2])[0]
        lat = ac.ksample(g, dm, pos, neg, lat, seed, a.steps, a.cfg, a.sampler, a.scheduler, a.denoise)
        dec = ac.vae_decode(g, vae, lat)
        img = g.add("InpaintStitchImproved", stitcher=crop[0], inpainted_image=dec)[0]
    else:
        img = li[0]
        if a.size:
            w, h = ac.parse_size(a.size)
            img = g.add("ImageScale", image=img, upscale_method="lanczos", width=w, height=h, crop="disabled")[0]
        lat = ac.vae_encode(g, vae, img)
        lat = ac.ksample(g, model, pos, neg, lat, seed, a.steps, a.cfg, a.sampler, a.scheduler, a.denoise)
        img = ac.vae_decode(g, vae, lat)
    out = g.add("SaveImage", images=img, filename_prefix="art_tools/edit")
    return g, out


def parse_expr(s):
    """"名字=正面标签|负面标签"，负面部分可省。"""
    name, _, rest = s.partition("=")
    pos, _, neg = rest.partition("|")
    return name.strip(), pos.strip(), neg.strip()


def main():
    ac.stdout_utf8()
    p = argparse.ArgumentParser(description="局部重绘 / 图生图")
    p.add_argument("image")
    p.add_argument("--mode", choices=["inpaint", "img2img"], default="inpaint")
    p.add_argument("--prompt", help="角色身份与画面描述；缺省取源图记录的提示词")
    p.add_argument("--expr", action="append", default=[], help="名字=正面标签|负面标签，可重复，每个出一张差分")
    p.add_argument("--neg", default="")
    p.add_argument("--out", help="单张输出路径")
    p.add_argument("--prefix", help="差分输出前缀，文件名为 前缀_名字.png")
    p.add_argument("--mask", help="灰度蒙版，白色 = 重画区域")
    p.add_argument("--box", help="x0,y0,x1,y1 像素坐标或 0～1 比例")
    p.add_argument("--detect", help="开放词表检测目标，例如 face；与 --mask/--box 三选一")
    p.add_argument("--threshold", type=float, default=0.3)
    p.add_argument("--shape", choices=["ellipse", "rect"], default="ellipse")
    p.add_argument("--grow", type=float, default=0.12, help="框外扩比例")
    p.add_argument("--feather", type=float, default=0.015, help="羽化半径占短边比例")
    p.add_argument("--blend", type=int, default=24, help="缩回原图时的融合像素")
    p.add_argument("--context", type=float, default=1.6, help="裁切上下文相对蒙版的倍数")
    p.add_argument("--crop", type=int, default=768, help="局部采样边长")
    p.add_argument("--denoise", type=float)
    p.add_argument("--size", help="img2img 先缩放到的尺寸")
    p.add_argument("--ckpt")
    p.add_argument("--lora", action="append")
    p.add_argument("--clip-skip", dest="clip_skip", type=int)
    p.add_argument("--steps", type=int)
    p.add_argument("--cfg", type=float)
    p.add_argument("--sampler")
    p.add_argument("--scheduler")
    p.add_argument("--seed", type=int, help="缺省随机；同一次运行的各差分共用同一种子")
    p.add_argument("--save-mask", dest="save_mask", help="把实际使用的蒙版另存到此路径")
    a = p.parse_args()

    src = Image.open(a.image)
    src.load()
    meta = ac.read_meta(a.image)
    if a.expr and not (a.prefix or a.out):
        p.error("差分需要 --prefix")
    if not a.expr and not a.out:
        p.error("需要 --out")
    a.prompt = a.prompt if a.prompt is not None else meta.get("prompt", "")
    a.steps = a.steps or meta.get("steps", 28)
    a.cfg = a.cfg if a.cfg is not None else meta.get("cfg", 5.5)
    a.sampler = a.sampler or meta.get("sampler", "euler_ancestral")
    a.scheduler = a.scheduler or meta.get("scheduler", "normal")
    a.clip_skip = a.clip_skip if a.clip_skip is not None else meta.get("clip_skip", 0)
    a.denoise = a.denoise if a.denoise is not None else (0.6 if a.mode == "inpaint" else 0.5)

    client = ac.Client()
    if not client.online():
        print("生图服务 %s 不在线" % client.host, file=sys.stderr)
        return 2
    a.ckpt = ac.ckpt_name(client, a.ckpt or meta.get("ckpt"))
    if a.lora is not None:
        a.loras = ac.parse_loras(client, a.lora)
    elif "loras" in meta:
        a.loras = [tuple(x) for x in meta["loras"]]
    else:
        a.loras = ac.parse_loras(client, ac.DEFAULT_LORAS)

    box = None
    mask_name = None
    if a.mode == "inpaint":
        if a.mask:
            m = Image.open(a.mask).convert("L").resize(src.size)
        else:
            if a.box:
                box = ac.parse_box(a.box, src.size)
            elif a.detect:
                saved_box = meta.get("box") if a.detect == "face" else None
                if isinstance(saved_box, list) and len(saved_box) == 4:
                    box = tuple(int(x) for x in saved_box)
                else:
                    box = ac.detect_box(client, src, a.detect, a.threshold)
                    if box is None:
                        print("没有检测到「%s」" % a.detect, file=sys.stderr)
                        return 3
                    if a.detect == "face" and meta:
                        meta["box"] = list(box)
                        ac.save_png(src, a.image, meta)
            else:
                p.error("局部重绘需要 --mask、--box 或 --detect")
            m = box_mask(src.size, box, a.grow, a.shape, a.feather)
        if a.save_mask:
            ac.save_png(m, a.save_mask)
        mask_name = client.upload(m, "mask.png")
    alpha = src.getchannel("A") if src.mode == "RGBA" else None
    src_name = client.upload(ac.flatten(src), "src.png")

    seed = a.seed if a.seed is not None else ac.new_seed()
    variants = [parse_expr(e) for e in a.expr] or [("", "", "")]
    for name, etags, eneg in variants:
        pos_text = ac.pos_prompt(ac.join_tags(a.prompt, etags))
        neg_text = ac.neg_prompt(ac.join_tags(a.neg, eneg))
        g, out = build(client, a, src_name, mask_name, pos_text, neg_text, seed)
        res = client.run(g)
        imgs = res.images(out)
        if not imgs:
            raise ac.ComfyError("任务完成但没有取到输出图")
        im = imgs[0]
        if alpha is not None and im.size == src.size:
            im = im.convert("RGBA")
            im.putalpha(alpha)
        if name:
            base = a.prefix or os.path.splitext(a.out)[0]
            dst = "%s_%s.png" % (base, name)
        else:
            dst = a.out
        info = {"tool": "art_edit", "mode": a.mode, "source": os.path.basename(a.image), "prompt": a.prompt,
                "expr": name, "expr_tags": etags, "positive": pos_text, "negative": neg_text, "ckpt": a.ckpt,
                "loras": a.loras, "seed": seed, "denoise": a.denoise, "steps": a.steps, "cfg": a.cfg,
                "sampler": a.sampler, "scheduler": a.scheduler, "clip_skip": a.clip_skip, "box": box,
                "shape": a.shape, "grow": a.grow, "feather": a.feather, "crop": a.crop, "context": a.context}
        ac.save_png(im, dst, info)
        print(json.dumps({"out": os.path.abspath(dst), "expr": name, "seed": seed, "box": box,
                          "size": list(im.size), "wall_s": round(res.wall, 1), "run_s": round(res.run, 1)},
                         ensure_ascii=False), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
