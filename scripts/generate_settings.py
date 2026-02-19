#!/usr/bin/env python3
"""
Monggle Vibe Coding Rules - Settings Generator
settings.json를 현재 경로에 맞게 동적으로 생성합니다.
Python 3.8+ 호환
"""

import os
import sys
import json
from pathlib import Path


def get_project_root() -> Path:
    """프로젝트 루트 경로 찾기"""
    # 이 스크립트가 있는 위치 기준
    script_dir = Path(__file__).parent.absolute()
    return script_dir.parent


def generate_settings(project_root: Path = None) -> dict:
    """settings.json 생성

    Args:
        project_root: 프로젝트 루트 경로 (None인 경우 자동 감지)

    Returns:
        dict: 생성된 settings
    """
    if project_root is None:
        project_root = get_project_root()

    # 경로를 문자열로 변환 (절대 경로)
    root_str = str(project_root)

    settings = {
        "teammateMode": "tmux",
        "env": {
            "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
        },
        "hooks": {
            "PreToolUse": [
                os.path.join(root_str, ".claude", "hooks", "pre-tool-use.sh")
            ]
        },
        "slashCommands": [
            {
                "name": "gate",
                "path": os.path.join(root_str, ".claude", "commands", "gate.sh")
            },
            {
                "name": "pipeline",
                "path": os.path.join(root_str, ".claude", "commands", "pipeline.sh")
            },
            {
                "name": "trace",
                "path": os.path.join(root_str, ".claude", "commands", "trace.sh")
            }
        ]
    }

    return settings


def write_settings(settings: dict, output_path: Path = None) -> bool:
    """settings.json 파일 작성

    Args:
        settings: 설정 딕셔너리
        output_path: 출력 경로 (None인 경우 기본 위치 사용)

    Returns:
        bool: 성공 여부
    """
    if output_path is None:
        project_root = get_project_root()
        output_path = project_root / ".claude" / "settings.json"

    # 부모 디렉토리 생성
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # JSON 작성 (들여쓰기 2칸)
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)

    print(f"Generated: {output_path}")
    return True


def create_template(output_path: Path = None) -> bool:
    """settings.json.template 템플릿 생성

    Args:
        output_path: 출력 경로

    Returns:
        bool: 성공 여부
    """
    if output_path is None:
        project_root = get_project_root()
        output_path = project_root / ".claude" / "settings.json.template"

    template_content = """{
  "teammateMode": "tmux",
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "hooks": {
    "PreToolUse": [
      "__PROJECT_ROOT__/.claude/hooks/pre-tool-use.sh"
    ]
  },
  "slashCommands": [
    {
      "name": "gate",
      "path": "__PROJECT_ROOT__/.claude/commands/gate.sh"
    },
    {
      "name": "pipeline",
      "path": "__PROJECT_ROOT__/.claude/commands/pipeline.sh"
    },
    {
      "name": "trace",
      "path": "__PROJECT_ROOT__/.claude/commands/trace.sh"
    }
  ]
}
"""

    output_path.parent.mkdir(parents=True, exist_ok=True)

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(template_content)

    print(f"Template created: {output_path}")
    return True


def main():
    """메인 진입점"""
    import argparse

    parser = argparse.ArgumentParser(
        description="Generate settings.json for Monggle Vibe Coding Rules"
    )
    parser.add_argument(
        "--template",
        action="store_true",
        help="Create settings.json.template instead"
    )
    parser.add_argument(
        "--output",
        type=str,
        default=None,
        help="Output path (default: .claude/settings.json)"
    )
    parser.add_argument(
        "--project-root",
        type=str,
        default=None,
        help="Project root path (default: auto-detect)"
    )

    args = parser.parse_args()

    # 프로젝트 루트 설정
    project_root = None
    if args.project_root:
        project_root = Path(args.project_root).absolute()

    # 템플릿 모드
    if args.template:
        output_path = Path(args.output) if args.output else None
        success = create_template(output_path)
        sys.exit(0 if success else 1)

    # 설정 생성 모드
    settings = generate_settings(project_root)

    # 출력 경로 설정
    output_path = None
    if args.output:
        output_path = Path(args.output).absolute()

    success = write_settings(settings, output_path)

    # 생성된 설정 출력
    if success:
        print("\nGenerated settings.json:")
        print(json.dumps(settings, indent=2, ensure_ascii=False))

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
