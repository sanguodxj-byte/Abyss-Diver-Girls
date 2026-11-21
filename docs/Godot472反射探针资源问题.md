# Godot 4.7.2 反射探针资源问题

实机验证：`Godot_v4.7.2-stable_win64_console.exe`，Forward+，RTX 4060 Ti，1920×1080。

## 可复现证据

执行 `-- --hub_lifecycle`，连续创建并释放四次机库，每次显示/释放后各等待三秒。每次机库 Node 均释放，孤儿节点为零，但引擎显存基线依次为 281.606、284.606、287.606、290.606 MiB，退出时报告 28 个 Texture RID 未释放。

单独禁用天空、SSAO 或辉光均保持相同的每轮 3 MiB 增长和 28 个警告。仅在测试中移除 ReflectionProbe 后，四轮显存基线均为 263.481 MiB，退出没有 Texture RID 警告。相关日志：`review/hub_lifecycle_before.log`、`hub_lifecycle_no_sky.log`、`hub_lifecycle_no_ssao.log`、`hub_lifecycle_no_glow.log`、`hub_lifecycle_no_probe.log`。测试选项不改变正常游戏行为。

## 对应引擎源码

对应版本文件：
https://github.com/godotengine/godot/blob/4.7.2-stable/servers/rendering/renderer_rd/storage_rd/light_storage.cpp

`reflection_probe_instance_begin_render` 为 atlas 创建一个 `color_buffer` cubemap，随后创建六个 `color_views`。`_reflection_atlas_clear` 释放 reflection、depth framebuffer、depth buffer 和各反射数据，却没有释放 `color_buffer`。这与每轮 1 + 6 个 Texture RID 警告，以及 256×256×6×8 = 3 MiB 的增长吻合。

已从准确版本源码编译补丁：在清理中释放 cubemap，由 RenderingDevice 释放其依赖视图。补丁纳入 `tools/engine/godot-4.7.2-reflection-cleanup.patch`，构建脚本为 `tools/engine/build_runtime.ps1`。官方 Godot 保留，没有提交到外部仓库。

## 修补运行时验证（后续轮次）

官方 4.7.2 加 `--expect-stable` 运行四轮，显存增加 9.000 MiB，门槛失败，28 个 Texture RID 警告，日志 `review/hub_lifecycle_official_gate.log`。

同版本源码补丁编译为 Windows x86_64 `template_debug`，用冻结项目导出 PCK 后实际启动。四轮退图后的显存基线相同，增长 0.000 MiB，孤儿节点为 0，退出无 Texture RID 警告，日志 `review/hub_lifecycle_patched_pck.log`。

扩展到 **20 轮**，每轮释放后的显存始终为 **278.605881 MiB**，节点数始终为 25，孤儿数始终为 0；退出无 ERROR / Texture RID 警告。日志为 `review/enginefix_pck_hub_lifecycle.log`，结构化结果为 `review/hub_lifecycle_patched_20.json`。编译与此资源生命周期回归并行，因此不使用本轮帧率作性能比较。

源码归档 SHA-256：`a18ce0ccec3ecc40b0dd6c4f5132ca934e9fb7c2979717940ff32aee1eb35481`；LLVM-MinGW 20261117 UCRT x86_64 工具链下载与官方 API digest 一致：`4d002e330a0f703625aa5ccbc37e96f8f824413e163bfc7336774aabd2c3a412`。使用 SCons 4.11.1；完整构建参数和二进制哈希保存在 `build/runtime-patched/*/build.json`。禁用未安装的 D3D12/ANGLE/WinRT 组件，测试路径使用 Vulkan；该运行时尚不代表其他图形后端验收。

## 已落地的独立显存优化

项目目前只在机库建立一个 ReflectionProbe，默认反射图集却为 64 槽。`project.godot` 将 `rendering/reflections/reflection_atlas/reflection_count` 设置为 4，给同一场景留出容量余量；反射分辨率、探针强度、盒投影、灯光和更新模式保持原值。

首轮机库引擎显存从 1,028.462 降至 562.906 MiB，减少 465.557 MiB，约 45.3%。图集容量优化本身没有解决释放缺陷，旧运行时的 `hub_lifecycle_atlas4.log` 仍保留 28 个警告；上面的修补运行时才完成实际释放。后续若在同一世界增加超过四个有效反射探针，需同步调整图集容量。
