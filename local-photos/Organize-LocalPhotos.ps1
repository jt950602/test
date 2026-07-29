# Organize photos under C:\Local into service folders.
# ASCII-only (safe for Windows PowerShell encoding).
#
# DEFAULT = MOVE files.
# Preview only:
#   powershell -ExecutionPolicy Bypass -File .\Organize-LocalPhotos.ps1 -Preview
#
# Inbox only:
#   powershell -ExecutionPolicy Bypass -File .\Organize-LocalPhotos.ps1 -InboxOnly

[CmdletBinding()]
param(
    [string]$Root = 'C:\Local',
    [switch]$Preview,
    [switch]$Copy,
    [switch]$InboxOnly,
    # old switches kept so previous .cmd files still work
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'

# Move unless -Preview. Legacy: if someone passes only -Apply, still move.
$DoWrite = -not $Preview
if ($PSBoundParameters.ContainsKey('Apply') -and -not $Apply -and -not $Preview) {
    # explicit -Apply:$false
    $DoWrite = $false
}

function U {
    param([int[]]$Codes)
    return -join ($Codes | ForEach-Object { [char]$_ })
}

# Cyrillic fragments via char codes (never break on file encoding)
$RU = @{
    manikyur   = (U 0x43C,0x430,0x43D,0x438,0x43A,0x44E,0x440)           # маникюр
    nogt       = (U 0x43D,0x43E,0x433,0x442)                               # ногт
    french     = (U 0x444,0x440,0x435,0x43D,0x447)                         # френч
    design     = (U 0x434,0x438,0x437,0x430,0x439,0x43D)                   # дизайн
    art        = (U 0x430,0x440,0x442)                                     # арт
    pedikyur   = (U 0x43F,0x435,0x434,0x438,0x43A,0x44E,0x440)             # педикюр
    resnic     = (U 0x440,0x435,0x441,0x43D,0x438,0x446)                   # ресниц
    narash     = (U 0x43D,0x430,0x440,0x430,0x449,0x438,0x432,0x430,0x43D) # наращиван
    obyom      = (U 0x43E,0x431,0x44A,0x435,0x43C)                         # объем
    obyom2     = (U 0x43E,0x431,0x44A,0x451,0x43C)                         # объём
    brov       = (U 0x431,0x440,0x43E,0x432)                               # бров
    permanent  = (U 0x43F,0x435,0x440,0x43C,0x430,0x43D,0x435,0x43D,0x442) # перманент
    tatuzh     = (U 0x442,0x430,0x442,0x443,0x430,0x436)                   # татуаж
    massazh    = (U 0x43C,0x430,0x441,0x441,0x430,0x436)                   # массаж
    complex    = (U 0x43A,0x43E,0x43C,0x43F,0x43B,0x435,0x43A,0x441)       # комплекс
    interier   = (U 0x438,0x43D,0x442,0x435,0x440,0x44C,0x435,0x440)       # интерьер
    zal        = (U 0x437,0x430,0x43B)                                     # зал
    studiya    = (U 0x441,0x442,0x443,0x434,0x438,0x44F)                   # студия
    salon      = (U 0x441,0x430,0x43B,0x43E,0x43D)                         # салон
    master     = (U 0x43C,0x430,0x441,0x442,0x435,0x440)                   # мастер
    komand     = (U 0x43A,0x43E,0x43C,0x430,0x43D,0x434)                   # команд
    logo       = (U 0x43B,0x43E,0x433,0x43E)                               # лого
    brand      = (U 0x431,0x440,0x435,0x43D,0x434)                         # бренд
    doPosle    = (U 0x434,0x43E) + '.?' + (U 0x43F,0x43E,0x441,0x43B,0x435) # до.?после
    etap       = (U 0x44D,0x442,0x430,0x43F)                               # этап
    gellak     = (U 0x433,0x435,0x43B)                                     # гел
    shellac    = (U 0x448,0x435,0x43B,0x43B,0x430,0x43A)                   # шеллак
    pokryt     = (U 0x43F,0x43E,0x43A,0x440,0x44B,0x442)                   # покрыт
    zilart     = (U 0x437,0x438,0x43B,0x430,0x440,0x442)                   # зиларт
    stories    = (U 0x441,0x442,0x43E,0x440,0x438,0x441)                   # сторис
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

function Write-Log {
    param([string]$Message, [string]$LogFile)
    $line = ('{0}  {1}' -f (Get-Date -Format 'HH:mm:ss'), $Message)
    Write-Host $Message
    Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
}

function Get-TargetRelative {
    param([string]$PathHint)

    $h = $PathHint.ToLower()
    $isVideo = $h -match '\.(mp4|mov|m4v|avi|mkv|webm)$'

    if ($h -match ("process|do.?posle|before|after|$($RU.doPosle)|$($RU.etap)")) {
        return '02_process'
    }
    if ($h -match ("interier|interior|studio|prostranstv|atmosphere|$($RU.interier)|$($RU.zal)|$($RU.studiya)")) {
        return '03_prostranstvo'
    }
    if ($h -match ("master|team|$($RU.master)|$($RU.komand)")) {
        return '04_komanda'
    }
    if ($h -match ("logo|brand|cover|avatar|template|$($RU.logo)|$($RU.brand)")) {
        return '05_brand'
    }
    if ($h -match ("massazh|massage|$($RU.massazh)")) {
        return '01_raboty\massazh'
    }
    if ($h -match ("pedikyur|pedicure|$($RU.pedikyur)")) {
        return '01_raboty\pedikyur'
    }
    if ($h -match ("complex|resnicy.?brovi|brovi.?resnicy|$($RU.complex)")) {
        return '01_raboty\complex'
    }
    if ($h -match ("resnic|lash|$($RU.resnic)|$($RU.narash)")) {
        if ($h -match ("obyom|volume|2d|3d|4d|$($RU.obyom)|$($RU.obyom2)")) {
            return '01_raboty\resnicy\obyom'
        }
        return '01_raboty\resnicy\classic'
    }
    if ($h -match ("permanent|$($RU.permanent)|$($RU.tatuzh)")) {
        return '01_raboty\brovi\permanent'
    }
    if ($h -match ("brov|brow|$($RU.brov)")) {
        return '01_raboty\brovi\oformlenie'
    }
    if ($h -match ("manikyur|manikur|manicure|nail|french|baby.?boomer|design|neon|botanical|nude|shellac|gel|nogt|$($RU.manikyur)|$($RU.nogt)|$($RU.french)|$($RU.design)|$($RU.art)|$($RU.gellak)|$($RU.shellac)|$($RU.pokryt)")) {
        if ($h -match ("french|$($RU.french)")) { return '01_raboty\manikyur\french' }
        if ($h -match 'baby.?boomer') { return '01_raboty\manikyur\baby-boomer' }
        if ($h -match ("design|nail.?art|neon|botanical|$($RU.design)|$($RU.art)")) {
            return '01_raboty\manikyur\design'
        }
        return '01_raboty\manikyur\classic'
    }
    if ($isVideo -or ($h -match ("reels|stories|story|shorts|$($RU.stories)"))) {
        return '06_reels-raw'
    }
    if ($h -match ("zilart|local.?beauty|salon|$($RU.zilart)|$($RU.salon)")) {
        return '03_prostranstvo'
    }

    # Fallback: use immediate parent folder name as weak signal
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

# --- start ---
if (-not (Test-Path -LiteralPath $Root)) {
    New-Item -ItemType Directory -Path $Root -Force | Out-Null
}
$Root = [IO.Path]::GetFullPath($Root)
$logFile = Join-Path $Root '_organize-log.txt'
Set-Content -LiteralPath $logFile -Value ("LOG start {0}" -f (Get-Date)) -Encoding UTF8

Write-Log "=== LOCAL Beauty Studio organizer ===" $logFile
Write-Log ("Root: {0}" -f $Root) $logFile
if ($DoWrite) {
    if ($Copy) { Write-Log 'Mode: COPY' $logFile } else { Write-Log 'Mode: MOVE (files will be relocated)' $logFile }
} else {
    Write-Log 'Mode: PREVIEW only — NOTHING will be moved. Re-run without -Preview to apply.' $logFile
}

foreach ($rel in $Structure) {
    $path = Join-Path $Root $rel
    if (-not (Test-Path -LiteralPath $path)) {
        if ($DoWrite) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
            Write-Log ("[mkdir] {0}" -f $rel) $logFile
        } else {
            Write-Log ("[mkdir?] {0}" -f $rel) $logFile
        }
    }
}

$scanRoot = if ($InboxOnly) { Join-Path $Root '00_inbox' } else { $Root }
if (-not (Test-Path -LiteralPath $scanRoot)) {
    Write-Log ("Folder not found: {0}" -f $scanRoot) $logFile
    exit 1
}

$allAny = @(Get-ChildItem -LiteralPath $scanRoot -Recurse -File -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne '_organize-log.txt' -and $_.Name -ne '_list.txt' -and $_.Name -ne 'README-struktura.txt' })
$allMedia = @($allAny | Where-Object { $MediaExt -contains $_.Extension.ToLowerInvariant() })

Write-Log ("Total files under scan: {0}" -f $allAny.Count) $logFile
Write-Log ("Media files: {0}" -f $allMedia.Count) $logFile

if ($allMedia.Count -eq 0) {
    Write-Log 'ERROR: no media files found. Check that photos are inside C:\Local' $logFile
    Write-Log 'Open the log: C:\Local\_organize-log.txt' $logFile
    if ($allAny.Count -gt 0) {
        Write-Log 'Non-media samples:' $logFile
        $allAny | Select-Object -First 15 | ForEach-Object {
            Write-Log ("  {0}" -f $_.FullName) $logFile
        }
    }
    exit 2
}

Write-Log 'Sample media paths:' $logFile
$allMedia | Select-Object -First 15 | ForEach-Object {
    Write-Log ("  {0}" -f $_.FullName) $logFile
}

$toProcess = @()
foreach ($f in $allMedia) {
    if ($InboxOnly) {
        $toProcess += $f
        continue
    }
    $rel = $f.FullName.Substring($Root.Length).TrimStart('\', '/')
    $top = ($rel -split '[\\/]')[0]
    if (($ManagedTop -contains $top) -and ($top -ne '00_inbox')) {
        continue
    }
    $toProcess += $f
}

Write-Log ("Files to classify/move: {0}" -f $toProcess.Count) $logFile

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
    Write-Log 'Nothing to move: already in target folders, or only unmatched files already in 00_inbox.' $logFile
} else {
    Write-Log 'Plan:' $logFile
    foreach ($key in ($stats.Keys | Sort-Object)) {
        Write-Log ('  {0,4} -> {1}' -f $stats[$key], $key) $logFile
    }

    $i = 0
    $ok = 0
    $fail = 0
    foreach ($item in $plan) {
        $i++
        $shortFrom = $item.From.Substring($Root.Length).TrimStart('\')
        $shortTo = $item.To.Substring($Root.Length).TrimStart('\')

        if (-not $DoWrite) {
            Write-Log ('[{0}/{1}] {2}  =>  {3}' -f $i, $plan.Count, $shortFrom, $shortTo) $logFile
            continue
        }

        try {
            $destParent = Split-Path -Parent $item.To
            if (-not (Test-Path -LiteralPath $destParent)) {
                New-Item -ItemType Directory -Path $destParent -Force | Out-Null
            }
            if ($Copy) {
                Copy-Item -LiteralPath $item.From -Destination $item.To -Force
                Write-Log ('[copy] {0} -> {1}' -f $shortFrom, $shortTo) $logFile
            } else {
                Move-Item -LiteralPath $item.From -Destination $item.To -Force
                Write-Log ('[move] {0} -> {1}' -f $shortFrom, $shortTo) $logFile
            }
            $ok++
        } catch {
            $fail++
            Write-Log ('[FAIL] {0} :: {1}' -f $shortFrom, $_.Exception.Message) $logFile
        }
    }

    if ($DoWrite) {
        Write-Log ("Done. Moved/copied OK={0} FAIL={1}" -f $ok, $fail) $logFile
    }
}

# inbox list
$inboxDir = Join-Path $Root '00_inbox'
if (Test-Path -LiteralPath $inboxDir) {
    $listPath = Join-Path $inboxDir '_list.txt'
    $inboxFiles = @(Get-ChildItem -LiteralPath $inboxDir -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object { ($MediaExt -contains $_.Extension.ToLowerInvariant()) })
    $lines = @('Files still in 00_inbox:', '')
    foreach ($inf in $inboxFiles) {
        $lines += $inf.FullName.Substring($inboxDir.Length).TrimStart('\')
    }
    Set-Content -LiteralPath $listPath -Value $lines -Encoding UTF8
    Write-Log ("Inbox remaining: {0} (list: {1})" -f $inboxFiles.Count, $listPath) $logFile
}

# cleanup empty old folders after move
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
                Write-Log ("[rmdir] {0}" -f $rel) $logFile
            }
        }
}

Write-Log ("Log saved: {0}" -f $logFile) $logFile
Write-Host ''
Write-Host 'Open C:\Local and check folders. Full log: C:\Local\_organize-log.txt' -ForegroundColor Cyan
if (-not $DoWrite) {
    Write-Host 'THIS WAS PREVIEW. Run RUN-MOVE.cmd to actually move files.' -ForegroundColor Yellow
}
Write-Host ''
