# Organize Local Beauty Studio photos under C:\Local (and subfolders).
# ASCII-only script so Windows PowerShell does not break on encoding.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\Organize-LocalPhotos.ps1
#   powershell -ExecutionPolicy Bypass -File .\Organize-LocalPhotos.ps1 -Apply -Copy
#   powershell -ExecutionPolicy Bypass -File .\Organize-LocalPhotos.ps1 -Apply

[CmdletBinding()]
param(
    [string]$Root = 'C:\Local',
    [switch]$Apply,
    [switch]$Copy
)

$ErrorActionPreference = 'Stop'

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

function Test-IsUnderManaged {
    param([string]$FullPath, [string]$RootPath)
    $rel = $FullPath.Substring($RootPath.Length).TrimStart('\', '/')
    $top = ($rel -split '[\\/]')[0]
    return $ManagedTop -contains $top
}

function Get-TargetRelative {
    param([string]$PathHint)

    # Lowercase; keep Unicode so Cyrillic folder/file names still match via \uXXXX
    $h = $PathHint.ToLower()

    $isVideo = $h -match '\.(mp4|mov|m4v|avi|mkv|webm)$'

    # process / before-after / etap
    if ($h -match ('process|do.?posle|before|after|' +
        '\u0434\u043e.?\u043f\u043e\u0441\u043b\u0435|' +
        '\u044d\u0442\u0430\u043f')) {
        return '02_process'
    }

    # interior / studio / atmosphere
    if ($h -match ('interier|interior|studio|prostranstv|atmosphere|' +
        '\u0438\u043d\u0442\u0435\u0440\u044c\u0435\u0440|' +
        '\u0437\u0430\u043b|' +
        '\u0441\u0442\u0443\u0434\u0438\u044f|' +
        '\u043f\u0440\u043e\u0441\u0442\u043e\u0440|' +
        '\u0430\u0442\u043c\u043e\u0441\u0444\u0435\u0440|' +
        '\u043a\u0440\u0435\u0441\u043b\u043e|' +
        '\u043a\u0430\u0431\u0438\u043d\u0435\u0442')) {
        return '03_prostranstvo'
    }

    # team / masters
    if ($h -match ('master|team|' +
        '\u043c\u0430\u0441\u0442\u0435\u0440|' +
        '\u043a\u043e\u043c\u0430\u043d\u0434|' +
        '\u0441\u043e\u0442\u0440\u0443\u0434|' +
        '\u043f\u043e\u0440\u0442\u0440\u0435\u0442')) {
        return '04_komanda'
    }

    # brand / cover / logo
    if ($h -match ('logo|brand|cover|avatar|template|' +
        '\u043b\u043e\u0433\u043e|' +
        '\u0431\u0440\u0435\u043d\u0434|' +
        '\u043e\u0431\u043b\u043e\u0436\u043a|' +
        '\u0430\u0432\u0430\u0442\u0430\u0440|' +
        '\u0448\u0430\u0431\u043b\u043e\u043d')) {
        return '05_brand'
    }

    # massage
    if ($h -match ('massazh|massage|' +
        '\u043c\u0430\u0441\u0441\u0430\u0436')) {
        return '01_raboty\massazh'
    }

    # pedicure
    if ($h -match ('pedikyur|pedicure|' +
        '\u043f\u0435\u0434\u0438\u043a\u044e\u0440')) {
        return '01_raboty\pedikyur'
    }

    # complex
    if ($h -match ('complex|resnicy.?brovi|brovi.?resnicy|' +
        '\u043a\u043e\u043c\u043f\u043b\u0435\u043a\u0441|' +
        '\u0431\u0440\u043e\u0432\u0438.?\u0440\u0435\u0441\u043d\u0438\u0446')) {
        return '01_raboty\complex'
    }

    # lashes
    if ($h -match ('resnic|lash|' +
        '\u0440\u0435\u0441\u043d\u0438\u0446|' +
        '\u043d\u0430\u0440\u0430\u0449\u0438\u0432\u0430\u043d')) {
        if ($h -match ('obyom|volume|2d|3d|4d|' +
            '\u043e\u0431\u044a[\u0435\u0451]\u043c')) {
            return '01_raboty\resnicy\obyom'
        }
        return '01_raboty\resnicy\classic'
    }

    # brows / permanent
    if ($h -match ('permanent|' +
        '\u043f\u0435\u0440\u043c\u0430\u043d\u0435\u043d\u0442|' +
        '\u0442\u0430\u0442\u0443\u0430\u0436|' +
        '(^|[\\/_-])\u043f\u043c([\\/_-]|$)')) {
        return '01_raboty\brovi\permanent'
    }
    if ($h -match ('brov|brow|' +
        '\u0431\u0440\u043e\u0432')) {
        return '01_raboty\brovi\oformlenie'
    }

    # manicure / nails
    if ($h -match ('manikyur|manicure|nail|french|baby.?boomer|design|neon|botanical|nude|' +
        '\u043c\u0430\u043d\u0438\u043a\u044e\u0440|' +
        '\u043d\u043e\u0433\u0442|' +
        '\u0444\u0440\u0435\u043d\u0447|' +
        '\u0434\u0438\u0437\u0430\u0439\u043d|' +
        '\u0444\u0443\u043a\u0441\u0438|' +
        '\u0430\u0440\u0442')) {
        if ($h -match ('french|\u0444\u0440\u0435\u043d\u0447')) {
            return '01_raboty\manikyur\french'
        }
        if ($h -match ('baby.?boomer|\u0431[\u044d\u0435]\u0431\u0438')) {
            return '01_raboty\manikyur\baby-boomer'
        }
        if ($h -match ('design|nail.?art|neon|botanical|\u0434\u0438\u0437\u0430\u0439\u043d|\u0430\u0440\u0442')) {
            return '01_raboty\manikyur\design'
        }
        return '01_raboty\manikyur\classic'
    }

    if ($isVideo) {
        return '06_reels-raw'
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

if (-not (Test-Path -LiteralPath $Root)) {
    Write-Host "Creating root: $Root"
    New-Item -ItemType Directory -Path $Root -Force | Out-Null
}

Write-Host ''
Write-Host '=== LOCAL Beauty Studio - content structure ===' -ForegroundColor Cyan
Write-Host "Root: $Root"
if ($Apply) {
    if ($Copy) { Write-Host 'Mode: COPY' } else { Write-Host 'Mode: MOVE' }
} else {
    Write-Host 'Mode: DRY-RUN (preview only). Add -Apply to execute.'
}
Write-Host ''

foreach ($rel in $Structure) {
    $path = Join-Path $Root $rel
    if (-not (Test-Path -LiteralPath $path)) {
        if ($Apply) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
            Write-Host "[mkdir] $rel"
        } else {
            Write-Host "[mkdir?] $rel"
        }
    }
}

$readmePath = Join-Path $Root 'README-struktura.txt'
$readmeText = @"
LOCAL Beauty Studio - photo/video structure
==========================================

00_inbox          - unsorted new files
01_raboty         - client work by service
02_process        - process / before-after
03_prostranstvo   - interior / atmosphere
04_komanda        - team
05_brand          - logo / covers / templates
06_reels-raw      - video sources
_archive          - duplicates / reject / old
_publish          - selected for site / VK / stories / Telegram

Suggested file names:
  2026-07-28_manikyur_french_01.jpg

Script: Organize-LocalPhotos.ps1
  dry-run:  .\Organize-LocalPhotos.ps1
  apply:    .\Organize-LocalPhotos.ps1 -Apply
"@

if ($Apply) {
    Set-Content -LiteralPath $readmePath -Value $readmeText -Encoding ASCII
} else {
    Write-Host '[write?] README-struktura.txt'
}

Write-Host ''
Write-Host 'Scanning media files...' -ForegroundColor Yellow

$allFiles = Get-ChildItem -LiteralPath $Root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $MediaExt -contains $_.Extension.ToLowerInvariant() }

$toProcess = @()
foreach ($f in $allFiles) {
    $relFull = $f.FullName
    if (Test-IsUnderManaged -FullPath $relFull -RootPath $Root) {
        $rel = $relFull.Substring($Root.Length).TrimStart('\', '/')
        $top = ($rel -split '[\\/]')[0]
        if ($top -ne '00_inbox') { continue }
    }
    $toProcess += $f
}

Write-Host ("Files to classify: {0}" -f $toProcess.Count)
Write-Host ''

$stats = @{}
$plan = @()

foreach ($f in $toProcess) {
    $hint = $f.FullName
    $targetRel = Get-TargetRelative -PathHint $hint
    $destDir = Join-Path $Root $targetRel
    $destPath = Join-Path $destDir $f.Name

    $currentDir = $f.DirectoryName
    if ($currentDir.TrimEnd('\') -ieq $destDir.TrimEnd('\')) {
        continue
    }

    $destPath = Get-UniquePath -DestPath $destPath
    $plan += [pscustomobject]@{
        From = $f.FullName
        To   = $destPath
        Rel  = $targetRel
    }
    if (-not $stats.ContainsKey($targetRel)) { $stats[$targetRel] = 0 }
    $stats[$targetRel]++
}

if ($plan.Count -eq 0) {
    Write-Host 'Nothing to move - empty or already organized.' -ForegroundColor Green
} else {
    Write-Host 'Plan:' -ForegroundColor Cyan
    foreach ($key in ($stats.Keys | Sort-Object)) {
        Write-Host ('  {0,4} -> {1}' -f $stats[$key], $key)
    }
    Write-Host ''

    $i = 0
    foreach ($item in $plan) {
        $i++
        $shortFrom = $item.From.Substring($Root.Length).TrimStart('\')
        $shortTo = $item.To.Substring($Root.Length).TrimStart('\')
        if (-not $Apply) {
            Write-Host ('[{0}/{1}] {2}' -f $i, $plan.Count, $shortFrom)
            Write-Host ('         -> {0}' -f $shortTo)
            continue
        }

        $destParent = Split-Path -Parent $item.To
        if (-not (Test-Path -LiteralPath $destParent)) {
            New-Item -ItemType Directory -Path $destParent -Force | Out-Null
        }

        if ($Copy) {
            Copy-Item -LiteralPath $item.From -Destination $item.To -Force
            Write-Host ('[copy] {0} -> {1}' -f $shortFrom, $shortTo)
        } else {
            Move-Item -LiteralPath $item.From -Destination $item.To -Force
            Write-Host ('[move] {0} -> {1}' -f $shortFrom, $shortTo)
        }
    }
}

if ($Apply -and -not $Copy) {
    Write-Host ''
    Write-Host 'Removing empty old folders...' -ForegroundColor Yellow
    Get-ChildItem -LiteralPath $Root -Directory -Recurse |
        Sort-Object { $_.FullName.Length } -Descending |
        ForEach-Object {
            $rel = $_.FullName.Substring($Root.Length).TrimStart('\', '/')
            $top = ($rel -split '[\\/]')[0]
            if ($ManagedTop -contains $top) { return }
            $children = Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
            if (-not $children) {
                Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
                Write-Host "[rmdir] $rel"
            }
        }
}

Write-Host ''
if ($Apply) {
    Write-Host "Done. Open $Root" -ForegroundColor Green
} else {
    Write-Host 'Preview only. To apply:' -ForegroundColor Yellow
    Write-Host '  .\Organize-LocalPhotos.ps1 -Apply'
    Write-Host 'Safer first run (copy):'
    Write-Host '  .\Organize-LocalPhotos.ps1 -Apply -Copy'
}
Write-Host ''
