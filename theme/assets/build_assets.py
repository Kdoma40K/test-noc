#!/usr/bin/env python3
"""Build Noctalia's asset override: UPPERCASE shell labels + NASA wording.

Copies Noctalia's installed assets, rewrites translations/en.json, and writes the
result where NOCTALIA_ASSETS_DIR points. Run it before every Noctalia start so new
upstream strings are always present (a stale copy would show raw keys).

  build_assets.py [--settings-upper] [SRC] [DST]
  --settings-upper uppercases Settings titles and labels too; descriptions and
                   placeholders keep their case and no word swaps apply there
                   (default: Settings stays sentence case)
  SRC default: first of /usr/share/noctalia/assets, /usr/local/share/noctalia/assets
  DST default: ~/.local/share/noctalia-nasapunk/assets
"""
import json
import re
import shutil
import sys
from pathlib import Path

WORDS = {
    "Wi-Fi": "NET", "Bluetooth": "BT LINK", "Do Not Disturb": "QUIET", "Do not disturb": "QUIET",
    "Night Light": "NIGHT", "Night light": "NIGHT", "Volume": "VOL", "Brightness": "BRT",
    "Notifications": "MSGS", "Power": "PWR",
}
KEEP_PREFIXES = ("settings.",)  # Settings window stays sentence case unless --settings-upper
PLACEHOLDER = re.compile(r"(\{[^}]*\})")


def shout(text: str, words: bool = True) -> str:
    if words:
        text = WORDS.get(text, text)
    return "".join(p if PLACEHOLDER.fullmatch(p) else p.upper() for p in PLACEHOLDER.split(text))


SETTINGS_KEEP_CASE = ("desc", "placeholder")  # long help text reads better in sentence case


def walk(node, path="", keep=KEEP_PREFIXES):
    if isinstance(node, dict):
        return {k: walk(v, f"{path}.{k}" if path else k, keep) for k, v in node.items()}
    if not isinstance(node, str):
        return node
    if path.startswith("settings."):
        if keep or any(t in path.rsplit(".", 1)[-1] for t in SETTINGS_KEEP_CASE):
            return node
        return shout(node, words=False)
    return shout(node)


def main() -> int:
    args = sys.argv[1:]
    keep = KEEP_PREFIXES
    if "--settings-upper" in args:
        args.remove("--settings-upper")
        keep = ()
    candidates = [Path(args[0])] if args else [
        Path("/usr/share/noctalia/assets"), Path("/usr/local/share/noctalia/assets")]
    src = next((c for c in candidates if (c / "translations" / "en.json").is_file()), None)
    if src is None:
        print("build_assets: Noctalia assets not found; tried " + ", ".join(map(str, candidates)), file=sys.stderr)
        return 1
    dst = Path(args[1]) if len(args) > 1 else Path.home() / ".local/share/noctalia-nasapunk/assets"
    tmp = dst.with_name(dst.name + ".tmp")
    shutil.rmtree(tmp, ignore_errors=True)
    shutil.copytree(src, tmp)
    en = tmp / "translations" / "en.json"
    en.write_text(json.dumps(walk(json.loads(en.read_text()), keep=keep), ensure_ascii=False, indent=1))
    shutil.rmtree(dst, ignore_errors=True)
    tmp.rename(dst)
    print(f"build_assets: {src} -> {dst}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
