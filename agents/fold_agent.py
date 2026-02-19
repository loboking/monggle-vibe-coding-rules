#!/usr/bin/env python3
"""
Monggle Vibe Coding Rules - Fold Agent
Gate와 Scan의 결과를 종합하여 구현 가능성과 위험도를 평가
Python 3.8+ 호환
"""

from typing import Dict, Any, List, Optional
from dataclasses import dataclass, field
from enum import Enum

from base_agent import BaseAgent, PRDContent, AgentResult


class Feasibility(Enum):
    """구현 가능성"""
    HIGH = "High"
    MEDIUM = "Medium"
    LOW = "Low"


class RiskLevel(Enum):
    """위험도"""
    CRITICAL = "Critical"
    HIGH = "High"
    MEDIUM = "Medium"
    LOW = "Low"


@dataclass
class RiskAssessment:
    """위험도 평가"""
    technical: str = "Medium"
    operational: str = "Medium"
    security: str = "Medium"

    def to_dict(self) -> Dict[str, str]:
        return {
            "technical": self.technical,
            "operational": self.operational,
            "security": self.security
        }


@dataclass
class Task:
    """우선순위 작업"""
    priority: int
    task: str
    reason: str
    estimated_hours: int = 1

    def to_dict(self) -> Dict[str, Any]:
        return {
            "priority": self.priority,
            "task": self.task,
            "reason": self.reason,
            "estimated_hours": self.estimated_hours
        }


class FoldAgent(BaseAgent):
    """Fold Agent - 결과 종합 및 타당성 평가"""

    name = "fold"
    description = "Synthesize results and assess feasibility"

    # 접근 방식
    APPROACH_INCREMENTAL = "점진적 구현"
    APPROACH_BIG_BANG = "빅뱅 구현"
    APPROACH_PARALLEL = "병렬 구현 후 전환"

    def __init__(self, project_root: Optional["Path"] = None):
        super().__init__(project_root)

    def execute(self, prd: PRDContent, context: Dict[str, Any] = None) -> AgentResult:
        """Fold Agent 실행

        Args:
            prd: 파싱된 PRD
            context: gate_result, scan_result 포함

        Returns:
            AgentResult: 종합 평가 결과
        """
        self.log("Starting fold analysis...", "step")

        context = context or {}

        # 1. Gate 결과 확인
        gate_result = context.get("gate_result", {})
        if not gate_result.get("valid", True):
            return AgentResult(
                success=False,
                error="Gate validation failed, cannot proceed with fold"
            )

        # 2. Scan 결과 확인
        scan_result = context.get("scan_result", {})

        # 3. 구현 가능성 평가
        feasibility = self._assess_feasibility(prd, gate_result, scan_result)

        # 4. 위험도 분석
        risk_assessment = self._assess_risks(prd, scan_result)

        # 5. 접근 방식 제안
        approach = self._recommend_approach(feasibility, risk_assessment, scan_result)

        # 6. 우선순위 작업 설정
        priority_tasks = self._prioritize_tasks(prd, scan_result, approach)

        # 7. 차단 요소 식별
        blockers = self._identify_blockers(prd, scan_result)

        # 8. 권장 사항
        recommendations = self._generate_recommendations(
            feasibility, risk_assessment, blockers
        )

        result_data = {
            "feasibility": feasibility.value,
            "risk_assessment": risk_assessment.to_dict(),
            "approach": approach,
            "priority_tasks": [t.to_dict() for t in priority_tasks],
            "blockers": blockers,
            "recommendations": recommendations
        }

        return AgentResult(success=True, data=result_data)

    def _assess_feasibility(
        self,
        prd: PRDContent,
        gate_result: Dict[str, Any],
        scan_result: Dict[str, Any]
    ) -> Feasibility:
        """구현 가능성 평가"""
        self.log("Assessing feasibility...", "step")

        score = 100  # 시작 점수

        # Gate 결과 감소
        if not gate_result.get("valid", True):
            score -= 50
        if gate_result.get("missing_sections"):
            score -= len(gate_result["missing_sections"]) * 10

        # 복잡도 감소
        complexity = scan_result.get("complexity", "Medium")
        if complexity == "High":
            score -= 30
        elif complexity == "Medium":
            score -= 15

        # 충돌 감소
        conflicts = scan_result.get("conflicts", [])
        score -= len(conflicts) * 10

        # 차단 요소 감소
        blockers_count = self._count_potential_blockers(scan_result)
        score -= blockers_count * 15

        # 의존성 문제
        dependencies = scan_result.get("dependencies", [])
        critical_deps = [d for d in dependencies if d.get("critical", False)]
        if len(critical_deps) > 3:
            score -= 10

        # 구현 가능성 결정
        if score >= 70:
            return Feasibility.HIGH
        elif score >= 40:
            return Feasibility.MEDIUM
        else:
            return Feasibility.LOW

    def _assess_risks(
        self,
        prd: PRDContent,
        scan_result: Dict[str, Any]
    ) -> RiskAssessment:
        """위험도 평가"""
        self.log("Assessing risks...", "step")

        # 기술적 위험
        technical = self._assess_technical_risk(prd, scan_result)

        # 운영 위험
        operational = self._assess_operational_risk(prd, scan_result)

        # 보안 위험
        security = self._assess_security_risk(prd)

        return RiskAssessment(
            technical=technical,
            operational=operational,
            security=security
        )

    def _assess_technical_risk(
        self,
        prd: PRDContent,
        scan_result: Dict[str, Any]
    ) -> str:
        """기술적 위험 평가"""
        score = 0

        # 복잡도
        complexity = scan_result.get("complexity", "Medium")
        if complexity == "High":
            score += 3
        elif complexity == "Medium":
            score += 2

        # 영향 파일 수
        affected_count = len(scan_result.get("affected_files", []))
        if affected_count > 10:
            score += 3
        elif affected_count > 5:
            score += 2

        # 충돌
        conflicts = scan_result.get("conflicts", [])
        score += len(conflicts)

        # 기술 스택
        tech_stack = prd.frontmatter.get("tech_stack", [])
        if isinstance(tech_stack, str):
            tech_stack = [tech_stack]

        # 복잡한 기술 스택
        high_tech_keywords = ["microservice", "kubernetes", "react-native", "web3"]
        for tech in tech_stack:
            if any(kw in tech.lower() for kw in high_tech_keywords):
                score += 2

        if score >= 7:
            return RiskLevel.HIGH.value
        elif score >= 4:
            return RiskLevel.MEDIUM.value
        else:
            return RiskLevel.LOW.value

    def _assess_operational_risk(
        self,
        prd: PRDContent,
        scan_result: Dict[str, Any]
    ) -> str:
        """운영 위험 평가"""
        score = 0

        # 데이터베이스 변경
        content = prd.raw.lower()
        if "database" in content or "migration" in content:
            score += 2

        # 마이그레이션 없는 DB 변경
        if "database" in content and "migration" not in content:
            score += 2

        # 배포 관련
        if "deploy" in content or "release" in content:
            score += 1

        # 롤백 계획
        if "rollback" not in content:
            score += 1

        if score >= 5:
            return RiskLevel.HIGH.value
        elif score >= 3:
            return RiskLevel.MEDIUM.value
        else:
            return RiskLevel.LOW.value

    def _assess_security_risk(self, prd: PRDContent) -> str:
        """보안 위험 평가"""
        content = prd.raw.lower()

        security_keywords = [
            "auth", "authentication", "authorization",
            "password", "token", "jwt", "oauth",
            "api", "endpoint", "webhook",
            "user", "login", "session"
        ]

        security_score = sum(1 for kw in security_keywords if kw in content)

        # 암호화 언급
        if "encrypt" not in content and security_score >= 3:
            security_score += 1

        if security_score >= 5:
            return RiskLevel.HIGH.value
        elif security_score >= 2:
            return RiskLevel.MEDIUM.value
        else:
            return RiskLevel.LOW.value

    def _recommend_approach(
        self,
        feasibility: Feasibility,
        risk_assessment: RiskAssessment,
        scan_result: Dict[str, Any]
    ) -> str:
        """접근 방식 제안"""
        self.log("Recommending approach...", "step")

        # 높은 위험도 있으면 점진적 구현
        if risk_assessment.technical == RiskLevel.HIGH.value:
            return self.APPROACH_INCREMENTAL

        if risk_assessment.security == RiskLevel.HIGH.value:
            return self.APPROACH_INCREMENTAL

        # 구현 가능성 낮으면 점진적
        if feasibility == Feasibility.LOW:
            return self.APPROACH_INCREMENTAL

        # 복잡도 높으면 점진적
        if scan_result.get("complexity") == "High":
            return self.APPROACH_INCREMENTAL

        # 기본: 점진적 구현 권장
        return self.APPROACH_INCREMENTAL

    def _prioritize_tasks(
        self,
        prd: PRDContent,
        scan_result: Dict[str, Any],
        approach: str
    ) -> List[Task]:
        """우선순위 작업 설정"""
        self.log("Prioritizing tasks...", "step")

        tasks = []
        priority = 1

        # 데이터베이스 관련 작업 우선
        content = prd.raw.lower()
        if "database" in content or "migration" in content:
            tasks.append(Task(
                priority=priority,
                task="데이터베이스 스키마 변경 및 마이그레이션",
                reason="다른 작업의 선행 조건",
                estimated_hours=4
            ))
            priority += 1

        # 핵심 기능
        if approach == self.APPROACH_INCREMENTAL:
            tasks.append(Task(
                priority=priority,
                task="핵심 기능 구현 (MVP)",
                reason="점진적 구현의 1단계",
                estimated_hours=8
            ))
            priority += 1

            tasks.append(Task(
                priority=priority,
                task="확장 기능 추가",
                reason="점진적 구현의 2단계",
                estimated_hours=6
            ))
            priority += 1
        else:
            tasks.append(Task(
                priority=priority,
                task="전체 기능 구현",
                reason="빅뱅 구현",
                estimated_hours=16
            ))
            priority += 1

        # 보안 관련
        if any(kw in content for kw in ["auth", "security", "jwt", "oauth"]):
            tasks.append(Task(
                priority=priority,
                task="보안 검토 및 테스트",
                reason="보안 관련 기능 포함",
                estimated_hours=4
            ))
            priority += 1

        # 테스트
        tasks.append(Task(
            priority=priority,
            task="테스트 작성 및 검증",
            reason="품질 보장",
            estimated_hours=scan_result.get("estimates", {}).get("estimated_hours", 4) // 2
        ))

        return tasks

    def _identify_blockers(
        self,
        prd: PRDContent,
        scan_result: Dict[str, Any]
    ) -> List[str]:
        """차단 요소 식별"""
        self.log("Identifying blockers...", "step")

        blockers = []
        content = prd.raw.lower()

        # 데이터베이스
        if "database" in content and "migration" not in content:
            blockers.append("데이터베이스 마이그레이션 계획 없음")

        # 외부 의존성
        if "oauth" in content and "provider" not in content:
            blockers.append("OAuth 공급자 승인 대기 중")

        # API
        if "external api" in content and "integration" not in content:
            blockers.append("외부 API 통합 계획 없음")

        # Scan 결과의 충돌
        for conflict in scan_result.get("conflicts", []):
            if "충돌" in conflict:
                blockers.append(conflict)

        return blockers

    def _count_potential_blockers(self, scan_result: Dict[str, Any]) -> int:
        """잠재적 차단 요소 수 계산"""
        count = 0

        # 충돌 수
        count += len(scan_result.get("conflicts", []))

        # 고위험 파일
        affected_files = scan_result.get("affected_files", [])
        for f in affected_files:
            if f.get("risk") == "High":
                count += 1

        return count

    def _generate_recommendations(
        self,
        feasibility: Feasibility,
        risk_assessment: RiskAssessment,
        blockers: List[str]
    ) -> List[str]:
        """권장 사항 생성"""
        self.log("Generating recommendations...", "step")

        recommendations = []

        # 구현 가능성 기반
        if feasibility == Feasibility.HIGH:
            recommendations.append("PRD가 잘 작성되었습니다. 즉시 구현을 시작할 수 있습니다.")
        elif feasibility == Feasibility.MEDIUM:
            recommendations.append("일부 보완이 필요하지만 구현 가능합니다.")
        else:
            recommendations.append("요구사항 재검토가 권장됩니다.")

        # 위험도 기반
        if risk_assessment.technical == RiskLevel.HIGH.value:
            recommendations.append("기술적 위험도가 높습니다. PoC(개념 증명)을 먼저 진행하세요.")

        if risk_assessment.security == RiskLevel.HIGH.value:
            recommendations.append("보안 전문가의 리뷰를 권장합니다.")

        # 차단 요소 기반
        if blockers:
            recommendations.append(f"{len(blockers)}개의 차단 요소를 먼저 해결하세요.")

        # 일반 권장
        recommendations.append("점진적 구현을 통해 위험을 분산하세요.")

        return recommendations


# CLI 인터페이스
def main():
    """CLI 진입점"""
    import sys
    import json
    from pathlib import Path

    if len(sys.argv) < 2:
        print("Usage: python fold_agent.py <prd_file> [gate_result.json] [scan_result.json]")
        sys.exit(1)

    prd_path = Path(sys.argv[1])
    if not prd_path.exists():
        print(f"PRD file not found: {prd_path}")
        sys.exit(1)

    # Gate 결과 로드 (선택)
    gate_result = {}
    if len(sys.argv) > 2:
        try:
            with open(sys.argv[2], "r") as f:
                gate_result = json.load(f)
        except Exception:
            pass

    # Scan 결과 로드 (선택)
    scan_result = {}
    if len(sys.argv) > 3:
        try:
            with open(sys.argv[3], "r") as f:
                scan_result = json.load(f)
        except Exception:
            pass

    agent = FoldAgent()
    prd = PRDContent.from_file(prd_path)

    context = {
        "gate_result": gate_result,
        "scan_result": scan_result
    }

    result = agent.execute_with_timing(prd, context)

    print("\n=== Fold Result ===")
    print(json.dumps(result.data, indent=2, ensure_ascii=False))
    print(f"\nDuration: {result.duration_ms}ms")

    sys.exit(0 if result.success else 1)


if __name__ == "__main__":
    main()
