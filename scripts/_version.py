"""Toolkit version SSOT for Python scripts.

VERSION 파일이 유일한 정본. 셸의 get_toolkit_version()과 동일한 해석 순서:
  1) env MONGGLE_TOOLKIT_VERSION
  2) <~/.claude/.repo_path 가 가리키는 repo>/VERSION  (글로벌 설치)
  3) <repo root>/VERSION  (이 파일이 scripts/ 안 → parent.parent)
  4) git toplevel /VERSION
  5) "unknown"
"""
import os
import subprocess
from pathlib import Path


def get_toolkit_version() -> str:
    env = os.environ.get("MONGGLE_TOOLKIT_VERSION")
    if env:
        return env.strip()

    ptr = Path.home() / ".claude" / ".repo_path"
    if ptr.is_file():
        try:
            repo = Path(ptr.read_text().strip())
            vf = repo / "VERSION"
            if vf.is_file():
                return vf.read_text().strip()
        except OSError:
            pass

    vf = Path(__file__).resolve().parent.parent / "VERSION"
    if vf.is_file():
        try:
            return vf.read_text().strip()
        except OSError:
            pass

    try:
        top = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"],
            stderr=subprocess.DEVNULL, text=True,
        ).strip()
        vf = Path(top) / "VERSION"
        if vf.is_file():
            return vf.read_text().strip()
    except (subprocess.SubprocessError, OSError):
        pass

    return "unknown"


__version__ = get_toolkit_version()
