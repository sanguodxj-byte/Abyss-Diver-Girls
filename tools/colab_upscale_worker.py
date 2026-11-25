# -*- coding: utf-8 -*-
"""在 Colab GPU 上运行 RealESRGAN_x4plus_anime_6B 2x 超分（4x 推理后 Lanczos 缩至精确 2x）。

纯 PyTorch 实现 RRDBNet(num_block=6, scale=4)，无需安装 basicsr/realesrgan 额外依赖。
"""

import argparse
from pathlib import Path
import urllib.request

import numpy as np
from PIL import Image
import torch
import torch.nn as nn
import torch.nn.functional as F

WEIGHT_URL = (
    "https://github.com/xinntao/Real-ESRGAN/releases/download/"
    "v0.2.2.4/RealESRGAN_x4plus_anime_6B.pth"
)


class ResidualDenseBlock(nn.Module):
    def __init__(self, num_feat: int = 64, num_grow_ch: int = 32):
        super().__init__()
        self.conv1 = nn.Conv2d(num_feat, num_grow_ch, 3, 1, 1)
        self.conv2 = nn.Conv2d(num_feat + num_grow_ch, num_grow_ch, 3, 1, 1)
        self.conv3 = nn.Conv2d(num_feat + 2 * num_grow_ch, num_grow_ch, 3, 1, 1)
        self.conv4 = nn.Conv2d(num_feat + 3 * num_grow_ch, num_grow_ch, 3, 1, 1)
        self.conv5 = nn.Conv2d(num_feat + 4 * num_grow_ch, num_feat, 3, 1, 1)
        self.lrelu = nn.LeakyReLU(negative_slope=0.2, inplace=True)

    def forward(self, x):
        x1 = self.lrelu(self.conv1(x))
        x2 = self.lrelu(self.conv2(torch.cat((x, x1), 1)))
        x3 = self.lrelu(self.conv3(torch.cat((x, x1, x2), 1)))
        x4 = self.lrelu(self.conv4(torch.cat((x, x1, x2, x3), 1)))
        x5 = self.conv5(torch.cat((x, x1, x2, x3, x4), 1))
        return x5 * 0.2 + x


class RRDB(nn.Module):
    def __init__(self, num_feat: int, num_grow_ch: int = 32):
        super().__init__()
        self.rdb1 = ResidualDenseBlock(num_feat, num_grow_ch)
        self.rdb2 = ResidualDenseBlock(num_feat, num_grow_ch)
        self.rdb3 = ResidualDenseBlock(num_feat, num_grow_ch)

    def forward(self, x):
        out = self.rdb1(x)
        out = self.rdb2(out)
        out = self.rdb3(out)
        return out * 0.2 + x


class RRDBNet(nn.Module):
    def __init__(
        self,
        num_in_ch: int = 3,
        num_out_ch: int = 3,
        scale: int = 4,
        num_feat: int = 64,
        num_block: int = 6,
        num_grow_ch: int = 32,
    ):
        super().__init__()
        self.scale = scale
        self.conv_first = nn.Conv2d(num_in_ch, num_feat, 3, 1, 1)
        self.body = nn.Sequential(*[RRDB(num_feat, num_grow_ch) for _ in range(num_block)])
        self.conv_body = nn.Conv2d(num_feat, num_feat, 3, 1, 1)
        self.conv_up1 = nn.Conv2d(num_feat, num_feat, 3, 1, 1)
        self.conv_up2 = nn.Conv2d(num_feat, num_feat, 3, 1, 1)
        self.conv_hr = nn.Conv2d(num_feat, num_feat, 3, 1, 1)
        self.conv_last = nn.Conv2d(num_feat, num_out_ch, 3, 1, 1)
        self.lrelu = nn.LeakyReLU(negative_slope=0.2, inplace=True)

    def forward(self, x):
        feat = self.conv_first(x)
        body_feat = self.conv_body(self.body(feat))
        feat = feat + body_feat
        feat = self.lrelu(self.conv_up1(F.interpolate(feat, scale_factor=2, mode="nearest")))
        feat = self.lrelu(self.conv_up2(F.interpolate(feat, scale_factor=2, mode="nearest")))
        out = self.conv_last(self.lrelu(self.conv_hr(feat)))
        return out


def load_model(weight_path: Path, device: torch.device) -> RRDBNet:
    if not weight_path.exists():
        weight_path.parent.mkdir(parents=True, exist_ok=True)
        print(f"[upscale] downloading {WEIGHT_URL} -> {weight_path}", flush=True)
        urllib.request.urlretrieve(WEIGHT_URL, str(weight_path))
    state = torch.load(str(weight_path), map_location="cpu", weights_only=True)
    if "params_ema" in state:
        state = state["params_ema"]
    elif "params" in state:
        state = state["params"]
    model = RRDBNet(num_in_ch=3, num_out_ch=3, scale=4, num_feat=64, num_block=6, num_grow_ch=32)
    model.load_state_dict(state, strict=True)
    model.eval().to(device)
    if device.type == "cuda":
        model.half()
    return model


@torch.no_grad()
def upscale_tiled(
    model: RRDBNet, img_rgb: Image.Image, device: torch.device, tile: int = 512, pad: int = 32
) -> Image.Image:
    arr = np.asarray(img_rgb, dtype=np.float32) / 255.0
    t = torch.from_numpy(arr).permute(2, 0, 1).unsqueeze(0).to(device)
    if device.type == "cuda":
        t = t.half()

    _, _, h, w = t.shape
    scale = 4
    out = torch.zeros((1, 3, h * scale, w * scale), dtype=torch.float32, device="cpu")

    tiles_x = (w + tile - 1) // tile
    tiles_y = (h + tile - 1) // tile
    for y in range(tiles_y):
        for x in range(tiles_x):
            ofs_x = x * tile
            ofs_y = y * tile
            in_x0 = max(ofs_x - pad, 0)
            in_x1 = min(ofs_x + tile + pad, w)
            in_y0 = max(ofs_y - pad, 0)
            in_y1 = min(ofs_y + tile + pad, h)

            patch = t[:, :, in_y0:in_y1, in_x0:in_x1]
            pred = model(patch).float().clamp(0.0, 1.0).cpu()

            out_x0 = ofs_x * scale
            out_x1 = min(ofs_x + tile, w) * scale
            out_y0 = ofs_y * scale
            out_y1 = min(ofs_y + tile, h) * scale

            crop_x0 = (ofs_x - in_x0) * scale
            crop_x1 = crop_x0 + (out_x1 - out_x0)
            crop_y0 = (ofs_y - in_y0) * scale
            crop_y1 = crop_y0 + (out_y1 - out_y0)

            out[:, :, out_y0:out_y1, out_x0:out_x1] = pred[:, :, crop_y0:crop_y1, crop_x0:crop_x1]

    out_np = (out.squeeze(0).permute(1, 2, 0).numpy() * 255.0 + 0.5).astype(np.uint8)
    return Image.fromarray(out_np, mode="RGB")


def main():
    import shutil
    import zipfile

    cands = [Path("/in_1152.zip"), Path("in_1152.zip"), Path("/content/in_1152.zip")]
    in_zip = next((p for p in cands if p.exists()), Path("/in_1152.zip"))
    print(f"[upscale] cwd={Path.cwd()} in_zip={in_zip} exists={in_zip.exists()}", flush=True)
    in_dir = Path("/tmp/in_1152")
    out_dir = Path("/tmp/out_2304")
    out_zip = Path("/out_2304.zip")
    weight_path = Path("/content/RealESRGAN_x4plus_anime_6B.pth")
    out_scale = 2.0

    if in_zip.exists():
        if in_dir.exists():
            shutil.rmtree(in_dir)
        in_dir.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(in_zip, "r") as zf:
            zf.extractall(in_dir)

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"[upscale] device={device}", flush=True)
    model = load_model(weight_path, device)

    out_dir.mkdir(parents=True, exist_ok=True)

    pngs = sorted(in_dir.glob("*.png"))
    print(f"[upscale] found {len(pngs)} png(s)", flush=True)
    for fp in pngs:
        im = Image.open(fp).convert("RGB")
        w, h = im.size
        im4x = upscale_tiled(model, im, device)
        tw = int(round(w * out_scale))
        th = int(round(h * out_scale))
        if (tw, th) != im4x.size:
            im_out = im4x.resize((tw, th), Image.Resampling.LANCZOS)
        else:
            im_out = im4x
        dst = out_dir / fp.name
        im_out.save(dst, format="PNG")
        print(f"[upscale] {fp.name}: {w}x{h} -> {im_out.size[0]}x{im_out.size[1]} ({dst.stat().st_size} bytes)", flush=True)

    with zipfile.ZipFile(out_zip, "w", compression=zipfile.ZIP_STORED) as zf:
        for fp in sorted(out_dir.glob("*.png")):
            zf.write(fp, arcname=fp.name)
    print(f"[upscale] wrote {out_zip} ({out_zip.stat().st_size} bytes)", flush=True)


if __name__ == "__main__":
    main()
