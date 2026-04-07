#!/usr/bin/env python3
"""
Auto Improvement System - 통계 분석으로 개선 제안 자동 생성 v2.4

하네스 방법론의 "On the Loop" 패러다임 구현:
- Guides/Sensors 데이터 분석
- 패턴 탐지 및 개선 제안 자동 생성
- 파이프라인 실행 후 자동 개선 제안 표시

사용법:
    python3 scripts/auto_improvement.py analyze
    python3 scripts/auto_improvement.py show
    python3 scripts/auto_improvement.py check [--alert-threshold critical]
"""

import json
import os
import sys
from pathlib import Path
from datetime import datetime, timedelta
from collections import defaultdict, Counter
import argparse

# stats.py의 StatsCollector를 사용하기 위해 경로 추가
SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent
sys.path.insert(0, str(SCRIPT_DIR))

try:
    from stats import StatsCollector, PipelineStats, ASCIIChart
except ImportError:
    # fallback: 간단한 StatsCollector 구현
    class StatsCollector:
        def __init__(self, project_root=None):
            self.project_root = Path(project_root) if project_root else Path.cwd()
            self.stats = PipelineStats()

        def collect_from_logs(self, limit=100):
            return self.stats

    class PipelineStats:
        def __init__(self):
            self.total_runs = 0
            self.successful_runs = 0
            self.prd_type_counts = {}
            self.agent_stats = {}
            self.verdict_stats = type('obj', (object,), {'pass_count': 0, 'fix_count': 0, 'fail_count': 0, 'history': []})()

# Paths
HARNESS_DIR = PROJECT_ROOT / ".harness"
IMPROVEMENT_LOG = HARNESS_DIR / "improvement-log.jsonl"
AGENT_METRICS = HARNESS_DIR / "metrics" / "agent-success-rate.json"
GUIDE_SENSOR_STATS = HARNESS_DIR / "metrics" / "guide-sensor-stats.json"
LOOP_DETECTION_FILE = HARNESS_DIR / "loop-detection.json"
SUGGESTIONS_FILE = HARNESS_DIR / "improvement-suggestions.json"


class ImprovementAnalyzer:
    """통계 분석으로 개선 제안 생성 (v2.4)"""

    def __init__(self, project_root=None, alert_threshold="critical"):
        """
        Args:
            project_root: 프로젝트 루트 경로
            alert_threshold: 알림 표시 임계값 (critical|major|minor|all)
        """
        self.project_root = Path(project_root) if project_root else PROJECT_ROOT
        self.alert_threshold = alert_threshold
        self.stats_collector = StatsCollector(self.project_root)

    def collect_data(self, limit=100):
        """StatsCollector를 통해 데이터 수집"""
        return self.stats_collector.collect_from_logs(limit=limit)

    def analyze_verdict_trends(self, stats):
        """Verdict 트렌드 분석"""
        suggestions = []
        verdict_stats = stats.verdict_stats
        total = verdict_stats.pass_count + verdict_stats.fix_count + verdict_stats.fail_count

        if total == 0:
            return suggestions

        pass_rate = verdict_stats.pass_count / total
        fix_rate = verdict_stats.fix_count / total
        fail_rate = verdict_stats.fail_count / total

        # 최근 10개 트렌드 분석
        recent_verdicts = [v for _, v in verdict_stats.history[-10:]]
        recent_pass_rate = recent_verdicts.count("PASS") / len(recent_verdicts) if recent_verdicts else 0

        # 1. 낮은 PASS 비율 (Critical)
        if pass_rate < 0.6:
            suggestions.append({
                "type": "sensor_addition",
                "severity": "critical",
                "observation": f"PASS 비율 {pass_rate*100:.1f}%가 매우 낮음 (전체)",
                "recommendation": "Gate Agent 검증 규칙 강화, PRD 최소 요건 사전 정의, PRD 템플릿 개선",
                "expected_impact": "불량 PRD 방지, 전반적 효율 향상",
                "metrics": {"pass_rate": pass_rate, "threshold": 0.6}
            })

        # 2. 높은 FIX 비율 (Major)
        elif fix_rate > 0.3:
            suggestions.append({
                "type": "guide_addition",
                "severity": "major",
                "observation": f"FIX 비율 {fix_rate*100:.1f}%가 높음 (30% 초과)",
                "recommendation": "PRD 템플릿에 구체적 예시 추가, 필수 섹션 명확화, PRD 가이드 문서 강화",
                "expected_impact": "초기 품질 향상, 재작업 감소",
                "metrics": {"fix_rate": fix_rate, "threshold": 0.3}
            })

        # 3. 최근 성적 저하 (Critical)
        if len(recent_verdicts) >= 5 and recent_pass_rate < 0.5:
            trend_desc = "최근 10개 실행 중 PASS 비율 저하"
            suggestions.append({
                "type": "sensor_addition",
                "severity": "critical",
                "observation": f"{trend_desc}: {recent_pass_rate*100:.1f}%",
                "recommendation": "최근 실패 원인 분석, 일관된 문제 패턴 확인, 가이드라인 재점검",
                "expected_impact": "품질 저하 방지, 신속한 문제 해결",
                "metrics": {"recent_pass_rate": recent_pass_rate}
            })

        # 4. FAIL 비율 증가 (Critical)
        if fail_rate > 0.2:
            suggestions.append({
                "type": "guide_addition",
                "severity": "critical",
                "observation": f"FAIL 비율 {fail_rate*100:.1f}%가 높음",
                "recommendation": "PRD 작성 가이드 재교육, PRD 템플릿 검증, 필수 요구사항 체크리스트 추가",
                "expected_impact": "기본 품질 보장, PRD 작성 시간 절감",
                "metrics": {"fail_rate": fail_rate}
            })

        return suggestions

    def analyze_agent_performance(self, stats):
        """에이전트 성능 분석"""
        suggestions = []

        for agent_name, agent in stats.agent_stats.items():
            if agent.total_runs == 0:
                continue

            success_rate = agent.successful_runs / agent.total_runs

            # 성공률 75% 미만 (Major)
            if success_rate < 0.75:
                suggestions.append({
                    "type": "sensor_addition",
                    "severity": "major",
                    "observation": f"{agent_name} 성공률 {success_rate*100:.1f}% 미만",
                    "recommendation": f"{agent_name} 프롬프트 개선, 입력 검증 강화, 에러 처리 로직 점검",
                    "expected_impact": f"{agent_name} 안정성 향상",
                    "metrics": {"agent": agent_name, "success_rate": success_rate}
                })

            # 평균 실행시간 10초 초과 (Minor)
            if agent.avg_duration_ms > 10000:
                suggestions.append({
                    "type": "guide_addition",
                    "severity": "minor",
                    "observation": f"{agent_name} 평균 실행시간 {agent.avg_duration_ms/1000:.1f}초",
                    "recommendation": f"{agent_name} 성능 최적화, 불필요한 처리 제거, 캐싱 고려",
                    "expected_impact": "응답 시간 단축",
                    "metrics": {"agent": agent_name, "avg_duration_ms": agent.avg_duration_ms}
                })

        return suggestions

    def analyze_loops(self):
        """루프 탐지 분석"""
        suggestions = []

        if not LOOP_DETECTION_FILE.exists():
            return suggestions

        try:
            with open(LOOP_DETECTION_FILE) as f:
                data = json.load(f)

            threshold = data.get("thresholds", {}).get("max_modifications", 5)
            loop_files = []

            for file_key, file_data in data.get("files", {}).items():
                count = file_data.get("count", 0)
                if count >= threshold:
                    loop_files.append({
                        "file": file_key,
                        "count": count,
                        "consecutive_failures": file_data.get("consecutive_failures", 0)
                    })

            if loop_files:
                suggestions.append({
                    "type": "critical",
                    "severity": "critical",
                    "observation": f"{len(loop_files)}개 파일이 루프 상태 (threshold: {threshold})",
                    "recommendation": "루프 탐지 강화, 근본 원인 분석 필요, /harness loops로 상세 확인",
                    "expected_impact": "무한 루프 방지, 리소스 절약",
                    "metrics": {"loop_files": loop_files, "threshold": threshold}
                })
        except (json.JSONDecodeError, KeyError):
            pass

        return suggestions

    def analyze_prd_types(self, stats):
        """PRD 타입 분석"""
        suggestions = []

        if not stats.prd_type_counts:
            return suggestions

        total = sum(stats.prd_type_counts.values())

        # 특정 타입 비율 분석
        for prd_type, count in stats.prd_type_counts.items():
            rate = count / total

            # bugfix 비율 40% 초과 (품질 이슈)
            if prd_type in ["bug", "hotfix"] and rate > 0.4:
                suggestions.append({
                    "type": "guide_addition",
                    "severity": "major",
                    "observation": f"버그 수정 요청 {rate*100:.1f}% (품질 이슈)",
                    "recommendation": "코드 리뷰 프로세스 강화, 테스트 커버리지 확대, linting 도구 추가",
                    "expected_impact": "버그 발생 감소, 코드 품질 향상",
                    "metrics": {"prd_type": prd_type, "rate": rate}
                })

        return suggestions

    def generate_suggestions(self, limit=100):
        """종합 개선 제안 생성"""
        stats = self.collect_data(limit)

        all_suggestions = []

        # 1. Verdict 트렌드 분석
        all_suggestions.extend(self.analyze_verdict_trends(stats))

        # 2. 에이전트 성능 분석
        all_suggestions.extend(self.analyze_agent_performance(stats))

        # 3. 루프 탐지
        all_suggestions.extend(self.analyze_loops())

        # 4. PRD 타입 분석
        all_suggestions.extend(self.analyze_prd_types(stats))

        # 중복 제거 (observation 기준)
        seen = set()
        unique_suggestions = []
        for s in all_suggestions:
            key = (s["type"], s["observation"])
            if key not in seen:
                seen.add(key)
                unique_suggestions.append(s)

        return unique_suggestions, stats

    def should_alert(self, suggestions):
        """알림 표시 여부 확인"""
        threshold_order = {"critical": 3, "major": 2, "minor": 1, "info": 0}
        min_threshold = threshold_order.get(self.alert_threshold, 0)

        for s in suggestions:
            severity = s.get("severity", "minor")
            if threshold_order.get(severity, 0) >= min_threshold:
                return True, s

        return False, None

    def save_suggestions(self, suggestions, output_file=None):
        """제안 저장"""
        if output_file is None:
            output_file = SUGGESTIONS_FILE

        output_file = Path(output_file)
        output_file.parent.mkdir(parents=True, exist_ok=True)

        output_data = {
            "generated_at": datetime.now().isoformat(),
            "suggestions": suggestions,
            "count": len(suggestions),
            "alert_threshold": self.alert_threshold
        }

        with open(output_file, 'w') as f:
            json.dump(output_data, f, indent=2)

        return output_file

    def print_summary(self, suggestions, show_alerts_only=False):
        """요약 출력"""
        print(f"\n{'='*60}")
        print("🔍 Auto Improvement Analysis")
        print(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"{'='*60}\n")

        if not suggestions:
            print("✅ No improvement suggestions at this time.")
            print("   System is performing within acceptable parameters.")
            return False

        # 필터링
        if show_alerts_only:
            threshold_order = {"critical": 3, "major": 2, "minor": 1, "info": 0}
            min_threshold = threshold_order.get(self.alert_threshold, 3)
            filtered = [s for s in suggestions if threshold_order.get(s.get("severity", "minor"), 0) >= min_threshold]

            if not filtered:
                print(f"✅ No {self.alert_threshold}+ level alerts.")
                return False

            suggestions = filtered

        # 심각도별 그룹화
        by_severity = {"critical": [], "major": [], "minor": [], "info": []}
        for s in suggestions:
            severity = s.get("severity", "minor")
            by_severity[severity].append(s)

        # Critical (🔴)
        if by_severity["critical"]:
            print("🔴 CRITICAL (즉시 조치 필요):")
            for s in by_severity["critical"]:
                print(f"  • {s['recommendation']}")
                print(f"    └─ {s['observation']}")
            print()

        # Major (🟡)
        if by_severity["major"]:
            print("🟡 MAJOR (개선 권장):")
            for s in by_severity["major"]:
                print(f"  • {s['recommendation']}")
                print(f"    └─ {s['observation']}")
            print()

        # Minor (🟢)
        if by_severity["minor"] and not show_alerts_only:
            print("🟢 MINOR (점검 필요):")
            for s in by_severity["minor"]:
                print(f"  • {s['recommendation']}")
            print()

        print(f"Total: {len(suggestions)} suggestion(s)")
        return True

    def add_to_log(self, suggestion):
        """개선 로그에 추가"""
        entry = {
            "timestamp": datetime.now().isoformat(),
            "type": suggestion.get("type", "custom"),
            "agent": "auto_improvement",
            "severity": suggestion.get("severity", "minor"),
            "observation": suggestion.get("observation", ""),
            "recommendation": suggestion.get("recommendation", ""),
            "expected_impact": suggestion.get("expected_impact", "TBD"),
            "metrics": suggestion.get("metrics", {})
        }

        with open(IMPROVEMENT_LOG, 'a') as f:
            f.write(json.dumps(entry) + "\n")


def show_saved_suggestions():
    """저장된 제안 표시"""
    if not SUGGESTIONS_FILE.exists():
        print("No suggestions found. Run 'analyze' first.")
        return

    with open(SUGGESTIONS_FILE) as f:
        data = json.load(f)

    print(f"\n{'='*60}")
    print("📋 Improvement Suggestions")
    print(f"Generated: {data['generated_at']}")
    print(f"{'='*60}\n")

    suggestions = data.get("suggestions", [])

    if not suggestions:
        print("✅ No improvement suggestions.")
        return

    by_severity = {"critical": [], "major": [], "minor": [], "info": []}
    for s in suggestions:
        severity = s.get("severity", "minor")
        by_severity[severity].append(s)

    for severity in ["critical", "major", "minor"]:
        items = by_severity[severity]
        if items:
            icon = {"critical": "🔴", "major": "🟡", "minor": "🟢"}[severity]
            print(f"{icon} {severity.upper()} ({len(items)}):")
            for item in items:
                print(f"  • {item['recommendation']}")
            print()


def main():
    parser = argparse.ArgumentParser(
        description="Auto Improvement System v2.4 - Harness On-the-Loop",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 auto_improvement.py analyze              # 전체 분석
  python3 auto_improvement.py analyze --alert major  # major+ 알림만
  python3 auto_improvement.py check               # 알림 여부만 확인 (exit code)
  python3 auto_improvement.py show                # 저장된 제안 표시
        """
    )

    subparsers = parser.add_subparsers(dest="command", help="Available commands")

    # Analyze command
    analyze_parser = subparsers.add_parser("analyze", help="Analyze and generate suggestions")
    analyze_parser.add_argument("--project-root", help="Project root path")
    analyze_parser.add_argument("--limit", type=int, default=100, help="Logs to process")
    analyze_parser.add_argument("--output", help="Output file")
    analyze_parser.add_argument("--alert", choices=["critical", "major", "minor", "all"],
                               default="critical", help="Alert threshold")
    analyze_parser.add_argument("--quiet", "-q", action="store_true",
                               help="Only print if alerts found")
    analyze_parser.add_argument("--auto-log", action="store_true",
                               help="Automatically add to improvement log")

    # Check command (for CI/CD integration)
    check_parser = subparsers.add_parser("check", help="Check for alerts (exit code based)")
    check_parser.add_argument("--alert", choices=["critical", "major", "minor"],
                             default="critical", help="Alert threshold")

    # Show command
    subparsers.add_parser("show", help="Show saved suggestions")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return 0

    if args.command == "check":
        # CI/CD 모드: 알림 여부만 확인
        analyzer = ImprovementAnalyzer(alert_threshold=args.alert)
        suggestions, _ = analyzer.generate_suggestions()
        has_alert, alert = analyzer.should_alert(suggestions)

        if has_alert:
            print(f"ALERT: {alert['severity']} - {alert['recommendation']}", file=sys.stderr)
            return 1
        return 0

    elif args.command == "show":
        show_saved_suggestions()
        return 0

    elif args.command == "analyze":
        analyzer = ImprovementAnalyzer(
            project_root=args.project_root,
            alert_threshold=args.alert
        )

        suggestions, stats = analyzer.generate_suggestions(limit=args.limit)

        # 저장
        output_file = args.output or SUGGESTIONS_FILE
        analyzer.save_suggestions(suggestions, output_file)

        # 출력
        has_alerts = analyzer.print_summary(suggestions, show_alerts_only=args.quiet)

        # 자동 로그 추가
        if args.auto_log and suggestions:
            for s in suggestions:
                analyzer.add_to_log(s)

        # 종료 코드 (CI/CD 연동)
        if has_alerts and args.alert in ["critical", "major"]:
            return 1
        return 0


if __name__ == "__main__":
    sys.exit(main())
