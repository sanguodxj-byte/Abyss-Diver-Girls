# -*- coding: utf-8 -*-
"""《潜渊少女》全员 11 位角色高细节纯白底三视图生成器（远端 gpt-image-2.5-flare API）。

基于各自已验收的 3 号画风亚人胸像（review\<角色>_3号画风_亚人版.png）作为参考图调用 /v1/images/edits，
锁定 3 号画风干刷厚涂笔触、高密度衣褶与配饰质感、胸像上半身服饰细节与纯净纯白底 (#FFFFFF)。
"""

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import json
import os
import sys
import time
import winreg

ROOT = r"D:\123\qianyuanshaonv"
sys.path.insert(0, os.path.join(ROOT, "tools"))


def _ensure_api_key():
    if os.environ.get("ART_API_KEY", "").strip():
        return
    try:
        k = winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment")
        val, _ = winreg.QueryValueEx(k, "ART_API_KEY")
        if val:
            os.environ["ART_API_KEY"] = val
    except OSError:
        pass


_ensure_api_key()
import art_api  # noqa: E402
import art_comfy as ac  # noqa: E402

COMMON_RULES = (
    "High-detail 2D anime concept-art full-body turnaround illustration of the exact character from the provided reference portrait, "
    "rendered in three standing orthographic views side by side at identical height and aligned head-to-toe scale: "
    "Left: Front view facing straight forward; Center: Side profile view; Right: Back view facing straight away. "
    "Draw strictly THREE complete figures only (never four, never duplicated side views), zoomed out cleanly so 100% of every figure from the very highest ear/horn/feather tip down to the bottom of her boot soles fits inside the frame with at least 8% empty pure white margin at both the top edge and bottom edge (never let ear tips or antler tips touch or clip the top border). "
    "CRITICAL ART STYLE & HIGH-DETAIL RETENTION: Keep the EXACT high-density 2D painterly concept illustration richness of the reference portrait — do NOT simplify into flat cel-shaded vector lines. "
    "Preserve rich dry matte brushwork, fine hand-drawn ink linework, finely layered individual hair strands, delicate animal fur and feather textures, realistic structured heavy fabric folds, stitched seam panels, subtle directional shadow planes, weathered matte leather, and crisp brushed metallic hardware details (buckles, zippers, rivets, pins, eyelets, laces). "
    "CRITICAL GARMENT FIDELITY: Copy the exact upper-body outfit from the reference portrait down to every color, collar height, inner lining, strap count and side, button placement, buckle, pocket, and emblem; extend the lower-body outfit seamlessly with equally intricate matching matte fabric folds, belt hardware, pockets, and detailed lace-up boots. "
    "Lips expressed by a single thin line only, no color fill on lips, lip line only, natural pale matte lips, strictly no lipstick or lip gloss. "
    "Completely plain pure solid white background (#FFFFFF) with zero cast floor shadow. "
    "Strictly NO text, NO letters, NO numbers, NO view labels, NO titles, NO grid lines, NO borders, NO watermarks anywhere."
)

CHARACTERS = {
    "nao": {
        "name": "奈绪",
        "ref": os.path.join(ROOT, "review", "奈绪_3号画风_亚人版.png"),
        "spec": (
            "UPPER BODY LOCKED TO REFERENCE: tall fluffy ash-silver rabbit ears with detailed inner fur tufts, long finely layered ash-silver hair, sculpted metallic silver star-and-wing hairclip on her right temple, muted crimson-rose eyes, matte jet-black tall zippered high-collar field jacket with crisp dark-grey horizontal chest stripes, dual matte black vertical chest harness straps with detailed buckles and clips, shoulder epaulette trim, and an intricate silver winged-star sleeve patch plus a slender vertical metallic silver crest pin on the right upper sleeve pocket. "
            "HIGH-DETAIL LOWER BODY & BACK: fitted matte charcoal-black field trousers with realistic knee seaming and crisp fabric folds, subtle hanging matte black harness thigh loops with metallic adjusters, sturdy matte jet-black lace-up ankle boots with finely drawn eyelets, ankle straps, and treaded soles. Back view shows flowing detailed ash-silver hair, rear jacket yoke seams, and a neat small fluffy ash-silver rabbit tail peeking cleanly below the jacket hem."
        ),
    },
    "rei": {
        "name": "零",
        "ref": os.path.join(ROOT, "review", "零_3号画风_亚人版.png"),
        "spec": (
            "UPPER BODY LOCKED TO REFERENCE: pointed midnight-indigo wolf ears with finely rendered pale-grey fluffy inner fur, textured midnight-indigo asymmetric short bob, muted icy-blue eyes, heavy matte charcoal-grey hooded field parka zipped completely up to the chin with a crisp white inner collar edge peeking out, ONE small dark square triangular metal badge pinned ONLY on the left side of the high collar, matte black backpack shoulder straps with ribbed webbing and buckles over both shoulders, and a dark matte black left upper-sleeve pocket with a single light-grey top trim bar. "
            "CRITICAL: Keep the parka chest plain structured matte charcoal-grey with detailed panel stitching and folds ONLY — strictly NO white triangle print or chest logo. "
            "HIGH-DETAIL LOWER BODY & BACK: streamlined matte charcoal-black utility cargo trousers with detailed thigh pockets, knee articulation folds, and belt loops, paired with sturdy matte black lace-up leather field boots; Side and Back views show the structured folded charcoal hood, a detailed compact matte black canvas-and-webbing backpack with zippers and straps, and a sleek midnight-indigo wolf tail with pale-grey underside fur peeking naturally below the parka hem."
        ),
    },
    "kurumi": {
        "name": "胡桃",
        "ref": os.path.join(ROOT, "review", "胡桃_3号画风_亚人版.png"),
        "spec": (
            "UPPER BODY LOCKED TO REFERENCE: tall fluffy copper-brown fox ears with dark charcoal tips and dense cream inner ear fur, layered copper-brown hair tied into a textured right-side ponytail with a thin matte black hairclip on her right fringe, warm olive-amber eyes, heavy matte dark-olive hooded utility field jacket worn open over a fine-knit matte black turtleneck, metallic snap eyelet on the left front collar edge, dark epaulette with grey bar, ONE weathered muted-orange leather crossbody strap with metallic buckle running diagonally from her right shoulder across her chest, and a crisp round silver compass badge on her right upper-sleeve flap pocket. "
            "CRITICAL: Keep the back of the olive jacket plain structured matte dark-olive fabric with seam stitching and folded hood ONLY — strictly NO giant compass print on the back. "
            "HIGH-DETAIL LOWER BODY & BACK: matte dark-charcoal utility cargo trousers with detailed side pockets, knee folds, and a small weathered dark field pouch at her left hip connected to the orange crossbody strap, rugged dark-brown leather lace-up hiking boots with visible stitching and eyelets, and a lush fluffy copper-brown fox tail with a cream tip emerging cleanly below the back jacket hem."
        ),
    },
    "lina": {
        "name": "莉娜",
        "ref": os.path.join(ROOT, "review", "莉娜_3号画风_亚人版.png"),
        "spec": (
            "UPPER BODY LOCKED TO REFERENCE: sculpted layered honey-gold and ivory horned-owl feathered ear-tufts with crisp individual feather barbs rising symmetrically from her wavy honey-blonde shoulder-length hair, dark navy fabric ribbon bow tied at the back of her hair, muted violet-blue eyes, finely tailored matte midnight-navy double-breasted dress officer jacket worn over a crisp pale ivory collared shirt and matte dark-navy necktie, sharp silver-grey angular trim stripes along the tips of the navy collar lapels, structured shoulder epaulettes with antique metallic buttons, small silver wing-and-star lapel pin on her right chest, and finely detailed antique pewter round buttons down the double-breasted front. "
            "CRITICAL: Preserve the clean structured double-breasted jacket silhouette WITHOUT adding a waist belt over the buttons. "
            "HIGH-DETAIL LOWER BODY & BACK: crisp tailored matte midnight-navy trousers (or knee-length pleated dress skirt) with sharp fabric folds, dark matte leather dress ankle boots with fine lacing and stacked heels completely inside frame, and clean tailored back coat seams, back vent, and dark navy hair ribbon clearly detailed in Side and Back views."
        ),
    },
    "mia": {
        "name": "米娅",
        "ref": os.path.join(ROOT, "review", "米娅_3号画风_亚人版.png"),
        "spec": (
            "UPPER BODY LOCKED TO REFERENCE: pointed dark wine-red cat ears with textured fluffy inner fur, tousled layered dark wine-red hair with low messy twin buns and thin matte-bronze hairpins on her left temple and bun, drowsy half-lidded muted amber eyes, PURE MATTE JET-BLACK / CHARCOAL-BLACK (strictly NOT green or olive) heavy tall stand-collar open utility jacket with bronze-studded shoulder epaulettes and ONE finely sculpted silver winged emblem pinned on the left chest pocket flap, worn open over a matte dark-burgundy/wine paneled utility chest vest with a black vertical buckle strap and a matte black ribbed turtleneck underneath. "
            "HIGH-DETAIL LOWER BODY & BACK: matte charcoal-black heavy utility work trousers with stitched pockets, sturdy belt with matte metal buckle, crisp fabric creases, and rugged matte dark-brown/black leather lace-up work boots with eyelets and soles; Side and Back views show clean heavy black jacket yoke stitching and a slender dark wine-red cat tail curving naturally below the jacket hem."
        ),
    },
    "ajin": {
        "name": "阿堇",
        "ref": os.path.join(ROOT, "review", "阿堇_3号画风_亚人版.png"),
        "spec": (
            "UPPER BODY LOCKED TO REFERENCE: finely textured dark wooden branched deer antlers rising from the top of her head, STRICTLY ONLY TWO (2) slender furry dark-brown deer ears positioned symmetrically at the sides of her head below the antlers (strictly NO second upper pair of ears), long silky straight dark-black hair with intricate braided side-crown and thin black hairclip, warm muted amber-brown eyes, heavy matte dark-taupe/brownish-grey tailored long greatcoat featuring a TALL stand-up collar fastened across the upper chest by a prominent horizontal square antique-brass buckle clasp, matte black epaulette button, worn over a black ribbed textured high-collar inner shirt. "
            "HIGH-DETAIL LOWER BODY & BACK: the structured matte dark-taupe greatcoat extends cleanly to below-knee length with rich vertical wool folds, cuffed sleeves with buttoned tabs, side welt pockets, and a neat back coat vent with back waist tab, worn over slim matte black tailored trousers and sturdy dark-brown leather lace-up boots with buckles and soles completely visible inside frame; Back view showcases her finely braided half-up crown and long flowing dark-black hair."
        ),
    },
    "xiaoman": {
        "name": "小满",
        "ref": os.path.join(ROOT, "review", "小满_3号画风_亚人版.png"),
        "spec": (
            "UPPER BODY LOCKED TO REFERENCE: tall sharp jet-black lynx ears with richly textured dark-teal inner fur tufts and fine dark ear-tip tufts, layered jet-black chin-length bob with dark-teal inner underlayer hair strands, sharp golden-amber eyes with a subtle calm smirk, structured matte dark-teal sleeveless high-collar fitted utility vest featuring clean geometric stitched panel seams across the chest, worn over a fitted matte black long-sleeve ribbed turtleneck, with ONLY ONE (1) single matte black leather shoulder strap with heavy metallic rectangular adjuster buckle running over her RIGHT shoulder only (strictly NO strap on her left shoulder and NO symmetrical dual chest harness). "
            "HIGH-DETAIL LOWER BODY & BACK: fitted matte jet-black utility field trousers with detailed stitched knee panels, cargo pockets, matte black belt with subtle buckle, and agile matte black lace-up boots with treaded soles; Back view shows clean dark-teal vest paneling, the single right-shoulder black leather strap crossing neatly behind her back, and a neat short bobbed jet-black lynx tail peeking cleanly below the vest hem."
        ),
    },
    "shiori": {
        "name": "诗织",
        "ref": os.path.join(ROOT, "review", "诗织_3号画风_亚人版.png"),
        "spec": (
            "UPPER BODY LOCKED TO REFERENCE: intricately ridged large curled pale silver-grey ram horns spiraling symmetrically around her head, soft drooping pale lavender-grey caprine ears, finely layered long pale lavender-grey straight hair with two detailed thin braids framing her face, muted violet eyes, matte black high-collar collared inner shirt, draped in a heavy matte dark-charcoal/black SLEEVELESS hooded weatherproof rain-poncho cloak (a continuous draped poncho-cape with hidden side arm slits and rich heavy fabric folds, NOT separate wide wizard sleeves) featuring a distinct stitched vertical rectangular front placket near the throat pinned with a finely detailed dark metallic beetle brooch. "
            "HIGH-DETAIL LOWER BODY & BACK: the heavy matte dark-charcoal rain-poncho cloak drapes cleanly to mid-calf with deep painterly folds, showing slim matte black leggings and detailed matte dark-grey leather lace-up weatherproof boots completely inside frame; RIGHT figure is a genuine Rear Back view showing both ridged curled ram horns symmetrically from behind, her long layered pale lavender-grey hair cascading over the folded structured poncho hood, and clean back cloak drape."
        ),
    },
    "karasu": {
        "name": "鸦",
        "ref": os.path.join(ROOT, "review", "鸦_3号画风_亚人版.png"),
        "spec": (
            "UPPER BODY LOCKED TO REFERENCE: swept-back intricately layered black raven crown plumes with subtle muted dark-crimson feather tips rising symmetrically from her silky long straight jet-black hime-cut hair, large matte dark slate-black folded feathered raven wings behind her shoulders with richly detailed layered primaries, coverts, and cool silver-grey upper-edge highlights, dark ruby-brown eyes, understated MATTE ALL-BLACK high-collar long coat with an ALL-BLACK structured shoulder cape draped over her shoulders, matte dark-silver double-bar shoulder epaulettes, subtle tone-on-tone dark embroidery on the black stand collar, and ONE dark-crimson braided cord clasp hanging down the center chest from a sculpted antique dark metal round button. "
            "CRITICAL: Keep the entire garment strictly understated MATTE ALL-BLACK with ONLY that single muted dark-crimson chest cord clasp as color accent — strictly NO bright red cape lining, NO red stripes, NO double-breasted rows of bright silver buttons. "
            "HIGH-DETAIL LOWER BODY & BACK: rich matte black fabric folds of the shoulder cape and sleek tailored matte black long coat parting cleanly over slim matte black trousers and tall finely detailed matte black leather riding boots with subtle seams and heels; Side and Back views clearly illustrate how the lush layered folded raven wings attach cleanly at her upper back over the plain matte black cape."
        ),
    },
    "nihong": {
        "name": "霓虹",
        "ref": os.path.join(ROOT, "review", "霓虹_3号画风_亚人版.png"),
        "spec": (
            "UPPER BODY LOCKED TO REFERENCE: tall alert pointed dark slate-grey caracal ears with finely detailed brown-grey and cream inner fur tufts and fine black tufted tips, messy layered dark slate-grey wolf-cut short hair with a prominent pale silver-white front streak and one thin matte black hairclip on her left fringe, heterochromatic eyes (right eye muted pale blue, left eye muted violet), crisp matte white ribbed turtleneck with ONE small matte black rectangular tag patch on the left side of the collar, worn under a heavy matte dark-charcoal hooded technical anorak jacket with a crisp thin muted-cyan zipper edge, ONE asymmetric thin cyan horizontal welt pocket stripe on her left chest ONLY, a thin cyan seam line along her left shoulder, and a detailed left upper-sleeve pocket with a thin cyan top bar and zipper pull. "
            "HIGH-DETAIL LOWER BODY & BACK: relaxed matte dark-slate technical tapered cargo pants with stitched articulation knees, side cargo pockets, matte straps, and detailed matte black high-top utility lace-up boots; Side and Back views show the structured folded charcoal anorak hood with seam details and a sleek dark slate-grey caracal tail peeking cleanly below the anorak hem."
        ),
    },
    "gin": {
        "name": "银",
        "ref": os.path.join(ROOT, "review", "银_3号画风_亚人版.png"),
        "spec": (
            "UPPER BODY LOCKED TO REFERENCE: finely sculpted swept-back dark-obsidian ridged dragon horns with subtle muted dark-burgundy crevices, silky cool pale silver-grey straight chin-length bob with crisp blunt bangs, calm sharp muted burgundy eyes, heavy structured matte jet-black tailored wool peacoat with LARGE WIDE FOLDED LAPELS worn PARTIALLY OPEN at the upper chest so the DISTINCT MATTE DARK-WINE/BURGUNDY INNER COLLAR LINING and the fitted matte jet-black high-collar inner turtleneck underneath are clearly visible, antique brass button on the structured shoulder epaulettes, and finely detailed antique brass buttons lower down the front. "
            "HIGH-DETAIL LOWER BODY & BACK: the structured matte jet-black long peacoat falls cleanly to mid-thigh/below-knee length with crisp tailored folds, cuffed wrist tabs with brass buttons, angled welt pockets, and a tailored back waist tab and vent, worn over slim matte black tailored trousers and sharp matte black leather lace-up boots with polished dark-wine/black leather sheen; Side and Back views also include a sleek slender dark-obsidian scaled dragon tail with subtle muted dark-burgundy underside ridges emerging naturally below the back coat hem."
        ),
    },
}


def generate_one(char_key: str, model: str = "gpt-image-2.5-flare", size: str = "1536x1024", quality: str = "high"):
    c = CHARACTERS[char_key]
    ref_path = c["ref"]
    if not os.path.exists(ref_path):
        print(f"[{char_key}] Missing reference image: {ref_path}", file=sys.stderr)
        return False

    out_path = os.path.join(ROOT, "review", f"{c['name']}_三视图.png")
    prompt = f"{COMMON_RULES} {c['spec']}"
    t0 = time.time()
    try:
        ims = art_api.edit(
            images=[ref_path],
            prompt=prompt,
            model=model,
            size=size,
            quality=quality,
            fmt="png",
            n=1,
        )
    except Exception as e:
        print(f"[{char_key}] API error: {e}", file=sys.stderr, flush=True)
        return False

    im = ims[0]
    meta = {
        "tool": "make_turnarounds_api25",
        "model": model,
        "char": char_key,
        "quality": quality,
        "size": list(im.size),
    }
    ac.save_png(im, out_path, meta)
    print(json.dumps({
        "status": "success",
        "char": char_key,
        "name": c["name"],
        "file": out_path,
        "model": model,
        "size": list(im.size),
        "seconds": round(time.time() - t0, 1),
        "bytes": os.path.getsize(out_path),
    }, ensure_ascii=False), flush=True)
    return True


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("characters", nargs="+", choices=list(CHARACTERS.keys()) + ["all"])
    parser.add_argument("--model", default="gpt-image-2.5-flare")
    parser.add_argument("--size", default="1536x1024")
    parser.add_argument("--quality", default="high")
    parser.add_argument("--workers", type=int, default=3)
    args = parser.parse_args()

    targets = list(CHARACTERS.keys()) if "all" in args.characters else args.characters
    if args.workers <= 1 or len(targets) == 1:
        for k in targets:
            generate_one(k, model=args.model, size=args.size, quality=args.quality)
    else:
        with ThreadPoolExecutor(max_workers=args.workers) as ex:
            futs = [ex.submit(generate_one, k, args.model, args.size, args.quality) for k in targets]
            for fut in as_completed(futs):
                fut.result()


if __name__ == "__main__":
    main()
