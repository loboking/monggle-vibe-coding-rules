#!/usr/bin/env python3
"""
Monggle Vibe Coding Rules - Rule Synchronization Script
Syncs rules/core-rules.yaml to all target files
Single Source of Truth pattern

Python 3.8+ compatible
API-free (uses standard library only)
"""

import os
import sys
import json
from pathlib import Path
from typing import Dict, Any, List, Optional
from datetime import datetime


def parse_yaml_simple(file_path: Path) -> Dict[str, Any]:
    """Simple YAML parser without PyYAML dependency

    Args:
        file_path: Path to YAML file

    Returns:
        Parsed configuration dictionary
    """
    config = {}
    current_key = None
    current_list = None
    current_dict = None

    with open(file_path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    for line in lines:
        line = line.rstrip()

        # Skip empty lines and comments
        if not line or line.strip().startswith("#"):
            continue

        # Calculate indentation
        indent = len(line) - len(line.lstrip())
        line = line.strip()

        # Key-value pair
        if ":" in line and not line.startswith("-"):
            key, value = line.split(":", 1)
            key = key.strip()
            value = value.strip()

            # Parse value types
            if not value:
                current_dict = {}
                current_list = None
                if indent == 0:
                    config[key] = current_dict
                    current_key = key
                else:
                    if current_dict is not None:
                        current_dict[key] = {}
                        current_dict = current_dict[key]
                    elif current_list is not None:
                        # List item with dict
                        pass

            elif value.startswith('"') or value.startswith("'"):
                value = value[1:-1]
                if current_dict is not None:
                    current_dict[key] = value
                else:
                    config[key] = value

            elif value.lower() == "true":
                if current_dict is not None:
                    current_dict[key] = True
                else:
                    config[key] = True

            elif value.lower() == "false":
                if current_dict is not None:
                    current_dict[key] = False
                else:
                    config[key] = False

            elif value.isdigit():
                if current_dict is not None:
                    current_dict[key] = int(value)
                else:
                    config[key] = int(value)

            else:
                if current_dict is not None:
                    current_dict[key] = value
                else:
                    config[key] = value

        # List item
        elif line.startswith("- "):
            item = line[2:].strip()

            if current_list is None:
                current_list = []
                if current_key and current_key in config:
                    if isinstance(config[current_key], dict):
                        # Parent dict, ignore
                        pass
                    else:
                        config[current_key] = current_list

            if item.startswith("- "):
                # Nested list
                pass
            else:
                if item.startswith('"') or item.startswith("'"):
                    item = item[1:-1]

                if current_list is not None:
                    current_list.append(item)

        # Reset on dedent
        if indent == 0:
            current_key = None
            current_dict = None
            current_list = None

    return config


def generate_cursor_rules(config: Dict[str, Any]) -> str:
    """Generate .cursorrules content from config

    Args:
        config: Parsed configuration

    Returns:
        .cursorrules file content
    """
    # Handle both dict and direct value for mode
    mode_config = config.get("mode", "solo")
    if isinstance(mode_config, dict):
        mode = mode_config.get("current", mode_config.get("default", "solo"))
    else:
        mode = mode_config

    prd_config = config.get("prd", {})
    dev_rules = config.get("development", {})
    testing = config.get("testing", {})
    token_opt = config.get("token_optimization", {})

    output = []
    output.append("# Monggle Vibe Coding Rules")
    output.append(f"# Mode: {mode}")
    output.append(f"# Generated: {datetime.now().isoformat()}")
    output.append("")
    output.append("---")
    output.append("")
    output.append("## Project Mode")
    output.append("")
    output.append(f"Current mode: **{mode}**")
    output.append("")
    if mode == "team":
        output.append("- PRD is **REQUIRED** for all development work")
        output.append("- Use `/quick` for urgent hotfixes only")
    else:
        output.append("- PRD is **OPTIONAL** (but recommended)")
        output.append("- Use PRD for complex features")
        output.append("- Quick iterations allowed")
    output.append("")
    output.append("---")
    output.append("")
    output.append("## PRD Types")

    for prd_type in prd_config.get("types", []):
        name = prd_type.get("name", "unknown")
        sections = prd_type.get("required_sections", [])
        output.append(f"\n### {name.capitalize()}")
        output.append(f"Required sections: {', '.join(sections)}")

    output.append("")
    output.append("---")
    output.append("")
    output.append("## Development Rules")
    output.append("")

    # Commit format
    output.append(f"**Commit format:** `{dev_rules.get('commit_format', 'type: description')}`")
    output.append(f"Types: {', '.join(dev_rules.get('commit_types', []))}")
    output.append("")

    # Branch rules
    output.append(f"**Branch prefix:** `{dev_rules.get('branch_prefix', 'dev/{{user}}/{{feature}}')}`")
    output.append("**Direct main push:** BLOCKED")
    output.append("")

    # PR rules
    output.append("**PR requirements:**")
    if dev_rules.get("pr_requires_prd_link"):
        output.append("- PRD link required")
    if dev_rules.get("pr_single_feature"):
        output.append("- One feature per PR")
    if dev_rules.get("pr_ci_blocking"):
        output.append("- CI must pass")

    output.append("")
    output.append("---")
    output.append("")
    output.append("## Testing")

    coverage = testing.get("coverage", {})
    output.append(f"**Coverage requirements:**")
    output.append(f"- Personal: {coverage.get('personal_branch', '80%+')}")
    output.append(f"- PR: {coverage.get('pr_creation', '80%+')}")
    output.append(f"- Main: {coverage.get('main_merge', '100%')}")

    output.append("")
    output.append("---")
    output.append("")
    output.append("## Token Optimization")

    if token_opt.get("diff_only_output"):
        output.append("- Output only diff (no full file reprint)")
    if token_opt.get("reference_over_reprint"):
        output.append("- Use file:line references")
    if token_opt.get("code_first_approach"):
        output.append("- Code first, minimal explanation")

    return "\n".join(output)


def generate_claude_md(config: Dict[str, Any]) -> str:
    """Generate CLAUDE.md content from config

    Args:
        config: Parsed configuration

    Returns:
        CLAUDE.md file content
    """
    # Handle both dict and direct value for mode
    mode_config = config.get("mode", "solo")
    if isinstance(mode_config, dict):
        mode = mode_config.get("current", mode_config.get("default", "solo"))
    else:
        mode = mode_config

    prd_config = config.get("prd", {})
    agents = config.get("agents", {})
    verdict = config.get("verdict", {})
    free_chat = config.get("free_chat", {})

    output = []
    output.append("# Vibe Coding Rules")
    output.append("")
    output.append(f"> **Mode: {mode.upper()}**")
    output.append("")
    if mode == "team":
        output.append("> PRD 없이는 어떠한 개발 요청도 응답하지 않습니다.")
    else:
        output.append("> PRD는 선택 사항이지만 복잡한 작업에는 권장됩니다.")
    output.append("")
    output.append("---")
    output.append("")
    output.append("## Current Mode")
    output.append("")
    output.append(f"**{mode.upper()}** 모드로 실행 중입니다.")
    output.append("")
    output.append(f"- `/mode` - 현재 모드 확인")
    output.append(f"- `/mode solo` - Solo 모드로 변경")
    output.append(f"- `/mode team` - Team 모드로 변경")
    output.append("")
    output.append("---")
    output.append("")
    output.append("## Agent Pipeline")

    pipeline = agents.get("pipeline", [])
    for agent_name in pipeline:
        agent_config = agents.get(agent_name, {})
        description = agent_config.get("description", "")
        output.append(f"\n### {agent_name.capitalize()}")
        output.append(f"{description}")

    output.append("")
    output.append("---")
    output.append("")
    output.append("## Verdict System")

    pass_config = verdict.get("pass", {})
    fix_config = verdict.get("fix", {})
    fail_config = verdict.get("fail", {})

    output.append(f"\n### PASS")
    output.append(f"Confidence >= {pass_config.get('min_confidence', 0.9)}")
    output.append(f"{pass_config.get('description', '')}")
    output.append("")
    output.append("### FIX")
    output.append(f"Confidence >= {fix_config.get('min_confidence', 0.5)}")
    output.append(f"{fix_config.get('description', '')}")
    if fix_config.get("auto_feedback"):
        output.append("- Automatic fix suggestions provided")
    output.append("")
    output.append("### FAIL")
    output.append(f"{fail_config.get('description', '')}")

    output.append("")
    output.append("---")
    output.append("")
    output.append("## Free Chat Rules")

    if free_chat.get("dev_requires_prd_in_team", False):
        output.append("\n**Team Mode:**")
        output.append("- All development requests require PRD")

    if not free_chat.get("dev_requires_prd_in_solo", True):
        output.append("\n**Solo Mode:**")
        output.append("- Development requests without PRD allowed")

    exemptions = free_chat.get("prd_exemptions", [])
    if exemptions:
        output.append("\n**PRD Exemptions** (always allowed):")
        for exemption in exemptions[:10]:
            output.append(f"- {exemption}")

    return "\n".join(output)


def sync_settings_json(config: Dict[str, Any], project_root: Path) -> bool:
    """Sync configuration to .claude/settings.json

    Args:
        config: Parsed configuration
        project_root: Project root path

    Returns:
        True if successful
    """
    settings_file = project_root / ".claude" / "settings.json"

    # Read existing settings
    existing_settings = {}
    if settings_file.exists():
        with open(settings_file, "r") as f:
            try:
                existing_settings = json.load(f)
            except json.JSONDecodeError:
                pass

    # Handle both dict and direct value for mode
    mode_config = config.get("mode", "solo")
    if isinstance(mode_config, dict):
        mode = mode_config.get("current", mode_config.get("default", "solo"))
    else:
        mode = mode_config

    # Update with monggle-specific settings
    existing_settings["monggle"] = {
        "mode": mode,
        "version": config.get("version", "2.2"),
        "last_sync": datetime.now().isoformat()
    }

    # Write updated settings
    settings_file.parent.mkdir(parents=True, exist_ok=True)
    with open(settings_file, "w") as f:
        json.dump(existing_settings, f, indent=2)

    return True


def sync_all(project_root: Optional[Path] = None) -> bool:
    """Sync core-rules.yaml to all target files

    Args:
        project_root: Project root path (auto-detect if None)

    Returns:
        True if successful
    """
    # Detect project root
    if project_root is None:
        project_root = Path.cwd()

        # Walk up to find project root (has rules/ directory)
        for _ in range(5):
            if (project_root / "rules" / "core-rules.yaml").exists():
                break
            project_root = project_root.parent

    rules_file = project_root / "rules" / "core-rules.yaml"

    if not rules_file.exists():
        print(f"[ERROR] Core rules not found: {rules_file}")
        return False

    print(f"[INFO] Loading core rules from: {rules_file}")

    # Parse YAML
    try:
        config = parse_yaml_simple(rules_file)
    except Exception as e:
        print(f"[ERROR] Failed to parse core rules: {e}")
        return False

    print(f"[SUCCESS] Loaded core rules v{config.get('version', 'unknown')}")

    # Sync to .cursorrules
    cursor_rules_file = project_root / ".cursorrules"
    print(f"[INFO] Syncing to .cursorrules...")
    cursor_content = generate_cursor_rules(config)
    cursor_rules_file.write_text(cursor_content, encoding="utf-8")
    print(f"[SUCCESS] .cursorrules updated")

    # Sync to CLAUDE.md
    claude_md_file = project_root / "CLAUDE.md"
    print(f"[INFO] Syncing to CLAUDE.md...")
    claude_content = generate_claude_md(config)
    claude_md_file.write_text(claude_content, encoding="utf-8")
    print(f"[SUCCESS] CLAUDE.md updated")

    # Sync to .claude/settings.json
    print(f"[INFO] Syncing to .claude/settings.json...")
    if sync_settings_json(config, project_root):
        print(f"[SUCCESS] .claude/settings.json updated")

    print(f"\n[SUCCESS] All rules synced successfully!")
    return True


def main():
    """CLI entry point"""
    import argparse

    parser = argparse.ArgumentParser(
        description="Sync Monggle Vibe Coding Rules"
    )
    parser.add_argument(
        "--project-root",
        type=str,
        help="Project root path (default: auto-detect)"
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Check if sync is needed (exit code 1 if needed)"
    )

    args = parser.parse_args()

    if args.project_root:
        project_root = Path(args.project_root).absolute()
    else:
        project_root = None

    if args.check:
        # Check-only mode (not fully implemented)
        print("[INFO] Check mode not yet implemented")
        return 0

    success = sync_all(project_root)
    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
