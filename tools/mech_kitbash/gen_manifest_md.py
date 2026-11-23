"""Generate/refresh docs/MECH_REFINEMENT_MANIFEST.md from tools/mech_kitbash/manifest.json & live GLB status."""
import json
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from specs import REPO_ROOT, OUT_GLB_DIR, CATEGORY_BUDGETS

MANIFEST_JSON = os.path.join(SCRIPT_DIR, "manifest.json")
OUT_MD = os.path.join(REPO_ROOT, "docs", "MECH_REFINEMENT_MANIFEST.md")


def main():
    data = json.load(open(MANIFEST_JSON, encoding="utf-8"))
    by_id = {}
    done = 0
    for m in data["modules"]:
        is_done = os.path.exists(os.path.join(OUT_GLB_DIR, f"{m['id']}.glb"))
        m["status"] = "DONE" if is_done else "TODO"
        if is_done:
            done += 1
        by_id[m["id"]] = m
    data["done_count"] = done
    data["todo_count"] = data["total_modules"] - done
    with open(MANIFEST_JSON, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    lines = [
        "# 全量 101 个机甲模块建模细化任务清单（MECH REFINEMENT MANIFEST）",
        "",
        f"> **规范基准**：[MECH_MODELING_STANDARD.md](./MECH_MODELING_STANDARD.md)（v1.0）  ",
        f"> **AI Studio Build 委托手册**：[AISTUDIO_BUILD_BRIEF.md](./AISTUDIO_BUILD_BRIEF.md)  ",
        f"> **机器可读完整参数表**：[tools/mech_kitbash/manifest.json](../tools/mech_kitbash/manifest.json)  ",
        f"> **当前总进度**：**`{done} / {data['total_modules']}`**（已完成 `{done}`，待细化 `{data['todo_count']}`）",
        "",
        "---",
        "",
        "## 批次总览",
        "",
        "| 批次 ID | 说明 | 进度 | 目标产出文件建议 |",
        "| :--- | :--- | :---: | :--- |",
    ]

    for b in data["batches"]:
        b_done = sum(1 for mid in b["modules"] if by_id[mid]["status"] == "DONE")
        out_hint = f"`tools/mech_kitbash/builders/{b['id']}.py`" if b["id"] != "batch_01_starter" else "`starter_*.py` (已完成参考样板)"
        lines.append(f"| `{b['id']}` | {b['title']} | `{b_done} / {b['count']}` | {out_hint} |")

    lines += ["", "---", ""]

    for b in data["batches"]:
        b_done = sum(1 for mid in b["modules"] if by_id[mid]["status"] == "DONE")
        lines.append(f"## {b['title']} (`{b['id']}` — `{b_done}/{b['count']}`)")
        lines.append("")
        lines.append("| 状态 | 模块 ID | 名称 | 类别 | 接口 / 骨骼关键参数 | 原版脚本参考 & 设计要点 |")
        lines.append("| :---: | :--- | :--- | :---: | :--- | :--- |")
        for mid in b["modules"]:
            m = by_id[mid]
            chk = "✅" if m["status"] == "DONE" else "⬜"
            nm = m["name"] + (f" ({m['name_en']})" if m.get("name_en") else "")
            cat = m["category"]
            # Summarize key geometry contracts concisely
            c_parts = []
            if m.get("sockets"):
                for sk, sv in m["sockets"].items():
                    c_parts.append(f"`{sk}={sv}`")
            if cat == "legs":
                c_parts.append(f"type=`{m.get('leg_type','biped')}`")
                if "hip_y" in m:
                    c_parts.append(f"hip=`{m['hip_y']}`")
                if "KN" in m:
                    c_parts.append(f"KN=`{m['KN']}`")
                if "AN" in m:
                    c_parts.append(f"AN=`{m['AN']}`")
                if "sole" in m:
                    c_parts.append(f"sole=`{m['sole']}`")
            elif cat == "arm":
                if "weapon_type" in m:
                    c_parts.append(f"wpn=`{m['weapon_type']}`")
                if "muzzle_local" in m:
                    c_parts.append(f"muzzle=`{m['muzzle_local']}`")
            contract = "<br>".join(c_parts) if c_parts else "见原版 `.gd`"
            brief = m.get("brief", "").replace("|", "/")
            if len(brief) > 110:
                brief = brief[:108] + "…"
            src_ref = f"[`{mid}.gd`](../{m['gd_source']})<br>{brief}"
            lines.append(f"| {chk} | `{mid}` | {nm} | `{cat}` | {contract} | {src_ref} |")
        lines.append("")

    with open(OUT_MD, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print(f"[MANIFEST] Updated {OUT_MD} ({done}/{data['total_modules']} DONE)")


if __name__ == "__main__":
    main()
