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

1. Скопируйте `Organize-LocalPhotos.ps1` куда угодно (можно на рабочий стол).
2. PowerShell:

```powershell
cd путь\к\скрипту

# Сначала только план (ничего не двигает)
.\Organize-LocalPhotos.ps1

# Безопасно: копирует в новую структуру (исходники остаются)
.\Organize-LocalPhotos.ps1 -Apply -Copy

# Или сразу переместить
.\Organize-LocalPhotos.ps1 -Apply
```

Если Windows ругается на политику:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Organize-LocalPhotos.ps1
```

Другой корень:

```powershell
.\Organize-LocalPhotos.ps1 -Root 'D:\Photos\Local' -Apply
```

## Как угадывает папку

По словам в **имени файла и пути**: `маникюр`, `френч`, `ресниц`, `бров`, `массаж`, `интерьер`, `nail`, `lash` и т.д.

Не уверен → `00_inbox`. Уже лежащее в новой структуре **не трогает** (кроме повторного разбора `00_inbox`).
