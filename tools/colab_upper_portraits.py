# -*- coding: utf-8 -*-
r"""通过 Colab GPU Studio (moss-image-sft-t2i) 生成全员 11 位角色高分辨率完整上半身立绘。

严格沿用已验收的 3 号画风亚人版 MOSS-Image SFT 正负提示词与画风栈，
将构图从紧裁胸像升级为完整上半身（头顶耳/角/羽翼、全发丝与双臂双手均 100% 在画框内无截断），
并将分辨率拉高至 1280x1280（1:1 宽幅防左右裁切），输出到 review\<角色名>_上半身立绘.png。
"""

import argparse
import os
from pathlib import Path
import shutil
import sys
import time
import uuid

STUDIO_ROOT = Path(r"D:\123\colab-gpu-studio")
PROJ_ROOT = Path(r"D:\123\qianyuanshaonv")
REV_DIR = PROJ_ROOT / "review"
PORTRAITS_DIR = PROJ_ROOT / "assets" / "portraits"

ACCOUNT_ID = "024839ad-3c12-50c7-baad-58425016c082"
PROJECT_ID = "e9b775eca4004b24984c395f1b109dfb"

STYLE_PREFIX = (
    "masterpiece, best quality, absurdres, highres, newest, year 2025, 1girl, solo, "
    "@liduke, @lm7, @neco, @chuzenji, @alchemaniac, "
    "2d illustration, painterly brushwork, dry matte texture, crisp ink lineart, "
    "muted gritty color palette, hard directional shadows, subtle rim light, "
)

FRAMING_SUFFIX = (
    "upper body standing portrait, waist-up to upper-hips character tachie, "
    "zoomed out neatly with generous empty pure black margin above the very top of ears horns antlers or feathers "
    "and generous empty pure black margin on both left and right sides, "
    "entire head ears horns antlers wings completely inside frame, "
    "all flowing hair strands and hair tips completely inside frame with zero cutoff, "
    "both shoulders both arms elbows and both hands hanging naturally completely inside frame with zero truncation, "
    "clean lower torso cutoff only at upper hips along the bottom border, "
    "looking at viewer at eye level, "
    "lips expressed by a single thin line only, no color fill on lips, lip line only, natural pale matte lips, "
    "pure solid black background, pitch black minimalist background"
)

COMMON_NEG = (
    "cropped, out of frame, cropped ears, cropped horns, cropped antlers, cropped hair, cut off hair, "
    "cut off wings, cut off arms, cut off hands, cut off shoulders, tight framing, close-up, bust shot, "
    "headshot, face close-up, touching frame edge, clipped, hands out of frame, "
    "airbrushed, plastic skin, glossy, soft gradient shading, generic moe, pastel, washed out, faded, overexposed, hazy, "
    "glowing eyes, glowing pupils, neon eyes, laser eyes, shiny plastic, glossy leather, latex, bodysuit, plugsuit, "
    "overly detailed armor, excessive straps, cluttered buckles, cluttered accessories, tactical greebles, messy details, "
    "off-shoulder, bare shoulders, cleavage, heavy blush, grey skin, blue skin, evening gown, ballgown, maid outfit, "
    "casual sweater, kimono, cheongsam, lab coat, apron, overalls, mature face, adult woman, tall mature female, "
    "long jaw, sharp angular chin, long horse face, sunken cheeks, aging, wrinkles, dark circles, milf, middle aged, older woman, "
    "pixel art, 16-bit, chunky pixels, pixelated, 3d, 3d render, realistic photo, photograph, dslr, "
    "lipstick, lip gloss, glossy lips, shiny lips, colored lips, red lips, pink lips, filled lips, painted lips, "
    "shaded lips, lip shading, lip color fill, makeup, id photo, passport photo, mugshot, "
    "front view, rigid pose, stiff pose, symmetrical, standing at attention, perfect symmetry, formal portrait, "
    "lowres, worst quality, low quality, bad anatomy, bad hands, extra digits, fewer digits, extra limbs, extra ears, four ears, "
    "watermark, text, human ears visible, headband, fake ears, headband ears"
)

CHARACTERS = {
    "nao": {
        "name": "奈绪",
        "seed": 3026,
        "desc": (
            "16 years old cute anime girl, youthful delicate face, "
            "tall slender ash-silver rabbit ears on top of head with subtle dark inner ear fur and one ear tip gently angled back, "
            "long ash-silver hair flowing fully inside frame, soft wispy bangs, small silver star-wing hair clip, "
            "pale muted crimson eyes, calm quiet kuudere gaze, "
            "matte jet-black high-collar military tactical jacket worn cleanly on both shoulders, dark-grey horizontal chest stripes, "
            "neat black dual chest harness straps, crisp silver wing-sword emblem on right sleeve, neat waist belt and fingerless black gloves, "
            "three-quarter view, body and face naturally aligned facing slightly to the right, "
        ),
        "extra_neg": "brown hair, blue coat, bunny girl suit",
    },
    "rei": {
        "name": "零",
        "seed": 3043,
        "desc": (
            "16 years old cute anime girl, youthful delicate face, "
            "pointed alert midnight-indigo wolf ears on top of head with pale grey inner fur, "
            "sleek midnight-indigo asymmetric bob hair with crisp bangs, calm muted pale blue eyes, quiet detached gaze, "
            "matte charcoal-grey high-collar military field parka zipped up with hood down and clean white inner collar trim, "
            "single simple black shoulder comms straps, tiny dark triangular silver ID pin on left collar, plain structured charcoal chest, "
            "three-quarter view, body and face naturally aligned facing slightly to the left, "
        ),
        "extra_neg": "white chest logo, giant chest print",
    },
    "kurumi": {
        "name": "胡桃",
        "seed": 3060,
        "desc": (
            "16 years old cute anime girl, youthful delicate face, "
            "tall fluffy copper-brown fox ears on top of head with dark charcoal ear tips and pale cream inner fur, "
            "natural copper-brown messy wolf-cut hair tied in a right-side ponytail completely inside the frame with a thin matte black hairclip, "
            "natural muted olive-amber anime eyes, calm steady expression, "
            "matte dark-olive high-collar military field jacket worn open over a plain charcoal turtleneck, "
            "single neat muted-orange diagonal crossbody strap, small silver compass emblem on right sleeve, small dark hip pouch, "
            "three-quarter view, body and face naturally aligned facing slightly to the right, "
        ),
        "extra_neg": "goggles, bandaid on nose, orange overalls",
    },
    "lina": {
        "name": "莉娜",
        "seed": 3077,
        "desc": (
            "17 years old cute anime girl, youthful delicate face, "
            "a pair of sculpted plush horned-owl feathered ear-tufts made of layered ivory-white and warm golden-brown bird feathers rising naturally from the upper sides of her head, "
            "natural honey-blonde wavy shoulder-length hair tied neatly with a dark navy ribbon at back, "
            "calm muted violet-blue anime eyes, composed earnest gaze, "
            "tailored matte midnight-navy double-breasted military officer field coat worn cleanly over a crisp ivory shirt and plain dark tie, "
            "small clean silver wing lapel pin, pewter double-breasted buttons, "
            "three-quarter view, body and face naturally aligned facing slightly to the right, "
        ),
        "extra_neg": "glasses, spectacles, waist belt over buttons",
    },
    "mia": {
        "name": "米娅",
        "seed": 3094,
        "desc": (
            "16 years old cute anime girl, youthful delicate face, "
            "relaxed slightly lowered dark wine-red cat ears with soft dark inner fur, "
            "dark wine-red slightly tousled hair tied in neat low twin buns completely inside frame with thin matte-bronze hairpins, "
            "drowsy half-lidded muted warm amber eyes, quiet sleepy expression, "
            "matte charcoal-black high-collar military field jacket worn open on both shoulders over a plain dark-crimson utility vest and black turtleneck, "
            "small neat silver wing-gear patch on chest pocket, sturdy work belt, "
            "three-quarter view, body and face naturally aligned facing slightly to the left, "
        ),
        "extra_neg": "green jacket, olive jacket, welding mask, helmet",
    },
    "ajin": {
        "name": "阿堇",
        "seed": 3111,
        "desc": (
            "18 years old cute anime girl, youthful delicate face, "
            "delicate dark-wooden branched deer antlers rising cleanly from her hair with generous empty space above antler tips, "
            "strictly two slender furry dark-brown deer ears angled gently outward at the sides below the antlers, "
            "soft black long straight hair in a neat half-up braid with a plain dark hairpin fully inside frame, "
            "gentle muted amber-brown eyes, calm composed expression, "
            "matte dark-taupe high-collar military greatcoat draped cleanly over a tidy black tactical shirt with one simple brass horizontal collar buckle clasp, "
            "three-quarter view, body and face naturally aligned facing slightly to the left, "
        ),
        "extra_neg": "four ears, second pair of ears, double ears",
    },
    "xiaoman": {
        "name": "小满",
        "seed": 3128,
        "desc": (
            "17 years old cute anime girl, youthful delicate face, "
            "sharp sleek jet-black lynx ears on top of head with distinct thin dark ear tufts and muted teal inner fur tint, "
            "jet-black short bob hair with subtle dark teal-green inner streaks, "
            "sharp natural golden-brown anime eyes, cool calm slight smirk, "
            "matte dark-teal sleeveless high-collar tactical utility vest worn cleanly over a plain black long-sleeve turtleneck, "
            "one single simple black leather strap over her right shoulder only, slim dark belt, "
            "three-quarter view, body and face naturally aligned facing slightly to the right, "
        ),
        "extra_neg": "dual shoulder straps, symmetrical chest harness",
    },
    "shiori": {
        "name": "诗织",
        "seed": 3145,
        "desc": (
            "17 years old cute anime girl, youthful delicate face, "
            "slender curved pale silver-grey ram horns spiraling neatly around her temples completely inside frame, "
            "soft drooping pale-grey caprine ears, pale lavender-grey long straight hair with two thin side braids completely inside frame, "
            "quiet muted violet anime eyes, calm thoughtful gaze, "
            "matte dark-charcoal hooded military rain-poncho cloak with hood down over a plain black high-collar shirt, "
            "continuous draped sleeveless rain-poncho silhouette fully inside left and right edges, one small dark metallic beetle brooch pinned cleanly on front placket, "
            "three-quarter view, body and face naturally aligned facing slightly to the left, "
        ),
        "extra_neg": "wide wizard sleeves, cropped cloak",
    },
    "karasu": {
        "name": "鸦",
        "seed": 3162,
        "desc": (
            "18 years old cute anime girl, youthful delicate face, "
            "long sleek swept-back dark-charcoal avian head-plume feathers with subtle muted crimson-tipped barbs emerging naturally from the upper crown of her hair, "
            "compactly folded layered dark slate-grey and black raven wings tucked neatly behind her shoulders completely inside left and right edges with zero wing cutoff, "
            "jet-black straight hime-cut hair framing her cheeks fully inside frame, calm dark ruby-brown anime eyes, stoic composed expression, "
            "understated matte all-black military trench coat with clean single-layer all-black shoulder cape and one simple dark-crimson braided cord clasp on center chest, "
            "three-quarter view, body and face naturally aligned facing slightly to the right, "
        ),
        "extra_neg": "spread huge wings, red cape lining, bright red clothes",
    },
    "nihong": {
        "name": "霓虹",
        "seed": 3179,
        "desc": (
            "16 years old cute anime girl, youthful delicate face, "
            "tall alert dark slate-grey caracal ears on top of head with fine black tufted tips completely inside frame, "
            "dark slate-grey messy short wolf-cut hair with a pale silver front lock and plain black hairclips, "
            "subtle heterochromatic muted-blue and muted-violet anime eyes, relaxed playful slight smirk, "
            "matte dark-grey hooded military anorak jacket with subtle thin cyan zipper trim over a plain white high-collar turtleneck tee, "
            "tiny matte-black collar comms clip, thin cyan accent on left chest pocket and left sleeve pocket, "
            "three-quarter view, body and face naturally aligned facing slightly to the left, "
        ),
        "extra_neg": "neon glowing outfit, cyberpunk glowing tubes",
    },
    "gin": {
        "name": "银",
        "seed": 3196,
        "desc": (
            "16 years old cute anime girl, youthful delicate face, "
            "slender swept-back dark-obsidian dragon horns with subtle muted burgundy ridges emerging cleanly from her hair completely inside frame, "
            "cool pale silver-grey chin-length bob with clean straight bangs, calm muted burgundy anime eyes, composed cool expression, "
            "tailored matte-black military peacoat with wide lapels worn slightly open showing subtle dark-wine inner collar lining over a plain dark high-collar shirt, antique brass buttons, "
            "three-quarter view, body and face naturally aligned facing slightly to the right, "
        ),
        "extra_neg": "closed uniform without burgundy lining",
    },
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--chars", nargs="+", default=list(CHARACTERS.keys()))
    ap.add_argument("--width", type=int, default=1280)
    ap.add_argument("--height", type=int, default=1280)
    ap.add_argument("--steps", type=int, default=50)
    ap.add_argument("--cfg", type=float, default=3.0)
    ap.add_argument("--shift", type=float, default=5.0)
    ap.add_argument("--seed-offset", type=int, default=0)
    ap.add_argument("--retain-end", action="store_true", help="最后一张跑完后仍保留 VM 供追加")
    ap.add_argument("--resume-job", default="", help="直接续跑已提交的单个 job_id（需仅指定 1 个 --chars）")
    args = ap.parse_args()

    os.chdir(STUDIO_ROOT)
    sys.path.insert(0, str(STUDIO_ROOT / "api"))

    from app.admission import admit_job
    from app.config import settings
    from app.db import Store
    from app.gpu.compute import GpuConfig
    from app.gpu.repository import Repository
    from app.gpu.scheduler import Scheduler, TERMINAL_STATES

    st = Store(os.environ.get("DATABASE_URL", "sqlite:///./data/studio.db"))
    repo = Repository(st)
    cfg = GpuConfig.from_env()
    sched = Scheduler(st, config=cfg)
    user = {"id": "owner"}

    chars = list(args.chars)
    print(f"[colab] starting batch: {chars} size={args.width}x{args.height} steps={args.steps} cfg={args.cfg}", flush=True)

    for idx, cid in enumerate(chars):
        c = CHARACTERS[cid]
        name = c["name"]
        is_last = (idx == len(chars) - 1)
        lifecycle = "retain" if (not is_last or args.retain_end) else "save"
        prompt = STYLE_PREFIX + c["desc"] + FRAMING_SUFFIX
        neg = COMMON_NEG + (", " + c["extra_neg"] if c["extra_neg"] else "")
        seed = c["seed"] + args.seed_offset

        body = {
            "project_id": PROJECT_ID,
            "model_id": "moss-image-sft",
            "workflow_key": "moss-image-sft-t2i",
            "workflow_version": "1.0.0",
            "asset_ids": [],
            "params": {
                "prompt": prompt,
                "negative": neg,
                "width": args.width,
                "height": args.height,
                "steps": args.steps,
                "cfg": args.cfg,
                "shift": args.shift,
                "seed": seed,
            },
            "execution_policy": {
                "provider": "colab",
                "account_id": ACCOUNT_ID,
                "lifecycle": lifecycle,
                "max_runtime_minutes": 40,
            },
        }
        if args.resume_job and idx == 0:
            jid = args.resume_job
            print(f"[{cid}:{name}] resuming existing job={jid}", flush=True)
        else:
            idem = f"upper-2k-{cid}-{args.width}x{args.height}-{seed}-{uuid.uuid4().hex[:8]}"
            job = admit_job(st, user, body, idem)
            jid = job["id"]
            print(f"[{cid}:{name}] admitted job={jid} lifecycle={lifecycle} seed={seed}", flush=True)

        last_state = ""
        last_stage = ""
        t0 = time.time()
        while True:
            sched.tick()
            cur = repo.get("jobs", jid, "owner")
            state = cur.get("state", "")
            stage = cur.get("stage_text") or cur.get("stage") or ""
            if state != last_state or stage != last_stage:
                print(f"[{cid}:{name}] {round(time.time() - t0, 1)}s state={state} stage={stage}", flush=True)
                last_state, last_stage = state, stage
            if state in TERMINAL_STATES:
                break
            time.sleep(3)

        if cur.get("state") != "completed":
            print(f"[{cid}:{name}] FAILED: {cur.get('error') or cur.get('failure_reason') or cur}", file=sys.stderr, flush=True)
            sys.exit(1)

        out_ids = cur.get("output_asset_ids") or []
        if not out_ids:
            print(f"[{cid}:{name}] FAILED: no output_asset_ids", file=sys.stderr, flush=True)
            sys.exit(1)

        asset = st.get("assets", out_ids[0])
        skey = asset["storage_key"]
        candidates = [
            Path(skey),
            Path(settings.data_dir) / "assets" / skey,
            Path(settings.data_dir) / skey,
            STUDIO_ROOT / "data" / "assets" / skey,
            STUDIO_ROOT / "data" / "storage" / skey,
        ]
        src_png = next((p for p in candidates if p.exists()), None)
        if src_png is None:
            print(f"[{cid}:{name}] FAILED: asset file not found for storage_key={skey}", file=sys.stderr, flush=True)
            sys.exit(1)

        out_rev = REV_DIR / f"{name}_上半身立绘.png"
        shutil.copy2(src_png, out_rev)
        print(f"[{cid}:{name}] DONE ({out_rev.stat().st_size} bytes) -> {out_rev}", flush=True)

    print("[colab] ALL REQUESTED CHARACTERS COMPLETED", flush=True)


if __name__ == "__main__":
    main()
