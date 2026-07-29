# Структура фото LOCAL Beauty Studio (`C:\Local`)

Скрипт **сразу переносит** фото/видео по папкам услуг (по умолчанию MOVE).

## Запуск

Скачай **всю папку** `local-photos` (и `.ps1`, и `.cmd` рядом).

1. Двойной клик **`RUN-MOVE.cmd`**  
2. Откроется блокнот с логом  

Лог всегда пишется в три места:
- рядом со скриптом: `organize-log.txt`
- на рабочий стол: `local-organize-log.txt`
- в `C:\Local\_organize-log.txt` (если папка есть)

Если «лога нет» — запусти **`DIAG.cmd`** и пришли `Desktop\local-diag.txt`.

Опционально:
- `RUN-PREVIEW.cmd` — только план, без переноса  
- `RUN-COPY.cmd` — копировать, исходники оставить  
- `RUN-SORT-INBOX.cmd` — ещё раз разобрать `00_inbox`

Или:

```powershell
powershell -ExecutionPolicy Bypass -File .\Organize-LocalPhotos.ps1
```

## Папки

| Папка | Назначение |
|--------|------------|
| `00_inbox` | Не распознано |
| `01_raboty\...` | Работы по услугам |
| `02_process` | До/после |
| `03_prostranstvo` | Интерьер |
| `04_komanda` | Мастера |
| `05_brand` | Лого / обложки |
| `06_reels-raw` | Видео |
| `_publish\...` | Отобранное на публикации |

Если пишет `no media files found` — фото не в `C:\Local`. Пришли содержимое `C:\Local\_organize-log.txt`.
