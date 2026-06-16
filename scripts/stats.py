#!/usr/bin/env python3
"""
Monggle Vibe Coding Rules - Pipeline Statistics v2.4
Track and display agent pipeline execution statistics

New in v2.4:
- ASCII visualization (bar charts, sparklines)
- Log filtering (by verdict, PRD type, agent, date)
- Web dashboard (HTML with CSS-only charts)
- Agent execution time analysis

Python 3.8+ compatible
API-free
"""

import os
import sys
import json
from pathlib import Path
from typing import Dict, Any, List, Optional, Tuple
from datetime import datetime, timedelta
from dataclasses import dataclass, field
from collections import defaultdict, Counter
import re


@dataclass
class AgentStats:
    """Statistics for a single agent"""
    name: str
    total_runs: int = 0
    successful_runs: int = 0
    failed_runs: int = 0
    total_duration_ms: int = 0
    avg_duration_ms: float = 0.0
    min_duration_ms: float = float('inf')
    max_duration_ms: int = 0
    duration_history: List[int] = field(default_factory=list)

    def update(self, duration_ms: int, success: bool):
        """Update stats with a run"""
        self.total_runs += 1
        if success:
            self.successful_runs += 1
        else:
            self.failed_runs += 1
        self.total_duration_ms += duration_ms
        self.avg_duration_ms = self.total_duration_ms / self.total_runs
        self.duration_history.append(duration_ms)
        self.min_duration_ms = min(self.min_duration_ms, duration_ms)
        self.max_duration_ms = max(self.max_duration_ms, duration_ms)


@dataclass
class VerdictStats:
    """Statistics for verdicts"""
    pass_count: int = 0
    fix_count: int = 0
    fail_count: int = 0
    history: List[Tuple[str, str]] = field(default_factory=list)  # (timestamp, verdict)

    def update(self, verdict: str, timestamp: str = ""):
        """Update stats with a verdict"""
        verdict_upper = verdict.upper()
        if verdict_upper == "PASS":
            self.pass_count += 1
        elif verdict_upper == "FIX":
            self.fix_count += 1
        elif verdict_upper == "FAIL":
            self.fail_count += 1
        if timestamp:
            self.history.append((timestamp, verdict))


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
    date_range: Tuple[datetime, datetime] = None

    def add_verdict(self, verdict: str, timestamp: str = ""):
        """Verdict 통계를 위임 기록"""
        self.verdict_stats.update(verdict, timestamp)

    def add_agent_stat(self, agent_name: str, duration_ms: int, success: bool):
        """에이전트별 통계 기록 (없으면 생성)"""
        if agent_name not in self.agent_stats:
            self.agent_stats[agent_name] = AgentStats(name=agent_name)
        self.agent_stats[agent_name].update(duration_ms, success)


class ASCIIChart:
    """ASCII chart generator"""

    @staticmethod
    def bar_chart(data: Dict[str, int], width: int = 30, max_label_len: int = 10) -> str:
        """Generate ASCII bar chart

        Args:
            data: Dictionary with labels and values
            width: Max bar width in characters
            max_label_len: Maximum label length

        Returns:
            ASCII chart string
        """
        if not data:
            return "  No data available"

        max_value = max(data.values()) if data.values() else 1
        lines = []

        for label, value in sorted(data.items(), key=lambda x: x[1], reverse=True):
            # Truncate label if needed
            display_label = label[:max_label_len].ljust(max_label_len)

            # Calculate bar length
            bar_length = int((value / max_value) * width)
            bar = "█" * bar_length

            # Value with percentage
            pct = (value / sum(data.values()) * 100) if sum(data.values()) > 0 else 0

            lines.append(f"  {display_label} │ {bar} {value} ({pct:.1f}%)")

        return "\n".join(lines)

    @staticmethod
    def sparkline(values: List[int], width: int = 20) -> str:
        """Generate ASCII sparkline

        Args:
            values: List of numeric values
            width: Output width in characters

        Returns:
            Sparkline string
        """
        if not values:
            return "▁"

        # Normalize values to 0-7 range (Unicode block elements)
        min_val = min(values)
        max_val = max(values)
        range_val = max_val - min_val if max_val != min_val else 1

        # Block elements for different heights
        blocks = ['▁', '▂', '▃', '▄', '▅', '▆', '▇', '█']

        # Sample to fit width
        if len(values) > width:
            step = len(values) / width
            sampled = [values[int(i * step)] for i in range(width)]
        else:
            sampled = values

        sparkline = ""
        for v in sampled:
            normalized = int((v - min_val) / range_val * 7)
            sparkline += blocks[normalized]

        return sparkline

    @staticmethod
    def timeline_chart(events: List[Tuple[str, str]], width: int = 40) -> str:
        """Generate ASCII timeline of verdicts

        Args:
            events: List of (timestamp, verdict) tuples
            width: Output width

        Returns:
            Timeline string
        """
        if not events:
            return "  No events"

        # Verdict colors (ANSI)
        colors = {
            "PASS": "\033[0;32m",
            "FIX": "\033[1;33m",
            "FAIL": "\033[0;31m",
            "UNKNOWN": "\033[0;36m"
        }
        reset = "\033[0m"

        # Sample to fit width
        if len(events) > width:
            step = len(events) / width
            sampled = [events[int(i * step)] for i in range(width)]
        else:
            sampled = events

        symbols = {
            "PASS": "✓",
            "FIX": "~",
            "FAIL": "✗",
            "UNKNOWN": "?"
        }

        timeline = ""
        for _, verdict in sampled:
            v_upper = verdict.upper()
            color = colors.get(v_upper, "")
            symbol = symbols.get(v_upper, "?")
            timeline += f"{color}{symbol}{reset}"

        return timeline


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
        self.filters: Dict[str, Any] = {}

    def set_filters(self, verdict: Optional[str] = None, prd_type: Optional[str] = None,
                    agent: Optional[str] = None, since: Optional[str] = None,
                    until: Optional[str] = None):
        """Set filters for log processing

        Args:
            verdict: Filter by verdict (PASS/FIX/FAIL)
            prd_type: Filter by PRD type
            agent: Filter by agent name
            since: Filter by date (ISO format)
            until: Filter by date (ISO format)
        """
        self.filters = {
            "verdict": verdict.upper() if verdict else None,
            "prd_type": prd_type.lower() if prd_type else None,
            "agent": agent.lower() if agent else None,
            "since": since,
            "until": until
        }

    def _matches_filters(self, log_data: Dict[str, Any]) -> bool:
        """Check if log entry matches filters"""
        results = log_data.get("results", {})

        # Verdict filter
        if self.filters.get("verdict"):
            verdict = str(results.get("verdict", {}).get("verdict", "UNKNOWN"))
            if verdict.upper() != self.filters["verdict"]:
                return False

        # PRD type filter
        if self.filters.get("prd_type"):
            prd_type = str(results.get("gate", {}).get("prd_type", "unknown"))
            if prd_type.lower() != self.filters["prd_type"]:
                return False

        # Date filter
        timestamp = log_data.get("timestamp", "")
        if timestamp:
            try:
                dt = datetime.fromisoformat(timestamp.replace("Z", "+00:00"))

                if self.filters.get("since"):
                    since_dt = datetime.fromisoformat(self.filters["since"])
                    if dt < since_dt:
                        return False

                if self.filters.get("until"):
                    until_dt = datetime.fromisoformat(self.filters["until"])
                    if dt > until_dt:
                        return False
            except ValueError:
                pass

        return True

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

        timestamps = []
        for log_file in log_files:
            if self._process_log_file(log_file):
                timestamps.append(log_file.stat().st_mtime)

        # Set date range
        if timestamps:
            self.stats.date_range = (
                datetime.fromtimestamp(min(timestamps)),
                datetime.fromtimestamp(max(timestamps))
            )

        return self.stats

    def _process_log_file(self, log_file: Path) -> bool:
        """Process a single log file

        Returns:
            True if file matched filters
        """
        try:
            with open(log_file, "r", encoding="utf-8") as f:
                data = json.load(f)

            # Check filters
            if not self._matches_filters(data):
                return False

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
            timestamp = data.get("timestamp", "")
            self.stats.add_verdict(verdict, timestamp)

            if verdict == "PASS":
                self.stats.successful_runs += 1

            # Agent stats from individual agent logs
            for agent_name in ["scan", "fold", "verdict", "patch", "trace"]:
                # Skip if agent filter is set and doesn't match
                if self.filters.get("agent") and agent_name != self.filters["agent"]:
                    continue

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
            self.stats.recent_runs.append({
                "session_id": data.get("session_id", ""),
                "timestamp": timestamp,
                "verdict": verdict,
                "prd_type": prd_type
            })

            return True

        except (json.JSONDecodeError, KeyError):
            return False

    def print_summary(self, verbose: bool = False):
        """Print statistics summary with visualization

        Args:
            verbose: Show detailed statistics
        """
        print(f"\n{'='*60}")
        print("  Pipeline Statistics v2.4")
        print(f"{'='*60}\n")

        # Date range
        if self.stats.date_range:
            start, end = self.stats.date_range
            print(f"Period: {start.strftime('%Y-%m-%d')} to {end.strftime('%Y-%m-%d')}")
            print()

        # Active filters
        if any(self.filters.values()):
            print("Active Filters:")
            for k, v in self.filters.items():
                if v:
                    print(f"  {k}: {v}")
            print()

        # Overall stats
        print("Overall:")
        print(f"  Total runs: {self.stats.total_runs}")
        if self.stats.total_runs > 0:
            success_rate = (self.stats.successful_runs / self.stats.total_runs) * 100
            print(f"  Successful: {self.stats.successful_runs} ({success_rate:.1f}%)")

            # Success rate sparkline
            if self.stats.verdict_stats.history:
                values = [1 if v == "PASS" else 0 for _, v in self.stats.verdict_stats.history[-20:]]
                print(f"  Trend: {ASCIIChart.sparkline(values)}")
        print()

        # Verdict distribution with bar chart
        print("Verdict Distribution:")
        verdict_data = {
            "PASS": self.stats.verdict_stats.pass_count,
            "FIX": self.stats.verdict_stats.fix_count,
            "FAIL": self.stats.verdict_stats.fail_count
        }
        if sum(verdict_data.values()) > 0:
            print(ASCIIChart.bar_chart(verdict_data))
        print()

        # Verdict timeline
        if self.stats.verdict_stats.history:
            print("Verdict Timeline (recent):")
            timeline = ASCIIChart.timeline_chart(self.stats.verdict_stats.history[-40:])
            print(f"  {timeline}")
            print()

        # PRD type distribution
        if self.stats.prd_type_counts:
            print("PRD Type Distribution:")
            print(ASCIIChart.bar_chart(self.stats.prd_type_counts))
            print()

        # Agent stats
        if self.stats.agent_stats:
            print("Agent Performance:")
            for agent_name in sorted(self.stats.agent_stats.keys()):
                agent = self.stats.agent_stats[agent_name]
                if agent.total_runs > 0:
                    success_rate = (agent.successful_runs / agent.total_runs) * 100
                    print(f"  {agent_name}:")
                    print(f"    Runs: {agent.total_runs}")
                    print(f"    Success rate: {success_rate:.1f}%")
                    print(f"    Avg duration: {agent.avg_duration_ms:.0f}ms")

                    # Duration sparkline
                    if agent.duration_history and verbose:
                        print(f"    Duration trend: {ASCIIChart.sparkline(agent.duration_history[-10:])}")

                    if verbose:
                        print(f"    Min duration: {agent.min_duration_ms}ms")
                        print(f"    Max duration: {agent.max_duration_ms}ms")
        print()

        # Recent runs
        if self.stats.recent_runs:
            print(f"Recent Runs (last {min(5, len(self.stats.recent_runs))}):")
            for run in self.stats.recent_runs[:5]:
                timestamp = run.get("timestamp", "")[:19]
                verdict = run.get("verdict", "UNKNOWN")
                prd_type = run.get("prd_type", "unknown")

                # Colorize verdict
                color = {
                    "PASS": "\033[0;32m",
                    "FIX": "\033[1;33m",
                    "FAIL": "\033[0;31m"
                }.get(verdict.upper(), "")
                reset = "\033[0m"

                print(f"  [{timestamp}] {prd_type} - {color}{verdict}{reset}")
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
                    "avg_duration_ms": agent.avg_duration_ms,
                    "min_duration_ms": agent.min_duration_ms if agent.min_duration_ms != float('inf') else 0,
                    "max_duration_ms": agent.max_duration_ms
                }
                for name, agent in self.stats.agent_stats.items()
            },
            "recent_runs": self.stats.recent_runs[:10]
        }

        return json.dumps(output, indent=2)

    def generate_web_dashboard(self, output_path: Optional[Path] = None) -> Path:
        """Generate HTML web dashboard

        Args:
            output_path: Output file path (default: logs/dashboard.html)

        Returns:
            Path to generated dashboard
        """
        if output_path is None:
            output_path = self.log_dir / "dashboard.html"

        # Prepare data
        verdict_data = [
            {"label": "PASS", "value": self.stats.verdict_stats.pass_count, "color": "#22c55e"},
            {"label": "FIX", "value": self.stats.verdict_stats.fix_count, "color": "#eab308"},
            {"label": "FAIL", "value": self.stats.verdict_stats.fail_count, "color": "#ef4444"}
        ]

        prd_type_data = [
            {"label": k, "value": v} for k, v in self.stats.prd_type_counts.items()
        ]

        agent_data = []
        for name, agent in self.stats.agent_stats.items():
            if agent.total_runs > 0:
                agent_data.append({
                    "name": name,
                    "runs": agent.total_runs,
                    "success_rate": (agent.successful_runs / agent.total_runs) * 100,
                    "avg_duration": agent.avg_duration_ms
                })

        # Generate HTML
        html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Pipeline Statistics Dashboard</title>
    <style>
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0f172a; color: #e2e8f0; }}
        .container {{ max-width: 1200px; margin: 0 auto; padding: 20px; }}
        h1 {{ text-align: center; margin-bottom: 30px; color: #38bdf8; }}
        .grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }}
        .card {{ background: #1e293b; border-radius: 12px; padding: 20px; border: 1px solid #334155; }}
        .card h2 {{ font-size: 18px; margin-bottom: 15px; color: #94a3b8; }}
        .stat-row {{ display: flex; justify-content: space-between; margin-bottom: 10px; }}
        .stat-value {{ font-weight: 600; color: #38bdf8; }}
        .bar-container {{ margin: 15px 0; }}
        .bar-label {{ display: flex; justify-content: space-between; margin-bottom: 5px; font-size: 14px; }}
        .bar {{ height: 24px; border-radius: 4px; background: #334155; overflow: hidden; }}
        .bar-fill {{ height: 100%; transition: width 0.3s; }}
        .recent-runs {{ max-height: 200px; overflow-y: auto; }}
        .run-item {{ padding: 8px; border-bottom: 1px solid #334155; font-size: 14px; }}
        .pass {{ color: #22c55e; }}
        .fix {{ color: #eab308; }}
        .fail {{ color: #ef4444; }}
        .timestamp {{ color: #64748b; font-size: 12px; }}
        .empty {{ text-align: center; color: #64748b; padding: 20px; }}
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Pipeline Statistics Dashboard</h1>

        <div class="grid">
            <!-- Overall Stats -->
            <div class="card">
                <h2>Overall Statistics</h2>
                <div class="stat-row">
                    <span>Total Runs</span>
                    <span class="stat-value">{self.stats.total_runs}</span>
                </div>
                <div class="stat-row">
                    <span>Successful</span>
                    <span class="stat-value">{self.stats.successful_runs}</span>
                </div>
                <div class="stat-row">
                    <span>Success Rate</span>
                    <span class="stat-value">{(self.stats.successful_runs / self.stats.total_runs * 100) if self.stats.total_runs > 0 else 0:.1f}%</span>
                </div>
            </div>

            <!-- Verdict Distribution -->
            <div class="card">
                <h2>Verdict Distribution</h2>
                {"".join(f'<div class="bar-container"><div class="bar-label"><span>{item["label"]}</span><span>{item["value"]}</span></div><div class="bar"><div class="bar-fill" style="width: {(item["value"] / sum(v["value"] for v in verdict_data) * 100) if sum(v["value"] for v in verdict_data) > 0 else 0}%; background: {item["color"]}"></div></div></div>' for item in verdict_data if item["value"] > 0) or '<div class="empty">No data available</div>'}
            </div>

            <!-- PRD Type Distribution -->
            <div class="card">
                <h2>PRD Type Distribution</h2>
                {"".join(f'<div class="bar-container"><div class="bar-label"><span>{item["label"]}</span><span>{item["value"]}</span></div><div class="bar"><div class="bar-fill" style="width: {(item["value"] / sum(v["value"] for v in prd_type_data) * 100) if sum(v["value"] for v in prd_type_data) > 0 else 0}%; background: #38bdf8"></div></div></div>' for item in prd_type_data) or '<div class="empty">No data available</div>'}
            </div>

            <!-- Agent Performance -->
            <div class="card">
                <h2>Agent Performance</h2>
                {"".join(f'<div class="stat-row"><span>{a["name"]}</span><span class="stat-value">{a["runs"]} runs ({a["success_rate"]:.1f}%)</span></div><div class="bar-container"><div class="bar"><div class="bar-fill" style="width: {a["success_rate"]}%; background: #22c55e"></div></div></div>' for a in agent_data) or '<div class="empty">No data available</div>'}
            </div>

            <!-- Recent Runs -->
            <div class="card" style="grid-column: 1 / -1;">
                <h2>Recent Runs</h2>
                <div class="recent-runs">
                    {"".join(f'<div class="run-item"><span class="{run.get("verdict", "unknown").lower()}">[{run.get("verdict", "UNKNOWN")}]</span> <span>{run.get("prd_type", "unknown")}</span> <span class="timestamp">{run.get("timestamp", "")[:19]}</span></div>' for run in self.stats.recent_runs[:20]) or '<div class="empty">No runs recorded</div>'}
                </div>
            </div>
        </div>

        <p style="text-align: center; margin-top: 30px; color: #64748b; font-size: 14px;">
            Last updated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
        </p>
    </div>
</body>
</html>"""

        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, "w", encoding="utf-8") as f:
            f.write(html)

        return output_path


def main():
    """CLI entry point"""
    import argparse

    parser = argparse.ArgumentParser(
        description="Show Pipeline Statistics v2.4",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  /stats                    Show basic statistics
  /stats --verbose          Show detailed statistics
  /stats --filter-verdict PASS  Show only PASS verdicts
  /stats --filter-type feature  Show only feature PRDs
  /stats --web              Generate web dashboard
  /stats --json             Export as JSON
        """
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
        "--web",
        action="store_true",
        help="Generate HTML web dashboard"
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Show detailed statistics"
    )
    parser.add_argument(
        "--clear",
        action="store_true",
        help="Clear all logs (use with caution)"
    )
    parser.add_argument(
        "--filter-verdict",
        type=str,
        choices=["PASS", "FIX", "FAIL"],
        help="Filter by verdict"
    )
    parser.add_argument(
        "--filter-type",
        type=str,
        help="Filter by PRD type (feature, bug, refactor, etc.)"
    )
    parser.add_argument(
        "--filter-agent",
        type=str,
        help="Filter by agent name"
    )
    parser.add_argument(
        "--since",
        type=str,
        help="Filter logs since date (ISO format: YYYY-MM-DD)"
    )
    parser.add_argument(
        "--until",
        type=str,
        help="Filter logs until date (ISO format: YYYY-MM-DD)"
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

    # Set filters
    collector.set_filters(
        verdict=args.filter_verdict,
        prd_type=args.filter_type,
        agent=args.filter_agent,
        since=args.since,
        until=args.until
    )

    stats = collector.collect_from_logs(limit=args.limit)

    # Output
    if args.json:
        print(collector.export_json())
    elif args.web:
        dashboard_path = collector.generate_web_dashboard()
        print(f"[SUCCESS] Web dashboard generated: {dashboard_path}")
        print(f"[INFO] Open in browser: file://{dashboard_path.absolute()}")
    else:
        collector.print_summary(verbose=args.verbose)

    return 0


if __name__ == "__main__":
    sys.exit(main())
