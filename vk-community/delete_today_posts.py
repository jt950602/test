#!/usr/bin/env python3
"""
Удаляет сегодняшние посты на стене сообщества LOCAL Beauty Studio.
Запускайте НА СВОЁМ КОМПЬЮТЕРЕ с токеном пользователя-админа.

  pip install requests
  export VK_TOKEN='ваш_токен'
  python delete_today_posts.py
"""

from __future__ import annotations

import datetime as dt
import os
import sys
import time

try:
    import requests
except ImportError:
    print("pip install requests")
    sys.exit(1)

API = "https://api.vk.com/method"
GROUP_ID = 240537516
OWNER_ID = -GROUP_ID
API_V = "5.199"


def api(method: str, token: str, **params):
    params = {"access_token": token, "v": API_V, **params}
    r = requests.post(f"{API}/{method}", data=params, timeout=60)
    r.raise_for_status()
    data = r.json()
    if "error" in data:
        err = data["error"]
        raise RuntimeError(f"{method}: {err.get('error_code')} {err.get('error_msg')}")
    return data["response"]


def main():
    token = os.environ.get("VK_TOKEN") or (sys.argv[1] if len(sys.argv) > 1 else "")
    if not token:
        print("Укажите токен: VK_TOKEN=... python delete_today_posts.py")
        sys.exit(1)

    # Граница «сегодня» по Москве (UTC+3)
    tz = dt.timezone(dt.timedelta(hours=3))
    start = dt.datetime.now(tz).replace(hour=0, minute=0, second=0, microsecond=0)
    start_ts = int(start.timestamp())
    print("Удаляю посты с", start.isoformat(), f"(ts>={start_ts})")

    deleted = 0
    offset = 0
    while True:
        resp = api("wall.get", token, owner_id=OWNER_ID, count=100, offset=offset)
        items = resp.get("items") or []
        if not items:
            break
        stop = False
        for post in items:
            # закреплённые тоже смотрим по дате
            date = post.get("date", 0)
            pid = post["id"]
            if date < start_ts:
                stop = True
                break
            try:
                api("wall.delete", token, owner_id=OWNER_ID, post_id=pid)
                deleted += 1
                print("удалён", pid, dt.datetime.fromtimestamp(date, tz).isoformat())
                time.sleep(0.35)
            except Exception as e:
                print("ошибка", pid, e)
        if stop or len(items) < 100:
            # если упёрлись в старые — выходим; иначе следующий offset
            # после удалений лента сдвигается, всегда берём offset=0
            if stop:
                break
            # если всё ещё сегодняшние — продолжаем с offset 0 после удалений
            if deleted and not stop:
                offset = 0
                continue
            break
        offset += len(items)

    # Ещё один проход с offset=0 на случай сдвига после удалений
    for _ in range(5):
        resp = api("wall.get", token, owner_id=OWNER_ID, count=50, offset=0)
        today = [p for p in (resp.get("items") or []) if p.get("date", 0) >= start_ts]
        if not today:
            break
        for post in today:
            try:
                api("wall.delete", token, owner_id=OWNER_ID, post_id=post["id"])
                deleted += 1
                print("удалён", post["id"])
                time.sleep(0.35)
            except Exception as e:
                print("ошибка", post["id"], e)
                break

    print(f"Готово. Удалено: {deleted}. Стена: https://vk.com/club240537516")


if __name__ == "__main__":
    main()
