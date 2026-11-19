#!/usr/bin/env python
"""发布页 DOM 采样器：小红书改版导致选择器失效时，用它重新校准 post_note.py。

流程：
  1. 打开创作者中心发布页（复用 post_note.py 的登录态）；
  2. 人工在页面上切到「上传图文」，可选随手传一张图；
  3. 回到终端按回车，脚本采样 input/contenteditable/按钮，并保存截图与 HTML。

产物：tools/xhs_publish/out/probe.json、probe.png、probe.html
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from playwright.sync_api import sync_playwright

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parent
STATE_DIR = HERE / "state" / "profile"
OUT_DIR = HERE / "out"
PUBLISH_URL = "https://creator.xiaohongshu.com/publish/publish?source=official"

JS_COLLECT = """
() => {
  const pick = (el) => ({
    tag: el.tagName.toLowerCase(),
    type: el.getAttribute('type'),
    placeholder: el.getAttribute('placeholder'),
    contenteditable: el.getAttribute('contenteditable'),
    maxlength: el.getAttribute('maxlength'),
    accept: el.getAttribute('accept'),
    cls: (el.className || '').toString().slice(0, 120),
    text: (el.innerText || el.value || '').slice(0, 60),
    visible: !!(el.offsetWidth || el.offsetHeight || el.getClientRects().length),
  });
  const q = (sel) => Array.from(document.querySelectorAll(sel)).map(pick);
  return {
    url: location.href,
    fileInputs: q("input[type=file]"),
    inputs: q("input").slice(0, 40),
    editables: q("[contenteditable=true]"),
    textareas: q("textarea"),
    buttons: q("button").slice(0, 60),
  };
}
"""


def main() -> int:
    with sync_playwright() as pw:
        ctx = pw.chromium.launch_persistent_context(
            user_data_dir=str(STATE_DIR),
            channel="chrome",
            headless=False,
            no_viewport=True,
            args=["--disable-blink-features=AutomationControlled"],
        )
        page = ctx.pages[0] if ctx.pages else ctx.new_page()
        page.goto(PUBLISH_URL, wait_until="domcontentloaded", timeout=60_000)
        print("页面已打开。若未登录请扫码；然后切到「上传图文」并（可选）传一张图。")
        input("就绪后按回车采样…")

        data = page.evaluate(JS_COLLECT)
        OUT_DIR.mkdir(parents=True, exist_ok=True)
        (OUT_DIR / "probe.json").write_text(
            json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8"
        )
        page.screenshot(path=str(OUT_DIR / "probe.png"))
        (OUT_DIR / "probe.html").write_text(page.content(), encoding="utf-8")

        print(f"file inputs : {len(data['fileInputs'])}")
        print(f"editables   : {len(data['editables'])}")
        for item in data["editables"][:5]:
            print("  editable  ", item["tag"], item["cls"][:60])
        print(f"probe.json / probe.png / probe.html 已写入 {OUT_DIR}")
        input("按回车关闭浏览器…")
        ctx.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())