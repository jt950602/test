#!/usr/bin/env python3
"""
Загрузка фото LOCAL Beauty Studio в сообщество ВК.
Запускайте НА СВОЁМ КОМПЬЮТЕРЕ (не на сервере) — токен привязан к вашему IP.

1) Получите токен пользователя (админ сообщества), даже без offline:
   https://oauth.vk.com/authorize?client_id=ВАШ_APP_ID&display=page&redirect_uri=https://oauth.vk.com/blank.html&scope=photos,groups&response_type=token&v=5.199

   Если invalid_scope — попробуйте scope=photos или числом scope=4

2) Скопируйте access_token из адресной строки.

3) В этой папке выполните:
   pip install requests
   set VK_TOKEN=ваш_токен          (Windows)
   export VK_TOKEN=ваш_токен       (Mac/Linux)
   python upload_photos_local.py

Скрипт создаст альбом «Работы с сайта», загрузит фото и опубликует посты С картинками.
"""

from __future__ import annotations

import json
import os
import sys
import time
from pathlib import Path

try:
    import requests
except ImportError:
    print("Установите requests: pip install requests")
    sys.exit(1)

API = "https://api.vk.com/method"
GROUP_ID = 240537516
OWNER_ID = -GROUP_ID
API_V = "5.199"
PHOTOS_DIR = Path(__file__).resolve().parent / "photos-to-upload"

CAPTIONS = {
    "01-manikyur-fuksiya.jpg": "Маникюр — фуксия 💅\n\nLOCAL Beauty Studio · ЖК Зиларт\nЗапись: https://n456129.yclients.com/company:432160",
    "02-manikyur-sinij.jpg": "Маникюр — синий дизайн\n\nLOCAL Beauty Studio · м. ЗИЛ\nЗапись: https://n456129.yclients.com/company:432160",
    "03-manikyur-nude.jpg": "Маникюр — nude matte\n\nLOCAL Beauty Studio · ЖК Зиларт\nЗапись: https://n456129.yclients.com/company:432160",
    "04-nail-art-botanical.jpg": "Nail art — botanical\n\nLOCAL Beauty Studio\nЗапись: https://n456129.yclients.com/company:432160",
    "05-nail-art-neon.jpg": "Neon nail art\n\nLOCAL Beauty Studio · Зиларт\nЗапись: https://n456129.yclients.com/company:432160",
    "06-resnicy.jpg": "Наращивание ресниц 👁\n\nLOCAL Beauty Studio · ЖК Зиларт\nЗапись: https://n456129.yclients.com/company:432160",
    "07-resnicy-brovi.jpg": "Ресницы и брови\n\nLOCAL Beauty Studio\nЗапись: https://n456129.yclients.com/company:432160",
    "08-permanent-brovej.jpg": "Перманентный макияж бровей\n\nLOCAL Beauty Studio · м. ЗИЛ\nЗапись: https://n456129.yclients.com/company:432160",
    "09-massazh.jpg": "Массаж\n\nLOCAL Beauty Studio · ЖК Зиларт\nЗапись: https://n456129.yclients.com/company:432160",
    "10-baby-boomer.jpg": "Baby boomer\n\nLOCAL Beauty Studio\nЗапись: https://n456129.yclients.com/company:432160",
    "11-french.jpg": "Французский маникюр\n\nLOCAL Beauty Studio · Зиларт\nЗапись: https://n456129.yclients.com/company:432160",
    "12-resnicy-obyom.jpg": "Объёмные ресницы\n\nLOCAL Beauty Studio\nЗапись: https://n456129.yclients.com/company:432160",
    "13-brovi-resnicy.jpg": "Брови и ресницы\n\nLOCAL Beauty Studio · ЖК Зиларт\nЗапись: https://n456129.yclients.com/company:432160",
    "14-manikyur.jpg": "Маникюр\n\nLOCAL Beauty Studio\nЗапись: https://n456129.yclients.com/company:432160",
    "15-rabota-salona.jpg": "Работа салона\n\nLOCAL Beauty Studio · м. ЗИЛ\nЗапись: https://n456129.yclients.com/company:432160",
    "16-dizajn-nogtej.jpg": "Дизайн ногтей\n\nLOCAL Beauty Studio · Зиларт\nЗапись: https://n456129.yclients.com/company:432160",
}


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
        print("Укажите токен:\n  VK_TOKEN=... python upload_photos_local.py\n  или: python upload_photos_local.py ТОКЕН")
        sys.exit(1)

    if not PHOTOS_DIR.is_dir():
        print(f"Нет папки с фото: {PHOTOS_DIR}")
        sys.exit(1)

    files = sorted(PHOTOS_DIR.glob("*.jpg"))
    if not files:
        print("В папке photos-to-upload нет jpg")
        sys.exit(1)

    me = api("users.get", token)
    print("Токен OK, пользователь:", me[0]["id"], me[0].get("first_name"), me[0].get("last_name"))

    # Проверка прав на группу
    g = api("groups.getById", token, group_id=GROUP_ID, fields="is_admin,admin_level")
    group = g["groups"][0] if isinstance(g, dict) and "groups" in g else g[0]
    print("Сообщество:", group["name"], "admin_level=", group.get("admin_level"))

    album = api(
        "photos.createAlbum",
        token,
        group_id=GROUP_ID,
        title="Работы с сайта",
        description="LOCAL Beauty Studio · ЖК Зиларт · local-beauty.site",
        upload_by_admins_only=1,
    )
    album_id = album["id"]
    print("Альбом создан:", album_id, "https://vk.com/album-240537516_" + str(album_id))

    uploaded = []
    for path in files:
        server = api("photos.getUploadServer", token, album_id=album_id, group_id=GROUP_ID)
        with path.open("rb") as fh:
            up = requests.post(server["upload_url"], files={"photo": fh}, timeout=120).json()
        saved = api(
            "photos.save",
            token,
            album_id=album_id,
            group_id=GROUP_ID,
            server=up["server"],
            photos_list=up["photos_list"],
            hash=up["hash"],
        )
        photo = saved[0]
        pid = photo["id"]
        uploaded.append((path.name, pid))
        print("  загружено", path.name, "->", f"photo{OWNER_ID}_{pid}")
        time.sleep(0.35)

    # Посты по одному фото
    for name, pid in uploaded:
        msg = CAPTIONS.get(name, "LOCAL Beauty Studio\nhttps://n456129.yclients.com/company:432160")
        post = api(
            "wall.post",
            token,
            owner_id=OWNER_ID,
            from_group=1,
            message=msg,
            attachments=f"photo{OWNER_ID}_{pid}",
        )
        print("  пост", post["post_id"], name)
        time.sleep(0.45)

    # Галерея
    chunk = [f"photo{OWNER_ID}_{pid}" for _, pid in uploaded[:10]]
    post = api(
        "wall.post",
        token,
        owner_id=OWNER_ID,
        from_group=1,
        message="Наши работы ✨ LOCAL Beauty Studio\nЖК Зиларт · запись: https://n456129.yclients.com/company:432160",
        attachments=",".join(chunk),
    )
    print("Галерея пост", post["post_id"])
    print("\nГотово. Откройте https://vk.com/club240537516 — фото должны быть видны.")


if __name__ == "__main__":
    main()
