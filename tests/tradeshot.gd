extends "res://tests/lib/test_base.gd"
## 交易 / 委托界面截图 → review/trade.png
func run() -> void:
	await wait(1.6)
	var h = get_parent().hub
	if h == null:
		fail("没有机库")
		return
	h._switch_tab("trade")
	await wait(0.6)
	await shot("trade_list.png")
	h._select_merchant("ajin")
	await wait(0.6)
	await shot("trade_deal.png")
	log_line("tradeshot ok")
