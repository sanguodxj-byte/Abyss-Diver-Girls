# -*- coding: utf-8 -*-
"""
后台单条动作全流程驱动脚本：
1. 使用 curl 轮询 ComfyUI history 状态直至 prompt_id 完成
2. 通过 ComfyUI view API 下载生成的 mp4 视频到本地
3. 驱动 VM 执行 LAB-CDF 校色与 Theora (.ogv) 编码
4. 从 VM 下载 .ogv 到本地 assets/animations/deepseek_{action}.ogv
5. 本地抽帧（0.5s, 2.5s, 4.5s）生成三联图保存到 review/deepseek_{action}_frames.png
"""
import json
import os
import subprocess
import sys
import time
from PIL import Image

ROOT = r"D:\123\qianyuanshaonv"
ART_HOST_FILE = os.path.join(ROOT, "tools", "art_host.txt")
PROXY = "http://127.0.0.1:7897"
VM_ENCODE_SCRIPT = os.path.join(ROOT, "tools", "vm_ogv_encode.py")

def get_base_url():
    with open(ART_HOST_FILE, "r", encoding="utf-8") as f:
        return f.read().strip()

def wait_for_prompt_curl(prompt_id: str, timeout: int = 900):
    base = get_base_url()
    start_t = time.time()
    print(f"Waiting for prompt {prompt_id} on {base}...")
    while time.time() - start_t < timeout:
        cmd = [
            "curl", "-s", "-m", "15", "-x", PROXY,
            f"{base}/history/{prompt_id}"
        ]
        p = subprocess.run(cmd, capture_output=True, text=True)
        if p.returncode == 0 and prompt_id in p.stdout:
            try:
                data = json.loads(p.stdout)
                if prompt_id in data:
                    print(f"Prompt {prompt_id} completed!")
                    return data[prompt_id]
            except Exception:
                pass
        time.sleep(5)
    raise TimeoutError(f"Prompt {prompt_id} timed out after {timeout}s")

def postprocess(action: str, prompt_data: dict):
    base = get_base_url()
    outputs = prompt_data.get("outputs", {})
    save_node = outputs.get("92", {})
    images = save_node.get("images", [])
    if not images:
        raise RuntimeError("No output video found in prompt data")

    fn = images[0].get("filename")
    sub = images[0].get("subfolder", "video")
    t = images[0].get("type", "output")

    env = os.environ.copy()
    env["HTTP_PROXY"] = PROXY
    env["HTTPS_PROXY"] = PROXY
    env["MSYS_NO_PATHCONV"] = "1"
    env["MSYS2_ARG_CONV_EXCL"] = "*"

    local_mp4 = os.path.join(ROOT, "assets", "animations", f"deepseek_{action}.mp4")
    view_url = f"{base}/view?filename={fn}&subfolder={sub}&type={t}"
    print(f"[1/4] 下载 MP4: {view_url} -> {local_mp4}")
    cmd = ["curl", "-L", "--retry", "5", "--retry-delay", "2", "-m", "120", "-x", PROXY, "-o", local_mp4, view_url]
    cp = subprocess.run(cmd)
    if cp.returncode != 0 or not os.path.exists(local_mp4) or os.path.getsize(local_mp4) < 1000:
        print("Curl view download failed, fallback to colab download...")
        remote_mp4 = f"/content/ComfyUI/output/{sub}/{fn}"
        subprocess.run(["colab", "download", "-s", "gen", remote_mp4, local_mp4], env=env, check=True)
    print(f"MP4 已保存: {local_mp4} ({os.path.getsize(local_mp4)} 字节)")

    env = os.environ.copy()
    env["HTTP_PROXY"] = PROXY
    env["HTTPS_PROXY"] = PROXY
    env["MSYS_NO_PATHCONV"] = "1"
    env["MSYS2_ARG_CONV_EXCL"] = "*"

    # 先清理 VM 侧旧残留 ogv
    clean_cmd = f"import os\nif os.path.exists('/content/deepseek_{action}.ogv'): os.remove('/content/deepseek_{action}.ogv')\n"
    subprocess.run(["colab", "exec", "-s", "gen"], input=clean_cmd, capture_output=True, text=True, env=env)

    print("[2/4] 远程驱动 VM 进行 LAB-CDF 校色与 Theora 编码...")
    with open(VM_ENCODE_SCRIPT, "r", encoding="utf-8") as f:
        vm_code = f.read()
    injected_code = f"import sys\nsys.argv = ['vm_ogv_encode.py', '{action}']\n" + vm_code

    encoded = False
    for attempt in range(1, 4):
        print(f"VM 转码尝试 {attempt}/3...")
        p = subprocess.run(["colab", "exec", "-s", "gen"], input=injected_code, capture_output=True, text=True, timeout=360, env=env)
        if "OGV_DONE" in p.stdout:
            print("VM 侧 OGV 转码成功:", p.stdout.strip()[-200:])
            encoded = True
            break
        chk = subprocess.run(["colab", "exec", "-s", "gen"], input=f"import os\nprint('EXISTS:', os.path.exists('/content/deepseek_{action}.ogv'))\n", capture_output=True, text=True, timeout=30, env=env)
        if "EXISTS: True" in chk.stdout:
            print("VM 侧 OGV 文件已确认存在")
            encoded = True
            break
        time.sleep(3)

    if not encoded:
        raise RuntimeError("VM 侧转码失败！")

    print("[3/4] 从 VM 下载 .ogv 产物到本地...")
    remote_ogv = f"/content/deepseek_{action}.ogv"
    local_ogv = os.path.join(ROOT, "assets", "animations", f"deepseek_{action}.ogv")
    dl = subprocess.run(["colab", "download", "-s", "gen", remote_ogv, local_ogv], env=env, capture_output=True, text=True, timeout=180)
    print(dl.stdout.strip())
    if not os.path.exists(local_ogv) or os.path.getsize(local_ogv) < 1000:
        raise RuntimeError(f"下载 OGV 失败: {local_ogv}")
    print(f"本地 OGV 已就绪: {local_ogv} ({os.path.getsize(local_ogv)} 字节)")

    # 归档到 review 目录
    import shutil
    review_mp4 = os.path.join(ROOT, "review", f"deepseek_{action}.mp4")
    review_ogv = os.path.join(ROOT, "review", f"deepseek_{action}.ogv")
    shutil.copy(local_mp4, review_mp4)
    shutil.copy(local_ogv, review_ogv)

    print("[4/4] 抽帧生成三联图 (0.5s / 2.5s / 4.5s) 与嘴部开合连续帧条带...")
    out_sheet = os.path.join(ROOT, "review", f"deepseek_{action}_frames.png")
    frames = []
    for i, t in enumerate(["0.5", "2.5", "4.5"]):
        fpath = os.path.join(ROOT, "review", f"_temp_ds_{action}_f{i}.png")
        subprocess.run(["ffmpeg", "-y", "-v", "error", "-ss", t, "-i", local_ogv, "-frames:v", "1", fpath], check=True)
        frames.append(Image.open(fpath))

    w, h = frames[0].size
    sheet = Image.new("RGB", (w * 3 + 40, h + 20), (20, 20, 20))
    for i, f in enumerate(frames):
        sheet.paste(f, (10 + i * (w + 10), 10))
    sheet.save(out_sheet)
    print(f"三联图生成成功: {out_sheet} ({sheet.size})")

    # 抽取口型连续切片 (帧 10, 25, 40, 55, 70, 85)
    mouth_strip_path = os.path.join(ROOT, "review", f"deepseek_{action}_mouth_strip.png")
    m_frames = []
    for fidx in [10, 25, 40, 55, 70, 85]:
        mp = os.path.join(ROOT, "review", f"_temp_mouth_{fidx}.png")
        subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", local_ogv, "-vf", f"select=eq(n\\,{fidx}),crop=180:180:420:130", "-vframes", "1", mp], check=True)
        if os.path.exists(mp):
            m_frames.append(Image.open(mp))
    if m_frames:
        mw, mh = m_frames[0].size
        m_strip = Image.new("RGB", (mw * len(m_frames) + (len(m_frames) + 1) * 4, mh + 8), (30, 30, 30))
        for idx, mf in enumerate(m_frames):
            m_strip.paste(mf, (4 + idx * (mw + 4), 4))
        m_strip.save(mouth_strip_path)
        print(f"口型连续切片已保存: {mouth_strip_path}")

def main():
    if len(sys.argv) < 3:
        print("Usage: python runner_talk_action.py <action> <prompt_id>")
        sys.exit(1)
    action = sys.argv[1]
    prompt_id = sys.argv[2]

    prompt_data = wait_for_prompt_curl(prompt_id)
    postprocess(action, prompt_data)
    print(f"ALL_DONE_SUCCESS:{action}")

if __name__ == "__main__":
    main()
