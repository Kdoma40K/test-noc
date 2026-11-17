#!/usr/bin/env python3
"""Build Noctalia's asset override: UPPERCASE shell labels + NASA wording.

Copies Noctalia's installed assets, rewrites translations/en.json, and writes the
result where NOCTALIA_ASSETS_DIR points. Run it before every Noctalia start so new
upstream strings are always present (a stale copy would show raw keys).

  build_assets.py [SRC] [DST]
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
KEEP_PREFIXES = ("settings.",)  # the Settings window stays sentence case
PLACEHOLDER = re.compile(r"(\{[^}]*\})")


def shout(text: str) -> str:
    text = WORDS.get(text, text)
    return "".join(p if PLACEHOLDER.fullmatch(p) else p.upper() for p in PLACEHOLDER.split(text))


def walk(node, path=""):
    if isinstance(node, dict):
        return {k: walk(v, f"{path}.{k}" if path else k) for k, v in node.items()}
    if isinstance(node, str) and not path.startswith(KEEP_PREFIXES):
        return shout(node)
    return node


def main() -> int:
    candidates = [Path(sys.argv[1])] if len(sys.argv) > 1 else [
        Path("/usr/share/noctalia/assets"), Path("/usr/local/share/noctalia/assets")]
    src = next((c for c in candidates if (c / "translations" / "en.json").is_file()), None)
    if src is None:
        print("build_assets: Noctalia assets not found; tried " + ", ".join(map(str, candidates)), file=sys.stderr)
        return 1
    dst = Path(sys.argv[2]) if len(sys.argv) > 2 else Path.home() / ".local/share/noctalia-nasapunk/assets"
    tmp = dst.with_name(dst.name + ".tmp")
    shutil.rmtree(tmp, ignore_errors=True)
    shutil.copytree(src, tmp)
    en = tmp / "translations" / "en.json"
    en.write_text(json.dumps(walk(json.loads(en.read_text())), ensure_ascii=False, indent=1))
    shutil.rmtree(dst, ignore_errors=True)
    tmp.rename(dst)
    print(f"build_assets: {src} -> {dst}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
