extends RefCounted
## 剧情团队的扩展数据：启动时由 GameData 并入核心表（规则见 scripts\game_data.gd 的「内容注册」一节）。
##
## ITEMS   剧情物品（档案物件以外的关键道具）。
## SFX     对话演出、通讯小窗音效的登记（格式同 scripts\audio\audio_registry.gd 的 SFX）。
## RAID_SCRIPTS  行动扩展脚本路径（规则见 scripts\raid.gd 的 _run_ext_build），如局内通讯小窗与局内剧情触发。
## EXTEND  给已有条目补字段。

const ITEMS := {}

## 对话演出与无线电小窗的音效。文件缺失时静默跳过，不影响演出推进。
## 局内通讯小窗由 scripts\hud.gd 挂载，触发与排队在 scripts\story\story_flow.gd，无需行动扩展脚本。
const SFX := {
	"story_open": {"files": ["story_open.wav"], "when": "对话演出开始，画面压暗、立绘入场（dialogue_player.gd open）", "bus": "UI", "d3": false, "vol": -4.0, "pitch": 0.0, "max": 1},
	"story_close": {"files": ["story_close.wav"], "when": "对话演出结束（播完、跳过或 Esc）", "bus": "UI", "d3": false, "vol": -5.0, "pitch": 0.0, "max": 1},
	"story_text": {"files": ["story_text.wav"], "when": "每句台词开始逐字显示", "bus": "UI", "d3": false, "vol": -10.0, "pitch": 0.02, "max": 2},
	"comm_open": {"files": ["comm_open_01.wav", "comm_open_02.wav"], "when": "无线电小窗出现一条新通讯（radio_window.gd _show）", "bus": "UI", "d3": false, "vol": -6.0, "pitch": 0.03, "max": 2},
}
const RAID_SCRIPTS := []
const EXTEND := {}
