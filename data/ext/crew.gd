extends RefCounted
## 船员日常文字的扩展数据：启动时由 GameData 并入核心表（规则见 scripts\game_data.gd 的「内容注册」一节）。
##
## DISPATCH_LINES  追加机库电台台词，格式与 GameData.DISPATCH_LINES 相同：一整句字符串「说话人：「台词」」，机库每次随机显示一句。

const DISPATCH_LINES := []
