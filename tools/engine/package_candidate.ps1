param(
    [Parameter(Mandatory=$true)][string]$Pack,
    [Parameter(Mandatory=$true)][string]$Runtime,
    [Parameter(Mandatory=$true)][string]$Output
)
$ErrorActionPreference = 'Stop'
$packPath = (Resolve-Path -LiteralPath $Pack).Path
$runtimePath = (Resolve-Path -LiteralPath $Runtime).Path
$outputPath = [IO.Path]::GetFullPath($Output)
if (Test-Path -LiteralPath $outputPath) { throw 'Choose a new output directory; candidates are never overwritten' }
New-Item -ItemType Directory -Path $outputPath | Out-Null
Copy-Item -LiteralPath $packPath -Destination (Join-Path $outputPath 'AbyssDiverGirls.pck')
Copy-Item -LiteralPath (Join-Path $runtimePath 'godot.exe') -Destination (Join-Path $outputPath 'AbyssDiverGirls.exe')
foreach ($name in @('LICENSE.txt','COPYRIGHT.txt','build.json')) {
    Copy-Item -LiteralPath (Join-Path $runtimePath $name) -Destination $outputPath
}
$launch = "@echo off`r`nstart `"`" /D `"%~dp0`" `"%~dp0AbyssDiverGirls.exe`"`r`n"
[IO.File]::WriteAllText((Join-Path $outputPath 'Play.bat'), $launch, [Text.Encoding]::ASCII)
$record = [ordered]@{
    packaged_at = [DateTime]::UtcNow.ToString('o')
    source_pack = $packPath
    runtime = $runtimePath
    pack_sha256 = (Get-FileHash -LiteralPath $packPath -Algorithm SHA256).Hash
    exe_sha256 = (Get-FileHash -LiteralPath (Join-Path $outputPath 'AbyssDiverGirls.exe') -Algorithm SHA256).Hash
    kind = 'Local performance candidate; contains diagnostic tests; not a public release.'
}
$record | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outputPath 'candidate.json') -Encoding UTF8
Write-Output $outputPath
