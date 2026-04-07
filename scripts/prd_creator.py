#!/usr/bin/env python3
"""
Monggle Vibe Coding - PRD Creator v2.4

체계적인 PRD 생성을 위한 Python 스크립트
질문 → 수집 → 검증 → 생성 자동화

Usage:
    python prd_creator.py --type feature
    python prd_creator.py --type api --interactive
"""

import os
import sys
import json
import argparse
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional
from dataclasses import dataclass, field


@dataclass
class PRDConfig:
    """PRD 설정"""
    prd_type: str
    project_root: Path
    output_file: Path
    interactive: bool = True


@dataclass
class PRDContent:
    """PRD 내용"""
    type: str
    frontmatter: Dict[str, str] = field(default_factory=dict)
    sections: Dict[str, str] = field(default_factory=dict)

    def to_markdown(self) -> str:
        """Markdown으로 변환"""
        lines = ["---"]

        # Frontmatter
        for key, value in self.frontmatter.items():
            lines.append(f'{key}: "{value}"')

        lines.append("---")
        lines.append("")
        lines.append(f"# {self.frontmatter.get('title', 'PRD')}")
        lines.append("")

        # Sections
        for section_name, content in self.sections.items():
            lines.append(f"## {section_name}")
            lines.append("")
            lines.append(content)
            lines.append("")

        return "\n".join(lines)


class QuestionBank:
    """PRD 타입별 질문 정의"""

    QUESTIONS = {
        "feature": [
            {"key": "title", "question": "프로젝트/기능 이름은?", "required": True},
            {"key": "goal", "question": "이 기능이 어떤 문제를 해결하나요?", "required": True},
            {"key": "requirements", "question": "주요 기능 요구사항을 나열해주세요", "required": True},
            {"key": "edge_cases", "question": "처리해야 할 엣지 케이스가 있나요?", "required": False},
            {"key": "testing", "question": "테스트 계획은?", "required": True},
        ],
        "bug": [
            {"key": "title", "question": "버그 제목은?", "required": True},
            {"key": "issue", "question": "어떤 버그인가요?", "required": True},
            {"key": "description", "question": "상세 설명", "required": True},
            {"key": "root_cause", "question": "원인을 알고 계신가요?", "required": False},
            {"key": "fix_plan", "question": "수정 계획은?", "required": True},
            {"key": "testing", "question": "수정 후 검증 방법은?", "required": True},
        ],
        "refactor": [
            {"key": "title", "question": "리팩토링 대상은?", "required": True},
            {"key": "current", "question": "현재 상태를 설명해주세요", "required": True},
            {"key": "issues", "question": "현재 어떤 문제가 있나요?", "required": True},
            {"key": "proposed_changes", "question": "어떻게 변경할 예정인가요?", "required": True},
            {"key": "impact", "question": "영향 범위는?", "required": True},
            {"key": "testing", "question": "리팩토링 후 검증 방법은?", "required": True},
        ],
        "hotfix": [
            {"key": "title", "question": "핫픽스 제목은?", "required": True},
            {"key": "issue", "question": "긴급 문제는 무엇인가요?", "required": True},
            {"key": "quick_fix", "question": "빠른 수정 방법은?", "required": True},
            {"key": "testing", "question": "빠른 검증 방법은?", "required": True},
        ],
        "experiment": [
            {"key": "title", "question": "실험 이름은?", "required": True},
            {"key": "hypothesis", "question": "가설은 무엇인가요?", "required": True},
            {"key": "test_plan", "question": "테스트 계획은?", "required": True},
            {"key": "success_criteria", "question": "성공 기준은?", "required": True},
        ],
        "api": [
            {"key": "title", "question": "API 이름은?", "required": True},
            {"key": "purpose", "question": "이 API의 목적은?", "required": True},
            {"key": "endpoints", "question": "필요한 엔드포인트를 나열해주세요 (GET/POST/PUT/DELETE)", "required": True},
            {"key": "request", "question": "Request 데이터 구조는?", "required": True},
            {"key": "response", "question": "Response 데이터 구조는?", "required": True},
            {"key": "authentication", "question": "인증 방식은?", "required": True},
            {"key": "testing", "question": "API 테스트 방법은?", "required": True},
        ],
        "migration": [
            {"key": "title", "question": "마이그레이션 이름은?", "required": True},
            {"key": "goal", "question": "마이그레이션 목표는?", "required": True},
            {"key": "schema_changes", "question": "스키마 변경사항은?", "required": True},
            {"key": "data_migration", "question": "데이터 변환이 필요한가요?", "required": True},
            {"key": "rollback_plan", "question": "롤백 계획은?", "required": True},
            {"key": "downtime", "question": "다운타임이 필요한가요?", "required": True},
        ],
        "ml": [
            {"key": "title", "question": "모델 이름은?", "required": True},
            {"key": "purpose", "question": "이 모델의 목적은?", "required": True},
            {"key": "data", "question": "데이터 소스는?", "required": True},
            {"key": "features", "question": "사용할 피쳐는?", "required": True},
            {"key": "model", "question": "어떤 모델을 사용할 예정인가요?", "required": True},
            {"key": "evaluation", "question": "평가 지표는?", "required": True},
            {"key": "deployment", "question": "배포 방식은?", "required": True},
        ],
        "devops": [
            {"key": "title", "question": "자동화 대상은?", "required": True},
            {"key": "automation_goal", "question": "자동화 목표는?", "required": True},
            {"key": "current_workflow", "question": "현재 워크플로우는?", "required": True},
            {"key": "tools", "question": "선호하는 도구가 있나요?", "required": False},
            {"key": "scope", "question": "범위 (CI/CD, 인프라, 모니터링)?", "required": True},
            {"key": "validation", "question": "검증 방법은?", "required": True},
        ],
    }

    @classmethod
    def get_questions(cls, prd_type: str) -> List[Dict]:
        """PRD 타입별 질문 반환"""
        return cls.QUESTIONS.get(prd_type, cls.QUESTIONS["feature"])


class PRDCreator:
    """PRD 생성기"""

    def __init__(self, config: PRDConfig):
        self.config = config
        self.prd = PRDContent(type=config.prd_type)
        self.answers: Dict[str, str] = {}

    def print_header(self):
        """헤더 출력"""
        print("\n" + "=" * 60)
        print(f"  PRD Creator v2.4 - {self.config.prd_type.upper()}")
        print("=" * 60)
        print()

    def ask_questions(self):
        """질문 진행"""
        questions = QuestionBank.get_questions(self.config.prd_type)

        print(f"📝 {self.config.prd_type.upper()} PRD 생성을 위해 질문을 드리겠습니다.")
        print("💡 답변은 Enter를 누르면 건너뛸 수 있습니다 (필수 항목 제외)")
        print()

        for idx, q in enumerate(questions, 1):
            key = q["key"]
            question = q["question"]
            required = q["required"]

            prompt = f"\n[{idx}/{len(questions)}] {question}"
            if required:
                prompt += " *"

            # 답변 받기
            if self.config.interactive:
                answer = input(f"{prompt}\n> ").strip()

                # 필수 항목 체크
                while required and not answer:
                    print("⚠️ 이 항목은 필수입니다.")
                    answer = input(f"> ").strip()

                self.answers[key] = answer or "(추가 예정)"
            else:
                # 비대화형 모드
                self.answers[key] = "(추가 예정)"

    def build_prd(self):
        """PRD 빌드"""
        # Frontmatter
        self.prd.frontmatter = {
            "type": self.config.prd_type,
            "feature_type": self.config.prd_type,
            "title": self.answers.get("title", f"{self.config.prd_type} PRD"),
            "created_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "status": "draft",
        }

        # Sections
        section_mapping = {
            "feature": {
                "Goal": self.answers.get("goal", ""),
                "Requirements": self.answers.get("requirements", ""),
                "Edge Cases": self.answers.get("edge_cases", "없음"),
                "Testing": self.answers.get("testing", ""),
            },
            "bug": {
                "Issue": self.answers.get("issue", ""),
                "Description": self.answers.get("description", ""),
                "Root Cause": self.answers.get("root_cause", "조사 필요"),
                "Fix Plan": self.answers.get("fix_plan", ""),
                "Testing": self.answers.get("testing", ""),
            },
            "refactor": {
                "Current": self.answers.get("current", ""),
                "Issues": self.answers.get("issues", ""),
                "Proposed Changes": self.answers.get("proposed_changes", ""),
                "Impact": self.answers.get("impact", ""),
                "Testing": self.answers.get("testing", ""),
            },
            "hotfix": {
                "Issue": self.answers.get("issue", ""),
                "Quick Fix": self.answers.get("quick_fix", ""),
                "Testing": self.answers.get("testing", ""),
            },
            "experiment": {
                "Hypothesis": self.answers.get("hypothesis", ""),
                "Test Plan": self.answers.get("test_plan", ""),
                "Success Criteria": self.answers.get("success_criteria", ""),
            },
            "api": {
                "Purpose": self.answers.get("purpose", ""),
                "Endpoints": self.answers.get("endpoints", ""),
                "Request": self.answers.get("request", ""),
                "Response": self.answers.get("response", ""),
                "Authentication": self.answers.get("authentication", ""),
                "Testing": self.answers.get("testing", ""),
            },
            "migration": {
                "Goal": self.answers.get("goal", ""),
                "Schema Changes": self.answers.get("schema_changes", ""),
                "Data Migration": self.answers.get("data_migration", ""),
                "Rollback Plan": self.answers.get("rollback_plan", ""),
                "Downtime": self.answers.get("downtime", ""),
            },
            "ml": {
                "Purpose": self.answers.get("purpose", ""),
                "Data": self.answers.get("data", ""),
                "Features": self.answers.get("features", ""),
                "Model": self.answers.get("model", ""),
                "Evaluation": self.answers.get("evaluation", ""),
                "Deployment": self.answers.get("deployment", ""),
            },
            "devops": {
                "Automation Goal": self.answers.get("automation_goal", ""),
                "Current Workflow": self.answers.get("current_workflow", ""),
                "Tools": self.answers.get("tools", ""),
                "Scope": self.answers.get("scope", ""),
                "Validation": self.answers.get("validation", ""),
            },
        }

        self.prd.sections = section_mapping.get(self.config.prd_type, {})

    def validate(self) -> bool:
        """PRD 검증"""
        print("\n🔍 PRD 검증 중...")

        # 필수 섹션 체크
        required_sections = QuestionBank.get_questions(self.config.prd_type)
        missing = []

        for section in required_sections:
            key = section["key"]
            if section.get("required", False):
                # 해당하는 section 이름 찾기
                section_name = self._find_section_name(key)
                if section_name and not self.prd.sections.get(section_name):
                    missing.append(section_name)

        if missing:
            print(f"⚠️ 누락된 섹션: {', '.join(missing)}")
            return False

        print("✅ PRD 검증 통과")
        return True

    def _find_section_name(self, key: str) -> Optional[str]:
        """key로 section 이름 찾기"""
        mapping = {
            "goal": "Goal",
            "requirements": "Requirements",
            "edge_cases": "Edge Cases",
            "testing": "Testing",
            "issue": "Issue",
            "description": "Description",
            "root_cause": "Root Cause",
            "fix_plan": "Fix Plan",
            "current": "Current",
            "issues": "Issues",
            "proposed_changes": "Proposed Changes",
            "impact": "Impact",
            "quick_fix": "Quick Fix",
            "hypothesis": "Hypothesis",
            "test_plan": "Test Plan",
            "success_criteria": "Success Criteria",
            "purpose": "Purpose",
            "endpoints": "Endpoints",
            "request": "Request",
            "response": "Response",
            "authentication": "Authentication",
            "schema_changes": "Schema Changes",
            "data_migration": "Data Migration",
            "rollback_plan": "Rollback Plan",
            "downtime": "Downtime",
            "data": "Data",
            "features": "Features",
            "model": "Model",
            "evaluation": "Evaluation",
            "deployment": "Deployment",
            "automation_goal": "Automation Goal",
            "current_workflow": "Current Workflow",
            "tools": "Tools",
            "scope": "Scope",
            "validation": "Validation",
        }
        return mapping.get(key)

    def save(self) -> Path:
        """PRD 저장"""
        # 디렉토리 생성
        self.config.output_file.parent.mkdir(parents=True, exist_ok=True)

        # 파일 쓰기
        content = self.prd.to_markdown()
        with open(self.config.output_file, "w", encoding="utf-8") as f:
            f.write(content)

        return self.config.output_file

    def create(self) -> Path:
        """PRD 생성 실행"""
        self.print_header()
        self.ask_questions()
        self.build_prd()

        if self.validate():
            output_path = self.save()
            print(f"\n✅ PRD 생성 완료: {output_path}")
            return output_path
        else:
            print("\n❌ PRD 생성 실패: 필수 항목 누락")
            sys.exit(1)


def main():
    """메인 진입점"""
    parser = argparse.ArgumentParser(
        description="Create PRD interactively"
    )
    parser.add_argument(
        "--type", "-t",
        type=str,
        required=True,
        choices=["feature", "bug", "refactor", "hotfix", "experiment", "api", "migration", "ml", "devops"],
        help="PRD type"
    )
    parser.add_argument(
        "--output", "-o",
        type=str,
        help="Output file path"
    )
    parser.add_argument(
        "--non-interactive",
        action="store_true",
        help="Non-interactive mode (use defaults)"
    )
    parser.add_argument(
        "--project-root",
        type=str,
        help="Project root path"
    )

    args = parser.parse_args()

    # 프로젝트 루트
    if args.project_root:
        project_root = Path(args.project_root)
    else:
        project_root = Path.cwd()

    # 출력 파일
    if args.output:
        output_file = Path(args.output)
    else:
        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        output_file = project_root / "prd" / f"{args.type}-{timestamp}.md"

    # 설정
    config = PRDConfig(
        prd_type=args.type,
        project_root=project_root,
        output_file=output_file,
        interactive=not args.non_interactive
    )

    # PRD 생성
    creator = PRDCreator(config)
    creator.create()

    return 0


if __name__ == "__main__":
    sys.exit(main())
