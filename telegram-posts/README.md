# Telegram: Клиентский день

Готовый пост и скрипт публикации карусели.

## Файлы

- `client-day/post.txt` — текст поста (отформатирован для Telegram)
- `publish_client_day.py` — публикация альбома + текста через Bot API
- `/workspace/media/` — положите сюда фото/видео перед публикацией

## Важно

Текст поста (~1560 символов) длиннее лимита подписи к медиа в Telegram (1024).
Скрипт отправляет карусель, затем полный текст ответом к ней.

Локальный путь `C:\Users\Admin\Downloads\клиентский день` из этой cloud-среды недоступен — скопируйте файлы в `media/` или передайте путь к папке аргументом.

## Публикация

1. Создайте бота у [@BotFather](https://t.me/BotFather) и добавьте его админом канала.
2. Узнайте `chat_id` канала (`@username` или числовой id).
3. Скопируйте медиа в папку, например `media/`.
4. Запустите:

```bash
export TELEGRAM_BOT_TOKEN="YOUR_BOT_TOKEN"
export TELEGRAM_CHAT_ID="@your_channel"
python3 telegram-posts/publish_client_day.py media
```
