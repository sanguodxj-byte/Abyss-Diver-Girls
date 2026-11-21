# -*- coding: utf-8 -*-
"""《潜渊少女》全员 11 位角色三视图人设生成器（严格对齐已验收 3 号画风亚人胸像服饰与设定）。

调用本地 AIStudio2API (/v1/images/edits) 以各角色已确认胸像为参考图，
像素级锁定参考图中的上半身服饰剪裁、颜色、领口、肩带、徽章与配饰，仅自然延展下装与侧/背面结构。
"""

import argparse
import base64
from concurrent.futures import ThreadPoolExecutor, as_completed
import json
import os
import subprocess
import sys
import time

ROOT = r"D:\123\qianyuanshaonv"
API_URL = "http://127.0.0.1:2048/v1/images/edits"

COMMON_RULES = (
    "Create three full-body standing orthographic turnaround poses of the exact character from the provided reference image, arranged cleanly in one horizontal row at identical height and aligned head-to-toe scale: "
    "Left: Front view facing straight forward; Center: Side profile view; Right: Back view facing straight away. "
    "Draw strictly THREE figures only (never four, never two side views). "
    "CRITICAL GARMENT FIDELITY RULE: Copy the exact upper-body clothing from the reference portrait down to every seam, color, collar height, lapel lining, strap count and side, button placement, buckle, and emblem. "
    "Do NOT invent extra chest logos, do NOT invent back prints, do NOT change garment colors, do NOT change open coats into buttoned coats, do NOT change single straps into double straps, and do NOT add unrequested belts or fancy trim. "
    "Extend the lower-body attire seamlessly in the same understated gritty military palette and matte fabric texture as the upper-body clothing in the reference image. "
    "Natural relaxed standing A-pose, full figure from ear/horn tips to boot soles inside frame with generous margin. "
    "Match the reference image's face, hairstyle, animal traits, eye color, and dry matte 2D painterly ink illustration style (no 3D rendering, no glossy plastic sheen). "
    "Lips expressed by a single thin line only, no color fill on lips, lip line only, natural pale matte lips, strictly no lipstick or lip gloss. "
    "Plain completely blank pure solid white background (#FFFFFF) — strictly pure bright white background, NEVER black or dark grey background. "
    "Strictly NO text, NO words, NO titles, NO view labels (do not write FRONT, SIDE, BACK, or REFERENCE SHEET), NO grid lines, NO measurement lines, NO borders anywhere."
)

CHARACTERS = {
    "nao": {
        "name": "奈绪",
        "ref": os.path.join(ROOT, "review", "奈绪_3号画风_亚人版.png"),
        "spec": (
            "EXACT UPPER BODY FROM REFERENCE: tall ash-silver rabbit ears, long ash-silver hair, silver star-wing hairclip on her right temple, muted crimson eyes, matte jet-black high-collar zippered tactical jacket, dark-grey horizontal chest stripes, dual matte black vertical chest harness straps, silver epaulette stripe, and silver wing-sword patch plus small silver dagger pin on her right sleeve pocket. "
            "MATCHING LOWER BODY & BACK: slim matte jet-black tactical trousers with subtle hanging thigh loops from the chest harness, matte black lace-up combat boots. Keep back of jacket plain matte black with clean seams and her long ash-silver hair flowing down."
        ),
    },
    "rei": {
        "name": "零",
        "ref": os.path.join(ROOT, "review", "零_3号画风_亚人版.png"),
        "spec": (
            "EXACT UPPER BODY FROM REFERENCE: pointed midnight-indigo wolf ears with pale grey inner fur, midnight-indigo asymmetric short bob, muted pale icy-blue eyes, matte charcoal-grey hooded field parka zipped all the way up to the chin with a crisp white inner collar edge peeking out, ONE small dark square triangular badge pinned ONLY on the left side of the high collar, black backpack shoulder straps over both shoulders, and a dark-black left sleeve pocket with a single light-grey top bar. "
            "CRITICAL: Keep the chest of the grey parka completely PLAIN dark charcoal-grey with clean seam lines ONLY — strictly NO white triangle print, NO chest logo, NO lettering on the chest. "
            "MATCHING LOWER BODY & BACK: slim matte charcoal-black tactical cargo trousers, matte black combat boots, and a compact matte black backpack matching the shoulder straps cleanly resting on her back beneath the folded charcoal hood."
        ),
    },
    "kurumi": {
        "name": "胡桃",
        "ref": os.path.join(ROOT, "review", "胡桃_3号画风_亚人版.png"),
        "spec": (
            "EXACT UPPER BODY FROM REFERENCE: tall copper-brown fox ears with black tips and cream inner fur, copper-brown hair tied in a right-side ponytail with a thin black hairclip on her right fringe, warm olive-amber eyes, matte dark-olive hooded military field jacket worn OPEN over a plain fitted matte black turtleneck, metallic snap button on the left front collar edge, dark epaulette with grey bar, ONE muted-orange/tan crossbody bag strap running from her right shoulder diagonally across her chest, and a round silver compass badge on her right upper sleeve pocket. "
            "CRITICAL: Keep the back of the olive jacket completely PLAIN matte dark-olive — strictly NO giant compass print or emblem on the back. "
            "MATCHING LOWER BODY & BACK: matte charcoal-brown tactical cargo trousers, rugged dark-brown lace-up field boots, folded olive hood on the back, and the single muted-orange strap continuing diagonally down to a small plain dark field pouch at her left hip."
        ),
    },
    "lina": {
        "name": "莉娜",
        "ref": os.path.join(ROOT, "review", "莉娜_3号画风_亚人版.png"),
        "spec": (
            "WIDE ZOOMED-OUT FULL-BODY STANDING SHOT: Show 100% of her entire body from the tips of her feathered ear-tufts all the way down to her knees, calves, and complete matte black lace-up boots resting on the ground, with generous blank space above her head and below her boots (strictly DO NOT crop at the knees or thighs). "
            "EXACT UPPER BODY FROM REFERENCE: sculpted honey-gold and ivory horned-owl feathered ear-tufts rising symmetrically from her wavy honey-blonde shoulder-length hair, dark navy ribbon tied at the back of her hair, muted violet-blue eyes, tailored matte midnight-navy double-breasted military officer jacket worn over a pale ivory collared shirt and dark navy necktie, distinct silver-grey angular trim stripes along the tips of the navy collar lapels, dark shoulder epaulettes with antique buttons, small silver wing-and-star pin on her right chest, and antique brass/pewter round buttons down the front. "
            "CRITICAL: Keep the jacket's natural clean tailored officer cut WITHOUT adding a waist belt over the buttons — preserve the exact silver-grey collar tip trim and open V-neck showing shirt and tie. "
            "MATCHING LOWER BODY & BACK: crisp knee-length matte midnight-navy officer skirt, sheer dark tights, matte black lace-up military officer ankle boots completely visible inside frame, and clean tailored back seam with her dark navy hair ribbon visible in side and back views. Plain solid neutral light-grey background."
        ),
    },
    "mia": {
        "name": "米娅",
        "ref": os.path.join(ROOT, "review", "米娅_3号画风_亚人版.png"),
        "spec": (
            "EXACT UPPER BODY FROM REFERENCE: pointed dark wine-red cat ears with fluffy inner fur, tousled dark wine-red hair with low messy twin buns and thin matte-bronze hairpins on her left temple and bun, drowsy half-lidded muted amber eyes, PURE MATTE JET-BLACK / CHARCOAL-BLACK (strictly NOT green and NOT olive) tall stand-collar open military jacket with matte-bronze epaulette studs and ONE crisp silver winged emblem pinned on the left chest pocket flap, worn open over a matte dark-burgundy/wine tactical chest vest with a black vertical buckle strap and a plain black turtleneck underneath. "
            "CRITICAL: The outer jacket MUST be pure matte charcoal-black/jet-black exactly matching the dark black jacket in the reference portrait — NEVER dark green or olive. Keep the tall rigid stand-up black collar and the silver wing emblem on the left chest exactly as in the reference. "
            "MATCHING LOWER BODY & BACK: matte dark-charcoal/black slim tactical cargo trousers, matte black lace-up heavy work boots, and clean plain matte charcoal-black jacket back with shoulder seam yoke."
        ),
    },
    "ajin": {
        "name": "阿堇",
        "ref": os.path.join(ROOT, "review", "阿堇_3号画风_亚人版.png"),
        "spec": (
            "WIDE ZOOMED-OUT FULL-BODY STANDING SHOT: Show 100% of her entire body from the top tips of her branched deer antlers all the way down to her complete dark-brown leather military boots and boot soles standing on the ground, with generous empty margin above her antlers and below her boots (strictly DO NOT crop ankles or boots). "
            "EXACT UPPER BODY FROM REFERENCE: dark wooden branched deer antlers rising from the top of her head, STRICTLY ONLY TWO (2) slender dark deer ears total — one single pair positioned symmetrically at the sides of her head below the antlers (strictly NO second upper pair of ears and NO four ears), long straight dark-black hair with braided side-crown section and thin black hairclip, warm muted amber-brown eyes, matte dark-taupe/brownish-grey military greatcoat featuring a TALL stand-up collar fastened across the upper chest by a prominent horizontal square antique-brass buckle clasp, matte black button on the shoulder epaulette, worn over a black ribbed/textured high-collar tactical inner shirt. "
            "CRITICAL: Keep the tall standing collar and the prominent square antique-brass clasp fastening the upper front of the dark-taupe greatcoat exactly as seen in the reference — do NOT shrink the collar into a flat open lapel. "
            "MATCHING LOWER BODY & BACK: the matte dark-taupe military greatcoat extends cleanly to below-knee length (leaving lower calves and full dark-brown lace-up military boots completely visible), worn over slim matte black tactical trousers, with her long straight black hair and braided half-up crown clearly shown in the back view. Pure solid bright white #FFFFFF background (NEVER black background)."
        ),
    },
    "xiaoman": {
        "name": "小满",
        "ref": os.path.join(ROOT, "review", "小满_3号画风_亚人版.png"),
        "spec": (
            "EXACT UPPER BODY FROM REFERENCE: tall sharp jet-black lynx ears with dark-teal inner fluff and fine ear-tip tufts, jet-black chin-length bob with dark-teal inner underlayer hair, sharp golden-amber eyes with a subtle confident smirk, matte dark-teal sleeveless high-collar fitted tactical vest featuring clean geometric panel stitching across the chest, worn over a plain matte black long-sleeve turtleneck, with ONLY ONE (1) single black leather shoulder strap with rectangular buckle running over her RIGHT shoulder only (strictly NO strap on her left shoulder, NO symmetrical H-harness, NO waist belt). "
            "CRITICAL: Keep the vest's clean paneled dark-teal high-collar sleeveless design and SINGLE right-shoulder black strap ONLY, exactly matching the reference portrait. "
            "MATCHING LOWER BODY & BACK: slim matte jet-black tactical trousers, matte black low-profile combat boots, and clean dark-teal paneled vest back showing the single black strap connecting cleanly behind her right shoulder."
        ),
    },
    "shiori": {
        "name": "诗织",
        "ref": os.path.join(ROOT, "review", "诗织_3号画风_亚人版.png"),
        "spec": (
            "EXACT UPPER BODY FROM REFERENCE: large curled pale silver-grey ram horns spiraling around her head, drooping pale lavender-grey caprine ears, long pale lavender-grey straight hair with two thin braids framing her face, muted violet eyes, plain matte black high-collar inner shirt, draped in a matte dark-charcoal/black SLEEVELESS hooded military rain-poncho cloak (a continuous draped cape-poncho with side arm slits, NOT a wizard robe with separate wide bell sleeves) featuring a distinct vertical front placket flap near the throat pinned with a dark metallic beetle brooch. "
            "CRITICAL: Preserve the exact sleeveless draped rain-poncho cloak construction and the rectangular center placket with the beetle brooch from the reference — do NOT give it separate wide robe sleeves. Ensure the RIGHT figure is a genuine Rear Back view showing both curled ram horns symmetrically from behind, her long pale lavender-grey hair, and the draped hood on the back of the poncho cloak. "
            "MATCHING LOWER BODY & BACK: the dark matte rain-poncho cloak falls smoothly to calf length with subtle hands emerging from hidden poncho slits, revealing slim matte black leggings and matte black lace-up weatherproof boots."
        ),
    },
    "karasu": {
        "name": "鸦",
        "ref": os.path.join(ROOT, "review", "鸦_3号画风_亚人版.png"),
        "spec": (
            "EXACT UPPER BODY FROM REFERENCE: swept-back black raven crown plumes with subtle muted dark-crimson tips rising from her long straight jet-black hime-cut hair, large dark matte slate-black folded feathered raven wings with cool silver-grey upper-edge highlights behind her shoulders, dark ruby-brown eyes, understated matte ALL-BLACK high-collar military coat with an ALL-BLACK shoulder cape draped over her arms, matte dark-silver double-bar shoulder epaulettes, subtle dark embroidery on the black stand collar, and ONE dark-crimson braided cord clasp hanging down the center chest from a dark antique round button. "
            "CRITICAL: Keep the entire outfit strictly understated MATTE ALL-BLACK with ONLY that single muted dark-crimson chest cord clasp as color accent — strictly NO bright red cape lining, NO red cuff stripes, NO double-breasted rows of silver buttons, NO red pant stripes, NO ornate gothic waist belt. "
            "MATCHING LOWER BODY & BACK: the plain matte black shoulder cape and sleek long matte black trench coat drape cleanly over slim matte black tactical trousers and plain tall matte black leather military boots; in the side and back views clearly show the dark folded feathered raven wings emerging cleanly from her upper back over the plain matte black cape."
        ),
    },
    "nihong": {
        "name": "霓虹",
        "ref": os.path.join(ROOT, "review", "霓虹_3号画风_亚人版.png"),
        "spec": (
            "EXACT UPPER BODY FROM REFERENCE: tall pointed dark slate-grey caracal ears with brown-grey inner fur and fine black tufted tips, messy dark slate-grey wolf-cut short hair with a prominent pale silver-white front streak and one black hairclip on her left fringe, heterochromatic eyes (right eye muted pale blue, left eye muted violet), crisp plain matte white turtleneck with ONE small matte black rectangular patch on the left side of the collar, worn under a matte dark-charcoal hooded military anorak jacket with a thin muted-cyan zipper edge, ONE asymmetric thin cyan horizontal welt pocket stripe on her left chest ONLY (not mirrored on the right chest), a thin cyan seam highlight along her left shoulder, and a left upper-sleeve pocket with a thin cyan top bar. "
            "MATCHING LOWER BODY & BACK: relaxed matte dark-slate tapered tactical cargo pants, matte black tactical lace-up combat boots, folded dark-charcoal anorak hood neatly resting on her back."
        ),
    },
    "gin": {
        "name": "银",
        "ref": os.path.join(ROOT, "review", "银_3号画风_亚人版.png"),
        "spec": (
            "EXACT UPPER BODY FROM REFERENCE: swept-back dark-obsidian dragon horns with subtle dark-burgundy ridges, cool pale silver-grey straight chin-length bob with blunt bangs, calm muted burgundy eyes, matte jet-black military trench peacoat with LARGE WIDE FOLDED LAPELS worn PARTIALLY OPEN at the chest so the DISTINCT DARK-WINE/BURGUNDY INNER COLLAR LINING and the fitted matte jet-black high-collar inner tactical turtleneck underneath are clearly visible, antique brass button on the shoulder epaulette, and subtle brass buttons lower down the front. "
            "CRITICAL: Do NOT button the coat tightly up to the throat and do NOT hide the dark-wine/burgundy inner collar lining — preserve the exact open wide-lapel silhouette and dark-wine collar lining from the reference portrait. "
            "MATCHING LOWER BODY & BACK: the matte jet-black military peacoat extends cleanly to mid-thigh/knee length with a simple matte black back waist tab, worn over slim matte black tailored military trousers and clean matte black leather combat boots."
        ),
    },
}


def generate_one(char_key: str, model: str = "gemini-3-pro-image", size: str = "1536x1024"):
    c = CHARACTERS[char_key]
    ref_path = c["ref"]
    if not os.path.exists(ref_path):
        print(f"[{char_key}] Missing reference image: {ref_path}", file=sys.stderr)
        return False

    out_path = os.path.join(ROOT, "review", f"{c['name']}_三视图.png")
    resp_json = os.path.join(ROOT, "review", f"_tmp_turnaround_{char_key}.json")
    prompt = f"{COMMON_RULES} {c['spec']}"

    cmd = [
        "curl", "-s", "-m", "240", "-X", "POST", API_URL,
        "-F", f"model={model}",
        "-F", f"prompt={prompt}",
        "-F", f"image=@{ref_path}",
        "-F", f"size={size}",
        "-F", "output_format=png",
        "-o", resp_json,
    ]
    t0 = time.time()
    res = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if res.returncode != 0:
        print(f"[{char_key}] curl failed: {res.stderr}", file=sys.stderr)
        return False

    try:
        with open(resp_json, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        print(f"[{char_key}] Invalid JSON response: {e}", file=sys.stderr)
        return False

    if "data" not in data or not data["data"]:
        print(f"[{char_key}] API error: {json.dumps(data, ensure_ascii=False)[:400]}", file=sys.stderr)
        return False

    b64 = data["data"][0].get("b64_json")
    if not b64:
        print(f"[{char_key}] Missing b64_json in response", file=sys.stderr)
        return False

    raw = base64.b64decode(b64)
    with open(out_path, "wb") as f:
        f.write(raw)
    try:
        os.remove(resp_json)
    except OSError:
        pass

    print(json.dumps({
        "status": "success",
        "char": char_key,
        "name": c["name"],
        "file": out_path,
        "model": model,
        "seconds": round(time.time() - t0, 1),
        "bytes": len(raw),
    }, ensure_ascii=False), flush=True)
    return True


BG_WHITE_PROMPT = (
    "Edit this exact 3-view character turnaround image ONLY by replacing the entire background with a completely plain, uniform, pure solid white background (#FFFFFF). "
    "CRITICAL: Keep all three full-body standing figures — their exact poses, alignment, scale, faces, expressions, hair, animal ears/horns, clothing design, garment colors, straps, clasps, emblems, inner linings, trousers/skirts, and boots — 100% IDENTICAL to the input image. "
    "Do NOT alter any outfit detail, do NOT change garment colors, do NOT crop or shift the figures, do NOT add shadows on the floor, and do NOT add any text, labels, grid lines, or borders anywhere. "
    "Render clean crisp dark ink outer outlines around all hair, ears, horns, dark coats, and boots so the characters separate sharply against the pure solid #FFFFFF white background. "
    "Preserve the exact matte 2D illustration style and thin single-line matte lips with strictly no lipstick or lip gloss."
)


def whiten_background_one(char_key: str, model: str = "gemini-3-pro-image", size: str = "1536x1024"):
    c = CHARACTERS[char_key]
    src_path = os.path.join(ROOT, "review", f"{c['name']}_三视图.png")
    if not os.path.exists(src_path):
        print(f"[{char_key}] Missing turnaround image: {src_path}", file=sys.stderr)
        return False

    resp_json = os.path.join(ROOT, "review", f"_tmp_whiten_{char_key}.json")
    cmd = [
        "curl", "-s", "-m", "240", "-X", "POST", API_URL,
        "-F", f"model={model}",
        "-F", f"prompt={BG_WHITE_PROMPT}",
        "-F", f"image=@{src_path}",
        "-F", f"size={size}",
        "-F", "output_format=png",
        "-o", resp_json,
    ]
    t0 = time.time()
    res = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if res.returncode != 0:
        print(f"[{char_key}] curl failed: {res.stderr}", file=sys.stderr)
        return False

    try:
        with open(resp_json, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        print(f"[{char_key}] Invalid JSON response: {e}", file=sys.stderr)
        return False

    if "data" not in data or not data["data"]:
        print(f"[{char_key}] API error: {json.dumps(data, ensure_ascii=False)[:400]}", file=sys.stderr)
        return False

    b64 = data["data"][0].get("b64_json")
    if not b64:
        print(f"[{char_key}] Missing b64_json in response", file=sys.stderr)
        return False

    raw = base64.b64decode(b64)
    with open(src_path, "wb") as f:
        f.write(raw)
    try:
        os.remove(resp_json)
    except OSError:
        pass

    print(json.dumps({
        "status": "success",
        "mode": "bg_white",
        "char": char_key,
        "name": c["name"],
        "file": src_path,
        "model": model,
        "seconds": round(time.time() - t0, 1),
        "bytes": len(raw),
    }, ensure_ascii=False), flush=True)
    return True


def run_with_fallback(char_key: str, model: str, size: str, bg_white: bool = False):
    fn = whiten_background_one if bg_white else generate_one
    ok = fn(char_key, model=model, size=size)
    if not ok:
        print(f"[{char_key}] Fallback retry with gemini-nano-banana-2.1...", flush=True)
        ok = fn(char_key, model="gemini-nano-banana-2.1", size=size)
    return char_key, ok


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("characters", nargs="+", choices=list(CHARACTERS.keys()) + ["all"])
    parser.add_argument("--model", default="gemini-3-pro-image")
    parser.add_argument("--size", default="1536x1024")
    parser.add_argument("--workers", type=int, default=3)
    parser.add_argument("--bg-white", action="store_true")
    args = parser.parse_args()

    targets = list(CHARACTERS.keys()) if "all" in args.characters else args.characters
    if args.workers <= 1 or len(targets) == 1:
        for k in targets:
            run_with_fallback(k, args.model, args.size, bg_white=args.bg_white)
    else:
        with ThreadPoolExecutor(max_workers=args.workers) as ex:
            futs = [ex.submit(run_with_fallback, k, args.model, args.size, args.bg_white) for k in targets]
            for fut in as_completed(futs):
                k, ok = fut.result()
                if not ok:
                    print(f"[{k}] FAILED after fallback", file=sys.stderr, flush=True)


if __name__ == "__main__":
    main()
