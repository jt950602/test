#!/usr/bin/env python3
"""Remove duplicate and near-duplicate photos under C:\\Local.

Exact duplicates: SHA-256 content hash.
Similar images: perceptual hash (phash), Hamming distance <= threshold.

Duplicates are moved to _archive/_duplicates/ (recoverable, not deleted).

Examples:
  python dedupe_photos.py --root C:\\Local --preview
  python dedupe_photos.py --root C:\\Local --apply
  python dedupe_photos.py --root C:\\Local --apply --exact-only
"""

from __future__ import annotations

import argparse
import hashlib
import re
import shutil
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path

IMAGE_EXT = {'.jpg', '.jpeg', '.png', '.webp', '.bmp', '.gif', '.tif', '.tiff'}
SKIP_DIRS = {'_duplicates'}
COPY_SUFFIX_RE = re.compile(r'_(\d+)$')


class Logger:
    def __init__(self) -> None:
        self.lines: list[str] = []

    def log(self, msg: str) -> None:
        line = f'{datetime.now():%H:%M:%S}  {msg}'
        enc = getattr(sys.stdout, 'encoding', None) or 'utf-8'
        print(msg.encode(enc, errors='replace').decode(enc))
        self.lines.append(line)

    def save(self, paths: list[Path]) -> None:
        text = '\n'.join(self.lines)
        for p in paths:
            try:
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_text(text, encoding='utf-8')
            except OSError as exc:
                print(f'WARN: cannot write log {p}: {exc}', file=sys.stderr)


def file_sha256(path: Path) -> str | None:
    try:
        h = hashlib.sha256()
        with path.open('rb') as f:
            for chunk in iter(lambda: f.read(1024 * 1024), b''):
                h.update(chunk)
        return h.hexdigest()
    except OSError:
        return None


def image_phash(path: Path):
    import imagehash
    from PIL import Image

    with Image.open(path) as img:
        return imagehash.phash(img.convert('RGB'))


def is_copy_name(path: Path) -> bool:
    m = COPY_SUFFIX_RE.search(path.stem)
    if not m:
        return False
    # unique_path uses _2, _3, ... — not timestamp tails like _180118
    n = int(m.group(1))
    return 2 <= n <= 99


def copy_index(path: Path) -> int:
    m = COPY_SUFFIX_RE.search(path.stem)
    if not m or not is_copy_name(path):
        return 0
    return int(m.group(1))


def keeper_score(path: Path) -> tuple:
    """Lower is better keeper."""
    return (
        1 if is_copy_name(path) else 0,
        copy_index(path),
        -path.stat().st_size,
        len(str(path)),
        str(path).lower(),
    )


def pick_keeper(paths: list[Path]) -> Path:
    return min(paths, key=keeper_score)


def collect_images(root: Path) -> list[Path]:
    files: list[Path] = []
    for p in root.rglob('*'):
        if not p.is_file() or p.suffix.lower() not in IMAGE_EXT:
            continue
        rel_parts = p.relative_to(root).parts
        if any(part in SKIP_DIRS for part in rel_parts):
            continue
        files.append(p)
    return sorted(files)


def group_exact(files: list[Path], log: Logger) -> list[tuple[Path, list[Path]]]:
    by_hash: dict[str, list[Path]] = defaultdict(list)
    for p in files:
        digest = file_sha256(p)
        if digest is None:
            log.log(f'[skip] unreadable: {p}')
            continue
        by_hash[digest].append(p)

    groups: list[tuple[Path, list[Path]]] = []
    for paths in by_hash.values():
        if len(paths) < 2:
            continue
        keeper = pick_keeper(paths)
        dupes = [p for p in paths if p != keeper]
        groups.append((keeper, dupes))
    return groups


def group_similar(files: list[Path], threshold: int, log: Logger) -> list[tuple[Path, list[Path]]]:
    hashes: dict[Path, object] = {}
    for p in files:
        try:
            hashes[p] = image_phash(p)
        except OSError:
            log.log(f'[skip] unreadable image: {p}')
        except Exception as exc:
            log.log(f'[skip] phash failed: {p} :: {exc}')

    paths = list(hashes.keys())
    parent = {p: p for p in paths}

    def find(x: Path) -> Path:
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(a: Path, b: Path) -> None:
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[rb] = ra

    for i, a in enumerate(paths):
        ha = hashes[a]
        for b in paths[i + 1:]:
            if ha - hashes[b] <= threshold:
                union(a, b)

    clusters: dict[Path, list[Path]] = defaultdict(list)
    for p in paths:
        clusters[find(p)].append(p)

    groups: list[tuple[Path, list[Path]]] = []
    for cluster in clusters.values():
        if len(cluster) < 2:
            continue
        keeper = pick_keeper(cluster)
        dupes = [p for p in cluster if p != keeper]
        groups.append((keeper, dupes))
    return groups


def merge_groups(*group_lists: list[tuple[Path, list[Path]]]) -> list[tuple[Path, Path, str]]:
    """Return unique (keeper, dupe, reason) pairs."""
    seen_dupes: set[Path] = set()
    out: list[tuple[Path, Path, str]] = []
    for reason, groups in group_lists:
        for keeper, dupes in groups:
            for dupe in dupes:
                if dupe in seen_dupes:
                    continue
                seen_dupes.add(dupe)
                out.append((keeper, dupe, reason))
    return sorted(out, key=lambda x: str(x[1]).lower())


def archive_dest(root: Path, src: Path) -> Path:
    try:
        rel = src.relative_to(root)
    except ValueError:
        rel = Path(src.name)
    dest = root / '_archive' / '_duplicates' / rel
    if not dest.exists():
        return dest
    stem, suffix = dest.stem, dest.suffix
    i = 2
    while True:
        candidate = dest.with_name(f'{stem}_{i}{suffix}')
        if not candidate.exists():
            return candidate
        i += 1


def main() -> int:
    parser = argparse.ArgumentParser(description='Remove duplicate/similar photos')
    parser.add_argument('--root', default=r'C:\Local')
    parser.add_argument('--preview', action='store_true')
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--exact-only', action='store_true', help='Skip perceptual similarity')
    parser.add_argument('--similar-threshold', type=int, default=6, help='phash Hamming distance')
    args = parser.parse_args()

    if not args.preview and not args.apply:
        args.preview = True

    root = Path(args.root).expanduser().resolve()
    apply = bool(args.apply) and not args.preview
    log = Logger()
    script_dir = Path(__file__).resolve().parent

    log.log('=== LOCAL photo deduplicator ===')
    log.log(f'Root: {root}')
    log.log(f'preview={args.preview or not apply} exact_only={args.exact_only} threshold={args.similar_threshold}')

    if not root.exists():
        log.log(f'ERROR: root does not exist: {root}')
        return 1

    files = collect_images(root)
    log.log(f'Images scanned: {len(files)}')
    if len(files) < 2:
        log.log('Nothing to dedupe.')
        return 0

    exact_groups = group_exact(files, log)
    log.log(f'Exact duplicate groups: {len(exact_groups)}')

    similar_groups: list[tuple[Path, list[Path]]] = []
    if not args.exact_only:
        exact_dupes = {d for _, ds in exact_groups for d in ds}
        remaining = [p for p in files if p not in exact_dupes]
        similar_groups = group_similar(remaining, args.similar_threshold, log)
        log.log(f'Similar groups: {len(similar_groups)}')

    pairs = merge_groups(
        ('exact', exact_groups),
        ('similar', similar_groups),
    )

    if not pairs:
        log.log('No duplicates found.')
        log.save([script_dir / 'dedupe-log.txt', root / '_dedupe-log.txt'])
        return 0

    exact_count = sum(1 for _, _, r in pairs if r == 'exact')
    similar_count = sum(1 for _, _, r in pairs if r == 'similar')
    log.log(f'Remove: {len(pairs)} files (exact={exact_count}, similar={similar_count})')

    ok = fail = 0
    for i, (keeper, dupe, reason) in enumerate(pairs, 1):
        try:
            k_rel = keeper.relative_to(root)
            d_rel = dupe.relative_to(root)
        except ValueError:
            k_rel = keeper
            d_rel = dupe
        log.log(f'[{i}/{len(pairs)}] {reason}: {d_rel}  <= keep {k_rel}')
        if not apply:
            continue
        dest = archive_dest(root, dupe)
        try:
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(dupe), str(dest))
            log.log(f'  -> archived {dest.relative_to(root)}')
            ok += 1
        except OSError as exc:
            fail += 1
            log.log(f'  [FAIL] {dupe}: {exc}')

    if apply:
        log.log(f'Done OK={ok} FAIL={fail}')

    log.save([
        script_dir / 'dedupe-log.txt',
        Path.home() / 'Desktop' / 'local-dedupe-log.txt',
        root / '_dedupe-log.txt',
    ])
    return 0 if fail == 0 else 1


if __name__ == '__main__':
    raise SystemExit(main())
