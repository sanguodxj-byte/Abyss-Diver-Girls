# 小红书半自动发帖（备用工具）

用 Playwright 驱动本机 Chrome 进入小红书创作者中心，完成 **挂图 → 填标题 → 填正文**，
然后**停下来**，把「发布」按钮留给人点。

> 长期维护版本已封装为 CodeArts Skill：`%USERPROFILE%\.codearts\skills\xiaohongshu-publish`
> （触发词「发小红书」「发布小红书笔记」）。本目录是项目内原型，逻辑与 skill 版一致，
> 后续以 skill 版为准，改这里需同步过去。

> 现状说明：小红书开放平台没有对外开放的「发布笔记」服务端接口
> （`write_notes` 权限仍是「规划中，需人工审核，仅特定场景开放」）。
> 本工具走的是浏览器自动化，属于**半自动**方案，风险见文末。

## 依赖

```powershell
python -m pip install playwright
```

浏览器直接用本机 Chrome（`channel="chrome"`），无需 `playwright install`。

## 首次使用

```powershell
# 1. 打开发布页，用小红书 App 扫码登录（登录态保存在 tools/xhs_publish/state/profile）
python tools/xhs_publish/post_note.py --draft tools/xhs_publish/posts.example.json --dry-run
```

扫码后脚本会自动进入图文发布页并停在「上传前」。确认页面正常后，用真实素材跑一次：

```powershell
python tools/xhs_publish/post_note.py --draft tools/xhs_publish/posts.example.json
```

脚本会：

1. 复用登录态打开 `creator.xiaohongshu.com` 发布页；
2. 切到「上传图文」，把 `images` 里的图片一次性投递给文件上传框；
3. 填标题（截断到 20 字）、填正文（`content` + 自动拼 `#标签`）；
4. 保存页面截图与 DOM 到 `tools/xhs_publish/out/`；
5. 在终端等你回车——期间浏览器保持打开，**发布由你手动点击**。

## 素材清单格式

```json
{
  "name": "文件名前缀，产物截图用",
  "title": "标题，≤20 字",
  "content": "正文，≤1000 字，支持 \\n 换行",
  "tags": ["独立游戏", "像素风"],
  "images": ["assets/illustrations/xxx.png"]
}
```

- `images` 支持绝对路径，或相对 JSON 文件 / 仓库根目录的路径，1–18 张，png/jpg/webp。
- 话题标签以纯文本 `#标签` 追加在正文末尾；需要做成可点击话题时，在发布页手动从联想下拉里选。
- 一次只处理一个草稿；要批量就准备多个 JSON，逐个跑。

## 实测记录（2026-11-19）

真机跑通：账号 `GungnirRH` 下投递 2 张图、填标题与正文，产物见 `out/draft-test-ready.png/.html`，页面无报错。

踩过并已修的问题：

- 文件上传框是 `display:none` 的隐藏 input，必须用 `state="attached"` 探测；用 `visible` 会永远等不到、直接超时。
- 登录后可能停在登录页/首页，脚本会检测会话 Cookie 并自动跳回发布页（最多 3 次）。
- 输入 `#话题` 会弹出联想下拉遮住标题，脚本填完正文自动按 `Esc` 收起。
- 图片计数改为读取页面「图片编辑 n/18」的计数，避免把侧栏头像算进去。
- 发布页有「图片可以编辑啦」引导浮层，若挡住视线可手点关闭，不影响字段已写入。

## 常用参数

| 参数 | 用途 |
|---|---|
| `--dry-run` | 只打开发布页，不投递内容（首次登录/验收用） |
| `--check` | 无头自检：验证 Playwright + Chrome 能启动，不做任何写操作 |
| `--login-timeout 600` | 放宽扫码等待时间 |
| `--no-wait` | 填完立即退出（不推荐，会丢掉未发布的草稿） |
| `--keep-profile` | 退出时多等一次回车，方便观察后台进程 |

## 小红书改版了怎么办

选择器失效（找不到标题框 / 编辑区）时：

```powershell
python tools/xhs_publish/probe_publish_page.py
```

在弹出页面里切到「上传图文」，按回车采样，然后把 `out/probe.json` 里的
`inputs` / `editables` / `fileInputs` 特征回填到 `post_note.py` 顶部的
`SEL_TITLE` / `SEL_EDITOR` / `SEL_FILE_INPUT` 候选列表（按优先级从上往下排）。
脚本对每个选择器都有回退与降级提示，单点失败不会中断整体流程。

## 风险提示

- 该方案**不是官方接口**，属于自动化操作，与平台用户协议存在冲突风险；
- 建议：单账号每天 1–3 条，保留人工检查与发布环节，避免纯模板化文案，不要多账号同 IP 批量操作；
- 被判定营销号后的限流通常 7–30 天且申诉成功率低，账号权重比发布效率更值钱。

## 目录

```
tools/xhs_publish/
  post_note.py            # 主脚本
  probe_publish_page.py   # DOM 采样 / 选择器校准
  posts.example.json      # 素材清单示例
  state/profile/          # Chrome 登录态（已 gitignore，勿提交）
  out/                    # 截图与 DOM 快照（已 gitignore）
```