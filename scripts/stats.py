#!/usr/bin/env python3
"""
Monggle Vibe Coding Rules - Pipeline Statistics
Track and display agent pipeline execution statistics

Python 3.8+ compatible
API-free
"""

import os
import sys
import json
from pathlib import Path
from typing import Dict, Any, List, Optional
from datetime import datetime, timedelta
from dataclasses import dataclass, field
from collections import defaultdict, Counter


@dataclass
class AgentStats:
    """Statistics for a single agent"""
    name: str
    total_runs: int = 0
    successful_runs: int = 0
    failed_runs: int = 0
    total_duration_ms: int = 0
    avg_duration_ms: float = 0.0

    def update(self, duration_ms: int, success: bool):
        """Update stats with a run"""
        self.total_runs += 1
        if success:
            self.successful_runs += 1
        else:
            self.failed_runs += 1
        self.total_duration_ms += duration_ms
        self.avg_duration_ms = self.total_duration_ms / self.total_runs


@dataclass
class VerdictStats:
    """Statistics for verdicts"""
    pass_count: int = 0
    fix_count: int = 0
    fail_count: int = 0

    def update(self, verdict: str):
        """Update stats with a verdict"""
        verdict_upper = verdict.upper()
        if verdict_upper == "PASS":
            self.pass_count += 1
        elif verdict_upper == "FIX":
            self.fix_count += 1
        elif verdict_upper == "FAIL":
            self.fail_count += 1


@dataclass
class PipelineStats:
    """Overall pipeline statistics"""
    total_runs: int = 0
    successful_runs: int = 0
    prd_type_counts: Dict[str, int] = field(default_factory=dict)
    agent_stats: Dict[str, AgentStats] = field(default_factory=dict)
    verdict_stats: VerdictStats = field(default_factory=VerdictStats)
    duration_by_prd_type: Dict[str, List[int]] = field(default_factory=lambda: defaultdict(list))
    recent_runs: List[Dict[str, Any]] = field(default_factory=list)

    def add_agent_stat(self, agent_name: str, duration_ms: int, success: bool):
        """Add agent run statistics"""
        if agent_name not in self.agent_stats:
            self.agent_stats[agent_name] = AgentStats(name=agent_name)

        self.agent_stats[agent_name].update(duration_ms, success)

    def add_verdict(self, verdict: str):
        """Add verdict statistics"""
        self.verdict_stats.update(verdict)


class StatsCollector:
    """Collect and analyze pipeline statistics"""

    def __init__(self, project_root: Optional[Path] = None):
        """Initialize collector

        Args:
            project_root: Project root path
        """
        if project_root is None:
            self.project_root = Path.cwd()
        else:
            self.project_root = Path(project_root)

        self.log_dir = self.project_root / "logs"
        self.stats = PipelineStats()

    def collect_from_logs(self, limit: int = 100) -> PipelineStats:
        """Collect statistics from log files

        Args:
            limit: Maximum number of recent logs to process

        Returns:
            PipelineStats object
        """
        if not self.log_dir.exists():
            return self.stats

        # Find all pipeline log files
        log_files = sorted(
            self.log_dir.glob("pipeline-*.json"),
            key=lambda p: p.stat().st_mtime,
            reverse=True
        )[:limit]

        for log_file in log_files:
            self._process_log_file(log_file)

        return self.stats

    def _process_log_file(self, log_file: Path):
        """Process a single log file"""
        try:
            with open(log_file, "r", encoding="utf-8") as f:
                data = json.load(f)

            # Update total runs
            self.stats.total_runs += 1

            # Get PRD type if available
            results = data.get("results", {})
            gate_result = results.get("gate", {})
            verdict_result = results.get("verdict", {})

            # PRD type from gate or filename
            prd_type = gate_result.get("prd_type", "unknown")
            if prd_type != "unknown":
                self.stats.prd_type_counts[prd_type] = \
                    self.stats.prd_type_counts.get(prd_type, 0) + 1

            # Verdict
            verdict = verdict_result.get("verdict", "UNKNOWN")
            self.stats.add_verdict(verdict)

            if verdict == "PASS":
                self.stats.successful_runs += 1

            # Agent stats from individual agent logs
            for agent_name in ["scan", "fold", "verdict", "patch", "trace"]:
                agent_log_file = self.log_dir / f"agent-{agent_name}-{data.get('session_id', '')}.json"

                if agent_log_file.exists():
                    try:
                        with open(agent_log_file, "r") as af:
                            agent_data = json.load(af)

                        result = agent_data.get("result", {})
                        duration_ms = result.get("duration_ms", 0)
                        success = result.get("success", False)

                        self.stats.add_agent_stat(agent_name, duration_ms, success)

                    except (json.JSONDecodeError, KeyError):
                        pass

            # Recent run info
            timestamp = data.get("timestamp", "")
            self.stats.recent_runs.append({
                "session_id": data.get("session_id", ""),
                "timestamp": timestamp,
                "verdict": verdict,
                "prd_type": prd_type
            })

        except (json.JSONDecodeError, KeyError):
            pass

    def print_summary(self):
        """Print statistics summary"""
        print(f"\n{'='*60}")
        print("  Pipeline Statistics")
        print(f"{'='*60}\n")

        # Overall stats
        print("Overall:")
        print(f"  Total runs: {self.stats.total_runs}")
        success_rate = 0
        if self.stats.total_runs > 0:
            success_rate = (self.stats.successful_runs / self.stats.total_runs) * 100
        print(f"  Successful: {self.stats.successful_runs} ({success_rate:.1f}%)")

        # Verdict distribution
        print("\nVerdict Distribution:")
        total_verdicts = (
            self.stats.verdict_stats.pass_count +
            self.stats.verdict_stats.fix_count +
            self.stats.verdict_stats.fail_count
        ) or 1

        print(f"  PASS: {self.stats.verdict_stats.pass_count} ({self.stats.verdict_stats.pass_count * 100 / total_verdicts:.1f}%)")
        print(f"  FIX:  {self.stats.verdict_stats.fix_count} ({self.stats.verdict_stats.fix_count * 100 / total_verdicts:.1f}%)")
        print(f"  FAIL: {self.stats.verdict_stats.fail_count} ({self.stats.verdict_stats.fail_count * 100 / total_verdicts:.1f}%)")

        # PRD type distribution
        if self.stats.prd_type_counts:
            print("\nPRD Type Distribution:")
            for prd_type, count in sorted(self.stats.prd_type_counts.items(), key=lambda x: x[1], reverse=True):
                print(f"  {prd_type}: {count}")

        # Agent stats
        if self.stats.agent_stats:
            print("\nAgent Performance:")
            for agent_name in sorted(self.stats.agent_stats.keys()):
                agent = self.stats.agent_stats[agent_name]
                if agent.total_runs > 0:
                    success_rate = (agent.successful_runs / agent.total_runs) * 100
                    print(f"  {agent_name}:")
                    print(f"    Runs: {agent.total_runs}")
                    print(f"    Success rate: {success_rate:.1f}%")
                    print(f"    Avg duration: {agent.avg_duration_ms:.0f}ms")

        # Recent runs
        if self.stats.recent_runs:
            print(f"\nRecent Runs (last {min(5, len(self.stats.recent_runs))}):")
            for run in self.stats.recent_runs[:5]:
                timestamp = run.get("timestamp", "")[:19]  # Truncate microseconds
                verdict = run.get("verdict", "UNKNOWN")
                prd_type = run.get("prd_type", "unknown")
                print(f"  [{timestamp}] {prd_type} - {verdict}")

        print()

    def export_json(self) -> str:
        """Export statistics as JSON

        Returns:
            JSON string
        """
        output = {
            "total_runs": self.stats.total_runs,
            "successful_runs": self.stats.successful_runs,
            "prd_type_counts": self.stats.prd_type_counts,
            "verdict_stats": {
                "pass": self.stats.verdict_stats.pass_count,
                "fix": self.stats.verdict_stats.fix_count,
                "fail": self.stats.verdict_stats.fail_count
            },
            "agent_stats": {
                name: {
                    "total_runs": agent.total_runs,
                    "successful_runs": agent.successful_runs,
                    "failed_runs": agent.failed_runs,
                    "avg_duration_ms": agent.avg_duration_ms
                }
                for name, agent in self.stats.agent_stats.items()
            },
            "recent_runs": self.stats.recent_runs[:10]
        }

        return json.dumps(output, indent=2)


def main():
    """CLI entry point"""
    import argparse

    parser = argparse.ArgumentParser(
        description="Show Pipeline Statistics"
    )
    parser.add_argument(
        "--project-root",
        type=str,
        help="Project root path (default: auto-detect)"
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=100,
        help="Number of recent logs to process (default: 100)"
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output as JSON"
    )
    parser.add_argument(
        "--clear",
        action="store_true",
        help="Clear all logs (use with caution)"
    )

    args = parser.parse_args()

    # Project root
    if args.project_root:
        project_root = Path(args.project_root).absolute()
    else:
        project_root = Path.cwd()

    # Clear logs?
    if args.clear:
        log_dir = project_root / "logs"
        if log_dir.exists():
            # Confirm
            response = input(f"Clear all logs in {log_dir}? (yes/NO): ")
            if response.lower() == "yes":
                for log_file in log_dir.glob("*.json"):
                    log_file.unlink()
                print("[SUCCESS] All logs cleared")
                return 0
            else:
                print("[INFO] Cancelled")
                return 0
        else:
            print("[INFO] No logs to clear")
            return 0

    # Collect stats
    collector = StatsCollector(project_root)
    stats = collector.collect_from_logs(limit=args.limit)

    # Output
    if args.json:
        print(collector.export_json())
    else:
        collector.print_summary()

    return 0


if __name__ == "__main__":
    sys.exit(main())
