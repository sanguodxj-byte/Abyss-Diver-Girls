param(
    [Parameter(Mandatory=$true)][string]$Source,
    [Parameter(Mandatory=$true)][string]$Toolchain,
    [Parameter(Mandatory=$true)][string]$Python,
    [ValidateSet('template_debug','template_release')][string]$Target = 'template_debug',
    [ValidateRange(1,32)][int]$Jobs = 8,
    [switch]$SourceRunner
)
$ErrorActionPreference = 'Stop'
$sourcePath = (Resolve-Path -LiteralPath $Source).Path
$toolchainPath = (Resolve-Path -LiteralPath $Toolchain).Path
$pythonPath = (Resolve-Path -LiteralPath $Python).Path
$projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$patchPath = Join-Path $PSScriptRoot 'godot-4.7.2-reflection-cleanup.patch'
$shutdownPatchPath = Join-Path $PSScriptRoot 'godot-4.7.2-worker-shutdown.patch'
$engineFile = Join-Path $sourcePath 'servers/rendering/renderer_rd/storage_rd/light_storage.cpp'
$shutdownFile = Join-Path $sourcePath 'core/object/worker_thread_pool.cpp'
if (-not (Test-Path -LiteralPath (Join-Path $sourcePath 'SConstruct'))) { throw 'Not a Godot source tree' }
$versionText = Get-Content -LiteralPath (Join-Path $sourcePath 'version.py') -Raw
if ($versionText -notmatch '(?m)^major = 4$' -or $versionText -notmatch '(?m)^minor = 7$' -or $versionText -notmatch '(?m)^patch = 2$') {
    throw 'This patch is pinned to Godot 4.7.2'
}
Push-Location $sourcePath
try {
    foreach ($enginePatch in @($patchPath, $shutdownPatchPath)) {
        & git apply --check $enginePatch 2>$null
        if ($LASTEXITCODE -eq 0) {
            & git apply $enginePatch
            if ($LASTEXITCODE -ne 0) { throw "Cannot apply engine patch: $enginePatch" }
        } else {
            & git apply --reverse --check $enginePatch 2>$null
            if ($LASTEXITCODE -ne 0) { throw "Source does not match patch: $enginePatch" }
        }
    }
    $env:PATH = (Join-Path $toolchainPath 'bin') + ';' + $env:PATH
    $buildArguments = @('-m','SCons','platform=windows',"target=$Target",'arch=x86_64',
        'use_mingw=yes','use_llvm=yes',"mingw_prefix=$toolchainPath",'d3d12=no','angle=no',
        'winrt=no','debug_symbols=no','lto=none',"-j$Jobs")
    if ($SourceRunner) { $buildArguments += 'disable_path_overrides=no' }
    & $pythonPath @buildArguments
    if ($LASTEXITCODE -ne 0) { throw "Godot build failed: $LASTEXITCODE" }
    $binary = Join-Path $sourcePath "bin/godot.windows.$Target.x86_64.llvm.exe"
    $folder = if ($SourceRunner) { "${Target}-source" } else { $Target }
    $destination = Join-Path $projectRoot "build/runtime-patched/$folder"
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    Copy-Item -LiteralPath $binary -Destination (Join-Path $destination 'godot.exe')
    foreach ($licenseFile in @('LICENSE.txt','COPYRIGHT.txt')) {
        Copy-Item -LiteralPath (Join-Path $sourcePath $licenseFile) -Destination $destination
    }
    $console = $binary -replace '\.exe$', '.console.exe'
    if (Test-Path -LiteralPath $console) {
        # The generated console wrapper expects the original binary basename.
        Copy-Item -LiteralPath $binary -Destination $destination
        Copy-Item -LiteralPath $console -Destination $destination
    }
    $record = [ordered]@{
        built_at = [DateTime]::UtcNow.ToString('o')
        source = $sourcePath
        arguments = $buildArguments
        patch_sha256 = (Get-FileHash -LiteralPath $patchPath -Algorithm SHA256).Hash
        shutdown_patch_sha256 = (Get-FileHash -LiteralPath $shutdownPatchPath -Algorithm SHA256).Hash
        source_file_sha256 = (Get-FileHash -LiteralPath $engineFile -Algorithm SHA256).Hash
        shutdown_source_sha256 = (Get-FileHash -LiteralPath $shutdownFile -Algorithm SHA256).Hash
        binary_sha256 = (Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash
        acceptance = 'Build only; run test_exit.py, hub_lifecycle --expect-stable and gameplay regressions before using.'
    }
    $record | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $destination 'build.json') -Encoding UTF8
    Write-Output "Runtime: $destination"
} finally {
    Pop-Location
}
