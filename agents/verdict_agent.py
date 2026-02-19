#!/usr/bin/env python3
"""
Monggle Vibe Coding Rules - Verdict Agent
Gate, Scan, Fold의 결과를 종합하여 최종 판정 (PASS/FIX/FAIL)
Python 3.8+ 호환
"""

from typing import Dict, Any, List, Optional, Tuple
from dataclasses import dataclass, field
from enum import Enum

from base_agent import BaseAgent, PRDContent, AgentResult


class Verdict(Enum):
    """최종 판정"""
    PASS = "PASS"
    FIX = "FIX"
    FAIL = "FAIL"


@dataclass
class VerdictCondition:
    """수정 조건 (FIX인 경우)"""
    section: str
    requirement: str
    priority: int = 1

    def to_dict(self) -> Dict[str, Any]:
        return {
            "section": self.section,
            "requirement": self.requirement,
            "priority": self.priority
        }


@dataclass
class NextStep:
    """다음 단계"""
    action: str
    description: str
    agent: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        result = {
            "action": self.action,
            "description": self.description
        }
        if self.agent:
            result["agent"] = self.agent
        return result


class VerdictAgent(BaseAgent):
    """Verdict Agent - 최종 판정"""

    name = "verdict"
    description = "Make final decision (PASS/FIX/FAIL)"

    # 판정 기준
    PASS_MIN_CONFIDENCE = 0.9
    FIX_MIN_CONFIDENCE = 0.5

    def __init__(self, project_root: Optional["Path"] = None):
        super().__init__(project_root)

    def execute(self, prd: PRDContent, context: Dict[str, Any] = None) -> AgentResult:
        """Verdict Agent 실행

        Args:
            prd: 파싱된 PRD
            context: gate_result, scan_result, fold_result 포함

        Returns:
            AgentResult: 최종 판정 결과
        """
        self.log("Starting verdict analysis...", "step")

        context = context or {}

        # 각 Agent 결과 수집
        gate_result = context.get("gate_result", {})
        scan_result = context.get("scan_result", {})
        fold_result = context.get("fold_result", {})

        # 1. Gate 검증 (1순위)
        gate_valid = gate_result.get("valid", True)
        if not gate_valid:
            # Gate 실패 = 전체 FAIL
            return self._create_fail_result(
                "PRD 유효성 검사에 실패했습니다",
                gate_result.get("missing_sections", ["Unknown"])
            )

        # 2. 결과 종합 및 판정
        verdict, confidence, reasoning = self._make_verdict(
            gate_result, scan_result, fold_result
        )

        # 3. 피드백 생성
        feedback = self._generate_feedback(verdict, gate_result, scan_result, fold_result)

        # 4. 조건 생성 (FIX인 경우)
        conditions = []
        if verdict == Verdict.FIX:
            conditions = self._generate_fix_conditions(
                gate_result, scan_result, fold_result
            )

        # 5. 다음 단계
        next_steps = self._generate_next_steps(verdict, conditions)

        result_data = {
            "verdict": verdict.value,
            "confidence": confidence,
            "reasoning": reasoning,
            "feedback": feedback,
            "conditions": [c.to_dict() for c in conditions],
            "next_steps": [s.to_dict() for s in next_steps]
        }

        return AgentResult(success=True, data=result_data)

    def _create_fail_result(self, reasoning: str, missing_sections: List[str]) -> AgentResult:
        """FAIL 결과 생성"""
        return AgentResult(
            success=True,
            data={
                "verdict": Verdict.FAIL.value,
                "confidence": 0.95,
                "reasoning": reasoning,
                "feedback": [
                    f"필수 섹션이 누락되었습니다: {', '.join(missing_sections)}",
                    "PRD를 수정한 후 다시 제출하세요."
                ],
                "conditions": [],
                "next_steps": [
                    {
                        "action": "fix_prd",
                        "description": f"누락된 섹션을 보완하세요: {', '.join(missing_sections)}"
                    }
                ]
            }
        )

    def _make_verdict(
        self,
        gate_result: Dict[str, Any],
        scan_result: Dict[str, Any],
        fold_result: Dict[str, Any]
    ) -> Tuple[Verdict, float, str]:
        """최종 판정 결정

        Returns:
            Tuple[Verdict, confidence, reasoning]
        """
        self.log("Making verdict...", "step")

        # 점수 계산
        score = 0
        reasons = []

        # Gate 점수 (최대 30점)
        gate_score = 30
        if gate_result.get("valid"):
            reasons.append("PRD 유효성 검사 통과")
        else:
            gate_score = 0
            reasons.append("PRD 유효성 검사 실패")

        # Scan 점수 (최대 40점)
        scan_score = 40
        complexity = scan_result.get("complexity", "Medium")
        conflicts = scan_result.get("conflicts", [])

        if complexity == "Low":
            scan_score = 40
            reasons.append("복잡도 낮음")
        elif complexity == "Medium":
            scan_score = 30
            reasons.append("복잡도 중간")
        else:  # High
            scan_score = 15
            reasons.append("복잡도 높음")

        # 충돌 감점
        scan_score -= len(conflicts) * 5
        if conflicts:
            reasons.append(f"{len(conflicts)}개의 충돌 발견")

        # Fold 점수 (최대 30점)
        fold_score = 30
        feasibility = fold_result.get("feasibility", "Medium")
        blockers = fold_result.get("blockers", [])

        if feasibility == "High":
            fold_score = 30
            reasons.append("구현 가능성 높음")
        elif feasibility == "Medium":
            fold_score = 20
            reasons.append("구현 가능성 중간")
        else:  # Low
            fold_score = 5
            reasons.append("구현 가능성 낮음")

        # 차단 요소 감점
        fold_score -= len(blockers) * 10
        if blockers:
            reasons.append(f"{len(blockers)}개의 차단 요소")

        # 총점
        total_score = gate_score + scan_score + fold_score

        # 확신도 계산 (0.0 ~ 1.0)
        confidence = min(1.0, total_score / 100)

        # 판정 결정
        if total_score >= 80:
            return Verdict.PASS, confidence, "모든 기준 충족, 즉시 구현 가능"
        elif total_score >= 50:
            return Verdict.FIX, confidence, "일부 수정 필요 후 구현 가능"
        else:
            return Verdict.FAIL, confidence, "현재 상태로는 구현 불가능"

    def _generate_feedback(
        self,
        verdict: Verdict,
        gate_result: Dict[str, Any],
        scan_result: Dict[str, Any],
        fold_result: Dict[str, Any]
    ) -> List[str]:
        """피드백 생성"""
        feedback = []

        if verdict == Verdict.PASS:
            feedback.extend([
                "PRD의 모든 필수 섹션이 포함되어 있습니다.",
                "구현 가능성이 높습니다.",
                "즉시 구현을 시작할 수 있습니다."
            ])

            # 추가 통계
            if scan_result.get("estimates"):
                estimates = scan_result["estimates"]
                feedback.append(
                    f"예상 작업 시간: {estimates.get('estimated_hours', 0)}시간"
                )

        elif verdict == Verdict.FIX:
            # 누락된 섹션
            missing = gate_result.get("missing_sections", [])
            if missing:
                feedback.append(f"누락된 섹션: {', '.join(missing)}")

            # 충돌
            conflicts = scan_result.get("conflicts", [])
            if conflicts:
                feedback.append(f"발견된 충돌: {len(conflicts)}개")
                for conflict in conflicts[:3]:  # 최대 3개
                    feedback.append(f"  - {conflict}")

            # 차단 요소
            blockers = fold_result.get("blockers", [])
            if blockers:
                feedback.append(f"차단 요소: {len(blockers)}개")
                for blocker in blockers[:3]:  # 최대 3개
                    feedback.append(f"  - {blocker}")

            # 위험도
            risk = fold_result.get("risk_assessment", {})
            if any(risk.get(v) == "High" for v in ["technical", "operational", "security"]):
                feedback.append("높은 위험도가 감지되었습니다. 신중한 접근이 필요합니다.")

        else:  # FAIL
            feedback.extend([
                "요구사항이 모호하거나 충돌합니다.",
                "현재 리소스로는 구현이 불가능할 수 있습니다.",
                "요구사항을 재검토하세요."
            ])

        return feedback

    def _generate_fix_conditions(
        self,
        gate_result: Dict[str, Any],
        scan_result: Dict[str, Any],
        fold_result: Dict[str, Any]
    ) -> List[VerdictCondition]:
        """수정 조건 생성"""
        conditions = []
        priority = 1

        # Gate 조건
        missing = gate_result.get("missing_sections", [])
        for section in missing:
            conditions.append(VerdictCondition(
                section=section,
                requirement=f"'{section}' 섹션을 추가하세요",
                priority=priority
            ))
            priority += 1

        # Scan 조건 (충돌 해결)
        conflicts = scan_result.get("conflicts", [])
        for conflict in conflicts:
            conditions.append(VerdictCondition(
                section="Conflict Resolution",
                requirement=f"충돌 해결 방안 제시: {conflict}",
                priority=priority
            ))
            priority += 1

        # Fold 조건 (차단 요소)
        blockers = fold_result.get("blockers", [])
        for blocker in blockers:
            conditions.append(VerdictCondition(
                section="Blocker Resolution",
                requirement=f"차단 요소 해결: {blocker}",
                priority=priority
            ))
            priority += 1

        return conditions

    def _generate_next_steps(
        self,
        verdict: Verdict,
        conditions: List[VerdictCondition]
    ) -> List[NextStep]:
        """다음 단계 생성"""
        steps = []

        if verdict == Verdict.PASS:
            steps.extend([
                NextStep(
                    action="start_implementation",
                    description="PRD를 기반으로 구현을 시작하세요",
                    agent="agent_m_patch"
                ),
                NextStep(
                    action="optional_agent",
                    description="agent_m_patch를 호출하여 자동 구현을 진행할 수 있습니다"
                )
            ])

        elif verdict == Verdict.FIX:
            steps.append(NextStep(
                action="fix_prd",
                description="PRD를 수정한 후 다시 Gate부터 시작하세요"
            ))

            if conditions:
                steps.append(NextStep(
                    action="resolve_conditions",
                    description=f"{len(conditions)}개의 조건을 해결하세요"
                ))

            steps.append(NextStep(
                action="expert_consultation",
                description="필요시 도메인 전문가와 상의하세요"
            ))

        else:  # FAIL
            steps.extend([
                NextStep(
                    action="revise_requirements",
                    description="요구사항을 재검토하고 수정하세요"
                ),
                NextStep(
                    action="reduce_scope",
                    description="범위를 줄이거나 단순화하세요"
                ),
                NextStep(
                    action="revalidation",
                    description="수정 후 Gate부터 다시 시작하세요"
                )
            ])

        return steps


# CLI 인터페이스
def main():
    """CLI 진입점"""
    import sys
    import json
    from pathlib import Path

    if len(sys.argv) < 2:
        print("Usage: python verdict_agent.py <prd_file> [gate.json] [scan.json] [fold.json]")
        sys.exit(1)

    prd_path = Path(sys.argv[1])
    if not prd_path.exists():
        print(f"PRD file not found: {prd_path}")
        sys.exit(1)

    # 결과 로드
    gate_result = {}
    scan_result = {}
    fold_result = {}

    if len(sys.argv) > 2:
        try:
            with open(sys.argv[2], "r") as f:
                gate_result = json.load(f)
        except Exception:
            pass

    if len(sys.argv) > 3:
        try:
            with open(sys.argv[3], "r") as f:
                scan_result = json.load(f)
        except Exception:
            pass

    if len(sys.argv) > 4:
        try:
            with open(sys.argv[4], "r") as f:
                fold_result = json.load(f)
        except Exception:
            pass

    agent = VerdictAgent()
    prd = PRDContent.from_file(prd_path)

    context = {
        "gate_result": gate_result,
        "scan_result": scan_result,
        "fold_result": fold_result
    }

    result = agent.execute_with_timing(prd, context)

    # 결과 출력
    verdict = result.data.get("verdict", "UNKNOWN")
    confidence = result.data.get("confidence", 0)

    print("\n" + "=" * 50)
    print(f"  VERDICT: {verdict}")
    print(f"  Confidence: {confidence:.2f}")
    print("=" * 50)

    print(f"\nReasoning: {result.data.get('reasoning', '')}")

    feedback = result.data.get("feedback", [])
    if feedback:
        print("\nFeedback:")
        for fb in feedback:
            print(f"  - {fb}")

    conditions = result.data.get("conditions", [])
    if conditions:
        print("\nConditions:")
        for cond in conditions:
            print(f"  [{cond['priority']}] {cond['requirement']}")

    next_steps = result.data.get("next_steps", [])
    if next_steps:
        print("\nNext Steps:")
        for step in next_steps:
            print(f"  - {step['description']}")
            if step.get("agent"):
                print(f"    Agent: {step['agent']}")

    print(f"\nDuration: {result.duration_ms}ms")

    sys.exit(0 if result.success else 1)


if __name__ == "__main__":
    main()
