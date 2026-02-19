#!/usr/bin/env python3
"""
Monggle Vibe Coding Rules - Trace Agent
모든 Agent의 실행 로그를 기록하고 추적합니다.
Python 3.8+ 호환
"""

import json
from pathlib import Path
from typing import Dict, Any, List, Optional
from dataclasses import dataclass, field
from datetime import datetime

from base_agent import BaseAgent, PRDContent, AgentResult


@dataclass
class TimelineEntry:
    """타임라인 엔트리"""
    step: int
    agent: str
    status: str
    duration_ms: int
    timestamp: str
    input_data: Dict[str, Any] = field(default_factory=dict)
    output_data: Dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "step": self.step,
            "agent": self.agent,
            "status": self.status,
            "duration_ms": self.duration_ms,
            "timestamp": self.timestamp,
            "input": self.input_data,
            "output": self.output_data
        }


@dataclass
class AgentPerformance:
    """Agent 성과"""
    agent: str
    duration_ms: int
    status: str

    def to_dict(self) -> Dict[str, Any]:
        return {
            "agent": self.agent,
            "duration_ms": self.duration_ms,
            "status": self.status
        }


class TraceAgent(BaseAgent):
    """Trace Agent - 실행 로그 기록 및 추적"""

    name = "trace"
    description = "Log and track all agent executions"

    # 성공 기준
    MAX_TOTAL_DURATION_SEC = 30
    MAX_AGENT_DURATION_MS = 5000

    def __init__(self, project_root: Optional["Path"] = None):
        super().__init__(project_root)

    def execute(self, prd: PRDContent, context: Dict[str, Any] = None) -> AgentResult:
        """Trace Agent 실행

        Args:
            prd: 파싱된 PRD
            context: 모든 Agent 결과 포함

        Returns:
            AgentResult: 추적 결과
        """
        self.log("Starting trace logging...", "step")

        context = context or {}

        # 각 Agent 결과 수집
        agent_logs = self._collect_agent_logs(context)

        # 타임라인 생성
        timeline = self._create_timeline(agent_logs)

        # 성과 분석
        agent_performance = self._analyze_performance(agent_logs)

        # 요약 작성
        summary = self._create_summary(agent_logs, timeline)

        # 성능 분석
        recommendations = self._generate_recommendations(agent_performance, summary)

        result_data = {
            "session_id": context.get("session_id", datetime.now().strftime("%Y%m%d-%H%M%S")),
            "timeline": [t.to_dict() for t in timeline],
            "agent_performance": [p.to_dict() for p in agent_performance],
            "summary": summary,
            "recommendations": recommendations
        }

        # 로그 파일 저장
        self._save_trace_log(result_data)

        return AgentResult(success=True, data=result_data)

    def _collect_agent_logs(self, context: Dict[str, Any]) -> List[Dict[str, Any]]:
        """각 Agent 로그 수집"""
        logs = []

        # Gate
        gate_result = context.get("gate_result", {})
        if gate_result:
            logs.append({
                "agent": "gate",
                "result": gate_result,
                "duration_ms": gate_result.get("duration_ms", 100)
            })

        # Scan
        scan_result = context.get("scan_result", {})
        if scan_result:
            logs.append({
                "agent": "scan",
                "result": scan_result,
                "duration_ms": scan_result.get("duration_ms", 500)
            })

        # Fold
        fold_result = context.get("fold_result", {})
        if fold_result:
            logs.append({
                "agent": "fold",
                "result": fold_result,
                "duration_ms": fold_result.get("duration_ms", 200)
            })

        # Verdict
        verdict_result = context.get("verdict_result", {})
        if verdict_result:
            logs.append({
                "agent": "verdict",
                "result": verdict_result,
                "duration_ms": verdict_result.get("duration_ms", 100)
            })

        # Patch
        patch_result = context.get("patch_result", {})
        if patch_result:
            logs.append({
                "agent": "patch",
                "result": patch_result,
                "duration_ms": patch_result.get("duration_ms", 1000)
            })

        return logs

    def _create_timeline(self, agent_logs: List[Dict[str, Any]]) -> List[TimelineEntry]:
        """타임라인 생성"""
        timeline = []
        current_time = datetime.now()

        for step, log in enumerate(agent_logs, start=1):
            agent = log["agent"]
            result = log["result"]
            duration_ms = log.get("duration_ms", 0)

            # 상태 결정
            if result.get("valid", result.get("success", True)):
                status = "success"
            else:
                status = "failed"

            entry = TimelineEntry(
                step=step,
                agent=agent,
                status=status,
                duration_ms=duration_ms,
                timestamp=current_time.isoformat(),
                input_data={},  # 간소화
                output_data=result
            )

            timeline.append(entry)

        return timeline

    def _analyze_performance(self, agent_logs: List[Dict[str, Any]]) -> List[AgentPerformance]:
        """성과 분석"""
        performance = []

        for log in agent_logs:
            agent = log["agent"]
            result = log["result"]
            duration_ms = log.get("duration_ms", 0)

            # 상태 결정
            if result.get("valid", result.get("success", True)):
                status = "success"
            else:
                status = "failed"

            performance.append(AgentPerformance(
                agent=agent,
                duration_ms=duration_ms,
                status=status
            ))

        return performance

    def _create_summary(
        self,
        agent_logs: List[Dict[str, Any]],
        timeline: List[TimelineEntry]
    ) -> Dict[str, Any]:
        """요약 작성"""
        # 총 소요 시간
        total_duration_ms = sum(log.get("duration_ms", 0) for log in agent_logs)

        # 상태
        verdict_result = next(
            (log["result"] for log in agent_logs if log["agent"] == "verdict"),
            {}
        )
        verdict = verdict_result.get("verdict", "UNKNOWN")

        # Patch 반복 횟수
        patch_result = next(
            (log["result"] for log in agent_logs if log["agent"] == "patch"),
            {}
        )
        iterations = patch_result.get("iterations", 0)

        return {
            "total_duration_ms": total_duration_ms,
            "total_duration_sec": round(total_duration_ms / 1000, 2),
            "status": "success" if verdict == "PASS" else "failed",
            "verdict": verdict,
            "iterations": iterations,
            "agents_executed": len(agent_logs)
        }

    def _generate_recommendations(
        self,
        performance: List[AgentPerformance],
        summary: Dict[str, Any]
    ) -> List[str]:
        """개선 권장사항 생성"""
        recommendations = []

        # 총 소요 시간
        total_sec = summary.get("total_duration_sec", 0)
        if total_sec > self.MAX_TOTAL_DURATION_SEC:
            recommendations.append(
                f"전체 파이프라인이 {total_sec}초 소요되었습니다. 최적화 고려하세요."
            )

        # 느린 Agent
        for perf in performance:
            if perf.duration_ms > self.MAX_AGENT_DURATION_MS:
                recommendations.append(
                    f"{perf.agent} Agent가 {perf.duration_ms}ms 소요되었습니다. 최적화를 권장합니다."
                )

        # Patch 반복
        iterations = summary.get("iterations", 0)
        if iterations > 3:
            recommendations.append(
                f"Patch가 {iterations}회 반복되었습니다. PRD를 더 명확히 작성하면 효율이 상승합니다."
            )

        # 성공 시
        if summary.get("status") == "success":
            recommendations.append("파이프라인이 성공적으로 완료되었습니다.")

        return recommendations

    def _save_trace_log(self, result_data: Dict[str, Any]):
        """추적 로그 저장"""
        session_id = result_data.get("session_id", datetime.now().strftime("%Y%m%d-%H%M%S"))
        log_file = self.log_dir / f"trace-{session_id}.json"

        with open(log_file, "w", encoding="utf-8") as f:
            json.dump(result_data, f, indent=2, ensure_ascii=False)

        self.log(f"Trace log saved: {log_file}", "info")


# CLI 인터페이스
def main():
    """CLI 진입점"""
    import sys
    from pathlib import Path

    if len(sys.argv) < 2:
        print("Usage: python trace_agent.py <session_id> [results.json]")
        sys.exit(1)

    session_id = sys.argv[1]

    # 결과 로드
    context = {"session_id": session_id}
    if len(sys.argv) > 2:
        try:
            with open(sys.argv[2], "r") as f:
                results = json.load(f)
                context.update(results)
        except Exception:
            pass

    agent = TraceAgent()

    # 빈 PRD (Trace는 PRD가 필요 없음)
    prd = PRDContent.from_content("# Trace\n\nTrace log.")

    result = agent.execute_with_timing(prd, context)

    print("\n=== Trace Result ===")
    print(json.dumps(result.data, indent=2, ensure_ascii=False))
    print(f"\nDuration: {result.duration_ms}ms")

    sys.exit(0 if result.success else 1)


if __name__ == "__main__":
    main()
