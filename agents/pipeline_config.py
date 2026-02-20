#!/usr/bin/env python3
"""
Monggle Vibe Coding Rules - Pipeline Configuration
Auto-selects agents based on PRD type
Implements auto-pipeline feature

Python 3.8+ compatible
API-free
"""

import os
import sys
import json
from pathlib import Path
from typing import Dict, Any, List, Optional, Tuple
from dataclasses import dataclass, field


@dataclass
class AgentConfig:
    """Agent configuration"""
    name: str
    enabled: bool
    type: str  # hook, python
    script: Optional[str] = None
    description: str = ""
    skip_for_prd_types: List[str] = field(default_factory=list)


@dataclass
class PipelineConfig:
    """Pipeline configuration"""
    prd_type: str
    agents: List[AgentConfig]
    mode: str = "solo"  # solo | team


class PipelineConfigurator:
    """Auto-pipeline configuration based on PRD type"""

    # Default agent definitions
    DEFAULT_AGENTS = {
        "gate": AgentConfig(
            name="gate",
            enabled=True,
            type="hook",
            description="PRD validation"
        ),
        "scan": AgentConfig(
            name="scan",
            enabled=True,
            type="python",
            script="agents/scan_agent.py",
            description="Codebase impact analysis"
        ),
        "fold": AgentConfig(
            name="fold",
            enabled=True,
            type="python",
            script="agents/fold_agent.py",
            description="Result synthesis and feasibility"
        ),
        "verdict": AgentConfig(
            name="verdict",
            enabled=True,
            type="python",
            script="agents/verdict_agent.py",
            description="Final decision (PASS/FIX/FAIL)"
        ),
        "patch": AgentConfig(
            name="patch",
            enabled=True,
            type="python",
            script="agents/patch_agent.py",
            description="Code generation/modification"
        ),
        "trace": AgentConfig(
            name="trace",
            enabled=True,
            type="python",
            script="agents/trace_agent.py",
            description="Execution log tracking"
        )
    }

    # PRD type to agent mapping
    PRD_PIPELINE_MAP = {
        "feature": ["gate", "scan", "fold", "verdict", "patch", "trace"],
        "bug": ["gate", "scan", "fold", "verdict", "patch", "trace"],
        "refactor": ["gate", "scan", "fold", "verdict", "patch", "trace"],
        "hotfix": ["gate", "scan", "verdict", "patch", "trace"],  # Skip fold
        "experiment": ["gate", "scan", "fold", "verdict", "trace"],  # Skip patch
    }

    def __init__(self, project_root: Optional[Path] = None):
        """Initialize configurator

        Args:
            project_root: Project root path
        """
        if project_root is None:
            self.project_root = Path.cwd()
        else:
            self.project_root = Path(project_root)

    def load_mode(self) -> str:
        """Load current mode from config

        Returns:
            Current mode (solo | team)
        """
        # Try environment variable first
        env_mode = os.getenv("MONGGLE_MODE")
        if env_mode:
            return env_mode

        # Try config file
        config_file = self.project_root / "monggle.config.yaml"
        if config_file.exists():
            content = config_file.read_text()
            for line in content.split("\n"):
                if line.strip().startswith("mode:"):
                    mode = line.split(":", 1)[1].strip()
                    return mode

        # Default
        return "solo"

    def get_pipeline_for_prd(self, prd_type: str) -> PipelineConfig:
        """Get pipeline configuration for PRD type

        Args:
            prd_type: PRD type (feature, bug, refactor, hotfix, experiment)

        Returns:
            PipelineConfig for this PRD type
        """
        # Get agent names for this PRD type
        agent_names = self.PRD_PIPELINE_MAP.get(prd_type, self.PRD_PIPELINE_MAP["feature"])

        # Build agent list
        agents = []
        for name in agent_names:
            if name in self.DEFAULT_AGENTS:
                agents.append(self.DEFAULT_AGENTS[name])

        mode = self.load_mode()

        return PipelineConfig(
            prd_type=prd_type,
            agents=agents,
            mode=mode
        )

    def get_agent_script(self, agent_name: str) -> Optional[str]:
        """Get script path for agent

        Args:
            agent_name: Agent name

        Returns:
            Script path or None
        """
        agent = self.DEFAULT_AGENTS.get(agent_name)
        if agent:
            return agent.script
        return None

    def should_skip_gate(self, prd_type: str, mode: str) -> bool:
        """Check if gate should be skipped

        Args:
            prd_type: PRD type
            mode: Current mode

        Returns:
            True if gate should be skipped
        """
        # In solo mode, gate is optional for non-team work
        if mode == "solo":
            return False  # Still run gate, but make it lenient

        return False

    def get_required_sections(self, prd_type: str) -> List[str]:
        """Get required sections for PRD type

        Args:
            prd_type: PRD type

        Returns:
            List of required section names
        """
        sections_map = {
            "feature": ["Goal", "Requirements", "Edge Cases", "Testing"],
            "bug": ["Issue", "Description", "Root Cause", "Fix Plan", "Testing"],
            "refactor": ["Current", "Issues", "Proposed Changes", "Impact", "Testing"],
            "hotfix": ["Issue", "Quick Fix", "Testing"],
            "experiment": ["Hypothesis", "Test Plan", "Success Criteria"],
        }

        return sections_map.get(prd_type, [])

    def detect_prd_type_from_file(self, prd_path: Path) -> str:
        """Detect PRD type from file

        Args:
            prd_path: Path to PRD file

        Returns:
            Detected PRD type
        """
        # From filename
        filename = prd_path.name.lower()
        for prd_type in ["feature", "bug", "refactor", "hotfix", "experiment"]:
            if prd_type in filename:
                return prd_type

        # From content
        if prd_path.exists():
            content = prd_path.read_text()

            # Check YAML frontmatter
            for line in content.split("\n")[:10]:
                if "feature_type:" in line:
                    prd_type = line.split("feature_type:")[1].strip().strip('"\'')
                    return prd_type

        return "feature"  # Default


def print_pipeline_summary(config: PipelineConfig):
    """Print pipeline configuration summary

    Args:
        config: Pipeline configuration
    """
    print(f"\n{'='*60}")
    print(f"Pipeline Configuration for PRD type: {config.prd_type.upper()}")
    print(f"Mode: {config.mode.upper()}")
    print(f"{'='*60}\n")

    print("Agents to execute:")
    for i, agent in enumerate(config.agents, 1):
        status = "ENABLED" if agent.enabled else "DISABLED"
        print(f"  {i}. {agent.name} ({agent.type}) - {status}")
        print(f"     {agent.description}")

    print()


def main():
    """CLI entry point"""
    import argparse

    parser = argparse.ArgumentParser(
        description="Configure Agent Pipeline"
    )
    parser.add_argument(
        "prd_file",
        nargs="?",
        help="PRD file path (auto-detect if not provided)"
    )
    parser.add_argument(
        "--type",
        type=str,
        choices=["feature", "bug", "refactor", "hotfix", "experiment"],
        help="PRD type (auto-detect from file if not provided)"
    )
    parser.add_argument(
        "--project-root",
        type=str,
        help="Project root path (default: auto-detect)"
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output as JSON"
    )

    args = parser.parse_args()

    # Project root
    if args.project_root:
        project_root = Path(args.project_root).absolute()
    else:
        project_root = Path.cwd()

    configurator = PipelineConfigurator(project_root)

    # Determine PRD type
    if args.type:
        prd_type = args.type
    elif args.prd_file:
        prd_path = Path(args.prd_file)
        prd_type = configurator.detect_prd_type_from_file(prd_path)
    else:
        # Auto-detect from prd/ directory
        prd_dir = project_root / "prd"
        if prd_dir.exists():
            prd_files = list(prd_dir.glob("*.md"))
            if prd_files:
                # Use most recent
                latest = max(prd_files, key=lambda p: p.stat().st_mtime)
                prd_type = configurator.detect_prd_type_from_file(latest)
            else:
                prd_type = "feature"
        else:
            prd_type = "feature"

    # Get configuration
    config = configurator.get_pipeline_for_prd(prd_type)

    # Output
    if args.json:
        output = {
            "prd_type": config.prd_type,
            "mode": config.mode,
            "agents": [
                {
                    "name": a.name,
                    "enabled": a.enabled,
                    "type": a.type,
                    "script": a.script,
                    "description": a.description
                }
                for a in config.agents
            ],
            "required_sections": configurator.get_required_sections(prd_type)
        }
        print(json.dumps(output, indent=2))
    else:
        print_pipeline_summary(config)

        print("Required sections:")
        for section in configurator.get_required_sections(prd_type):
            print(f"  - {section}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
