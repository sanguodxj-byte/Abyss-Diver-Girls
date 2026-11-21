@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo 浏览器打开 http://127.0.0.1:8765/
python tools\serve_web.py
pause
