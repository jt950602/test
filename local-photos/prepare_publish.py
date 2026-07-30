#!/usr/bin/env python3
"""Copy best classified photos into C:\\Local\\_publish\\ for social/site use.

Picks up to N files per service folder (largest = usually higher quality).

Examples:
  python prepare_publish.py --root C:\\Local --preview
  python prepare_publish.py --root C:\\Local --apply
"""

from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

IMAGE_EXT = {'.jpg', '.jpeg', '.png', '.webp'}

PICK = {
    '_publish/site/manikyur': ('01_raboty/manikyur', 8),
    '_publish/site/resnicy': ('01_raboty/resnicy', 6),
    '_publish/site/brovi': ('01_raboty/brovi', 6),
    '_publish/site/pedikyur': ('01_raboty/pedikyur', 4),
    '_publish/site/massazh': ('01_raboty/massazh', 4),
    '_publish/site/interior': ('03_prostranstvo', 6),
    '_publish/site/process': ('02_process', 4),
    '_publish/site/komanda': ('04_komanda', 6),
    '_publish/vk-album': ('01_raboty', 20),
    '_publish/stories': ('01_raboty/manikyur/design', 4),
    '_publish/telegram': ('01_raboty', 12),
    '_publish/cover': ('05_brand', 2),
}


def pick_files(src_dir: Path, limit: int) -> list[Path]:
    if not src_dir.exists():
        return []
    files = [p for p in src_dir.rglob('*') if p.is_file() and p.suffix.lower() in IMAGE_EXT]
    files.sort(key=lambda p: (-p.stat().st_size, p.name.lower()))
    return files[:limit]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', default=r'C:\Local')
    parser.add_argument('--preview', action='store_true')
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    if not args.preview and not args.apply:
        args.preview = True

    root = Path(args.root).resolve()
    apply = args.apply and not args.preview
    enc = getattr(sys.stdout, 'encoding', None) or 'utf-8'

    def out(msg: str) -> None:
        print(msg.encode(enc, errors='replace').decode(enc))

    out(f'=== prepare _publish from {root} ===')
    total = 0
    for dest_rel, (src_rel, limit) in PICK.items():
        src = root / Path(src_rel)
        dest_root = root / Path(dest_rel)
        chosen = pick_files(src, limit)
        if not chosen and src_rel != '05_brand':
            # fallback: any manikyur if brand empty
            if 'brand' in dest_rel:
                chosen = pick_files(root / '03_prostranstvo', 1)
        out(f'{dest_rel}: {len(chosen)} from {src_rel}')
        for p in chosen:
            dest = dest_root / p.name
            out(f'  {"copy" if apply else "plan"} {p.relative_to(root)} -> {dest.relative_to(root)}')
            if apply:
                dest_root.mkdir(parents=True, exist_ok=True)
                if dest.exists():
                    continue
                shutil.copy2(p, dest)
            total += 1
    out(f'Total: {total}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
