# Structure + classify LOCAL Beauty Studio photos (`C:\Local`)

Two tools:

| Tool | What it does |
|------|----------------|
| **PowerShell** `Organize-LocalPhotos.ps1` | Fast sort by **filename keywords** |
| **Python** `classify_photos.py` | Hybrid: keywords + **CLIP vision** for `IMG_1234.jpg` |

Vision is for phone dumps without useful names. First Python run downloads the CLIP model (~350 MB).

## Quick start (vision classifier)

1. Install [Python 3.10+](https://www.python.org/downloads/) (check «Add to PATH»).
2. Download the whole `local-photos` folder.
3. Double-click **`RUN-CLASSIFY-PREVIEW.cmd`** — plan only.
4. Double-click **`RUN-CLASSIFY-MOVE.cmd`** — move files.

Also:
- `RUN-CLASSIFY-INBOX.cmd` — re-sort only `00_inbox`
- PowerShell launchers: `RUN-MOVE.cmd`, `RUN-PREVIEW.cmd`, `RUN-COPY.cmd`, `RUN-SORT-INBOX.cmd`, `DIAG.cmd`

```powershell
cd local-photos
python -m pip install -r requirements.txt
python classify_photos.py --root C:\Local --preview
python classify_photos.py --root C:\Local --apply
python classify_photos.py --root C:\Local --inbox-only --apply
python classify_photos.py --root C:\Local --keywords-only --apply
```

Logs:
- next to script: `classify-log.txt`
- Desktop: `local-classify-log.txt`
- `C:\Local\_classify-log.txt`

## Folders

| Folder | Purpose |
|--------|---------|
| `00_inbox` | Unrecognized / low confidence |
| `01_raboty\...` | Work by service |
| `02_process` | Before/after |
| `03_prostranstvo` | Interior |
| `04_komanda` | Masters |
| `05_brand` | Logo / covers |
| `06_reels-raw` | Video |
| `_publish\...` | Selected for posting |

## How classification works

1. **Keywords** in path/filename (EN + RU): `manikyur`, `french`, `resnicy`, `permanent`, …
2. If no keyword and file is an image → **CLIP** guesses the service (nails / lashes / brows / massage / …).
3. Low vision confidence → `00_inbox` (open `_list.txt` there).

Useful naming: `2026-07-28_manikyur_french_01.jpg`

## Samples

`samples/` — 16 salon photos for local tests:

```bash
mkdir -p /tmp/demo/dump && cp samples/*.jpg /tmp/demo/dump/
python classify_photos.py --root /tmp/demo --apply
```
