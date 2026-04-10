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
    language: str = "ko"  # PRD 출력 언어 (ko=en|zh|ja 등)


@dataclass
class PRDContent:
    """PRD 내용"""
    type: str
    language: str = "ko"
    frontmatter: Dict[str, str] = field(default_factory=dict)
    sections: Dict[str, str] = field(default_factory=dict)

    # 언어별 메시지
    MESSAGES = {
        "ko": {
            "prd_creator_title": "PRD 생성기 v2.5",
            "creating_prd": "PRD 생성을 위해 질문을 드리겠습니다.",
            "skip_hint": "답변은 Enter를 누르면 건너뛸 수 있습니다 (필수 항목 제외)",
            "validating": "PRD 검증 중...",
            "missing_sections": "누락된 섹션",
            "validation_passed": "PRD 검증 통과",
            "validation_failed": "PRD 생성 실패: 필수 항목 누락",
            "required_warning": "이 항목은 필수입니다.",
            "prd_completed": "PRD 생성 완료",
        },
        "en": {
            "prd_creator_title": "PRD Creator v2.5",
            "creating_prd": "I'll ask some questions to create the PRD.",
            "skip_hint": "Press Enter to skip (except required fields)",
            "validating": "Validating PRD...",
            "missing_sections": "Missing sections",
            "validation_passed": "PRD validation passed",
            "validation_failed": "PRD creation failed: Missing required fields",
            "required_warning": "This field is required.",
            "prd_completed": "PRD created successfully",
        },
        "zh": {
            "prd_creator_title": "PRD 生成器 v2.5",
            "creating_prd": "为了创建 PRD，我将询问一些问题。",
            "skip_hint": "按 Enter 跳过（必填项除外）",
            "validating": "验证 PRD 中...",
            "missing_sections": "缺失部分",
            "validation_passed": "PRD 验证通过",
            "validation_failed": "PRD 创建失败：缺少必填字段",
            "required_warning": "此字段为必填项。",
            "prd_completed": "PRD 创建成功",
        },
        "ja": {
            "prd_creator_title": "PRD作成ツール v2.5",
            "creating_prd": "PRDを作成するために質問します。",
            "skip_hint": "Enterでスキップ（必須項目を除く）",
            "validating": "PRD検証中...",
            "missing_sections": "欠落セクション",
            "validation_passed": "PRD検証通過",
            "validation_failed": "PRD作成失敗：必須項目が不足",
            "required_warning": "この項目は必須です。",
            "prd_completed": "PRD作成完了",
        },
    }

    def get_message(self, key: str) -> str:
        """언어에 따른 메시지 반환"""
        lang_messages = self.MESSAGES.get(self.language, self.MESSAGES["en"])
        return lang_messages.get(key, key)

    # 언어별 섹션 이름 매핑
    SECTION_NAMES = {
        "ko": {
            "feature": {
                "goal": "목표",
                "requirements": "요구사항",
                "edge_cases": "엣지 케이스",
                "testing": "테스트",
            },
            "bug": {
                "issue": "문제",
                "description": "상세 설명",
                "root_cause": "원인",
                "fix_plan": "수정 계획",
                "testing": "검증",
            },
            "refactor": {
                "current": "현재 상태",
                "issues": "문제점",
                "proposed_changes": "제안 변경사항",
                "impact": "영향 범위",
                "testing": "검증",
            },
            "hotfix": {
                "issue": "문제",
                "quick_fix": "빠른 수정",
                "testing": "검증",
            },
            "experiment": {
                "hypothesis": "가설",
                "test_plan": "테스트 계획",
                "success_criteria": "성공 기준",
            },
            "api": {
                "purpose": "목적",
                "endpoints": "엔드포인트",
                "request": "요청",
                "response": "응답",
                "authentication": "인증",
                "testing": "테스트",
            },
            "migration": {
                "goal": "목표",
                "schema_changes": "스키마 변경",
                "data_migration": "데이터 마이그레이션",
                "rollback_plan": "롤백 계획",
                "downtime": "다운타임",
            },
            "ml": {
                "purpose": "목적",
                "data": "데이터",
                "features": "피쳐",
                "model": "모델",
                "evaluation": "평가",
                "deployment": "배포",
            },
            "devops": {
                "automation_goal": "자동화 목표",
                "current_workflow": "현재 워크플로우",
                "tools": "도구",
                "scope": "범위",
                "validation": "검증",
            },
        },
        "en": {
            "feature": {
                "goal": "Goal",
                "requirements": "Requirements",
                "edge_cases": "Edge Cases",
                "testing": "Testing",
            },
            "bug": {
                "issue": "Issue",
                "description": "Description",
                "root_cause": "Root Cause",
                "fix_plan": "Fix Plan",
                "testing": "Testing",
            },
            "refactor": {
                "current": "Current",
                "issues": "Issues",
                "proposed_changes": "Proposed Changes",
                "impact": "Impact",
                "testing": "Testing",
            },
            "hotfix": {
                "issue": "Issue",
                "quick_fix": "Quick Fix",
                "testing": "Testing",
            },
            "experiment": {
                "hypothesis": "Hypothesis",
                "test_plan": "Test Plan",
                "success_criteria": "Success Criteria",
            },
            "api": {
                "purpose": "Purpose",
                "endpoints": "Endpoints",
                "request": "Request",
                "response": "Response",
                "authentication": "Authentication",
                "testing": "Testing",
            },
            "migration": {
                "goal": "Goal",
                "schema_changes": "Schema Changes",
                "data_migration": "Data Migration",
                "rollback_plan": "Rollback Plan",
                "downtime": "Downtime",
            },
            "ml": {
                "purpose": "Purpose",
                "data": "Data",
                "features": "Features",
                "model": "Model",
                "evaluation": "Evaluation",
                "deployment": "Deployment",
            },
            "devops": {
                "automation_goal": "Automation Goal",
                "current_workflow": "Current Workflow",
                "tools": "Tools",
                "scope": "Scope",
                "validation": "Validation",
            },
        },
        "zh": {
            "feature": {
                "goal": "目标",
                "requirements": "需求",
                "edge_cases": "边界情况",
                "testing": "测试",
            },
            "bug": {
                "issue": "问题",
                "description": "详细描述",
                "root_cause": "根本原因",
                "fix_plan": "修复计划",
                "testing": "验证",
            },
            "refactor": {
                "current": "当前状态",
                "issues": "问题",
                "proposed_changes": "建议更改",
                "impact": "影响范围",
                "testing": "验证",
            },
            "hotfix": {
                "issue": "问题",
                "quick_fix": "快速修复",
                "testing": "验证",
            },
            "experiment": {
                "hypothesis": "假设",
                "test_plan": "测试计划",
                "success_criteria": "成功标准",
            },
            "api": {
                "purpose": "目的",
                "endpoints": "端点",
                "request": "请求",
                "response": "响应",
                "authentication": "认证",
                "testing": "测试",
            },
            "migration": {
                "goal": "目标",
                "schema_changes": "架构变更",
                "data_migration": "数据迁移",
                "rollback_plan": "回滚计划",
                "downtime": "停机时间",
            },
            "ml": {
                "purpose": "目的",
                "data": "数据",
                "features": "特征",
                "model": "模型",
                "evaluation": "评估",
                "deployment": "部署",
            },
            "devops": {
                "automation_goal": "自动化目标",
                "current_workflow": "当前工作流",
                "tools": "工具",
                "scope": "范围",
                "validation": "验证",
            },
        },
        "ja": {
            "feature": {
                "goal": "目標",
                "requirements": "要件",
                "edge_cases": "エッジケース",
                "testing": "テスト",
            },
            "bug": {
                "issue": "問題",
                "description": "詳細説明",
                "root_cause": "根本原因",
                "fix_plan": "修正計画",
                "testing": "検証",
            },
            "refactor": {
                "current": "現在の状態",
                "issues": "問題",
                "proposed_changes": "提案された変更",
                "impact": "影響範囲",
                "testing": "検証",
            },
            "hotfix": {
                "issue": "問題",
                "quick_fix": "迅速な修正",
                "testing": "検証",
            },
            "experiment": {
                "hypothesis": "仮説",
                "test_plan": "テスト計画",
                "success_criteria": "成功基準",
            },
            "api": {
                "purpose": "目的",
                "endpoints": "エンドポイント",
                "request": "リクエスト",
                "response": "レスポンス",
                "authentication": "認証",
                "testing": "テスト",
            },
            "migration": {
                "goal": "目標",
                "schema_changes": "スキーマ変更",
                "data_migration": "データ移行",
                "rollback_plan": "ロールバック計画",
                "downtime": "ダウンタイム",
            },
            "ml": {
                "purpose": "目的",
                "data": "データ",
                "features": "特徴",
                "model": "モデル",
                "evaluation": "評価",
                "deployment": "デプロイ",
            },
            "devops": {
                "automation_goal": "自動化目標",
                "current_workflow": "現在のワークフロー",
                "tools": "ツール",
                "scope": "範囲",
                "validation": "検証",
            },
        },
    }

    def get_section_name(self, key: str) -> str:
        """언어에 따른 섹션 이름 반환"""
        lang_sections = self.SECTION_NAMES.get(self.language, {})
        type_sections = lang_sections.get(self.type, {})
        return type_sections.get(key, key)  # fallback to key

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
        for section_key, content in self.sections.items():
            section_name = self.get_section_name(section_key)
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
        self.prd = PRDContent(type=config.prd_type, language=config.language)
        self.answers: Dict[str, str] = {}

    def print_header(self):
        """헤더 출력"""
        print("\n" + "=" * 60)
        print(f"  {self.prd.get_message('prd_creator_title')} - {self.config.prd_type.upper()}")
        print("=" * 60)
        print()

    def ask_questions(self):
        """질문 진행"""
        questions = QuestionBank.get_questions(self.config.prd_type)

        print(f"📝 {self.prd.get_message('creating_prd')}")
        print(f"💡 {self.prd.get_message('skip_hint')}")
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
                    print(f"⚠️ {self.prd.get_message('required_warning')}")
                    answer = input(f"> ").strip()

                self.answers[key] = answer or self._get_pending_text()
            else:
                # 비대화형 모드
                self.answers[key] = self._get_pending_text()

    def _get_pending_text(self) -> str:
        """언어별 '추가 예정' 텍스트 반환"""
        pending_map = {
            "ko": "(추가 예정)",
            "en": "(To be added)",
            "zh": "(待补充)",
            "ja": "(追加予定)",
        }
        return pending_map.get(self.config.language, "(To be added)")

    def build_prd(self):
        """PRD 빌드"""
        # 언어별 기본값
        none_text = {
            "ko": "없음",
            "en": "None",
            "zh": "无",
            "ja": "なし",
        }.get(self.config.language, "None")

        investigate_text = {
            "ko": "조사 필요",
            "en": "To be investigated",
            "zh": "待调查",
            "ja": "調査必要",
        }.get(self.config.language, "To be investigated")

        # Frontmatter
        self.prd.frontmatter = {
            "type": self.config.prd_type,
            "feature_type": self.config.prd_type,
            "title": self.answers.get("title", f"{self.config.prd_type} PRD"),
            "created_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "status": "draft",
        }

        # Sections - 소문자 키 사용 (언어별 섹션 이름 변환을 위해)
        section_mapping = {
            "feature": {
                "goal": self.answers.get("goal", ""),
                "requirements": self.answers.get("requirements", ""),
                "edge_cases": self.answers.get("edge_cases", none_text),
                "testing": self.answers.get("testing", ""),
            },
            "bug": {
                "issue": self.answers.get("issue", ""),
                "description": self.answers.get("description", ""),
                "root_cause": self.answers.get("root_cause", investigate_text),
                "fix_plan": self.answers.get("fix_plan", ""),
                "testing": self.answers.get("testing", ""),
            },
            "refactor": {
                "current": self.answers.get("current", ""),
                "issues": self.answers.get("issues", ""),
                "proposed_changes": self.answers.get("proposed_changes", ""),
                "impact": self.answers.get("impact", ""),
                "testing": self.answers.get("testing", ""),
            },
            "hotfix": {
                "issue": self.answers.get("issue", ""),
                "quick_fix": self.answers.get("quick_fix", ""),
                "testing": self.answers.get("testing", ""),
            },
            "experiment": {
                "hypothesis": self.answers.get("hypothesis", ""),
                "test_plan": self.answers.get("test_plan", ""),
                "success_criteria": self.answers.get("success_criteria", ""),
            },
            "api": {
                "purpose": self.answers.get("purpose", ""),
                "endpoints": self.answers.get("endpoints", ""),
                "request": self.answers.get("request", ""),
                "response": self.answers.get("response", ""),
                "authentication": self.answers.get("authentication", ""),
                "testing": self.answers.get("testing", ""),
            },
            "migration": {
                "goal": self.answers.get("goal", ""),
                "schema_changes": self.answers.get("schema_changes", ""),
                "data_migration": self.answers.get("data_migration", ""),
                "rollback_plan": self.answers.get("rollback_plan", ""),
                "downtime": self.answers.get("downtime", ""),
            },
            "ml": {
                "purpose": self.answers.get("purpose", ""),
                "data": self.answers.get("data", ""),
                "features": self.answers.get("features", ""),
                "model": self.answers.get("model", ""),
                "evaluation": self.answers.get("evaluation", ""),
                "deployment": self.answers.get("deployment", ""),
            },
            "devops": {
                "automation_goal": self.answers.get("automation_goal", ""),
                "current_workflow": self.answers.get("current_workflow", ""),
                "tools": self.answers.get("tools", ""),
                "scope": self.answers.get("scope", ""),
                "validation": self.answers.get("validation", ""),
            },
        }

        self.prd.sections = section_mapping.get(self.config.prd_type, {})

    def validate(self) -> bool:
        """PRD 검증"""
        print(f"\n🔍 {self.prd.get_message('validating')}")

        # 비대화형 모드에서는 기본 검증만 수행
        if not self.config.interactive:
            print(f"✅ {self.prd.get_message('validation_passed')} (non-interactive mode)")
            return True

        # 필수 섹션 체크
        required_sections = QuestionBank.get_questions(self.config.prd_type)
        missing = []

        # 언어별 "추가 예정" 텍스트
        pending_texts = {
            "ko": ["(추가 예정)", "없음", "조사 필요"],
            "en": ["(To be added)", "None", "To be investigated"],
            "zh": ["(待补充)", "无", "待调查"],
            "ja": ["(追加予定)", "なし", "調査必要"],
        }
        pending = pending_texts.get(self.config.language, pending_texts["en"])

        for section in required_sections:
            key = section["key"]
            if section.get("required", False):
                # frontmatter 필드 (title 등)는 별도 처리
                if key == "title":
                    title = self.answers.get("title", "").strip()
                    if not title:
                        missing.append("Title")
                    continue

                # 섹션 내용이 비어있는지 확인 (공백만 있는 경우도 누락으로 간주)
                content = self.prd.sections.get(key, "").strip()
                if not content or content in pending:
                    # 언어별로 섹션 이름 표시
                    section_name = self.prd.get_section_name(key)
                    missing.append(section_name)

        if missing:
            print(f"⚠️ {self.prd.get_message('missing_sections')}: {', '.join(missing)}")
            return False

        print(f"✅ {self.prd.get_message('validation_passed')}")
        return True

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
            print(f"\n✅ {self.prd.get_message('prd_completed')}: {output_path}")
            return output_path
        else:
            print(f"\n❌ {self.prd.get_message('validation_failed')}")
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
    parser.add_argument(
        "--language",
        type=str,
        default="ko",
        choices=["ko", "en", "zh", "ja"],
        help="PRD output language (default: ko)"
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
        interactive=not args.non_interactive,
        language=args.language
    )

    # PRD 생성
    creator = PRDCreator(config)
    creator.create()

    return 0


if __name__ == "__main__":
    sys.exit(main())
