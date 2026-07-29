# Как самому выложить фото в посты (единственный рабочий способ сейчас)

С облачного агента **нельзя** сделать так, чтобы фото реально отображались в постах.
Ключ сообщества ВК принимает вложения, но подписчики их не видят. Токен пользователя
с сервера не работает (привязка к IP / `invalid_scope`).

## Вариант А — скрипт на вашем компьютере (рекомендую)

1. Скачайте папку `vk-community` из репозитория (там фото + скрипт).
2. Получите токен **на этом же компьютере** (IP совпадёт):

```
https://oauth.vk.com/authorize?client_id=ВАШ_APP_ID&display=page&redirect_uri=https://oauth.vk.com/blank.html&scope=photos,groups&response_type=token&v=5.199
```

Если `invalid_scope` — попробуйте `scope=photos` или `scope=4`.

3. Запустите:

```bash
cd vk-community
pip install requests
export VK_TOKEN='вставьте_токен'
python upload_photos_local.py
```

Windows PowerShell:

```powershell
cd vk-community
pip install requests
$env:VK_TOKEN="вставьте_токен"
python upload_photos_local.py
```

Скрипт создаст альбом **«Работы с сайта»** и посты **с настоящими фото**.

## Вариант Б — руками в ВК (без токена)

1. https://vk.com/club240537516 → **Фотографии** → создать альбом «Работы»
2. Загрузить файлы из `photos-to-upload/`
3. На стене: **Пост** → прикрепить фото из альбома
