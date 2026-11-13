import os, sys, glob, subprocess, tempfile
import cv2
import numpy as np

action = sys.argv[1] if len(sys.argv) > 1 else "smile"
pattern = f"/content/ComfyUI/output/video/deepseek_{action}_*.mp4" if not action.startswith("talk_") else f"/content/ComfyUI/output/video/deepseek_{action}*.mp4"
cands = sorted(glob.glob(pattern), key=os.path.getmtime)
if not cands:
    cands = sorted(glob.glob(f"/content/ComfyUI/output/video/*{action}*.mp4"), key=os.path.getmtime)
video_in = cands[-1]
print('SRC:', video_in)

def lab_cdf_match(src, dst):
    luts = []
    for ch in range(3):
        hs = np.bincount(src[:, :, ch].ravel(), minlength=256).astype(np.float64)
        hd = np.bincount(dst[:, :, ch].ravel(), minlength=256).astype(np.float64)
        cs = np.cumsum(hs) / max(hs.sum(), 1)
        cd = np.cumsum(hd) / max(hd.sum(), 1)
        luts.append(np.interp(cs, cd, np.arange(256)).astype(np.uint8))
    return luts

cap = cv2.VideoCapture(video_in)
frames = []
while True:
    ok, f = cap.read()
    if not ok:
        break
    frames.append(f)
cap.release()
print('frames:', len(frames))

# 以第一帧（首帧参考图）为色彩真值基准目标，消除各帧光照漂移
ref_lab = cv2.cvtColor(frames[0], cv2.COLOR_BGR2LAB)

tmp = tempfile.mkdtemp(prefix='dslab_')
for i, f in enumerate(frames):
    lab = cv2.cvtColor(f, cv2.COLOR_BGR2LAB)
    luts = lab_cdf_match(lab, ref_lab)
    for ch in range(3):
        lab[:, :, ch] = cv2.LUT(lab[:, :, ch], luts[ch])
    cv2.imwrite(os.path.join(tmp, f"{i:05d}.png"), cv2.cvtColor(lab, cv2.COLOR_LAB2BGR))

silent = os.path.join(tmp, 'silent.mp4')
subprocess.run(['ffmpeg', '-y', '-v', 'error', '-framerate', '24',
                '-i', os.path.join(tmp, '%05d.png'), '-c:v', 'libx264', '-crf', '14',
                '-pix_fmt', 'yuv420p', silent], check=True)

out_path = f"/content/deepseek_{action}.ogv"
subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', silent, '-i', video_in,
                '-map', '0:v:0', '-map', '1:a:0?', '-c:v', 'libtheora', '-q:v', '7',
                '-c:a', 'libvorbis', '-q:a', '5', out_path], check=True)
print('OGV_DONE', out_path, os.path.getsize(out_path))
