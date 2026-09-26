<#
  Mano Campaign Machine - one-shot Windows installer.

  STRICT RULE: nothing may run automatically at Windows startup.
  This script snapshots services, scheduled tasks, Startup folders and Run keys
  before and after the install, removes anything new, and reports it.

  It creates no passwords, tokens or keys, and never uses "Start with Windows".

  Run from an elevated (Administrator) PowerShell, or double-click
  Install-ManoCampaignMachine.cmd next to this file.
#>

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2

$ZipPath    = Join-Path $env:USERPROFILE 'Downloads\mano-campaign-machine.zip'
$InstallDir = 'C:\ManoCampaignMachine'
$LogDir     = Join-Path $InstallDir '_install-logs'
$Stamp      = Get-Date -Format 'yyyyMMdd-HHmmss'

$Installed = New-Object System.Collections.Generic.List[string]
$Failed    = New-Object System.Collections.Generic.List[string]
$Removed   = New-Object System.Collections.Generic.List[string]

function Say($msg) { Write-Host "[$(Get-Date -Format HH:mm:ss)] $msg" }

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Update-SessionPath {
    $m = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $u = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = (@($m, $u) | Where-Object { $_ }) -join ';'
}

# ---------------------------------------------------------------- snapshot
$StartupFolders = @(
    [Environment]::GetFolderPath('Startup'),        # user
    [Environment]::GetFolderPath('CommonStartup')   # all users
)
$RunKeys = @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
    'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'   # 32-bit view of HKLM Run
)

function Get-StartupSnapshot {
    $items = New-Object System.Collections.Generic.List[object]

    foreach ($s in Get-Service -ErrorAction SilentlyContinue) {
        $items.Add([pscustomobject]@{ Kind = 'Service'; Id = $s.Name; Detail = "$($s.DisplayName) | StartType=$($s.StartType)" })
    }
    foreach ($t in Get-ScheduledTask -ErrorAction SilentlyContinue) {
        $items.Add([pscustomobject]@{ Kind = 'ScheduledTask'; Id = "$($t.TaskPath)$($t.TaskName)"; Detail = "State=$($t.State)" })
    }
    foreach ($f in $StartupFolders) {
        if ($f -and (Test-Path -LiteralPath $f)) {
            foreach ($i in Get-ChildItem -LiteralPath $f -Force -ErrorAction SilentlyContinue) {
                $items.Add([pscustomobject]@{ Kind = 'StartupFolder'; Id = $i.FullName; Detail = '' })
            }
        }
    }
    foreach ($k in $RunKeys) {
        if (Test-Path $k) {
            $p = Get-ItemProperty -Path $k
            foreach ($prop in $p.PSObject.Properties) {
                if ($prop.Name -notmatch '^PS(Path|ParentPath|ChildName|Drive|Provider)$') {
                    $items.Add([pscustomobject]@{ Kind = 'RunKey'; Id = "$k\$($prop.Name)"; Detail = [string]$prop.Value })
                }
            }
        }
    }
    return ,$items
}

function Save-Snapshot($snap, $name) {
    $path = Join-Path $LogDir "$name-$Stamp.csv"
    $snap | Sort-Object Kind, Id | Export-Csv -LiteralPath $path -NoTypeInformation -Encoding UTF8
    Say "Snapshot saved: $path ($($snap.Count) items)"
}

function Remove-StartupItem($item) {
    switch ($item.Kind) {
        'Service' {
            Stop-Service -Name $item.Id -Force -ErrorAction SilentlyContinue
            & sc.exe delete $item.Id | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "sc.exe delete exit code $LASTEXITCODE" }
        }
        'ScheduledTask' {
            $leaf = Split-Path $item.Id -Leaf
            $path = $item.Id.Substring(0, $item.Id.Length - $leaf.Length)
            Unregister-ScheduledTask -TaskName $leaf -TaskPath $path -Confirm:$false
        }
        'StartupFolder' { Remove-Item -LiteralPath $item.Id -Recurse -Force }
        'RunKey' {
            $name = Split-Path $item.Id -Leaf
            $key  = $item.Id.Substring(0, $item.Id.Length - $name.Length - 1)
            Remove-ItemProperty -Path $key -Name $name -Force
        }
    }
}

function Compare-AndClean($before, $label) {
    $after = Get-StartupSnapshot
    Save-Snapshot $after $label
    $known = @{}
    foreach ($b in $before) { $known["$($b.Kind)|$($b.Id)"] = $true }
    $new = @($after | Where-Object { -not $known.ContainsKey("$($_.Kind)|$($_.Id)") })
    if ($new.Count -eq 0) { Say "Compare ($label): nothing new."; return }
    foreach ($n in $new) {
        $desc = "$($n.Kind): $($n.Id) $($n.Detail)".Trim()
        try   { Remove-StartupItem $n; $Removed.Add("REMOVED $desc"); Say "REMOVED new startup item -> $desc" }
        catch { $Failed.Add("Could not remove $desc : $($_.Exception.Message)"); Say "FAILED to remove $desc" }
    }
}

# ------------------------------------------------------------------ main
if (-not (Test-Path -LiteralPath $ZipPath)) { throw "Not found: $ZipPath" }
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
Start-Transcript -LiteralPath (Join-Path $LogDir "install-$Stamp.log") | Out-Null
if (-not (Test-Admin)) {
    Say 'WARNING: not running as Administrator - new services or HKLM Run values could not be removed.'
    $Failed.Add('Script was not run as Administrator (cleanup of services/HKLM limited)')
}

# 0. BEFORE snapshot
$Before = Get-StartupSnapshot
Save-Snapshot $Before 'before'

try {
    # 1. Extract zip (flatten a single top-level folder if the zip has one)
    Say "Extracting $ZipPath -> $InstallDir"
    $tmp = Join-Path $env:TEMP "mcm-extract-$Stamp"
    Expand-Archive -LiteralPath $ZipPath -DestinationPath $tmp -Force
    $root = $tmp
    $top  = @(Get-ChildItem -LiteralPath $tmp -Force)
    if ($top.Count -eq 1 -and $top[0].PSIsContainer) { $root = $top[0].FullName }
    Get-ChildItem -LiteralPath $root -Force | Copy-Item -Destination $InstallDir -Recurse -Force
    Remove-Item -LiteralPath $tmp -Recurse -Force
    foreach ($f in 'requirements.txt', 'start.bat', 'tests') {
        if (-not (Test-Path -LiteralPath (Join-Path $InstallDir $f))) { throw "Missing after extract: $f" }
    }
    $Installed.Add("App extracted to $InstallDir")

    # 2. Python 3.11+
    function Find-Python {
        $cands = @()
        if (Get-Command py -ErrorAction SilentlyContinue) { $cands += ,@('py', '-3') }
        $cands += ,@('python')
        foreach ($v in '313', '312', '311') {
            $cands += ,@((Join-Path $env:LOCALAPPDATA "Programs\Python\Python$v\python.exe"))
            $cands += ,@((Join-Path $env:ProgramFiles "Python$v\python.exe"))
        }
        $prevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'   # PS 5.1: stderr redirect + Stop = throw
        foreach ($c in $cands) {
            try {
                $exe = $c[0]; $args2 = @($c | Select-Object -Skip 1)
                $out = & $exe @args2 -c 'import sys;print(sys.executable);print(sys.version_info>=(3,11))' 2>$null
                if ($LASTEXITCODE -eq 0 -and @($out).Count -ge 2 -and @($out)[1] -eq 'True') { $ErrorActionPreference = $prevEap; return @($out)[0] }
            } catch { }
        }
        $ErrorActionPreference = $prevEap
        return $null
    }
    $Python = Find-Python
    if (-not $Python) {
        Say 'Python 3.11+ missing -> installing Python 3.12 via winget'
        winget install -e --id Python.Python.3.12 --accept-package-agreements --accept-source-agreements
        Update-SessionPath
        $Python = Find-Python
        if (-not $Python) { throw 'Python 3.12 install finished but python.exe was not found' }
        $Installed.Add('Python 3.12 (winget)')
    } else { Say "Python OK: $Python" }

    # 3. Node.js
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        Say 'Node.js missing -> installing Node.js LTS via winget'
        winget install -e --id OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements
        Update-SessionPath
        if (-not (Get-Command node -ErrorAction SilentlyContinue)) { throw 'Node.js install finished but node was not found' }
        $Installed.Add("Node.js $(node --version) (winget)")
    } else { Say "Node OK: $(node --version)" }

    # 4. Claude Code CLI
    Say 'npm install -g @anthropic-ai/claude-code'
    & npm.cmd install -g '@anthropic-ai/claude-code'
    if ($LASTEXITCODE -ne 0) { $Failed.Add("npm install -g @anthropic-ai/claude-code (exit $LASTEXITCODE)") }
    else { $Installed.Add('Claude Code CLI (npm -g)') }

    # 5. venv + requirements + tests
    Push-Location $InstallDir
    try {
        Say 'Creating .venv'
        & $Python -m venv .venv
        if ($LASTEXITCODE -ne 0) { throw "venv creation failed (exit $LASTEXITCODE)" }
        $VPy = Join-Path $InstallDir '.venv\Scripts\python.exe'
        & $VPy -m pip install --upgrade pip
        & $VPy -m pip install -r requirements.txt
        if ($LASTEXITCODE -ne 0) { throw "pip install -r requirements.txt failed (exit $LASTEXITCODE)" }
        $Installed.Add('.venv + requirements.txt')

        Say 'Running unit tests'
        $ErrorActionPreference = 'Continue'   # unittest reports on stderr
        $testOut = @(& $VPy -m unittest discover -s tests -t . 2>&1 | ForEach-Object { "$_" })
        $testExit = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        $testOut | ForEach-Object { Write-Host $_ }
        if ($testExit -ne 0) { $Failed.Add("Unit tests FAILED (exit $testExit) - see log") }
        else {
            $ran = ($testOut | Select-String -Pattern '^Ran \d+ tests?' | Select-Object -Last 1)
            $Installed.Add("Unit tests passed ($ran)")
        }
    } finally { Pop-Location }

    # 6. Desktop shortcut (Desktop only - never Startup)
    $desktop = [Environment]::GetFolderPath('Desktop')
    $lnk = Join-Path $desktop 'Mano Campaign Machine.lnk'
    $ws = New-Object -ComObject WScript.Shell
    $sc = $ws.CreateShortcut($lnk)
    $sc.TargetPath       = Join-Path $InstallDir 'start.bat'
    $sc.WorkingDirectory = $InstallDir
    $sc.Save()
    $Installed.Add("Desktop shortcut: $lnk")
}
catch {
    $Failed.Add("Install step failed: $($_.Exception.Message)")
    Say "ERROR: $($_.Exception.Message)"
}

# 7. AFTER snapshot + compare + remove anything new
Compare-AndClean $Before 'after-install'

# 9. Start the dashboard once (manual run, not at startup), then re-check
if (-not ($Failed | Where-Object { $_ -like 'Install step failed*' })) {
    Say 'Starting start.bat once'
    Start-Process -FilePath (Join-Path $InstallDir 'start.bat') -WorkingDirectory $InstallDir
    Start-Sleep -Seconds 20
    Compare-AndClean $Before 'after-first-start'
} else {
    $Failed.Add('start.bat not launched because an install step failed')
}

# ---------------------------------------------------------------- summary
$cmp = if ($Removed.Count -eq 0) { 'Before/after startup comparison: nothing new (0 services, tasks, Startup items or Run keys added).' }
       else { "Before/after startup comparison: $($Removed.Count) new item(s) found and removed -> " + ($Removed -join '; ') }
$fail = if ($Failed.Count -eq 0) { 'Failed: nothing.' } else { 'Failed: ' + ($Failed -join '; ') }
$summary = @('Installed: ' + ($Installed -join '; '), $cmp, $fail)
$summary | Set-Content -LiteralPath (Join-Path $LogDir "summary-$Stamp.txt") -Encoding UTF8
Write-Host ''
Write-Host '================ SUMMARY ================'
$summary | ForEach-Object { Write-Host $_ }
Stop-Transcript | Out-Null
