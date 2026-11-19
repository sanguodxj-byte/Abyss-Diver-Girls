#!/usr/bin/env python
"""小红书创作者中心「半自动」发帖原型。

原则：
  * 只做三件事——进入发布页、挂图、填标题/正文；
  * **绝不点击「发布」按钮**，最终由人工检查并点击；
  * 复用持久化的浏览器登录态，扫码登录只需人工做一次（过期再扫）。

用法：
    python tools/xhs_publish/post_note.py --draft tools/xhs_publish/posts.example.json
    python tools/xhs_publish/post_note.py --draft draft.json --dry-run     # 只打开页面，不填内容
    python tools/xhs_publish/post_note.py --check                          # 无头自检，不做任何发布动作

首次运行若提示未登录：在弹出的 Chrome 里扫码登录，脚本会自动继续。
若选择器失效（小红书改版），跑 probe_publish_page.py 重新采样 DOM，再调整下方 SEL_* 常量。
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

from playwright.sync_api import Error as PWError
from playwright.sync_api import TimeoutError as PWTimeout
from playwright.sync_api import sync_playwright

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
STATE_DIR = HERE / "state" / "profile"
OUT_DIR = HERE / "out"

PUBLISH_URL = "https://creator.xiaohongshu.com/publish/publish?source=official"
HOME_URL = "https://creator.xiaohongshu.com/new/home"

# ---------------------------------------------------------------- 选择器（按顺序尝试）
SEL_IMAGE_TAB = [
    "text=上传图文",
    "text=图文",
    "div[class*='tab']:has-text('图文')",
]
SEL_FILE_INPUT = [
    "input[type='file'][accept*='image']",
    "input[type='file']",
]
SEL_TITLE = [
    "input[placeholder*='填写标题']",
    "input[placeholder*='标题']",
    "input[type='text'][maxlength='20']",
    "div[class*='title'] input",
]
SEL_EDITOR = [
    "div[contenteditable='true']",
    "div.ql-editor",
    "div[placeholder*='正文']",
]
SEL_LOGIN_HINT = [
    "text=扫码登录",
    "text=登录后查看",
    "text=手机号登录",
]

TITLE_MAX = 20
CONTENT_MAX = 1000
IMAGE_MAX = 18


def log(msg: str) -> None:
    print(f"[xhs] {msg}", flush=True)


def first_locator(page, selectors, timeout_ms: int = 1200, state: str = "visible"):
    """按候选选择器依次探测，返回第一个命中的元素；全失败返回 None。

    注意：文件上传框通常是 display:none 的隐藏 input，必须用 state="attached"，
    否则永远等不到可见状态。
    """
    for sel in selectors:
        try:
            loc = page.locator(sel).first
            loc.wait_for(state=state, timeout=timeout_ms)
            return loc
        except Exception:
            continue
    return None


def any_visible(page, selectors) -> bool:
    return first_locator(page, selectors, timeout_ms=800) is not None


def has_session(ctx) -> bool:
    """登录态判定：创作者域下存在会话 Cookie。"""
    try:
        names = {c.get("name") for c in ctx.cookies("https://creator.xiaohongshu.com")}
    except Exception:
        return False
    return bool(names & {"web_session", "access-token-creator.xiaohongshu.com", "customerClientId"})


def load_draft(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(data, list):
        data = data[0]
    images = data.get("images") or []
    resolved = []
    for item in images:
        p = Path(item)
        if not p.is_absolute():
            p = (path.parent / p).resolve()
            if not p.exists():
                p = (ROOT / item).resolve()
        resolved.append(p)
    missing = [str(p) for p in resolved if not p.exists()]
    if missing:
        raise SystemExit("图片不存在：\n  " + "\n  ".join(missing))
    data["images"] = resolved
    return data


def validate(draft: dict) -> list[str]:
    warns: list[str] = []
    title = (draft.get("title") or "").strip()
    content = (draft.get("content") or "").strip()
    images = draft.get("images") or []
    if not title:
        warns.append("标题为空（小红书笔记可以无标题，但推荐填写）")
    if title and len(title) > TITLE_MAX:
        warns.append(f"标题 {len(title)} 字，超过上限 {TITLE_MAX}，发布页会截断")
    if not content:
        warns.append("正文为空")
    if len(content) > CONTENT_MAX:
        warns.append(f"正文 {len(content)} 字，超过上限 {CONTENT_MAX}")
    if not (1 <= len(images) <= IMAGE_MAX):
        warns.append(f"图片 {len(images)} 张，小红书图文笔记要求 1-{IMAGE_MAX} 张")
    for w in warns:
        log(f"⚠ {w}")
    return warns


def wait_login(page, ctx, timeout_s: int) -> None:
    """等到发布页出现文件上传 input（隐藏的也算）；期间负责跳回发布页。"""
    deadline = time.time() + timeout_s
    hinted = False
    jumped = 0
    while time.time() < deadline:
        if first_locator(page, SEL_FILE_INPUT, timeout_ms=600, state="attached"):
            return
        if has_session(ctx):
            # 已登录但被留在登录页 / 首页：重新进入发布页（最多 3 次，避免死循环）
            if "/login" in page.url or "/publish" not in page.url:
                if jumped < 3:
                    jumped += 1
                    log(f"检测到登录态，重新进入发布页（第 {jumped} 次）…")
                    page.goto(PUBLISH_URL, wait_until="domcontentloaded", timeout=60_000)
                    page.wait_for_timeout(2500)
                    continue
        elif not hinted:
            log(f"未登录：请在打开的 Chrome 里扫码登录（最多等 {timeout_s} 秒）")
            hinted = True
        time.sleep(1.5)
    raise SystemExit("等待登录超时。可在浏览器里登录后重跑，或加大 --login-timeout。")


def open_publish_page(page, ctx) -> None:
    page.goto(PUBLISH_URL, wait_until="domcontentloaded", timeout=60_000)
    page.wait_for_timeout(2500)

    tab = first_locator(page, SEL_IMAGE_TAB, timeout_ms=2500)
    if tab:
        try:
            tab.click(timeout=5000)
            page.wait_for_timeout(800)
            return
        except PWError:
            pass

    if not has_session(ctx):
        return  # 还在登录页，交给 wait_login

    # 兜底：直接尝试图文发布页的几种历史 URL 形态
    for url in (
        "https://creator.xiaohongshu.com/publish/publish?target=image",
        "https://creator.xiaohongshu.com/publish/publish?source=official&target=image",
    ):
        page.goto(url, wait_until="domcontentloaded", timeout=45_000)
        page.wait_for_timeout(1800)
        if first_locator(page, SEL_FILE_INPUT, timeout_ms=1500, state="attached"):
            return
    log("没找到「上传图文」标签，可能已在图文页或页面已改版")


def dump_page_hints(page, tag: str) -> None:
    """把当前 URL 与可见按钮文本写进日志，方便对照改版后的页面。"""
    try:
        labels = page.evaluate(
            """() => Array.from(document.querySelectorAll('button, [role=tab], [class*=tab]'))
                .map(e => (e.innerText || '').trim())
                .filter(t => t && t.length < 16).slice(0, 20)"""
        )
    except Exception:
        labels = []
    log(f"[{tag}] url={page.url}")
    log(f"[{tag}] 文本样张={labels}")


def count_uploaded_images(page) -> int:
    """读页面上「图片编辑 n/18」里的 n；读不到时回退到编辑器图片统计。"""
    try:
        n = page.evaluate(
            """() => {
                for (const t of document.querySelectorAll('.title')) {
                    if ((t.textContent || '').trim() === '图片编辑') {
                        const s = t.parentElement && t.parentElement.querySelector('.status');
                        const m = s && (s.textContent || '').match(/(\\d+)\\s*\\/\\s*(\\d+)/);
                        if (m) return parseInt(m[1], 10);
                    }
                }
                return -1;
            }"""
        )
        if isinstance(n, int) and n >= 0:
            return n
    except Exception:
        pass
    try:
        return page.evaluate(
            """() => Array.from(document.querySelectorAll('img')).filter(i => {
                const s = i.src || '';
                return (s.startsWith('blob:') || s.startsWith('data:')
                        || s.includes('ci.xiaohongshu.com')) && i.naturalWidth >= 60;
            }).length"""
        )
    except Exception:
        return 0


def attach_images(page, images: list[Path]) -> None:
    inp = first_locator(page, SEL_FILE_INPUT, timeout_ms=8000, state="attached")
    if inp is None:
        raise SystemExit("找不到文件上传 input；跑 probe_publish_page.py 校准选择器")
    inp.set_input_files([str(p) for p in images])
    log(f"已投递 {len(images)} 张图片，等待上传…")

    deadline = time.time() + max(30, len(images) * 10)
    while time.time() < deadline:
        page.wait_for_timeout(1000)
        fail = first_locator(page, ["text=上传失败", "text=重新上传"], timeout_ms=300)
        if fail is not None:
            raise SystemExit("图片上传失败（发布页提示重新上传），请检查图片格式/大小")
        if count_uploaded_images(page) >= len(images):
            break
    else:
        log("上传等待超时，若缩略图不齐请在页面上手动补传")
    log(f"已识别 {count_uploaded_images(page)}/{len(images)} 张缩略图")


def fill_title(page, title: str) -> None:
    if not title:
        return
    loc = first_locator(page, SEL_TITLE, timeout_ms=5000)
    if loc is None:
        log("⚠ 找不到标题输入框，标题需人工粘贴")
        return
    try:
        loc.click()
        loc.fill(title[:TITLE_MAX])
        log(f"标题已填：{title[:TITLE_MAX]}")
    except PWError as exc:
        log(f"⚠ 填写标题失败：{exc}")


def fill_body(page, content: str, tags: list[str]) -> None:
    body = content.strip()
    if tags:
        body += "\n\n" + " ".join(f"#{t}" for t in tags if t)
    if not body:
        return
    body = body[:CONTENT_MAX]

    loc = first_locator(page, SEL_EDITOR, timeout_ms=5000)
    if loc is None:
        log("⚠ 找不到正文编辑区，正文需人工粘贴")
        return
    try:
        loc.click()
        # 逐字输入：比 fill/insert_text 更接近真实输入，Quill 类编辑器兼容性也更好
        page.keyboard.type(body, delay=6)
        page.wait_for_timeout(400)
        # 输入 #tag 会弹出话题联想下拉，按 Esc 收起，避免遮挡标题输入框
        try:
            page.keyboard.press("Escape")
        except PWError:
            pass
        log(f"正文已填（{len(body)} 字，含话题标签）")
    except PWError as exc:
        log(f"⚠ 填写正文失败：{exc}")


def snapshot(page, name: str) -> Path:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    shot = OUT_DIR / f"{name}.png"
    page.screenshot(path=str(shot), full_page=False)
    html = OUT_DIR / f"{name}.html"
    html.write_text(page.content(), encoding="utf-8")
    log(f"已保存截图 {shot}")
    log(f"已保存 DOM  {html}")
    return shot


def wait_for_human(page, skip: bool) -> None:
    log("—" * 60)
    log("已停在「发布前」。请在浏览器里检查图片顺序、正文排版和话题标签，")
    log("确认无误后 **自己点击「发布」**（脚本不会点）。")
    log("—" * 60)
    if skip:
        return
    try:
        input("检查并发布完成后，按回车关闭浏览器（直接关窗口也行）…")
    except EOFError:
        # 无交互终端（后台运行）时，保留浏览器 10 分钟供人工检查/发布
        log("无交互终端：浏览器将保留 10 分钟，请在此期间人工检查并发布")
        page.wait_for_timeout(600_000)


def run_check() -> int:
    """无头自检：只验证 Playwright/Chrome 可用、页面能打开，不做任何写操作。"""
    with sync_playwright() as pw:
        browser = pw.chromium.launch(channel="chrome", headless=True)
        page = browser.new_page()
        page.goto(HOME_URL, wait_until="domcontentloaded", timeout=60_000)
        page.wait_for_timeout(2500)
        print("url     :", page.url)
        print("title   :", page.title())
        print("登录态   :", "未知（无头模式不共用登录态）")
        browser.close()
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="小红书创作者中心半自动发帖（不自动点发布）")
    ap.add_argument("--draft", type=Path, help="素材清单 JSON")
    ap.add_argument("--check", action="store_true", help="无头自检，不做任何写操作")
    ap.add_argument("--dry-run", action="store_true", help="只打开发布页，不投递内容")
    ap.add_argument("--no-wait", action="store_true", help="填完立即退出，不等待人工确认")
    ap.add_argument("--login-timeout", type=int, default=300, help="等待扫码登录的秒数")
    ap.add_argument("--headless", action="store_true", help="无头运行（不推荐，扫码需人工）")
    ap.add_argument("--keep-profile", action="store_true", help="保留上一次的浏览器进程状态")
    args = ap.parse_args()

    if args.check:
        return run_check()
    if not args.draft:
        ap.error("需要 --draft 素材清单，或用 --check 自检")

    draft = load_draft(args.draft)
    log(f"素材：{args.draft}（{len(draft.get('images') or [])} 张图）")
    validate(draft)

    STATE_DIR.mkdir(parents=True, exist_ok=True)
    name = (draft.get("name") or "draft").strip().replace(" ", "_") or "draft"

    with sync_playwright() as pw:
        ctx = pw.chromium.launch_persistent_context(
            user_data_dir=str(STATE_DIR),
            channel="chrome",
            headless=args.headless,
            no_viewport=True,
            args=["--disable-blink-features=AutomationControlled"],
        )
        page = ctx.pages[0] if ctx.pages else ctx.new_page()
        try:
            open_publish_page(page, ctx)
            wait_login(page, ctx, args.login_timeout)
            dump_page_hints(page, "ready")
            log("发布页就绪")

            if args.dry_run:
                snapshot(page, f"{name}-dryrun")
                log("dry-run：未投递任何内容")
                wait_for_human(page, args.no_wait)
                return 0

            images = draft.get("images") or []
            if images:
                attach_images(page, images)
            fill_title(page, (draft.get("title") or "").strip())
            fill_body(page, draft.get("content") or "", draft.get("tags") or [])
            page.wait_for_timeout(1200)
            snapshot(page, f"{name}-ready")
            wait_for_human(page, args.no_wait)
            return 0
        finally:
            if args.keep_profile:
                input("按回车结束进程…")
            ctx.close()


if __name__ == "__main__":
    raise SystemExit(main())