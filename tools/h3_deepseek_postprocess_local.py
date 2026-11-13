# -*- coding: utf-8 -*-
"""
DeepSeek-chan 单条动作后处理：
1. 远程驱动 Colab 执行 LAB-CDF 与 Theora 转码生成 .ogv
2. 下载 .ogv 与 .mp4 到本地 assets/animations
3. 抽三帧生成拼接图保存到 review/deepseek_{action}_frames.png
"""
import os
import subprocess
import sys
from PIL import Image

ROOT = r"D:\123\qianyuanshaonv"
VM_ENCODE_SCRIPT = os.path.join(ROOT, "tools", "vm_ogv_encode.py")
PROXY = "http://127.0.0.1:7897"

def run_postprocess(action: str):
    print(f"=== 开始后处理: {action} ===")
    
    env = os.environ.copy()
    env["HTTP_PROXY"] = PROXY
    env["HTTPS_PROXY"] = PROXY
    env["MSYS_NO_PATHCONV"] = "1"
    env["MSYS2_ARG_CONV_EXCL"] = "*"

    with open(VM_ENCODE_SCRIPT, "r", encoding="utf-8") as f:
        code = f.read()

    # 在代码首部注入参数 action
    injected_code = f"import sys\nsys.argv = ['vm_ogv_encode.py', '{action}']\n" + code
    # 先检查 VM 上是否已经生成好该 ogv
    check_code = f"import os\nprint('EXISTS:', os.path.exists('/content/deepseek_{action}.ogv'))\n"
    cp = subprocess.run(["colab", "exec", "-s", "gen"], input=check_code, text=True, capture_output=True, timeout=30, env=env)
    already_done = "EXISTS: True" in cp.stdout

    if not already_done:
        print("[1/3] 远程驱动 VM 进行 LAB-CDF 校色与 Theora 编码...")
        p = subprocess.run(
            ["colab", "exec", "-s", "gen"],
            input=injected_code,
            text=True,
            capture_output=True,
            timeout=360,
            env=env
        )
        print(p.stdout[-500:])
        if "OGV_DONE" not in p.stdout:
            # 再次检查文件是否实际生成完成
            cp2 = subprocess.run(["colab", "exec", "-s", "gen"], input=check_code, text=True, capture_output=True, timeout=30, env=env)
            if "EXISTS: True" not in cp2.stdout:
                print("VM 侧转码失败:", p.stderr[-300:])
                sys.exit(1)
    else:
        print("[1/3] 远程 ogv 已存在，直接下载...")

    print("[2/3] 从 VM 下载 .ogv 产物到本地...")
    remote_ogv = f"/content/deepseek_{action}.ogv"
    local_ogv = os.path.join(ROOT, "assets", "animations", f"deepseek_{action}.ogv")
    
    env = os.environ.copy()
    env["HTTP_PROXY"] = PROXY
    env["HTTPS_PROXY"] = PROXY
    env["MSYS_NO_PATHCONV"] = "1"
    env["MSYS2_ARG_CONV_EXCL"] = "*"
    
    dl = subprocess.run(
        ["colab", "download", "-s", "gen", remote_ogv, local_ogv],
        env=env,
        capture_output=True,
        text=True,
        timeout=180
    )
    print(dl.stdout.strip())
    
    if not os.path.exists(local_ogv) or os.path.getsize(local_ogv) < 1000:
        print("下载失败或文件为空！")
        sys.exit(1)

    print(f"本地 ogv 已就绪: {local_ogv} ({os.path.getsize(local_ogv)} 字节)")

    print("[3/3] 抽帧生成三联图 (0.5s / 2.5s / 4.5s)...")
    out_sheet = os.path.join(ROOT, "review", f"deepseek_{action}_frames.png")
    frames = []
    for i, t in enumerate(["0.5", "2.5", "4.5"]):
        fpath = os.path.join(ROOT, "review", f"_temp_ds_{action}_f{i}.png")
        subprocess.run(
            ["ffmpeg", "-y", "-v", "error", "-ss", t, "-i", local_ogv, "-frames:v", "1", fpath],
            check=True
        )
        frames.append(Image.open(fpath))
    
    w, h = frames[0].size
    sheet = Image.new("RGB", (w * 3 + 40, h + 20), (20, 20, 20))
    for i, f in enumerate(frames):
        sheet.paste(f, (10 + i * (w + 10), 10))
    sheet.save(out_sheet)
    print(f"三联图生成成功: {out_sheet} ({sheet.size})")

if __name__ == "__main__":
    act = sys.argv[1] if len(sys.argv) > 1 else "talk_neutral"
    run_postprocess(act)
