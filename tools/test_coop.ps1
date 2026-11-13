param(
    [string]$Godot = 'D:\123\tmp\godot472\Godot_v4.7.2-stable_win64_console.exe',
    [ValidateRange(2,4)][int]$Players = 2,
    [int]$Port = 28847,
    [string]$Test = 'coop_smoke',
    [switch]$Render
)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path $PSScriptRoot -Parent
$logDir = Join-Path $projectPath 'review'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$runs = @()
try {
    for ($i = 0; $i -lt $Players; $i++) {
        $role = if ($i -eq 0) { 'host' } else { "client$i" }
        $log = Join-Path $logDir "$Test-$role.log"
        $stderr = Join-Path $logDir "$Test-$role.stderr.log"
        $toolArguments = @('--headless', '--path', ('"' + $projectPath + '"'), '--', "--$Test", "--role=$role", "--port=$Port", "--count=$Players")
        if ($Render) { $toolArguments = $toolArguments | Where-Object { $_ -ne '--headless' } }
        $proc = Start-Process -FilePath $Godot -ArgumentList $toolArguments -PassThru -WindowStyle Hidden -RedirectStandardOutput $log -RedirectStandardError $stderr
        # Retain the native process handle; Windows PowerShell otherwise loses ExitCode
        # after HasExited/Refresh observes process termination.
        $null = $proc.Handle
        $runs += [pscustomobject]@{ Process=$proc; Role=$role; Log=$log; Stderr=$stderr }
    }
    $deadline = [DateTime]::UtcNow.AddSeconds(200)
    while (@($runs | Where-Object { -not $_.Process.HasExited }).Count -gt 0) {
        if ([DateTime]::UtcNow -gt $deadline) { throw 'Co-op test timed out' }
        Start-Sleep -Milliseconds 500
    }
    $failed = $false
    foreach ($run in $runs) {
        $run.Process.WaitForExit()
        $output = Get-Content -LiteralPath $run.Log -Raw -Encoding UTF8
        $errors = Get-Content -LiteralPath $run.Stderr -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        Write-Output "$($run.Role): exit=$($run.Process.ExitCode) $($run.Log)"
        Write-Output ($output -split "`n" | Where-Object { $_ -match "\[$Test\]" })
        if ($run.Process.ExitCode -ne 0 -or $output -notmatch "\[$Test\] DONE" -or $output -match '\] FAIL' -or $errors -match 'SCRIPT ERROR') {
            $failed = $true
            Write-Output $errors
        }
    }
    if ($failed) { exit 1 }
} finally {
    foreach ($run in $runs) {
        if (-not $run.Process.HasExited) { Stop-Process -Id $run.Process.Id -Force }
    }
}
