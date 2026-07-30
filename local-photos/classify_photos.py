#!/usr/bin/env python3
"""Classify salon photos into C:\\Local service folders.

Hybrid:
  1) filename / path keywords (fast, precise when names are meaningful)
  2) CLIP vision for IMG_*.jpg style files
  3) low-confidence vision -> 00_inbox

Examples:
  python classify_photos.py --root C:\\Local --preview
  python classify_photos.py --root ./demo-root --apply
  python classify_photos.py --root C:\\Local --inbox-only --apply
"""

from __future__ import annotations

import argparse
import re
import shutil
import sys
from collections import Counter
from datetime import datetime
from pathlib import Path

IMAGE_EXT = {'.jpg', '.jpeg', '.png', '.webp', '.heic', '.tif', '.tiff', '.bmp', '.gif'}
VIDEO_EXT = {'.mp4', '.mov', '.m4v', '.avi', '.mkv', '.webm'}
MEDIA_EXT = IMAGE_EXT | VIDEO_EXT

MANAGED_TOP = {
    '00_inbox', '01_raboty', '02_process', '03_prostranstvo',
    '04_komanda', '05_brand', '06_reels-raw', '_archive', '_publish',
}

STRUCTURE = [
    '00_inbox',
    '01_raboty/manikyur/classic',
    '01_raboty/manikyur/french',
    '01_raboty/manikyur/baby-boomer',
    '01_raboty/manikyur/design',
    '01_raboty/pedikyur',
    '01_raboty/resnicy/classic',
    '01_raboty/resnicy/obyom',
    '01_raboty/brovi/oformlenie',
    '01_raboty/brovi/permanent',
    '01_raboty/massazh',
    '01_raboty/complex',
    '02_process',
    '03_prostranstvo',
    '04_komanda',
    '05_brand',
    '06_reels-raw',
    '_archive',
    '_publish/site',
    '_publish/vk-album',
    '_publish/stories',
    '_publish/cover',
    '_publish/telegram',
]

# Keyword rules: first match wins (more specific first).
KEYWORD_RULES = [
    (r'process|do.?posle|before|after|\u0434\u043e.?\u043f\u043e\u0441\u043b\u0435|\u044d\u0442\u0430\u043f', '02_process'),
    (r'interier|interior|studio|prostranstv|atmosphere|\u0438\u043d\u0442\u0435\u0440\u044c\u0435\u0440|\u0437\u0430\u043b|\u0441\u0442\u0443\u0434\u0438\u044f', '03_prostranstvo'),
    (r'master|team|\u043c\u0430\u0441\u0442\u0435\u0440|\u043a\u043e\u043c\u0430\u043d\u0434', '04_komanda'),
    (r'logo|brand|cover|avatar|template|\u043b\u043e\u0433\u043e|\u0431\u0440\u0435\u043d\u0434', '05_brand'),
    (r'massazh|massage|\u043c\u0430\u0441\u0441\u0430\u0436', '01_raboty/massazh'),
    (r'pedikyur|pedicure|\u043f\u0435\u0434\u0438\u043a\u044e\u0440', '01_raboty/pedikyur'),
    (r'complex|resnicy.?brovi|brovi.?resnicy|\u043a\u043e\u043c\u043f\u043b\u0435\u043a\u0441', '01_raboty/complex'),
    (r'(?:resnic|lash|\u0440\u0435\u0441\u043d\u0438\u0446|\u043d\u0430\u0440\u0430\u0449\u0438\u0432).*(?:obyom|volume|2d|3d|4d|\u043e\u0431\u044a\u0435\u043c|\u043e\u0431\u044a\u0451\u043c)|(?:obyom|volume).*(?:resnic|lash)', '01_raboty/resnicy/obyom'),
    (r'resnic|lash|\u0440\u0435\u0441\u043d\u0438\u0446|\u043d\u0430\u0440\u0430\u0449\u0438\u0432', '01_raboty/resnicy/classic'),
    (r'permanent|\u043f\u0435\u0440\u043c\u0430\u043d\u0435\u043d\u0442|\u0442\u0430\u0442\u0443\u0430\u0436', '01_raboty/brovi/permanent'),
    (r'brov|brow|\u0431\u0440\u043e\u0432', '01_raboty/brovi/oformlenie'),
    (r'french|\u0444\u0440\u0435\u043d\u0447', '01_raboty/manikyur/french'),
    (r'baby.?boomer', '01_raboty/manikyur/baby-boomer'),
    (r'design|nail.?art|neon|botanical|dizajn|\u0434\u0438\u0437\u0430\u0439\u043d|\u0430\u0440\u0442', '01_raboty/manikyur/design'),
    (r'manikyur|manikur|manicure|nail|shellac|gel|nogt|\u043c\u0430\u043d\u0438\u043a\u044e\u0440|\u043d\u043e\u0433\u0442|\u0433\u0435\u043b|\u0448\u0435\u043b\u043b\u0430\u043a|\u043f\u043e\u043a\u0440\u044b\u0442', '01_raboty/manikyur/classic'),
    (r'reels|stories|story|shorts|\u0441\u0442\u043e\u0440\u0438\u0441', '06_reels-raw'),
    (r'zilart|local.?beauty|salon|\u0437\u0438\u043b\u0430\u0440\u0442|\u0441\u0430\u043b\u043e\u043d', '03_prostranstvo'),
]

PARENT_HINTS = [
    (r'manik|nail|nogt|\u043c\u0430\u043d\u0438\u043a|\u043d\u043e\u0433\u0442', '01_raboty/manikyur/classic'),
    (r'resnic|lash|\u0440\u0435\u0441\u043d\u0438\u0446', '01_raboty/resnicy/classic'),
    (r'brov|brow|\u0431\u0440\u043e\u0432', '01_raboty/brovi/oformlenie'),
    (r'massaz|\u043c\u0430\u0441\u0441\u0430\u0436', '01_raboty/massazh'),
    (r'pedik|\u043f\u0435\u0434\u0438\u043a', '01_raboty/pedikyur'),
]

COARSE_PROMPTS = {
    'manikyur': [
        'a close-up photo of manicured fingernails with gel polish',
        'hands showing painted nails manicure beauty',
        'fingernail manicure nail polish close up',
    ],
    'resnicy': [
        'close-up of a woman eye with eyelash extensions',
        'eyelash extensions on eyelid beauty macro',
        'lashes after lash extension procedure',
    ],
    'brovi': [
        'close-up of eyebrows after brow shaping or permanent makeup',
        'eyebrow microblading powder brows beauty',
        'beautiful shaped eyebrows on a face forehead',
    ],
    'massazh': [
        'spa massage therapy hands on client body',
        'masseur performing massage treatment',
    ],
    'pedikyur': [
        'pedicure toenails feet with nail polish',
    ],
    'prostranstvo': [
        'beauty salon interior empty room furniture',
        'nail salon workspace chairs tables interior',
    ],
    'komanda': [
        'group team photo of beauty salon employees in uniform smiling at camera',
        'professional headshot portrait of hairdresser or nail master in salon apron',
        'staff team picture inside beauty salon not a client',
    ],
    'brand': [
        'logo graphic brand design flat artwork not a photo',
    ],
    'process': [
        'before and after split comparison beauty photo',
    ],
}

NAIL_FINE = {
    'classic': ['solid single color manicure nails without art', 'plain color gel nails'],
    'french': ['french manicure nails with white tips'],
    'baby-boomer': ['baby boomer ombre gradient nude to white nails'],
    'design': ['nail art decorated nails with patterns glitter neon'],
}
LASH_FINE = {
    'classic': ['natural classic eyelash extensions'],
    'obyom': ['thick dramatic volume eyelash extensions'],
}
BROW_FINE = {
    'oformlenie': ['natural shaped tinted eyebrows'],
    'permanent': ['permanent makeup microblading tattooed eyebrows'],
}


WORK_COARSE = {'manikyur', 'resnicy', 'brovi', 'massazh', 'pedikyur'}
KOMANDA_MIN_CONF = 0.55
WORK_KOMANDA_MARGIN = 0.18


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


def unique_path(dest: Path) -> Path:
    if not dest.exists():
        return dest
    stem, suffix = dest.stem, dest.suffix
    i = 2
    while True:
        candidate = dest.with_name(f'{stem}_{i}{suffix}')
        if not candidate.exists():
            return candidate
        i += 1


def classify_by_keywords(path: Path, root: Path) -> str | None:
    try:
        rel = str(path.relative_to(root)).replace('\\', '/')
    except ValueError:
        rel = str(path)
    hint = rel.lower()
    ext = path.suffix.lower()

    for pat, folder in KEYWORD_RULES:
        if re.search(pat, hint, flags=re.IGNORECASE):
            return folder

    if ext in VIDEO_EXT:
        return '06_reels-raw'

    parent = path.parent.name.lower()
    for pat, folder in PARENT_HINTS:
        if re.search(pat, parent, flags=re.IGNORECASE):
            return folder
    return None


class VisionClassifier:
    def __init__(self, min_confidence: float = 0.35) -> None:
        import open_clip
        import torch
        from PIL import Image

        self.torch = torch
        self.Image = Image
        self.min_confidence = min_confidence
        self.model, _, self.preprocess = open_clip.create_model_and_transforms(
            'ViT-B-32', pretrained='laion2b_s34b_b79k'
        )
        self.tokenizer = open_clip.get_tokenizer('ViT-B-32')
        self.model.eval()
        self._text_cache: dict[str, object] = {}

    def _encode_texts(self, prompts: list[str]):
        key = '\n'.join(prompts)
        if key not in self._text_cache:
            with self.torch.no_grad():
                feats = self.model.encode_text(self.tokenizer(prompts))
                feats /= feats.norm(dim=-1, keepdim=True)
            self._text_cache[key] = feats
        return self._text_cache[key]

    def _best(self, img_feat, labels: dict[str, list[str]]):
        owners: list[str] = []
        prompts: list[str] = []
        for label, ps in labels.items():
            for p in ps:
                owners.append(label)
                prompts.append(p)
        text_feat = self._encode_texts(prompts)
        sims = (img_feat @ text_feat.T).squeeze(0)
        scores: dict[str, float] = {}
        for i, label in enumerate(owners):
            scores[label] = max(scores.get(label, -1e9), float(sims[i]))
        ranked = sorted(scores.items(), key=lambda x: -x[1])
        vals = self.torch.tensor([s for _, s in ranked])
        probs = self.torch.softmax(vals * 100, dim=0)
        prob_map = {k: float(p) for (k, _), p in zip(ranked, probs)}
        return ranked[0][0], float(probs[0]), prob_map

    def classify(self, path: Path) -> tuple[str, float, str]:
        try:
            image = self.Image.open(path).convert('RGB')
        except OSError:
            return '00_inbox', 0.0, 'unreadable'
        img = self.preprocess(image).unsqueeze(0)
        with self.torch.no_grad():
            feat = self.model.encode_image(img)
            feat /= feat.norm(dim=-1, keepdim=True)

        # Classify without komanda first — faces on work photos wrongly land in team folder.
        no_komanda = {k: v for k, v in COARSE_PROMPTS.items() if k != 'komanda'}
        coarse, conf, scores = self._best(feat, no_komanda)

        if conf < self.min_confidence:
            k_coarse, k_conf, _ = self._best(feat, {'komanda': COARSE_PROMPTS['komanda']})
            if k_conf >= KOMANDA_MIN_CONF:
                coarse, conf = k_coarse, k_conf
            else:
                return '00_inbox', conf, 'low-conf'

        # Note: "complex" (lashes+brows) is keyword-only — vision confuses
        # permanent brows with lashes too often.

        if conf < self.min_confidence:
            return '00_inbox', conf, 'low-conf'

        if coarse == 'manikyur':
            fine, _, _ = self._best(feat, NAIL_FINE)
            return f'01_raboty/manikyur/{fine}', conf, 'vision'
        if coarse == 'resnicy':
            fine, _, _ = self._best(feat, LASH_FINE)
            return f'01_raboty/resnicy/{fine}', conf, 'vision'
        if coarse == 'brovi':
            fine, _, _ = self._best(feat, BROW_FINE)
            return f'01_raboty/brovi/{fine}', conf, 'vision'

        mapping = {
            'massazh': '01_raboty/massazh',
            'pedikyur': '01_raboty/pedikyur',
            'prostranstvo': '03_prostranstvo',
            'komanda': '04_komanda',
            'brand': '05_brand',
            'process': '02_process',
        }
        return mapping[coarse], conf, 'vision'


def ensure_structure(root: Path, apply: bool, log: Logger) -> None:
    for rel in STRUCTURE:
        path = root / Path(rel)
        if not path.exists():
            if apply:
                path.mkdir(parents=True, exist_ok=True)
                log.log(f'[mkdir] {rel}')
            else:
                log.log(f'[mkdir?] {rel}')


def collect_media(root: Path, inbox_only: bool, folder_only: str | None = None) -> list[Path]:
    if folder_only:
        scan = root / folder_only
        if not scan.exists():
            return []
        files: list[Path] = []
        skip_names = {'_organize-log.txt', '_list.txt', 'README-struktura.txt', 'organize-log.txt', 'classify-log.txt'}
        for p in scan.rglob('*'):
            if not p.is_file() or p.suffix.lower() not in MEDIA_EXT or p.name in skip_names:
                continue
            files.append(p)
        return sorted(files)

    scan = root / '00_inbox' if inbox_only else root
    if not scan.exists():
        return []
    files: list[Path] = []
    skip_names = {'_organize-log.txt', '_list.txt', 'README-struktura.txt', 'organize-log.txt', 'classify-log.txt'}
    for p in scan.rglob('*'):
        if not p.is_file():
            continue
        if p.name in skip_names:
            continue
        if p.suffix.lower() not in MEDIA_EXT:
            continue
        if not inbox_only:
            try:
                top = p.relative_to(root).parts[0]
            except ValueError:
                continue
            if top in MANAGED_TOP and top != '00_inbox':
                continue
        files.append(p)
    return sorted(files)


def write_inbox_list(root: Path, log: Logger) -> None:
    inbox = root / '00_inbox'
    if not inbox.exists():
        return
    remaining = [
        p for p in inbox.rglob('*')
        if p.is_file() and p.suffix.lower() in MEDIA_EXT
    ]
    lines = ['Files still in 00_inbox:', '']
    for p in sorted(remaining):
        lines.append(str(p.relative_to(inbox)).replace('\\', '/'))
    (inbox / '_list.txt').write_text('\n'.join(lines), encoding='utf-8')
    log.log(f'Inbox remaining: {len(remaining)}')


def main() -> int:
    parser = argparse.ArgumentParser(description='Classify LOCAL Beauty Studio photos')
    parser.add_argument('--root', default=r'C:\Local', help='Photo root folder')
    parser.add_argument('--preview', action='store_true', help='Plan only, no moves')
    parser.add_argument('--apply', action='store_true', help='Actually move/copy files')
    parser.add_argument('--copy', action='store_true', help='Copy instead of move')
    parser.add_argument('--inbox-only', action='store_true', help='Only re-sort 00_inbox')
    parser.add_argument('--keywords-only', action='store_true', help='Skip CLIP vision')
    parser.add_argument('--vision-only', action='store_true', help='Skip keyword rules')
    parser.add_argument('--min-confidence', type=float, default=0.35)
    parser.add_argument('--folder-only', help='Re-classify only this folder, e.g. 04_komanda')
    parser.add_argument('--limit', type=int, default=0, help='Process at most N files (0=all)')
    args = parser.parse_args()

    if not args.preview and not args.apply:
        # Safe default: preview unless --apply
        args.preview = True

    root = Path(args.root).expanduser().resolve()
    apply = bool(args.apply) and not args.preview
    log = Logger()
    script_dir = Path(__file__).resolve().parent

    log.log('=== LOCAL Beauty Studio vision classifier ===')
    log.log(f'Script: {Path(__file__).resolve()}')
    log.log(f'Root: {root}')
    log.log(
        f'preview={args.preview or not apply} copy={args.copy} '
        f'inbox_only={args.inbox_only} keywords_only={args.keywords_only} '
        f'vision_only={args.vision_only} folder_only={args.folder_only}'
    )

    if not root.exists():
        if apply:
            root.mkdir(parents=True, exist_ok=True)
            log.log(f'Created root: {root}')
        else:
            log.log(f'ERROR: root does not exist: {root}')
            _save_logs(log, script_dir, root)
            return 1

    ensure_structure(root, apply, log)
    media = collect_media(root, args.inbox_only, args.folder_only)
    log.log(f'Media to classify: {len(media)}')
    if not media:
        log.log('ERROR: no media files found under root (unmanaged / inbox).')
        log.log('Put photos into the root folder (or 00_inbox) and re-run.')
        _save_logs(log, script_dir, root)
        return 2

    for sample in media[:15]:
        try:
            log.log(f'  sample: {sample.relative_to(root)}')
        except ValueError:
            log.log(f'  sample: {sample}')

    vision: VisionClassifier | None = None
    if not args.keywords_only:
        need_vision = False
        if args.vision_only:
            need_vision = True
        else:
            # Load vision only if at least one file lacks keyword match,
            # or always if we want hybrid for images. Pre-scan lightly.
            for p in media:
                if p.suffix.lower() in IMAGE_EXT and classify_by_keywords(p, root) is None:
                    need_vision = True
                    break
        if need_vision or args.vision_only:
            log.log('Loading CLIP model (first run downloads ~350MB)...')
            vision = VisionClassifier(min_confidence=args.min_confidence)
            log.log('CLIP ready.')

    plan: list[tuple[Path, Path, str, str, float]] = []
    stats: Counter[str] = Counter()
    sources: Counter[str] = Counter()

    for idx, src in enumerate(media):
        if args.limit and idx >= args.limit:
            break
        folder = None
        source = 'unknown'
        conf = 1.0

        if not args.vision_only:
            folder = classify_by_keywords(src, root)
            if folder:
                source = 'keyword'

        if folder is None and src.suffix.lower() in VIDEO_EXT:
            folder, source, conf = '06_reels-raw', 'video', 1.0

        if folder is None and vision is not None and src.suffix.lower() in IMAGE_EXT:
            folder, conf, source = vision.classify(src)
        elif folder is None:
            folder, source, conf = '00_inbox', 'no-match', 0.0

        dest_dir = root / Path(folder)
        dest = unique_path(dest_dir / src.name)
        if src.resolve() == dest.resolve() or src.parent.resolve() == dest_dir.resolve():
            # already in target folder name-wise; still count skip
            continue
        # Avoid no-op when already under same relative folder
        try:
            cur_rel = str(src.parent.relative_to(root)).replace('\\', '/')
        except ValueError:
            cur_rel = ''
        if cur_rel == folder:
            continue

        plan.append((src, dest, folder, source, conf))
        stats[folder] += 1
        sources[source] += 1

    if not plan:
        log.log('Nothing to move (already organized or already in matching folder).')
    else:
        log.log('Plan:')
        for folder, count in sorted(stats.items()):
            log.log(f'  {count:4d} -> {folder}')
        log.log('Sources: ' + ', '.join(f'{k}={v}' for k, v in sorted(sources.items())))

        ok = fail = 0
        for i, (src, dest, folder, source, conf) in enumerate(plan, 1):
            try:
                short_from = str(src.relative_to(root))
            except ValueError:
                short_from = str(src)
            try:
                short_to = str(dest.relative_to(root))
            except ValueError:
                short_to = str(dest)
            tag = f'{source}:{conf:.2f}' if source.startswith('vision') or source == 'low-conf' else source
            if not apply:
                log.log(f'[{i}/{len(plan)}] {short_from} => {short_to}  ({tag})')
                continue
            try:
                dest.parent.mkdir(parents=True, exist_ok=True)
                if args.copy:
                    shutil.copy2(src, dest)
                    log.log(f'[copy] {short_from} -> {short_to}  ({tag})')
                else:
                    shutil.move(str(src), str(dest))
                    log.log(f'[move] {short_from} -> {short_to}  ({tag})')
                ok += 1
            except OSError as exc:
                fail += 1
                log.log(f'[FAIL] {short_from} :: {exc}')
        if apply:
            log.log(f'Done OK={ok} FAIL={fail}')

    if apply and not args.copy:
        # remove empty unmanaged dirs
        for d in sorted(root.rglob('*'), key=lambda p: len(p.parts), reverse=True):
            if not d.is_dir():
                continue
            try:
                rel = d.relative_to(root)
            except ValueError:
                continue
            if not rel.parts:
                continue
            if rel.parts[0] in MANAGED_TOP:
                continue
            try:
                next(d.iterdir())
            except StopIteration:
                d.rmdir()
                log.log(f'[rmdir] {rel}')
            except OSError:
                pass

    write_inbox_list(root, log)
    _save_logs(log, script_dir, root)
    return 0


def _save_logs(log: Logger, script_dir: Path, root: Path) -> None:
    desktop = Path.home() / 'Desktop' / 'local-classify-log.txt'
    paths = [
        script_dir / 'classify-log.txt',
        desktop,
        root / '_classify-log.txt',
    ]
    log.save(paths)
    print()
    for p in paths:
        print(f'Log: {p}')


if __name__ == '__main__':
    raise SystemExit(main())
