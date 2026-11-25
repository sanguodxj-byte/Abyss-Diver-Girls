# -*- coding: utf-8 -*-
r"""通过 Colab GPU Studio (moss-image-sft-t2i) 生成全员 11 位角色高分辨率完整上半身绿幕立绘。

所有角色特征正向与负向提示词均严格原样沿用 review\<角色名>_3号画风_亚人版.png 元数据，一字不改；
仅调整构图景别（竖版 1024x1536、严格腰部以上上半身、顶/左/右留足余量零截断）与纯平绿幕背景（用于抠图）。
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
TMP_DIR = Path(r"D:\123\tmp")
TMP_DIR.mkdir(parents=True, exist_ok=True)
os.environ["TMP"] = str(TMP_DIR)
os.environ["TEMP"] = str(TMP_DIR)
os.environ["TMPDIR"] = str(TMP_DIR)
os.environ["SQLITE_TMPDIR"] = str(TMP_DIR)

ACCOUNT_ID = "024839ad-3c12-50c7-baad-58425016c082"
PROJECT_ID = "e9b775eca4004b24984c395f1b109dfb"

# 共享画风与中景上半身构图前缀（统一与奈绪/米娅/霓虹相同的中景头身比，三分之四微侧脸 + 自然看镜头）
STYLE_PREFIX = (
    "masterpiece, best quality, absurdres, highres, newest, year 2025, 1girl, solo, "
    "small figure in frame, zoomed out medium shot, waist up, upper body shown down to her upper waist, "
    "upper arms and sleeves cleanly visible along her sides, "
    "horizontally centered and compactly framed within the central-lower 66% of the vertical canvas, "
    "three-quarter view, looking at viewer, direct eye contact with viewer, "
    "negative space, vast empty flat chroma-key green space occupying the top 30% of the canvas well above the highest tips of her ears, horns, or antlers, "
    "torso ending cleanly at her upper waist along the bottom edge, "
    "wide empty flat chroma-key green margins on both the left and right sides outside all hair strands, loose hair wisps, shoulders, and sleeves, "
    "complete head, all hair strands, and both shoulders positioned comfortably inside the frame with zero edge cutoff, "
    "@liduke, @lm7, @neco, @chuzenji, @alchemaniac, "
    "2d illustration, painterly brushwork, dry matte texture, crisp ink lineart, "
    "muted gritty color palette, hard directional shadows, subtle rim light, "
)

STYLE_PREFIX_KARASU = (
    "masterpiece, best quality, absurdres, highres, newest, year 2025, 1girl, solo, "
    "looking at viewer, direct eye contact with viewer, "
    "upper body portrait, three-quarter view, zoomed out slightly, horizontally centered in the vertical frame, "
    "both folded wings tucked closely inward behind her shoulders and completely contained within the central 70% width of the canvas, "
    "negative space, wide empty flat chroma-key green space at the top and wide empty flat chroma-key green borders on both the far left outside her left wing and the far right outside her right wing, "
    "entire head, head plumes, shoulders, and both folded wings completely inside the frame with zero edge cutoff on left, right, or top, "
    "@liduke, @lm7, @neco, @chuzenji, @alchemaniac, "
    "2d illustration, painterly brushwork, dry matte texture, crisp ink lineart, "
    "muted gritty color palette, hard directional shadows, subtle rim light, "
)

# 三分之四微侧脸 + 双眼自然看向观察者 + 中景齐腰上半身构图
FRAMING_SUFFIX_TEMPLATE = (
    "medium shot, waist up, three-quarter view, head and torso angled slightly to the {facing} while her eyes look directly at the viewer, "
    "looking at viewer at eye level, eye contact with viewer, "
    "side hair falling smoothly down over both temples and cheeks completely covering where human ears would be, animal ears only with no human ears, "
    "wide empty green headroom above her ears, horns, or antlers, wide empty flat green margins on both left and right sides, "
    "torso ending cleanly at the upper waist along the bottom edge, zero edge clipping, "
    "lips expressed by a single thin line only, no color fill on lips, lip line only, natural pale matte lips, "
    "pure solid flat chroma-key green screen background, uniform bright #00FF00 green background"
)

FRAMING_SUFFIX_KARASU = (
    "upper body, three-quarter view, head and torso angled slightly to the {facing} while her eyes look directly at the viewer, "
    "looking at viewer at eye level, eye contact with viewer, "
    "both folded wings tucked neatly inward behind her back with wide empty flat green margin between the outer wing edges and the left and right canvas borders, zero wing clipping, "
    "lips expressed by a single thin line only, no color fill on lips, lip line only, natural pale matte lips, "
    "pure solid flat chroma-key green screen background, uniform bright #00FF00 green background"
)

# 原版 3号画风 共享负向（100% 原样保留，绝不在负向中写 staring straight ahead / facing front 以免 CFG 反向把瞳孔推向眼角外侧）
BASE_ORIG_NEG = (
    "airbrushed, plastic skin, glossy, soft gradient shading, generic moe, pastel, washed out, faded, overexposed, hazy, "
    "glowing eyes, glowing pupils, neon eyes, laser eyes, shiny plastic, glossy leather, latex, bodysuit, plugsuit, "
    "overly detailed armor, excessive straps, cluttered buckles, cluttered accessories, tactical greebles, messy details, "
    "off-shoulder, bare shoulders, cleavage, heavy blush, grey skin, blue skin, evening gown, ballgown, maid outfit, "
    "casual sweater, kimono, cheongsam, lab coat, apron, overalls, mature face, adult woman, tall mature female, "
    "long jaw, sharp angular chin, long horse face, sunken cheeks, aging, wrinkles, dark circles, milf, middle aged, older woman, "
    "pixel art, 16-bit, chunky pixels, pixelated, 3d, 3d render, realistic photo, photograph, dslr, "
    "lipstick, lip gloss, glossy lips, shiny lips, colored lips, red lips, pink lips, filled lips, painted lips, "
    "shaded lips, lip shading, lip color fill, makeup, id photo, passport photo, mugshot, "
    "front view, rigid pose, stiff pose, symmetrical, standing at attention, perfect symmetry, centered headshot, formal portrait, "
    "lowres, worst quality, low quality, bad anatomy, bad hands, extra digits, fewer digits, extra limbs, extra ears, four ears, "
    "watermark, text"
)

FRAMING_AND_BG_NEG = (
    "human ear, human ears, visible human ear, exposed human ear, side human ear, four ears, extra ears, "
    "looking away, looking to the side, looking left, looking right, looking off-camera, looking past viewer, averted gaze, averted eyes, side glance, eyes looking away, "
    "from behind, back view, looking over shoulder, back turned, "
    "bust shot, chest up, shoulders up, tight close-up, close-up portrait, headshot, face close-up, extreme close-up, zoomed in, oversized head, large head, big head, large face, "
    "cropped, out of frame, cropped ears, cropped ear tips, cropped horns, cropped antlers, cropped wings, cropped hair, "
    "wing touching left edge, wing touching right edge, wing cut off at side, wide spread wings, open wings, wings extending to border, "
    "ear touching top edge, horn touching top edge, antler touching top edge, head near top edge, "
    "hair touching left edge, hair touching right edge, shoulder touching left edge, shoulder touching right edge, "
    "cut off at top, cut off at side, touching top edge, touching left edge, touching right edge, off-center, leaning to edge, "
    "full body, cowboy shot, waist belt, belt buckle, hips, pelvis, thighs, legs, knees, feet, tiny head, distant figure, "
    "black background, dark background, grey background, gradient background, shadows on background, "
    "green lighting, green tint on skin, green color spill, green rim light"
)

# 以下全部 11 位角色的 desc 与 orig_extra_neg 均逐字复制自 review\<角色名>_3号画风_亚人版.png 元数据
CHARACTERS = {
    "nao": {
        "name": "奈绪",
        "seed": 4026,
        "facing": "right",
        "desc": (
            "16 years old cute anime girl, youthful delicate face, "
            "tall slender ash-silver rabbit ears on top of head with subtle dark inner ear fur and one ear tip gently angled back, "
            "long ash-silver hair, soft wispy bangs, small silver star-wing hair clip, "
            "pale muted crimson eyes, calm quiet kuudere gaze, "
            "matte jet-black high-collar military tactical jacket worn cleanly on both shoulders, "
            "neat black chest rig straps, crisp silver wing-sword emblem on sleeve, "
        ),
        "orig_extra_neg": "brown hair, blue coat, human ears visible, bunny girl suit, headband, fake ears, headband ears",
    },
    "rei": {
        "name": "零",
        "seed": 2083,
        "facing": "left",
        "desc": (
            "16 years old cute anime girl, youthful delicate face, "
            "pointed alert midnight-indigo wolf ears on top of head with pale grey inner fur, "
            "sleek midnight-indigo asymmetric bob hair with crisp bangs, calm muted pale blue eyes, quiet detached gaze, "
            "matte charcoal-grey high-collar military field parka with hood down and clean white inner collar trim, "
            "single simple black shoulder comms strap, tiny silver ID pin on collar, "
        ),
        "orig_extra_neg": "silver hair, white hair, camouflage, eyepatch, glowing visor, ear crystal, human ears visible, headband",
    },
    "kurumi": {
        "name": "胡桃",
        "seed": 2068,
        "facing": "right",
        "desc": (
            "16 years old cute anime girl, youthful delicate face, "
            "tall fluffy copper-brown fox ears on top of head with dark charcoal ear tips and pale cream inner fur, "
            "natural copper-brown messy wolf-cut hair tied in a side ponytail with a thin matte black hairclip, "
            "natural muted olive-amber anime eyes, calm steady expression, "
            "matte dark-olive high-collar military field jacket worn fully on both shoulders over a plain charcoal turtleneck, "
            "single neat muted-orange chest strap, small silver compass emblem on sleeve, "
        ),
        "orig_extra_neg": "overalls, denim, bandage on nose, twin tails, welding goggles, hard hat, neon orange, neon green eyes, choker, human ears visible, headband",
    },
    "lina": {
        "name": "莉娜",
        "seed": 2078,
        "facing": "right",
        "desc": (
            "17 years old cute anime girl, youthful delicate face, "
            "a pair of sculpted plush horned-owl feathered ear-tufts (plumicorns) made of layered ivory-white and warm golden-brown bird feathers rising naturally from the upper sides of her head through her hair, "
            "natural honey-blonde wavy shoulder-length hair with subtle feather-layered tips tied neatly with a dark navy ribbon, "
            "calm muted violet-blue anime eyes, composed earnest gaze, "
            "tailored matte midnight-navy military officer field coat worn cleanly over a crisp ivory tactical shirt and plain dark tie, "
            "small clean silver wing lapel pin, "
        ),
        "orig_extra_neg": "ear wings, wing on ear, small wing on head, hairclip wing, feather barrette, glasses, spectacles, microphone, headset, military cap, peaked cap, ruffles, angel halo, cat ears, fox ears",
    },
    "mia": {
        "name": "米娅",
        "seed": 2094,
        "facing": "left",
        "desc": (
            "16 years old cute anime girl, youthful delicate face, "
            "relaxed slightly lowered dark wine-red cat ears with soft dark inner fur, "
            "dark wine-red slightly tousled hair tied in neat low twin buns with thin matte-bronze hairpins, "
            "drowsy half-lidded muted warm amber eyes, quiet sleepy expression, "
            "matte charcoal-black high-collar military field jacket worn cleanly on both shoulders over a plain dark-crimson utility vest and black turtleneck, "
            "small neat silver wing-gear patch on sleeve, "
        ),
        "orig_extra_neg": "welding mask, goggles, overalls, denim, grease, wrench, hard hat, corset, choker, collarbone exposed, human ears visible, headband",
    },
    "ajin": {
        "name": "阿堇",
        "seed": 2166,
        "facing": "right",
        "desc": (
            "18 years old cute anime girl, youthful delicate face, "
            "long soft drooping warm tea-brown lop ears hanging gently down along both sides of her face past her cheeks from ear level with pale cream inner ear fur, "
            "long sleek dark chestnut-brown straight hair with soft cheek-framing bangs and a plain matte-bronze hairpin, "
            "gentle muted warm amber eyes, calm composed expression, "
            "matte dark-taupe high-collar double-breasted military greatcoat worn cleanly on both shoulders over a tidy black tactical turtleneck with one simple brass collar clasp, "
        ),
        "orig_extra_neg": "antlers, horns, upright ears, standing ears, bunny girl suit, apron, chef hat, kitchen utensils, maid outfit, sweater, cheongsam, frog buttons, human ears visible, headband, fake ears",
    },
    "xiaoman": {
        "name": "小满",
        "seed": 4487,
        "facing": "right",
        "desc": (
            "17 years old cute anime girl, youthful delicate face, "
            "sharp sleek jet-black lynx ears on top of head with distinct thin dark ear tufts and muted teal inner fur tint, "
            "jet-black short bob hair with subtle dark teal-green inner streaks, "
            "sharp natural golden-brown anime eyes, cool calm slight smirk, "
            "matte dark-teal sleeveless tactical utility vest worn cleanly over a plain black long-sleeve turtleneck, "
            "simple black leather shoulder strap, "
        ),
        "orig_extra_neg": "bomber jacket, leather jacket, fur collar, orange scarf, pilot goggles, shell earrings, human ears visible, headband",
    },
    "shiori": {
        "name": "诗织",
        "seed": 2146,
        "facing": "left",
        "desc": (
            "17 years old cute anime girl, youthful delicate face, "
            "slender curved pale silver-grey ram horns swept neatly back from temples and soft drooping pale-grey caprine ears, "
            "pale lavender-grey long straight hair with two thin side braids, "
            "quiet muted violet anime eyes, calm thoughtful gaze, "
            "matte dark-charcoal hooded military rain-poncho coat with hood down over a plain black high-collar shirt, "
            "one small dark metallic beetle brooch pinned cleanly on lapel, "
        ),
        "orig_extra_neg": "white coat, lab coat, glasses, ID badge, clipboard, glowing vials, shoulder armor, giant demon horns",
    },
    "karasu": {
        "name": "鸦",
        "seed": 2101,
        "facing": "right",
        "desc": (
            "18 years old cute anime girl, youthful delicate face, "
            "long sleek swept-back dark-charcoal avian head-plume feathers with crisp pale silver-grey and muted crimson-tipped barbs emerging naturally from the upper crown of her hair, "
            "real layered folded dark slate-grey and black raven wings rising neatly behind her shoulders catching crisp cool rim light along the feather edges, "
            "jet-black straight hime-cut hair framing her cheeks, calm dark ruby-brown anime eyes, stoic composed expression, "
            "tailored matte-black military trench coat with clean single-layer shoulder cape and a simple dark-crimson cord clasp, "
        ),
        "orig_extra_neg": "ear wings, wing on ear, feather glued on ear, feather hairclip, apron, blacksmith, hammer, ammo belt, bullet belt, spiky armor, pauldrons, cat ears",
    },
    "nihong": {
        "name": "霓虹",
        "seed": 2179,
        "facing": "left",
        "desc": (
            "16 years old cute anime girl, youthful delicate face, "
            "tall alert dark slate-grey caracal ears on top of head with fine black tufted tips, "
            "dark slate-grey messy short wolf-cut hair with a pale silver front lock and plain black hairclips, "
            "subtle heterochromatic muted-blue and muted-violet anime eyes, relaxed playful slight smirk, "
            "matte dark-grey hooded military anorak jacket with subtle thin cyan zipper trim over a plain white high-collar tee, "
            "tiny matte-black collar comms clip, "
        ),
        "orig_extra_neg": "large headphones, gaming headset, bulky headset, tangled cables, neon glow, human ears visible, headband",
    },
    "gin": {
        "name": "银",
        "seed": 2221,
        "facing": "right",
        "desc": (
            "16 years old cute anime girl, youthful delicate face, "
            "slender swept-back dark-obsidian dragon horns with subtle muted burgundy ridges emerging cleanly from her hair, "
            "cool pale silver-grey chin-length bob with clean straight bangs, calm muted burgundy anime eyes, composed cool expression, "
            "tailored matte-black military peacoat with subtle dark-wine collar lining over a plain dark high-collar shirt, "
        ),
        "orig_extra_neg": "monocle, brass goggles, top hat, steampunk gears, red velvet vest, ruffled jabot, giant demon horns",
    },
}

LOCKED_CHARS = {"nao", "mia", "nihong", "lina", "karasu", "shiori", "xiaoman", "kurumi", "gin"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--chars", nargs="+", default=[k for k in CHARACTERS.keys() if k not in LOCKED_CHARS])
    ap.add_argument("--width", type=int, default=1152)
    ap.add_argument("--height", type=int, default=1536)
    ap.add_argument("--steps", type=int, default=45)
    ap.add_argument("--cfg", type=float, default=3.8)
    ap.add_argument("--shift", type=float, default=5.0)
    ap.add_argument("--seed-offset", type=int, default=0)
    ap.add_argument("--retain-end", action="store_true", help="最后一张跑完后仍保留 VM 供追加")
    ap.add_argument("--resume-job", default="", help="直接续跑已提交的单个 job_id（需仅指定 1 个 --chars）")
    ap.add_argument("--out-dir", default="", help="可选输出目录（按 <cid>.png 写出，默认写入 review\\<角色名>_上半身立绘.png）")
    args = ap.parse_args()

    for cid in args.chars:
        if cid in LOCKED_CHARS:
            raise SystemExit(f"禁止覆盖已锁定保留的角色: {cid}")

    os.chdir(STUDIO_ROOT)
    env_file = STUDIO_ROOT / ".env"
    if env_file.exists():
        for raw_line in env_file.read_text(encoding="utf-8").splitlines():
            line = raw_line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))
    sys.path.insert(0, str(STUDIO_ROOT / "api"))

    from app.admission import admit_job
    from app.config import settings
    from app.db import Store
    from app.gpu.colab import ColabError, GoogleColabProvider
    from app.gpu.compute import GpuConfig
    from app.gpu.repository import Repository
    from app.gpu.scheduler import Scheduler, TERMINAL_STATES
    import httpx

    _orig_colab_init = GoogleColabProvider.__init__
    _orig_tunnel_req = GoogleColabProvider._tunnel_request
    _orig_api_req = GoogleColabProvider._request

    def _patched_colab_init(self, *a, **kw):
        kw.setdefault("timeout", 35.0)
        _orig_colab_init(self, *a, **kw)

    def _patched_tunnel_req(self, method: str, path: str, **kw):
        last_exc = None
        for retry_i in range(6):
            try:
                return _orig_tunnel_req(self, method, path, **kw)
            except ColabError as exc:
                last_exc = exc
                if "网络异常" not in str(exc) or retry_i == 5:
                    raise
                try:
                    self.client.close()
                except Exception:
                    pass
                self.client = httpx.Client(timeout=httpx.Timeout(35.0), follow_redirects=False)
                self.google.client = self.client
                time.sleep(1.5 * (retry_i + 1))
        raise last_exc

    def _patched_api_req(self, method: str, path: str, **kw):
        last_exc = None
        for retry_i in range(6):
            try:
                return _orig_api_req(self, method, path, **kw)
            except ColabError as exc:
                last_exc = exc
                if "网络异常" not in str(exc) or retry_i == 5:
                    raise
                try:
                    self.client.close()
                except Exception:
                    pass
                self.client = httpx.Client(timeout=httpx.Timeout(35.0), follow_redirects=False)
                self.google.client = self.client
                time.sleep(1.5 * (retry_i + 1))
        raise last_exc

    GoogleColabProvider.__init__ = _patched_colab_init
    GoogleColabProvider._tunnel_request = _patched_tunnel_req
    GoogleColabProvider._request = _patched_api_req

    from sqlalchemy import event, text

    st = Store(os.environ.get("DATABASE_URL", "sqlite:///./data/studio.db"))

    @event.listens_for(st.engine, "connect")
    def _set_sqlite_pragma(dbapi_con, _con_rec):
        cur = dbapi_con.cursor()
        cur.execute("PRAGMA temp_store = MEMORY;")
        cur.close()

    with st.engine.connect() as conn:
        conn.execute(text("PRAGMA temp_store = MEMORY;"))

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
        prefix = STYLE_PREFIX_KARASU if cid == "karasu" else STYLE_PREFIX
        suffix_tpl = FRAMING_SUFFIX_KARASU if cid == "karasu" else FRAMING_SUFFIX_TEMPLATE
        prompt = prefix + c["desc"] + suffix_tpl.format(facing=c["facing"])
        neg = FRAMING_AND_BG_NEG + ", " + BASE_ORIG_NEG + ", " + c["orig_extra_neg"]
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
        for attempt in range(1, 4):
            if args.resume_job and idx == 0 and attempt == 1:
                jid = args.resume_job
                print(f"[{cid}:{name}] resuming job={jid}", flush=True)
            else:
                idem = f"upper-{cid}-{uuid.uuid4().hex[:10]}"
                job = admit_job(st, user, body, idem)
                jid = job["id"]
                print(f"[{cid}:{name}] admitted job={jid} (attempt {attempt}) lifecycle={lifecycle} seed={seed}", flush=True)

            t0 = time.time()
            last_state = None
            while True:
                try:
                    sched.tick()
                except Exception as exc:
                    print(f"[{cid}:{name}] tick warn: {exc}", flush=True)
                cur = repo.get("jobs", jid, "owner")
                state = cur.get("state")
                stage = cur.get("stage", "")
                if (state, stage) != last_state:
                    print(f"[{cid}:{name}] {time.time() - t0:.1f}s state={state} stage={stage}", flush=True)
                    last_state = (state, stage)
                if state in TERMINAL_STATES:
                    break
                time.sleep(3.0)

            if cur.get("state") == "completed":
                break
            print(f"[{cid}:{name}] attempt {attempt} ended: state={cur.get('state')} code={cur.get('error_code')} msg={cur.get('error_message')}", flush=True)
            if attempt < 3:
                time.sleep(5.0)

        if cur.get("state") != "completed":
            print(f"[{cid}:{name}] FAILED after 3 attempts: state={cur.get('state')} error={cur.get('error_message')}", flush=True)
            sys.exit(2)

        asset_ids = cur.get("output_asset_ids") or []
        if not asset_ids:
            print(f"[{cid}:{name}] FAILED: no output_asset_ids", flush=True)
            sys.exit(3)
        asset = st.get("assets", asset_ids[0])
        src_path = Path(settings.data_dir) / "assets" / asset["storage_key"]
        if not src_path.exists():
            matches = list(Path(settings.data_dir).rglob(Path(asset["storage_key"]).name))
            src_path = matches[0]
        if args.out_dir:
            out_dir = Path(args.out_dir)
            out_dir.mkdir(parents=True, exist_ok=True)
            dst_path = out_dir / f"{cid}.png"
        else:
            dst_path = REV_DIR / f"{name}_上半身立绘.png"
        shutil.copy2(src_path, dst_path)
        print(f"[{cid}:{name}] DONE ({dst_path.stat().st_size} bytes) -> {dst_path}", flush=True)

    if not args.retain_end:
        for lease in repo.list("leases", "owner"):
            if lease.get("state") not in ("deleted", "failed"):
                try:
                    ok = sched._provider(lease).delete(lease["handle"])
                    print(f"[colab] released lease {lease['id']} -> {ok}", flush=True)
                except Exception as exc:
                    print(f"[colab] release warn {lease['id']}: {exc}", flush=True)
                repo.update("leases", lease["id"], {"state": "deleted", "remote_deleted": True}, "owner")
                if lease.get("instance_id"):
                    repo.update("instances", lease["instance_id"], {"state": "deleted"}, "owner")

    print("[colab] ALL REQUESTED CHARACTERS COMPLETED", flush=True)


if __name__ == "__main__":
    main()
