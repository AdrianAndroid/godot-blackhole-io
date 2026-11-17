#!/usr/bin/env python3
"""Export, patch, and fault-test the current Web loader for acceptance."""

from __future__ import annotations

import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
EXPORT_DIR = ROOT / "artifacts/web-loader-export"
GODOT = Path(os.environ.get("GODOT", "/usr/local/bin/godot"))


def run(command: list[str]) -> None:
    print("+", " ".join(command), flush=True)
    subprocess.run(command, cwd=ROOT, check=True)


def main() -> int:
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    run([
        str(GODOT), "--headless", "--path", str(ROOT), "--export-release",
        "Web / GitHub Pages", str(EXPORT_DIR / "play.html"),
    ])
    shutil.copyfile(ROOT / "web/index.html", EXPORT_DIR / "index.html")
    run([
        sys.executable, "-I", str(ROOT / "tools/patch_web_loader.py"),
        "--input", str(EXPORT_DIR / "play.html"),
        "--index", str(EXPORT_DIR / "index.html"),
        "--version", "acceptance-resume",
    ])
    run([
        sys.executable, "-I", str(ROOT / "tools/patch_web_loader.py"),
        "--input", str(EXPORT_DIR / "play.html"),
        "--version", "acceptance-resume", "--check",
    ])
    run([
        sys.executable, "-I", str(ROOT / "tools/web_loader_test.py"),
        "--export-dir", str(EXPORT_DIR),
        "--output", str(ROOT / "artifacts/web/acceptance-loader"),
        "--headless",
    ])
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except subprocess.CalledProcessError as error:
        raise SystemExit(error.returncode)
