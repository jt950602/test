<#
.SYNOPSIS
  Создаёт структуру папок в C:\Local и раскладывает фото/видео по услугам.

.DESCRIPTION
  По умолчанию только показывает план (dry-run).
  Реальное перемещение:  .\Organize-LocalPhotos.ps1 -Apply

.PARAMETER Root
  Корень архива. По умолчанию C:\Local

.PARAMETER Apply
  Без этого флага файлы НЕ перемещаются — только отчёт.

.PARAMETER Copy
  Копировать вместо перемещения (безопаснее на первый прогон).

.EXAMPLE
  .\Organize-LocalPhotos.ps1
  .\Organize-LocalPhotos.ps1 -Apply
  .\Organize-LocalPhotos.ps1 -Apply -Copy
#>
[CmdletBinding()]
param(
    [string]$Root = 'C:\Local',
    [switch]$Apply,
    [switch]$Copy
)

$ErrorActionPreference = 'Stop'

# --- Целевая структура ---
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

# Папки новой структуры — из них файлы не трогаем повторно
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

    $h = $PathHint.ToLowerInvariant()

    # Видео → reels-raw, если нет явной услуги
    $isVideo = $h -match '\.(mp4|mov|m4v|avi|mkv|webm)$'

    # Процесс / до-после
    if ($h -match 'process|process|до.?после|do.?posle|before|after|этап') {
        return '02_process'
    }

    # Пространство / интерьер
    if ($h -match 'интерьер|interier|interior|зал|studio|студия|простор|prostranstv|atmosphere|атмосфер|кресло|кабинет') {
        return '03_prostranstvo'
    }

    # Команда
    if ($h -match 'мастер|master|команд|team|сотрудник|портрет|сотруд') {
        return '04_komanda'
    }

    # Бренд
    if ($h -match 'лого|logo|бренд|brand|обложк|cover|avatar|аватар|шаблон|template') {
        return '05_brand'
    }

    # Массаж
    if ($h -match 'массаж|massazh|massage') {
        return '01_raboty\massazh'
    }

    # Педикюр
    if ($h -match 'педикюр|pedikyur|pedicure') {
        return '01_raboty\pedikyur'
    }

    # Комплекс
    if ($h -match 'complex|комплекс|брови.?ресниц|resnicy.?brovi|brovi.?resnicy') {
        return '01_raboty\complex'
    }

    # Ресницы
    if ($h -match 'ресниц|resnic|lash|наращиван') {
        if ($h -match 'объ[её]м|obyom|volume|2d|3d|4d') {
            return '01_raboty\resnicy\obyom'
        }
        return '01_raboty\resnicy\classic'
    }

    # Брови / перманент
    if ($h -match 'перманент|permanent|пм|татуаж') {
        return '01_raboty\brovi\permanent'
    }
    if ($h -match 'бров|brov|brow') {
        return '01_raboty\brovi\oformlenie'
    }

    # Маникюр / ногти
    if ($h -match 'маникюр|manikyur|manicure|ногт|nail|френч|french|baby.?boomer|дизайн|design|nail.?art|neon|botanical|nude|фукси|french') {
        if ($h -match 'френч|french') { return '01_raboty\manikyur\french' }
        if ($h -match 'baby.?boomer|бэби|беби') { return '01_raboty\manikyur\baby-boomer' }
        if ($h -match 'дизайн|design|nail.?art|neon|botanical|арт') { return '01_raboty\manikyur\design' }
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
        $candidate = Join-Path $dir ("{0}_{1}{2}" -f $base, $i, $ext)
        $i++
    } while (Test-Path -LiteralPath $candidate)
    return $candidate
}

# --- Старт ---
if (-not (Test-Path -LiteralPath $Root)) {
    Write-Host "Создаю корень: $Root"
    New-Item -ItemType Directory -Path $Root -Force | Out-Null
}

Write-Host ""
Write-Host "=== LOCAL Beauty Studio · структура контента ===" -ForegroundColor Cyan
Write-Host "Корень: $Root"
Write-Host ("Режим: " + $(if ($Apply) { if ($Copy) { 'КОПИРОВАНИЕ' } else { 'ПЕРЕМЕЩЕНИЕ' } } else { 'ПРОСМОТР (dry-run). Добавьте -Apply для выполнения' }))
Write-Host ""

# 1) Создать папки
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

# README в корне
$readmePath = Join-Path $Root 'README-struktura.txt'
$readmeText = @"
LOCAL Beauty Studio — структура фото/видео
==========================================

00_inbox          — новое, ещё не разобрано
01_raboty         — работы клиентов по услугам
02_process        — процесс, до/после
03_prostranstvo   — интерьер, атмосфера
04_komanda        — мастера
05_brand          — лого, обложки, шаблоны
06_reels-raw      — видео-исходники
_archive          — дубли, брак, старое
_publish          — отобранное на сайт / VK / stories / Telegram

Имена файлов (рекомендация):
  2026-07-28_manikyur_french_01.jpg

Скрипт: Organize-LocalPhotos.ps1
  dry-run:  .\Organize-LocalPhotos.ps1
  применить: .\Organize-LocalPhotos.ps1 -Apply
"@

if ($Apply) {
    Set-Content -LiteralPath $readmePath -Value $readmeText -Encoding UTF8
} else {
    Write-Host "[write?] README-struktura.txt"
}

# 2) Собрать медиа вне managed-папок (и всё в корне / старых подпапках)
Write-Host ""
Write-Host "Сканирую медиафайлы..." -ForegroundColor Yellow

$allFiles = Get-ChildItem -LiteralPath $Root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {
        $MediaExt -contains $_.Extension.ToLowerInvariant()
    }

$toProcess = @()
foreach ($f in $allFiles) {
    # Уже лежит в целевой структуре — пропускаем (кроме 00_inbox: можно переклассифицировать)
    $relFull = $f.FullName
    if (Test-IsUnderManaged -FullPath $relFull -RootPath $Root) {
        $rel = $relFull.Substring($Root.Length).TrimStart('\', '/')
        $top = ($rel -split '[\\/]')[0]
        if ($top -ne '00_inbox') { continue }
    }
    $toProcess += $f
}

Write-Host ("Найдено к разбору: {0} файл(ов)" -f $toProcess.Count)
Write-Host ""

$stats = @{}
$plan = @()

foreach ($f in $toProcess) {
    $hint = $f.FullName
    $targetRel = Get-TargetRelative -PathHint $hint
    $destDir = Join-Path $Root $targetRel
    $destPath = Join-Path $destDir $f.Name

    # Если уже в нужной папке — skip
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
    Write-Host "Нечего перемещать — либо пусто, либо всё уже на местах." -ForegroundColor Green
} else {
    Write-Host "План раскладки:" -ForegroundColor Cyan
    foreach ($key in ($stats.Keys | Sort-Object)) {
        Write-Host ("  {0,4} → {1}" -f $stats[$key], $key)
    }
    Write-Host ""

    $i = 0
    foreach ($item in $plan) {
        $i++
        $shortFrom = $item.From.Substring($Root.Length).TrimStart('\')
        $shortTo = $item.To.Substring($Root.Length).TrimStart('\')
        if (-not $Apply) {
            Write-Host ("[{0}/{1}] {2}" -f $i, $plan.Count, $shortFrom)
            Write-Host ("         → {0}" -f $shortTo)
            continue
        }

        $destParent = Split-Path -Parent $item.To
        if (-not (Test-Path -LiteralPath $destParent)) {
            New-Item -ItemType Directory -Path $destParent -Force | Out-Null
        }

        if ($Copy) {
            Copy-Item -LiteralPath $item.From -Destination $item.To -Force
            Write-Host ("[copy] {0} → {1}" -f $shortFrom, $shortTo)
        } else {
            Move-Item -LiteralPath $item.From -Destination $item.To -Force
            Write-Host ("[move] {0} → {1}" -f $shortFrom, $shortTo)
        }
    }
}

# 3) Убрать пустые старые папки (только при -Apply и не managed)
if ($Apply -and -not $Copy) {
    Write-Host ""
    Write-Host "Чищу пустые старые папки..." -ForegroundColor Yellow
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

Write-Host ""
if ($Apply) {
    Write-Host "Готово. Откройте $Root" -ForegroundColor Green
} else {
    Write-Host "Это был просмотр. Чтобы выполнить:" -ForegroundColor Yellow
    Write-Host "  .\Organize-LocalPhotos.ps1 -Apply"
    Write-Host "Безопаснее сначала скопировать:"
    Write-Host "  .\Organize-LocalPhotos.ps1 -Apply -Copy"
}
Write-Host ""
