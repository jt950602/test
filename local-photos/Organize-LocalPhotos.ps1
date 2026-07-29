# Organize photos under C:\Local into service folders.
# ASCII-only (safe for Windows PowerShell encoding).
#
# DEFAULT = MOVE files.
# Prefer launching via RUN-MOVE.cmd (writes log next to script + Desktop).

[CmdletBinding()]
param(
    [string]$Root = 'C:\Local',
    [switch]$Preview,
    [switch]$Copy,
    [switch]$InboxOnly,
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }

function U {
    param([int[]]$Codes)
    return -join ($Codes | ForEach-Object { [char]$_ })
}

# Write log in 3 places so user always finds it
$scriptLog = Join-Path $scriptDir 'organize-log.txt'
$desktopLog = Join-Path $env:USERPROFILE 'Desktop\local-organize-log.txt'
$logBuffers = New-Object System.Collections.Generic.List[string]

function Write-Log {
    param([string]$Message)
    $line = ('{0}  {1}' -f (Get-Date -Format 'HH:mm:ss'), $Message)
    Write-Host $Message
    $logBuffers.Add($line) | Out-Null
}

function Save-Logs {
    param([string]$RootPath)
    $text = $logBuffers -join [Environment]::NewLine
    try { Set-Content -LiteralPath $scriptLog -Value $text -Encoding UTF8 } catch {}
    try { Set-Content -LiteralPath $desktopLog -Value $text -Encoding UTF8 } catch {}
    if ($RootPath) {
        try {
            if (-not (Test-Path -LiteralPath $RootPath)) {
                New-Item -ItemType Directory -Path $RootPath -Force | Out-Null
            }
            Set-Content -LiteralPath (Join-Path $RootPath '_organize-log.txt') -Value $text -Encoding UTF8
        } catch {}
    }
}

trap {
    Write-Log ("FATAL: {0}" -f $_.Exception.Message)
    Save-Logs -RootPath $Root
    break
}

$DoWrite = -not $Preview

$RU = @{
    manikyur   = (U 0x43C,0x430,0x43D,0x438,0x43A,0x44E,0x440)
    nogt       = (U 0x43D,0x43E,0x433,0x442)
    french     = (U 0x444,0x440,0x435,0x43D,0x447)
    design     = (U 0x434,0x438,0x437,0x430,0x439,0x43D)
    art        = (U 0x430,0x440,0x442)
    pedikyur   = (U 0x43F,0x435,0x434,0x438,0x43A,0x44E,0x440)
    resnic     = (U 0x440,0x435,0x441,0x43D,0x438,0x446)
    narash     = (U 0x43D,0x430,0x440,0x430,0x449,0x438,0x432,0x430,0x43D)
    obyom      = (U 0x43E,0x431,0x44A,0x435,0x43C)
    obyom2     = (U 0x43E,0x431,0x44A,0x451,0x43C)
    brov       = (U 0x431,0x440,0x43E,0x432)
    permanent  = (U 0x43F,0x435,0x440,0x43C,0x430,0x43D,0x435,0x43D,0x442)
    tatuzh     = (U 0x442,0x430,0x442,0x443,0x430,0x436)
    massazh    = (U 0x43C,0x430,0x441,0x441,0x430,0x436)
    complex    = (U 0x43A,0x43E,0x43C,0x43F,0x43B,0x435,0x43A,0x441)
    interier   = (U 0x438,0x43D,0x442,0x435,0x440,0x44C,0x435,0x440)
    zal        = (U 0x437,0x430,0x43B)
    studiya    = (U 0x441,0x442,0x443,0x434,0x438,0x44F)
    salon      = (U 0x441,0x430,0x43B,0x43E,0x43D)
    master     = (U 0x43C,0x430,0x441,0x442,0x435,0x440)
    komand     = (U 0x43A,0x43E,0x43C,0x430,0x43D,0x434)
    logo       = (U 0x43B,0x43E,0x433,0x43E)
    brand      = (U 0x431,0x440,0x435,0x43D,0x434)
    doPosle    = (U 0x434,0x43E) + '.?' + (U 0x43F,0x43E,0x441,0x43B,0x435)
    etap       = (U 0x44D,0x442,0x430,0x43F)
    gellak     = (U 0x433,0x435,0x43B)
    shellac    = (U 0x448,0x435,0x43B,0x43B,0x430,0x43A)
    pokryt     = (U 0x43F,0x43E,0x43A,0x440,0x44B,0x442)
    zilart     = (U 0x437,0x438,0x43B,0x430,0x440,0x442)
    stories    = (U 0x441,0x442,0x43E,0x440,0x438,0x441)
}

$Structure = @(
    '00_inbox',
    '01_raboty\manikyur\classic',
    '01_raboty\manikyur\french',
    '01_raboty\manikyur\baby-boomer',
    '01_raboty\manikyur\design',
    '01_raboty\pedikyur',
    '01_raboty\resnicy\classic',
    '01_raboty\resnicy\obyom',
    '01_raboty\brovi\oformlenie',
    '01_raboty\brovi\permanent',
    '01_raboty\massazh',
    '01_raboty\complex',
    '02_process',
    '03_prostranstvo',
    '04_komanda',
    '05_brand',
    '06_reels-raw',
    '_archive',
    '_publish\site',
    '_publish\vk-album',
    '_publish\stories',
    '_publish\cover',
    '_publish\telegram'
)

$MediaExt = @(
    '.jpg', '.jpeg', '.png', '.webp', '.heic', '.tif', '.tiff', '.bmp', '.gif',
    '.mp4', '.mov', '.m4v', '.avi', '.mkv', '.webm'
)

$ManagedTop = @(
    '00_inbox', '01_raboty', '02_process', '03_prostranstvo',
    '04_komanda', '05_brand', '06_reels-raw', '_archive', '_publish'
)

function Get-TargetRelative {
    param([string]$PathHint)
    $h = $PathHint.ToLower()
    $isVideo = $h -match '\.(mp4|mov|m4v|avi|mkv|webm)$'

    if ($h -match ("process|do.?posle|before|after|$($RU.doPosle)|$($RU.etap)")) { return '02_process' }
    if ($h -match ("interier|interior|studio|prostranstv|atmosphere|$($RU.interier)|$($RU.zal)|$($RU.studiya)")) { return '03_prostranstvo' }
    if ($h -match ("master|team|$($RU.master)|$($RU.komand)")) { return '04_komanda' }
    if ($h -match ("logo|brand|cover|avatar|template|$($RU.logo)|$($RU.brand)")) { return '05_brand' }
    if ($h -match ("massazh|massage|$($RU.massazh)")) { return '01_raboty\massazh' }
    if ($h -match ("pedikyur|pedicure|$($RU.pedikyur)")) { return '01_raboty\pedikyur' }
    if ($h -match ("complex|resnicy.?brovi|brovi.?resnicy|$($RU.complex)")) { return '01_raboty\complex' }
    if ($h -match ("resnic|lash|$($RU.resnic)|$($RU.narash)")) {
        if ($h -match ("obyom|volume|2d|3d|4d|$($RU.obyom)|$($RU.obyom2)")) { return '01_raboty\resnicy\obyom' }
        return '01_raboty\resnicy\classic'
    }
    if ($h -match ("permanent|$($RU.permanent)|$($RU.tatuzh)")) { return '01_raboty\brovi\permanent' }
    if ($h -match ("brov|brow|$($RU.brov)")) { return '01_raboty\brovi\oformlenie' }
    if ($h -match ("manikyur|manikur|manicure|nail|french|baby.?boomer|design|neon|botanical|nude|shellac|gel|nogt|$($RU.manikyur)|$($RU.nogt)|$($RU.french)|$($RU.design)|$($RU.art)|$($RU.gellak)|$($RU.shellac)|$($RU.pokryt)")) {
        if ($h -match ("french|$($RU.french)")) { return '01_raboty\manikyur\french' }
        if ($h -match 'baby.?boomer') { return '01_raboty\manikyur\baby-boomer' }
        if ($h -match ("design|nail.?art|neon|botanical|$($RU.design)|$($RU.art)")) { return '01_raboty\manikyur\design' }
        return '01_raboty\manikyur\classic'
    }
    if ($isVideo -or ($h -match ("reels|stories|story|shorts|$($RU.stories)"))) { return '06_reels-raw' }
    if ($h -match ("zilart|local.?beauty|salon|$($RU.zilart)|$($RU.salon)")) { return '03_prostranstvo' }

    $parent = [IO.Path]::GetFileName([IO.Path]::GetDirectoryName($PathHint))
    if ($parent) {
        $p = $parent.ToLower()
        if ($p -match ("manik|nail|nogt|$($RU.manikyur)|$($RU.nogt)")) { return '01_raboty\manikyur\classic' }
        if ($p -match ("resnic|lash|$($RU.resnic)")) { return '01_raboty\resnicy\classic' }
        if ($p -match ("brov|brow|$($RU.brov)")) { return '01_raboty\brovi\oformlenie' }
        if ($p -match ("massaz|$($RU.massazh)")) { return '01_raboty\massazh' }
        if ($p -match ("pedik|$($RU.pedikyur)")) { return '01_raboty\pedikyur' }
    }
    return '00_inbox'
}

function Get-UniquePath {
    param([string]$DestPath)
    if (-not (Test-Path -LiteralPath $DestPath)) { return $DestPath }
    $dir = Split-Path -Parent $DestPath
    $base = [IO.Path]::GetFileNameWithoutExtension($DestPath)
    $ext = [IO.Path]::GetExtension($DestPath)
    $i = 2
    do {
        $candidate = Join-Path $dir ('{0}_{1}{2}' -f $base, $i, $ext)
        $i++
    } while (Test-Path -LiteralPath $candidate)
    return $candidate
}

Write-Log '=== LOCAL Beauty Studio organizer ==='
Write-Log ("Script: {0}" -f $MyInvocation.MyCommand.Path)
Write-Log ("Root param: {0}" -f $Root)
Write-Log ("Preview={0} Copy={1} InboxOnly={2}" -f $Preview, $Copy, $InboxOnly)

try {
    if (-not (Test-Path -LiteralPath $Root)) {
        Write-Log ("Creating root: {0}" -f $Root)
        New-Item -ItemType Directory -Path $Root -Force | Out-Null
    }
    $Root = [IO.Path]::GetFullPath($Root)
    Write-Log ("Root resolved: {0}" -f $Root)

    if ($DoWrite) {
        if ($Copy) { Write-Log 'Mode: COPY' } else { Write-Log 'Mode: MOVE' }
    } else {
        Write-Log 'Mode: PREVIEW (no moves)'
    }

    foreach ($rel in $Structure) {
        $path = Join-Path $Root $rel
        if (-not (Test-Path -LiteralPath $path)) {
            if ($DoWrite) {
                New-Item -ItemType Directory -Path $path -Force | Out-Null
                Write-Log ("[mkdir] {0}" -f $rel)
            } else {
                Write-Log ("[mkdir?] {0}" -f $rel)
            }
        }
    }

    $scanRoot = if ($InboxOnly) { Join-Path $Root '00_inbox' } else { $Root }
    if (-not (Test-Path -LiteralPath $scanRoot)) {
        Write-Log ("Folder not found: {0}" -f $scanRoot)
        Save-Logs -RootPath $Root
        exit 1
    }

    $allAny = @(Get-ChildItem -LiteralPath $scanRoot -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -ne '_organize-log.txt' -and
            $_.Name -ne '_list.txt' -and
            $_.Name -ne 'README-struktura.txt' -and
            $_.Name -ne 'organize-log.txt'
        })
    $allMedia = @($allAny | Where-Object { $MediaExt -contains $_.Extension.ToLowerInvariant() })

    Write-Log ("Total files under scan: {0}" -f $allAny.Count)
    Write-Log ("Media files: {0}" -f $allMedia.Count)

    if ($allMedia.Count -eq 0) {
        Write-Log 'ERROR: no media files found under Root.'
        Write-Log 'Photos must be inside C:\Local (including subfolders).'
        if ($allAny.Count -gt 0) {
            Write-Log 'Non-media samples:'
            $allAny | Select-Object -First 20 | ForEach-Object { Write-Log ("  {0}" -f $_.FullName) }
        } else {
            Write-Log 'Directory appears empty (or inaccessible).'
            try {
                Get-ChildItem -LiteralPath $Root -Force | Select-Object -First 30 | ForEach-Object {
                    Write-Log ("  entry: {0}" -f $_.FullName)
                }
            } catch {
                Write-Log ("  list failed: {0}" -f $_.Exception.Message)
            }
        }
        Save-Logs -RootPath $Root
        exit 2
    }

    Write-Log 'Sample media:'
    $allMedia | Select-Object -First 20 | ForEach-Object { Write-Log ("  {0}" -f $_.FullName) }

    $toProcess = @()
    foreach ($f in $allMedia) {
        if ($InboxOnly) { $toProcess += $f; continue }
        $rel = $f.FullName.Substring($Root.Length).TrimStart('\', '/')
        $top = ($rel -split '[\\/]')[0]
        if (($ManagedTop -contains $top) -and ($top -ne '00_inbox')) { continue }
        $toProcess += $f
    }
    Write-Log ("Files to classify/move: {0}" -f $toProcess.Count)

    $stats = @{}
    $plan = New-Object System.Collections.Generic.List[object]
    foreach ($f in $toProcess) {
        $targetRel = Get-TargetRelative -PathHint $f.FullName
        $destDir = Join-Path $Root $targetRel
        $destPath = Join-Path $destDir $f.Name
        $fromDir = $f.DirectoryName.TrimEnd('\')
        $toDir = $destDir.TrimEnd('\')
        if ($fromDir -ieq $toDir) { continue }
        $destPath = Get-UniquePath -DestPath $destPath
        $plan.Add([pscustomobject]@{ From = $f.FullName; To = $destPath; Rel = $targetRel }) | Out-Null
        if (-not $stats.ContainsKey($targetRel)) { $stats[$targetRel] = 0 }
        $stats[$targetRel]++
    }

    if ($plan.Count -eq 0) {
        Write-Log 'Nothing to move (already organized or stuck in matching inbox folder).'
    } else {
        Write-Log 'Plan:'
        foreach ($key in ($stats.Keys | Sort-Object)) {
            Write-Log ('  {0,4} -> {1}' -f $stats[$key], $key)
        }
        $ok = 0; $fail = 0; $i = 0
        foreach ($item in $plan) {
            $i++
            $shortFrom = $item.From.Substring($Root.Length).TrimStart('\')
            $shortTo = $item.To.Substring($Root.Length).TrimStart('\')
            if (-not $DoWrite) {
                Write-Log ('[{0}/{1}] {2} => {3}' -f $i, $plan.Count, $shortFrom, $shortTo)
                continue
            }
            try {
                $destParent = Split-Path -Parent $item.To
                if (-not (Test-Path -LiteralPath $destParent)) {
                    New-Item -ItemType Directory -Path $destParent -Force | Out-Null
                }
                if ($Copy) {
                    Copy-Item -LiteralPath $item.From -Destination $item.To -Force
                    Write-Log ('[copy] {0} -> {1}' -f $shortFrom, $shortTo)
                } else {
                    Move-Item -LiteralPath $item.From -Destination $item.To -Force
                    Write-Log ('[move] {0} -> {1}' -f $shortFrom, $shortTo)
                }
                $ok++
            } catch {
                $fail++
                Write-Log ('[FAIL] {0} :: {1}' -f $shortFrom, $_.Exception.Message)
            }
        }
        if ($DoWrite) { Write-Log ("Done OK={0} FAIL={1}" -f $ok, $fail) }
    }

    $inboxDir = Join-Path $Root '00_inbox'
    if (Test-Path -LiteralPath $inboxDir) {
        $listPath = Join-Path $inboxDir '_list.txt'
        $inboxFiles = @(Get-ChildItem -LiteralPath $inboxDir -Recurse -File -Force -ErrorAction SilentlyContinue |
            Where-Object { $MediaExt -contains $_.Extension.ToLowerInvariant() })
        $lines = @('Files still in 00_inbox:', '')
        foreach ($inf in $inboxFiles) {
            $lines += $inf.FullName.Substring($inboxDir.Length).TrimStart('\')
        }
        Set-Content -LiteralPath $listPath -Value $lines -Encoding UTF8
        Write-Log ("Inbox remaining: {0}" -f $inboxFiles.Count)
    }

    if ($DoWrite -and -not $Copy) {
        Get-ChildItem -LiteralPath $Root -Directory -Recurse -Force -ErrorAction SilentlyContinue |
            Sort-Object { $_.FullName.Length } -Descending |
            ForEach-Object {
                $rel = $_.FullName.Substring($Root.Length).TrimStart('\', '/')
                if (-not $rel) { return }
                $top = ($rel -split '[\\/]')[0]
                if ($ManagedTop -contains $top) { return }
                $children = @(Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue)
                if ($children.Count -eq 0) {
                    Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
                    Write-Log ("[rmdir] {0}" -f $rel)
                }
            }
    }
} catch {
    Write-Log ("ERROR: {0}" -f $_.Exception.Message)
    Write-Log ($_ | Out-String)
}

Save-Logs -RootPath $Root
Write-Host ''
Write-Host "Log 1: $scriptLog"
Write-Host "Log 2: $desktopLog"
Write-Host "Log 3: $(Join-Path $Root '_organize-log.txt')"
Write-Host ''
