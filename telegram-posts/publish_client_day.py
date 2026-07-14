#!/usr/bin/env python3
"""Publish the Client Day carousel post to Telegram via Bot API.

Usage:
  export TELEGRAM_BOT_TOKEN="..."
  export TELEGRAM_CHAT_ID="@your_channel_or_id"
  python3 telegram-posts/publish_client_day.py /path/to/media

Telegram media-group captions allow max 1024 chars. This post is longer, so the
script sends the album first, then the full text as a reply to that album.
"""

from __future__ import annotations

import json
import mimetypes
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

API = "https://api.telegram.org"
CAPTION_LIMIT = 1024
MESSAGE_LIMIT = 4096
MEDIA_GROUP_LIMIT = 10
IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp"}
VIDEO_EXTS = {".mp4", ".mov", ".m4v"}


def die(message: str, code: int = 1) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(code)


def load_text(path: Path) -> str:
    text = path.read_text(encoding="utf-8").strip()
    if not text:
        die(f"Post text is empty: {path}")
    if len(text) > MESSAGE_LIMIT:
        die(f"Post text is {len(text)} chars; Telegram messages allow {MESSAGE_LIMIT}.")
    return text


def collect_media(folder: Path) -> list[Path]:
    files = [
        p
        for p in sorted(folder.iterdir())
        if p.is_file() and p.suffix.lower() in IMAGE_EXTS | VIDEO_EXTS
    ]
    if not files:
        die(f"No images/videos found in {folder}")
    return files


def encode_multipart(
    fields: dict[str, str], files: list[tuple[str, Path]] | None = None
) -> tuple[bytes, str]:
    boundary = "----cursorTelegramBoundary7MA4YWxkTrZu0gW"
    chunks: list[bytes] = []
    files = files or []

    for name, value in fields.items():
        chunks.append(f"--{boundary}\r\n".encode())
        chunks.append(f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode())
        chunks.append(value.encode("utf-8"))
        chunks.append(b"\r\n")

    for field_name, path in files:
        mime = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
        chunks.append(f"--{boundary}\r\n".encode())
        chunks.append(
            (
                f'Content-Disposition: form-data; name="{field_name}"; '
                f'filename="{path.name}"\r\n'
            ).encode()
        )
        chunks.append(f"Content-Type: {mime}\r\n\r\n".encode())
        chunks.append(path.read_bytes())
        chunks.append(b"\r\n")

    chunks.append(f"--{boundary}--\r\n".encode())
    return b"".join(chunks), f"multipart/form-data; boundary={boundary}"


def api_call(
    token: str,
    method: str,
    fields: dict[str, str],
    files: list[tuple[str, Path]] | None = None,
):
    body, content_type = encode_multipart(fields, files)
    req = urllib.request.Request(
        f"{API}/bot{token}/{method}",
        data=body,
        headers={"Content-Type": content_type},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:
            payload = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        die(f"Telegram API HTTP {exc.code}: {detail}")
    except urllib.error.URLError as exc:
        die(f"Network error: {exc}")

    if not payload.get("ok"):
        die(f"Telegram API error: {json.dumps(payload, ensure_ascii=False)}")
    return payload


def send_album(
    token: str, chat_id: str, files: list[Path], caption: str | None
) -> int:
    media = []
    uploads: list[tuple[str, Path]] = []

    for index, path in enumerate(files):
        attach = f"file{index}"
        kind = "photo" if path.suffix.lower() in IMAGE_EXTS else "video"
        item: dict[str, str] = {"type": kind, "media": f"attach://{attach}"}
        if index == 0 and caption:
            item["caption"] = caption
        media.append(item)
        uploads.append((attach, path))

    payload = api_call(
        token,
        "sendMediaGroup",
        {"chat_id": chat_id, "media": json.dumps(media, ensure_ascii=False)},
        uploads,
    )
    message_id = payload["result"][0]["message_id"]
    print(f"Sent album with {len(files)} file(s), message_id={message_id}")
    return message_id


def send_text(token: str, chat_id: str, text: str, reply_to: int | None = None) -> None:
    fields = {"chat_id": chat_id, "text": text}
    if reply_to is not None:
        fields["reply_to_message_id"] = str(reply_to)
    payload = api_call(token, "sendMessage", fields)
    print(f"Sent text message_id={payload['result']['message_id']}")


def main() -> None:
    token = os.environ.get("TELEGRAM_BOT_TOKEN", "").strip()
    chat_id = os.environ.get("TELEGRAM_CHAT_ID", "").strip()
    if not token or not chat_id:
        die(
            "Set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID, then rerun.\n"
            "Example:\n"
            '  export TELEGRAM_BOT_TOKEN="123:ABC"\n'
            '  export TELEGRAM_CHAT_ID="@channel_or_numeric_id"\n'
            "  python3 telegram-posts/publish_client_day.py /path/to/media"
        )

    if len(sys.argv) < 2:
        die("Usage: python3 telegram-posts/publish_client_day.py /path/to/media")

    media_dir = Path(sys.argv[1]).expanduser().resolve()
    if not media_dir.is_dir():
        die(f"Media folder not found: {media_dir}")

    root = Path(__file__).resolve().parent
    text = load_text(root / "client-day" / "post.txt")
    files = collect_media(media_dir)

    print(f"Text: {len(text)} chars")
    print(f"Media files: {len(files)}")
    for path in files:
        print(f"  - {path.name}")

    # Attach caption to the album only when it fits Telegram's limit.
    album_caption = text if len(text) <= CAPTION_LIMIT else None
    first_message_id: int | None = None

    remaining = files
    while remaining:
        batch, remaining = remaining[:MEDIA_GROUP_LIMIT], remaining[MEDIA_GROUP_LIMIT:]
        caption = album_caption if first_message_id is None else None
        message_id = send_album(token, chat_id, batch, caption)
        if first_message_id is None:
            first_message_id = message_id
            album_caption = None

    if len(text) > CAPTION_LIMIT:
        send_text(token, chat_id, text, reply_to=first_message_id)

    print("Done.")


if __name__ == "__main__":
    main()
