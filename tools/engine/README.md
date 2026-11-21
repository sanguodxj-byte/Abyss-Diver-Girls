# 修补运行时

Godot 4.7.2 的反射探针颜色 cubemap 在图集清理时没有释放。本目录保留最小引擎补丁和可复现构建入口，实机证据见 `docs/Godot472反射探针资源问题.md`。

构建需要官方 `godot-4.7.2-stable.tar.xz`、LLVM-MinGW 20261117 UCRT x86_64 和装有 SCons 4.11.1 的 Python。源归档及工具链哈希见上述报告。使用独立目录，不覆盖官方 Godot。

```powershell
./tools/engine/build_runtime.ps1 -Source D:/123/tmp/godot472-reflection-fix/godot-4.7.2-stable -Toolchain D:/123/tmp/godot472-toolchain/llvm-mingw-20261117-ucrt-x86_64 -Python D:/123/tmp/godot472-build-venv/Scripts/python.exe -SourceRunner
```

默认构建 `template_debug`；`-SourceRunner` 启用源码目录运行，输出到 `build/runtime-patched/template_debug-source`。省略该参数输出到 `template_debug`，用于与同目录 `godot.pck` 一起运行。输出包括构建参数、补丁/源码/二进制哈希和引擎许可证。

本轮验证 Vulkan Forward+。为避免引入未安装的后端依赖，D3D12、ANGLE、WinRT 不在此构建中；不能将结果推广到这些后端。源码运行版本没有编辑器导入器；新增或修改需导入的素材后仍需使用官方编辑器完成导入。

构建成功后至少运行 `hub_lifecycle --expect-stable`、生命周期/存档/转场回归，再使用 `tools/perf_monitor.py --engine <exe>` 采样。修改引擎或构建参数后，不沿用旧可执行文件的验收结论。
