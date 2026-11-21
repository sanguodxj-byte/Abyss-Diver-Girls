param([string]$Godot = 'D:/123/tmp/godot472/Godot_v4.7.2-stable_win64_console.exe')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$output = Join-Path $projectRoot 'build/web'
New-Item -ItemType Directory -Path $output -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $projectRoot 'build/.gdignore') -Force | Out-Null
& $Godot --headless --path $projectRoot --export-release Web (Join-Path $output 'index.html')
if ($LASTEXITCODE -ne 0) { throw "Web export failed: $LASTEXITCODE" }
& python (Join-Path $PSScriptRoot 'compress_web.py') $output
if ($LASTEXITCODE -ne 0) { throw 'Web compression failed' }
Write-Output "Preview: python tools/serve_web.py --root $output"
