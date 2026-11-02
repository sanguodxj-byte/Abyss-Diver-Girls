extends "res://tests/lib/test_base.gd"
## 二级菜单截图测试：整备、交易、降落、仓库、图鉴
const START := "hub"
const TIMEOUT := 60.0

func run() -> void:
	await wait(1.5)
	# 1. 整备
	main.hub._switch_tab("maintenance")
	await wait(0.8)
	await shot("hub_nav_01_maintenance.png")

	# 2. 交易（展示阿堇，切换一下小满与银）
	main.hub._switch_tab("trade")
	await wait(0.5)
	main.hub._select_merchant("xiaoman")
	await wait(0.5)
	await shot("hub_nav_02_trade.png")

	# 3. 降落（战区选择与出击准备）
	main.hub._switch_tab("deploy")
	await wait(0.5)
	await shot("hub_nav_03_deploy.png")

	# 4. 仓库（分类与物品明细）
	main.hub._switch_tab("stash")
	await wait(0.5)
	if not main.hub.stash_ids.is_empty():
		main.hub.stash_list.select(0)
		main.hub._on_stash_selected(0)
	await wait(0.5)
	await shot("hub_nav_04_stash.png")

	# 5. 图鉴（船员、模块、异体）
	main.hub._switch_tab("codex")
	await wait(0.5)
	main.hub._populate_codex_list()
	await wait(0.5)
	await shot("hub_nav_05_codex.png")

	# 回到整备
	main.hub._switch_tab("maintenance")
	await wait(0.5)
