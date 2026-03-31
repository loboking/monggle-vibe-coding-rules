#!/usr/bin/env python3
"""
Monggle Vibe Coding Rules - Agent Runner
모든 Agent를 순차적으로 실행하는 CLI
Python 3.8+ 호환
"""

import os
import sys
import json
import argparse
from pathlib import Path
from typing import Dict, Any, Optional, List
from datetime import datetime

# 프로젝트 루트를 경로에 추가
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root / "agents"))

from base_agent import BaseAgent, PRDContent, AgentResult
from scan_agent import ScanAgent
from fold_agent import FoldAgent
from verdict_agent import VerdictAgent
from patch_agent import PatchAgent
from trace_agent import TraceAgent


class AgentPipeline:
    """Agent 파이프라인 실행기"""

    # Agent 목록
    AGENTS = {
        "gate": None,  # Hook으로 처리
        "scan": ScanAgent,
        "fold": FoldAgent,
        "verdict": VerdictAgent,
        "patch": PatchAgent,
        "trace": TraceAgent,
    }

    def __init__(self, project_root: Path = None):
        """초기화 v2.4

        Args:
            project_root: 프로젝트 루트 경로
        """
        if project_root is None:
            self.project_root = Path.cwd()
        else:
            self.project_root = Path(project_root)

        self.log_dir = self.project_root / "logs"
        self.log_dir.mkdir(exist_ok=True)

        self.session_id = datetime.now().strftime("%Y%m%d-%H%M%S")
        self.results: Dict[str, Any] = {}

        # v2.4 options
        self.verbose = False
        self.retry_count = 0
        self.parallel_mode = False

    def log(self, message: str, level: str = "info"):
        """로그 출력"""
        prefix_map = {
            "info": "\033[0;36m[INFO]\033[0m",
            "warning": "\033[1;33m[WARN]\033[0m",
            "error": "\033[0;31m[ERROR]\033[0m",
            "success": "\033[0;32m[✓]\033[0m",
            "step": "\033[0;35m[→]\033[0m",
        }
        prefix = prefix_map.get(level, f"[{level}]")
        print(f"{prefix} {message}")

    def print_header(self):
        """헤더 출력 v2.4"""
        print("\n" + "=" * 60)
        print("  Vibe Coding Agent Pipeline v2.4")
        print("=" * 60 + "\n")

    def print_stage(self, stage: str, status: str):
        """스테이지 상태 출력"""
        icons = {
            "pending": "\033[1;33m○\033[0m",
            "running": "\033[0;34m◉\033[0m",
            "success": "\033[0;32m✓\033[0m",
            "error": "\033[0;31m✗\033[0m",
            "skip": "\033[1;33m−\033[0m",
        }
        icon = icons.get(status, "○")
        print(f"  {icon} {stage}")

    def run_gate(self, prd: PRDContent) -> Dict[str, Any]:
        """Gate 단계 실행 (Hook 호출)"""
        self.print_stage("gate", "running")

        hook_file = self.project_root / ".claude" / "hooks" / "pre-tool-use.sh"

        if not hook_file.exists():
            self.log("Gate hook not found, skipping", "warning")
            self.print_stage("gate", "skip")
            return {"valid": True, "verdict": "PASS"}

        # PRD 파일 경로
        prd_path = self.project_root / "prd" / f"{prd.feature_type}-temp.md"

        # Hook 실행
        import subprocess
        try:
            result = subprocess.run(
                [str(hook_file), str(prd_path)],
                capture_output=True,
                text=True,
                timeout=30
            )

            if result.returncode == 0:
                self.print_stage("gate", "success")
                return {"valid": True, "verdict": "PASS"}
            else:
                self.print_stage("gate", "error")
                return {"valid": False, "verdict": "FAIL", "error": result.stderr}

        except subprocess.TimeoutExpired:
            self.print_stage("gate", "error")
            return {"valid": False, "verdict": "FAIL", "error": "Timeout"}
        except Exception as e:
            self.print_stage("gate", "error")
            return {"valid": False, "verdict": "FAIL", "error": str(e)}

    def run_agent(self, name: str, agent_class, prd: PRDContent, context: Dict[str, Any]) -> AgentResult:
        """단일 Agent 실행 (v2.4: with retry support)"""
        self.print_stage(name, "running")

        max_attempts = self.retry_count + 1
        last_result = None

        for attempt in range(max_attempts):
            try:
                if attempt > 0:
                    self.log(f"Retry {name} (attempt {attempt + 1}/{max_attempts})", "warning")

                agent = agent_class(self.project_root)
                result = agent.execute_with_timing(prd, context)

                if result.success:
                    self.print_stage(name, "success")
                    if self.verbose and attempt > 0:
                        self.log(f"{name} succeeded after {attempt + 1} attempts", "success")
                    return result
                else:
                    last_result = result
                    if attempt < max_attempts - 1:
                        self.log(f"{name} failed: {result.error}, will retry...", "warning")

            except Exception as e:
                last_result = AgentResult(success=False, error=str(e))
                if attempt < max_attempts - 1:
                    self.log(f"Agent {name} exception: {e}, will retry...", "warning")

        # All attempts failed
        self.print_stage(name, "error")
        if self.verbose:
            self.log(f"Agent {name} failed after {max_attempts} attempts", "error")
        return last_result or AgentResult(success=False, error="Max retries exceeded")

    def run_pipeline(self, prd_path: Path, skip_gate: bool = False, skip_fold: bool = False, prd_type_override: str = None) -> bool:
        """전체 파이프라인 실행

        Args:
            prd_path: PRD 파일 경로
            skip_gate: Gate 건너뛰기
            skip_fold: Fold 건너뛰기 (hotfix mode)
            prd_type_override: PRD 타입 오버라이드

        Returns:
            bool: 성공 여부
        """
        self.print_header()

        # PRD 로드
        self.log(f"Loading PRD: {prd_path}", "step")
        try:
            prd = PRDContent.from_file(prd_path)
            if prd_type_override:
                prd.feature_type = prd_type_override
                self.log(f"PRD type override: {prd_type_override}", "info")
            else:
                self.log(f"PRD type: {prd.feature_type}", "info")
        except Exception as e:
            self.log(f"Failed to load PRD: {e}", "error")
            return False

        context = {}
        exit_code = 0

        # 1. Gate
        if not skip_gate:
            gate_result = self.run_gate(prd)
            self.results["gate"] = gate_result

            if not gate_result.get("valid", True):
                self.log("Gate validation failed", "error")
                self.print_summary(False)
                return False
        else:
            self.log("Skipping gate", "warning")
            self.results["gate"] = {"valid": True, "verdict": "PASS"}

        context["gate_result"] = self.results["gate"]

        # 2. Scan
        scan_result = self.run_agent("scan", ScanAgent, prd, context)
        self.results["scan"] = scan_result.data if scan_result.success else {}
        context["scan_result"] = self.results["scan"]

        if not scan_result.success:
            self.log("Scan failed, but continuing...", "warning")

        # 3. Fold (skip if hotfix mode)
        if skip_fold:
            self.log("Skipping fold: Hotfix mode", "warning")
            self.print_stage("fold", "skip")
            self.results["fold"] = {
                "feasibility": "High",
                "approach": "Fast-track hotfix",
                "risk_assessment": {"technical": "Low", "operational": "Low"}
            }
        else:
            fold_result = self.run_agent("fold", FoldAgent, prd, context)
            self.results["fold"] = fold_result.data if fold_result.success else {}
            context["fold_result"] = self.results["fold"]

            if not fold_result.success:
                self.log("Fold failed, but continuing...", "warning")

        # 4. Verdict
        verdict_result = self.run_agent("verdict", VerdictAgent, prd, context)
        self.results["verdict"] = verdict_result.data if verdict_result.success else {}
        context["verdict_result"] = self.results["verdict"]

        # Verdict에 따른 결과
        verdict = self.results.get("verdict", {}).get("verdict", "UNKNOWN")

        # 5. Patch (PASS인 경우만)
        if verdict == "PASS":
            patch_result = self.run_agent("patch", PatchAgent, prd, context)
            self.results["patch"] = patch_result.data if patch_result.success else {}
            context["patch_result"] = self.results["patch"]
        else:
            self.log(f"Skipping patch: Verdict is {verdict}", "warning")

        # 6. Trace (항상 실행)
        context["session_id"] = self.session_id
        trace_result = self.run_agent("trace", TraceAgent, prd, context)
        self.results["trace"] = trace_result.data if trace_result.success else {}

        # 요약 출력
        self.print_results()

        # 전체 결과 저장
        self.save_results()

        # 최종 결과
        if verdict == "PASS":
            self.print_summary(True)
            return True
        elif verdict == "FIX":
            self.log("Verdict: FIX required", "warning")
            self.print_summary(False)
            return False
        else:  # FAIL
            self.log("Verdict: FAIL", "error")
            self.print_summary(False)
            return False

    def print_results(self):
        """결과 출력"""
        print("\n" + "=" * 60)
        print("  Results")
        print("=" * 60 + "\n")

        # Verdict
        verdict_data = self.results.get("verdict", {})
        verdict = verdict_data.get("verdict", "UNKNOWN")
        confidence = verdict_data.get("confidence", 0)

        print(f"Verdict: {verdict}")
        print(f"Confidence: {confidence:.2f}")
        print(f"Reasoning: {verdict_data.get('reasoning', 'N/A')}")

        # Feedback
        feedback = verdict_data.get("feedback", [])
        if feedback:
            print("\nFeedback:")
            for fb in feedback:
                print(f"  - {fb}")

        # Scan 결과
        scan_data = self.results.get("scan", {})
        if scan_data:
            complexity = scan_data.get("complexity", "Unknown")
            affected_files = len(scan_data.get("affected_files", []))
            print(f"\nComplexity: {complexity}")
            print(f"Affected files: {affected_files}")

        # Fold 결과
        fold_data = self.results.get("fold", {})
        if fold_data:
            feasibility = fold_data.get("feasibility", "Unknown")
            approach = fold_data.get("approach", "Unknown")
            print(f"Feasibility: {feasibility}")
            print(f"Approach: {approach}")

    def print_summary(self, success: bool):
        """요약 출력"""
        print("\n" + "=" * 60)
        if success:
            print("  PIPELINE COMPLETED SUCCESSFULLY")
            print("  Ready for implementation")
        else:
            print("  PIPELINE FAILED")
            print("  Please fix the issues above")
        print("=" * 60 + "\n")

    def save_results(self):
        """결과 저장"""
        result_file = self.log_dir / f"pipeline-{self.session_id}.json"

        output_data = {
            "session_id": self.session_id,
            "timestamp": datetime.now().isoformat(),
            "results": self.results
        }

        with open(result_file, "w", encoding="utf-8") as f:
            json.dump(output_data, f, indent=2, ensure_ascii=False)

        self.log(f"Results saved: {result_file}", "info")


def main():
    """CLI 진입점 v2.4"""
    parser = argparse.ArgumentParser(
        description="Run Vibe Coding Agent Pipeline v2.4",
        epilog="""
Examples:
  %(prog)s                          # Auto-detect PRD
  %(prog)s prd/feature.md           # Specific PRD
  %(prog)s --verbose --retry 3      # Detailed logging with retry
  %(prog)s --parallel               # Parallel mode (experimental)
        """
    )
    parser.add_argument(
        "prd",
        nargs="?",
        help="PRD file path (default: auto-detect)"
    )
    parser.add_argument(
        "--skip-gate",
        action="store_true",
        help="Skip gate validation"
    )
    parser.add_argument(
        "--project-root",
        type=str,
        default=None,
        help="Project root path (default: auto-detect)"
    )
    parser.add_argument(
        "--agent",
        type=str,
        choices=["gate", "scan", "fold", "verdict", "patch", "trace"],
        help="Run only specific agent"
    )
    parser.add_argument(
        "--type",
        type=str,
        choices=["feature", "bug", "refactor", "hotfix", "experiment", "api", "migration", "ml", "devops"],
        help="Override PRD type (auto-detect from file if not provided)"
    )
    parser.add_argument(
        "--skip-fold",
        action="store_true",
        help="Skip Fold agent (for hotfix mode)"
    )
    # New in v2.4
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Enable detailed logging"
    )
    parser.add_argument(
        "--retry",
        type=int,
        default=0,
        metavar="N",
        help="Retry failed agents up to N times (default: 0)"
    )
    parser.add_argument(
        "--parallel",
        action="store_true",
        help="Run independent agents in parallel (experimental)"
    )

    args = parser.parse_args()

    # 프로젝트 루트
    if args.project_root:
        project_root = Path(args.project_root).absolute()
    else:
        project_root = Path.cwd()

    pipeline = AgentPipeline(project_root)
    pipeline.verbose = args.verbose
    pipeline.retry_count = args.retry
    pipeline.parallel_mode = args.parallel

    # PRD 파일 결정
    if args.prd:
        prd_path = Path(args.prd)
        if not prd_path.is_absolute():
            prd_path = project_root / prd_path
    else:
        # 자동 감지
        prd_dir = project_root / "prd"
        if not prd_dir.exists():
            print("Error: prd/ directory not found")
            sys.exit(1)

        prd_files = list(prd_dir.glob("*.md"))
        if not prd_files:
            print("Error: No PRD files found in prd/")
            sys.exit(1)

        # 가장 최근 파일
        prd_path = max(prd_files, key=lambda p: p.stat().st_mtime)

    print(f"Using PRD: {prd_path}")

    # 특정 Agent만 실행
    if args.agent:
        print(f"Running only: {args.agent}")
        # 단일 Agent 실행 로직
        # (간략화를 위해 전체 파이프라인만 구현)
        print("Note: Single agent mode not fully implemented, running pipeline...")

    # 전체 파이프라인 실행
    success = pipeline.run_pipeline(
        prd_path,
        skip_gate=args.skip_gate,
        skip_fold=args.skip_fold,
        prd_type_override=args.type
    )

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
