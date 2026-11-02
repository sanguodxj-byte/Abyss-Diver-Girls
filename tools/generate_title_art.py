"""生成主界面艺术标题「潜渊少女」生图脚本。
包含 txt2img 与基于高精度排版的 img2img 两种模式，严格遵从：
- 军事工业风
- 灰黑（装甲碳素/暗钛合金）
- 橙黄线条（战术警戒/高亮刻线）
- 隐约的紫色微光（边缘紫外荧光/幽暗微辉）
"""
import os
import sys
import subprocess

ROOT = r"D:\123\qianyuanshaonv"
PYTHON = sys.executable
ART_MOSS = os.path.join(ROOT, "tools", "art_moss.py")
REVIEW_DIR = os.path.join(ROOT, "review")

def run_img2img():
    init_path = os.path.join(REVIEW_DIR, "title_base_stencil.png")
    out_path = os.path.join(REVIEW_DIR, "title_art_img2img.png")
    prompt = (
        'masterpiece, high quality graphic design, military industrial mech title typography "潜渊少女", '
        'Chinese characters, gunmetal gray armor plates, dark carbon composite, weathered titanium bevels, '
        'tactical hazard orange-yellow warning stripes, subtle ethereal violet neon edge glow, '
        'faint ultraviolet luminescence, clean black background, sharp graphic design, no humans, no character, no scenery'
    )
    cmd = [
        PYTHON, ART_MOSS, "img2img",
        "--init", init_path,
        "--prompt", prompt,
        "--denoise", "0.40",
        "--steps", "35",
        "--cfg", "3.2",
        "--width", "1024",
        "--height", "512",
        "--out", out_path
    ]
    print("Running img2img title generation...")
    res = subprocess.run(cmd)
    if res.returncode == 0:
        print("img2img successfully saved to:", out_path)
    else:
        print("img2img failed with code:", res.returncode)

def run_txt2img():
    out_path = os.path.join(REVIEW_DIR, "title_art_txt2img.png")
    prompt = (
        'masterpiece, highest quality graphic design, bold Chinese text "潜渊少女", 4 Chinese characters only, '
        'military industrial mech typography, heavy dark gunmetal armor plates, dark carbon gray metal, '
        'chamfered metallic edges, tactical hazard yellow-orange accent lines, vibrant amber warning stripes, '
        'faint subtle ethereal violet edge glow, dark purple luminescence, cybernetic sci-fi stencil typography, '
        'isolated on pure black background, graphic design, vector sharpness, no humans, no character, no face, no scenery'
    )
    cmd = [
        PYTHON, ART_MOSS, "txt2img",
        "--prompt", prompt,
        "--steps", "35",
        "--cfg", "3.5",
        "--width", "1024",
        "--height", "512",
        "--out", out_path
    ]
    print("Running txt2img title generation...")
    res = subprocess.run(cmd)
    if res.returncode == 0:
        print("txt2img successfully saved to:", out_path)
    else:
        print("txt2img failed with code:", res.returncode)

if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "img2img"
    if mode == "img2img":
        run_img2img()
    elif mode == "txt2img":
        run_txt2img()
    elif mode == "all":
        run_img2img()
        run_txt2img()
