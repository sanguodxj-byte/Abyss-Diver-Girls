@echo off
chcp 65001 >nul
set "GAME_ENGINE=%~dp0build\runtime-patched\template_debug-source\godot.exe"
if not exist "%GAME_ENGINE%" set "GAME_ENGINE=D:\123\tmp\godot472\Godot_v4.7.2-stable_win64.exe"
start "" "%GAME_ENGINE%" --path "%~dp0"
