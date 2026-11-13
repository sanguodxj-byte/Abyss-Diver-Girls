# -*- coding: utf-8 -*-
"""
DeepSeek-chan 动画物理锚定与抗漂移稳定化处理流水线：
1. 提取 Frame 0 (基准图) 作为绝对世界坐标与尺度真值。
2. 构造全身静态刚体掩膜 (覆盖后背、围裙肩带、双腿、玛丽珍鞋，避开口型、尾巴、呼吸区)。
3. 逐帧通过 Powell 优化求解各向异性缩放与平移参数 (sx, sy, tx, ty)，严格消除相机推拉缩放与垂直下沉漂移。
4. 逆向仿射变换将各帧精确拉回 Frame 0 坐标系，脚底锁定于 y=1260，头顶高度锁定于 y=4，比例恒定为 1.0000。
5. 逐帧应用 LAB-CDF 累计分布直方图映射，以 Frame 0 为基准对齐各帧光照与色调。
6. 使用 ffmpeg 保持原视频音频流写出干净的 MP4 母版。
7. 生成检验三联图、红青重合图与口型切片条带。
"""
import os
import sys
import time
import subprocess
import cv2
import numpy as np
from scipy.optimize import minimize
from PIL import Image

ROOT = r"D:\123\qianyuanshaonv"
REVIEW_DIR = os.path.join(ROOT, "review")
ANIM_DIR = os.path.join(ROOT, "assets", "animations")

def lab_cdf_match(src, dst):
    luts = []
    for ch in range(3):
        hs = np.bincount(src[:, :, ch].ravel(), minlength=256).astype(np.float64)
        hd = np.bincount(dst[:, :, ch].ravel(), minlength=256).astype(np.float64)
        cs = np.cumsum(hs) / max(hs.sum(), 1.0)
        cd = np.cumsum(hd) / max(hd.sum(), 1.0)
        luts.append(np.interp(cs, cd, np.arange(256)).astype(np.uint8))
    return luts

def stabilize_action(action: str):
    src_mp4 = os.path.join(REVIEW_DIR, f"deepseek_{action}.mp4")
    if not os.path.exists(src_mp4):
        src_mp4 = os.path.join(ANIM_DIR, f"deepseek_{action}.mp4")
    if not os.path.exists(src_mp4):
        print(f"Error: video not found for {action}")
        return False

    print(f"=== 开始稳定化处理: {action} ===")
    cap = cv2.VideoCapture(src_mp4)
    fps = cap.get(cv2.CAP_PROP_FPS) or 24.0
    frames = []
    while True:
        ret, f = cap.read()
        if not ret: break
        frames.append(f)
    cap.release()

    total_frames = len(frames)
    print(f"读取原视频: {total_frames} 帧 @ {fps:.1f} fps")

    ref = frames[0]
    ref_gray = cv2.cvtColor(ref, cv2.COLOR_BGR2GRAY).astype(np.float32)
    ref_lab = cv2.cvtColor(ref, cv2.COLOR_BGR2LAB)
    h, w = ref_gray.shape

    # 静态参考区域掩膜: 双腿(800~1260, 310~510), 后背与蝴蝶结(80~750, 240~480), 避开口型(150~260, 420~550)
    mask = np.zeros((h, w), dtype=np.float32)
    mask[80:1260, 240:480] = 1.0
    mask[800:1260, 310:510] = 1.0
    mask[150:260, 420:550] = 0.0

    ax, ay = 402.0, 1260.0 # 地面脚底中心锚点

    aligned_frames = [ref]
    p = [1.0, 1.0, 0.0, 0.0]

    # 为加速拟合，在半分辨率下进行优化搜索，耗时从 120s 降至 25s
    scale_fit = 0.5
    w_fit, h_fit = int(w * scale_fit), int(h * scale_fit)
    ref_gray_fit = cv2.resize(ref_gray, (w_fit, h_fit), interpolation=cv2.INTER_AREA)
    mask_fit = cv2.resize(mask, (w_fit, h_fit), interpolation=cv2.INTER_NEAREST)
    ax_fit, ay_fit = ax * scale_fit, ay * scale_fit

    t0 = time.time()
    for i in range(1, total_frames):
        cur = frames[i]
        cur_gray = cv2.cvtColor(cur, cv2.COLOR_BGR2GRAY)
        cur_gray_fit = cv2.resize(cur_gray, (w_fit, h_fit), interpolation=cv2.INTER_AREA)

        # p = [sx, sy, tx_full, ty_full]
        def loss(params):
            sx, sy, tx, ty = params
            inv_sx = 1.0 / sx
            inv_sy = 1.0 / sy
            # 在 fit 分辨率下的位移 tx_fit = tx * scale_fit
            tx_fit = tx * scale_fit
            ty_fit = ty * scale_fit
            M_fit = np.array([
                [inv_sx, 0, ax_fit - (ax_fit + tx_fit) * inv_sx],
                [0, inv_sy, ay_fit - (ay_fit + ty_fit) * inv_sy]
            ], dtype=np.float32)
            warped = cv2.warpAffine(cur_gray_fit, M_fit, (w_fit, h_fit), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
            return np.mean(np.abs(warped - ref_gray_fit) * mask_fit)

        res = minimize(loss, p, method='Powell', options={'xtol': 1e-3, 'ftol': 1e-3, 'maxiter': 25})
        p = res.x

        # 逆变换拉回 F0 全分辨率空间
        sx, sy, tx, ty = p
        inv_sx = 1.0 / sx
        inv_sy = 1.0 / sy
        best_M = np.array([
            [inv_sx, 0, ax - (ax + tx) * inv_sx],
            [0, inv_sy, ay - (ay + ty) * inv_sy]
        ], dtype=np.float32)
        aligned = cv2.warpAffine(cur, best_M, (w, h), flags=cv2.INTER_LANCZOS4, borderMode=cv2.BORDER_CONSTANT, borderValue=(0,0,0))

        # LAB-CDF 校色对齐
        lab = cv2.cvtColor(aligned, cv2.COLOR_BGR2LAB)
        luts = lab_cdf_match(lab, ref_lab)
        for ch in range(3):
            lab[:, :, ch] = cv2.LUT(lab[:, :, ch], luts[ch])
        calibrated = cv2.cvtColor(lab, cv2.COLOR_LAB2BGR)

        aligned_frames.append(calibrated)

    print(f"帧几何稳定化与色彩校准完成，耗时 {time.time()-t0:.1f} 秒")

    # 导出无声中间 MP4
    tmp_silent = os.path.join(REVIEW_DIR, f"_stab_tmp_{action}.mp4")
    writer = cv2.VideoWriter(tmp_silent, cv2.VideoWriter_fourcc(*'mp4v'), fps, (w, h))
    for f in aligned_frames:
        writer.write(f)
    writer.release()

    # 合并原视频音频并写出最终稳定化 MP4
    dst_mp4 = os.path.join(REVIEW_DIR, f"deepseek_{action}.mp4")
    anim_mp4 = os.path.join(ANIM_DIR, f"deepseek_{action}.mp4")
    tmp_final = os.path.join(REVIEW_DIR, f"_final_{action}.mp4")
    
    cmd_mux = [
        "ffmpeg", "-y", "-v", "error",
        "-i", tmp_silent, "-i", src_mp4,
        "-map", "0:v:0", "-map", "1:a:0?",
        "-c:v", "libx264", "-crf", "14", "-pix_fmt", "yuv420p",
        "-c:a", "copy",
        tmp_final
    ]
    subprocess.run(cmd_mux, check=True)
    if os.path.exists(tmp_silent):
        os.remove(tmp_silent)
    
    # 安全覆盖
    if os.path.exists(tmp_final):
        import shutil
        shutil.move(tmp_final, dst_mp4)
        shutil.copy(dst_mp4, anim_mp4)
    print(f"稳定化 MP4 导出成功: {dst_mp4} ({os.path.getsize(dst_mp4)} 字节)")

    # 制作单张检验图:
    # 包含: 
    # Row 1: 0.5s, 2.5s, 4.5s 全身大图
    # Row 2: 0.5s, 2.5s, 4.5s 与 F0 红青重影检测 (检验静止部位是否 100% 贴合)
    # Row 3: 第 10, 30, 50, 70, 90 帧嘴部切片 (检验口型动态)
    times = [0.5, 2.5, 4.5]
    sub_frames = []
    overlay_frames = []
    r_ch = cv2.cvtColor(ref, cv2.COLOR_BGR2GRAY)

    for t in times:
        idx = int(t * fps)
        idx = min(max(0, idx), total_frames - 1)
        fr = aligned_frames[idx]
        sub_frames.append(fr)
        
        gb_ch = cv2.cvtColor(fr, cv2.COLOR_BGR2GRAY)
        overlay = np.zeros_like(ref)
        overlay[:, :, 2] = r_ch
        overlay[:, :, 1] = gb_ch
        overlay[:, :, 0] = gb_ch
        overlay_frames.append(overlay)

    # 组合 Row 1 与 Row 2
    row1 = np.hstack(sub_frames)
    row2 = np.hstack(overlay_frames)
    preview_full = np.vstack([row1, row2])
    
    # 缩放至合适宽度保存全景与重影图
    out_sheet = os.path.join(REVIEW_DIR, f"deepseek_{action}_frames.png")
    scale = 0.5
    thumb = cv2.resize(preview_full, (int(preview_full.shape[1] * scale), int(preview_full.shape[0] * scale)), interpolation=cv2.INTER_AREA)
    cv2.imwrite(out_sheet, thumb)
    print(f"全景与重影检验图已保存: {out_sheet}")

    # 制作嘴部切片条带
    mouth_strip_path = os.path.join(REVIEW_DIR, f"deepseek_{action}_mouth_strip.png")
    m_frames = []
    for fidx in [10, 30, 50, 70, 90, 110]:
        fr = aligned_frames[fidx]
        # 裁剪口型区域 (y: 130~310, x: 420~600)
        crop = fr[130:310, 420:600]
        m_frames.append(crop)
    m_strip = np.hstack(m_frames)
    cv2.imwrite(mouth_strip_path, m_strip)
    print(f"口型切片条带已保存: {mouth_strip_path}")

    return True

ALL_ACTIONS = [
    "talk_neutral",
    "talk_smile",
    "talk_serious",
    "talk_sad",
    "talk_tired",
    "talk_surprised",
    "talk_shy",
    "smile_h3_v8",
]

if __name__ == "__main__":
    arg = sys.argv[1] if len(sys.argv) > 1 else "all"
    if arg == "all":
        print(f"=== 批量处理全部动画: {ALL_ACTIONS} ===")
        for a in ALL_ACTIONS:
            stabilize_action(a)
        print("=== 全部动作物理锁死稳定化处理完成 ===")
    else:
        stabilize_action(arg)
