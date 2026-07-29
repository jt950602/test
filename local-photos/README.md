# Структура фото LOCAL Beauty Studio (`C:\Local`)

Скрипт создаёт папки и раскладывает фото/видео из `C:\Local` **и всех подпапок** по услугам.

## Папки

| Папка | Назначение |
|--------|------------|
| `00_inbox` | Не распознано — разобрать руками |
| `01_raboty\...` | Работы: маникюр, педикюр, ресницы, брови, массаж |
| `02_process` | До/после, процесс |
| `03_prostranstvo` | Интерьер, атмосфера |
| `04_komanda` | Мастера |
| `05_brand` | Лого, обложки |
| `06_reels-raw` | Видео |
| `_archive` | Брак / старое |
| `_publish\...` | Отобранное на сайт, VK, stories, Telegram |

## Как запустить (на вашем ПК)

Самый простой способ — скачать **всю папку** `local-photos` и двойной клик:

1. `RUN-PREVIEW.cmd` — только план  
2. `RUN-COPY.cmd` — безопасно скопировать  
3. `RUN-MOVE.cmd` — переместить  
4. `RUN-SORT-INBOX.cmd` — ещё раз разобрать только `00_inbox`  

Или в PowerShell (обход политики + без поломки кодировки):

```powershell
cd $env:USERPROFILE\Downloads

powershell -ExecutionPolicy Bypass -File .\Organize-LocalPhotos.ps1
powershell -ExecutionPolicy Bypass -File .\Organize-LocalPhotos.ps1 -Apply -Copy

# Только inbox:
powershell -ExecutionPolicy Bypass -File .\Organize-LocalPhotos.ps1 -InboxOnly -Apply
```

Другой корень:

```powershell
powershell -ExecutionPolicy Bypass -File .\Organize-LocalPhotos.ps1 -Root 'D:\Photos\Local' -Apply -Copy
```

> Скрипт специально **без кириллицы в коде** (только `\uXXXX` в regex), чтобы Windows PowerShell не падал с `Unexpected token`.

Если после сортировки в `00_inbox` что-то осталось — открой `C:\Local\00_inbox\_list.txt` и пришли список сюда, допишем правила.

## Как угадывает папку

По словам в **имени файла и пути**: `маникюр`, `френч`, `ресниц`, `бров`, `массаж`, `интерьер`, `nail`, `lash` и т.д.

Не уверен → `00_inbox`. Уже лежащее в новой структуре **не трогает** (кроме повторного разбора `00_inbox`).
