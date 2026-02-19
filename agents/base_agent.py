#!/usr/bin/env python3
"""
Monggle Vibe Coding Rules - Base Agent
모든 Agent의 기본 클래스
Python 3.8+ 호환
"""

import os
import sys
import json
import re
from abc import ABC, abstractmethod
from pathlib import Path
from typing import Dict, Any, List, Optional, Tuple
from datetime import datetime
from dataclasses import dataclass, field


@dataclass
class AgentResult:
    """Agent 실행 결과"""
    success: bool
    data: Dict[str, Any] = field(default_factory=dict)
    error: Optional[str] = None
    duration_ms: int = 0

    def to_dict(self) -> Dict[str, Any]:
        """딕셔너리 변환"""
        return {
            "success": self.success,
            "data": self.data,
            "error": self.error,
            "duration_ms": self.duration_ms
        }


@dataclass
class PRDContent:
    """PRD 파싱 결과"""
    raw: str
    frontmatter: Dict[str, Any] = field(default_factory=dict)
    sections: Dict[str, str] = field(default_factory=dict)
    feature_type: str = "unknown"

    @classmethod
    def from_file(cls, prd_path: Path) -> "PRDContent":
        """파일에서 PRD 로드

        Args:
            prd_path: PRD 파일 경로

        Returns:
            PRDContent: 파싱된 PRD
        """
        if not prd_path.exists():
            raise FileNotFoundError(f"PRD not found: {prd_path}")

        content = prd_path.read_text(encoding="utf-8")
        return cls.from_content(content)

    @classmethod
    def from_content(cls, content: str) -> "PRDContent":
        """내용에서 PRD 파싱

        Args:
            content: PRD 내용

        Returns:
            PRDContent: 파싱된 PRD
        """
        # YAML frontmatter 추출
        frontmatter_match = re.match(r"^---\n(.*?)\n---", content, re.DOTALL)
        frontmatter = {}
        body = content

        if frontmatter_match:
            yaml_content = frontmatter_match.group(1)
            frontmatter = cls._parse_simple_yaml(yaml_content)
            body = content[frontmatter_match.end():]

        # 섹션 추출
        sections = cls._extract_sections(body)

        # PRD 타입 감지
        feature_type = frontmatter.get("feature_type", cls._detect_type_from_content(sections))

        return cls(
            raw=content,
            frontmatter=frontmatter,
            sections=sections,
            feature_type=feature_type
        )

    @staticmethod
    def _parse_simple_yaml(yaml_content: str) -> Dict[str, Any]:
        """간단한 YAML 파서"""
        config = {}
        for line in yaml_content.split("\n"):
            if ":" in line and not line.strip().startswith("#"):
                key, value = line.split(":", 1)
                key = key.strip()
                value = value.strip()

                # 리스트 파싱
                if value.startswith("[") and value.endswith("]"):
                    value = [v.strip().strip('"\'') for v in value[1:-1].split(",") if v.strip()]
                # 문자열 따옴표 제거
                elif value.startswith('"') or value.startswith("'"):
                    value = value[1:-1]
                # 불리언
                elif value.lower() == "true":
                    value = True
                elif value.lower() == "false":
                    value = False

                config[key] = value

        return config

    @staticmethod
    def _extract_sections(body: str) -> Dict[str, str]:
        """마크다운 섹션 추출

        Args:
            body: 마크다운 본문

        Returns:
            Dict[str, str]: 섹션 이름 -> 내용
        """
        sections = {}
        current_section = "_intro"
        current_content = []

        for line in body.split("\n"):
            if line.startswith("## "):
                # 이전 섹션 저장
                if current_content:
                    sections[current_section] = "\n".join(current_content).strip()

                # 새 섹션 시작
                current_section = line[3:].strip()
                current_content = []
            else:
                current_content.append(line)

        # 마지막 섹션 저장
        if current_content:
            sections[current_section] = "\n".join(current_content).strip()

        return sections

    @staticmethod
    def _detect_type_from_content(sections: Dict[str, str]) -> str:
        """섹션 내용으로 PRD 타입 감지"""
        section_names = [name.lower() for name in sections.keys()]

        if "issue" in section_names or "root cause" in section_names:
            return "bug"
        if "current" in section_names and "proposed changes" in section_names:
            return "refactor"
        if "hypothesis" in section_names or "success criteria" in section_names:
            return "experiment"
        if "goal" in section_names or "requirements" in section_names:
            return "feature"

        return "unknown"


class BaseAgent(ABC):
    """Agent 기본 클래스"""

    # Agent 이름
    name: str = "base"

    # Agent 설명
    description: str = "Base agent"

    def __init__(self, project_root: Path = None):
        """초기화

        Args:
            project_root: 프로젝트 루트 경로
        """
        if project_root is None:
            self.project_root = Path.cwd()
        else:
            self.project_root = Path(project_root)

        self.log_dir = self.project_root / "logs"
        self.log_dir.mkdir(exist_ok=True)

    def log(self, message: str, level: str = "info"):
        """로그 출력

        Args:
            message: 로그 메시지
            level: 로그 레벨 (info, warning, error, success)
        """
        prefix_map = {
            "info": "\033[0;36m[INFO]\033[0m",
            "warning": "\033[1;33m[WARN]\033[0m",
            "error": "\033[0;31m[ERROR]\033[0m",
            "success": "\033[0;32m[✓]\033[0m",
            "step": "\033[0;35m[→]\033[0m",
        }
        prefix = prefix_map.get(level, f"[{level}]")
        print(f"{prefix} {message}")

    def get_prd_required_sections(self, prd_type: str) -> List[str]:
        """PRD 타입별 필수 섹션

        Args:
            prd_type: PRD 타입 (feature, bug, refactor, experiment)

        Returns:
            List[str]: 필수 섹션 목록
        """
        sections_map = {
            "feature": ["Goal", "Requirements", "Edge Cases", "Testing"],
            "bug": ["Issue", "Description", "Root Cause", "Fix Plan", "Testing"],
            "refactor": ["Current", "Issues", "Proposed Changes", "Impact", "Testing"],
            "experiment": ["Hypothesis", "Test Plan", "Success Criteria"],
        }
        return sections_map.get(prd_type, [])

    @abstractmethod
    def execute(self, prd: PRDContent, context: Dict[str, Any] = None) -> AgentResult:
        """Agent 실행

        Args:
            prd: 파싱된 PRD
            context: 추가 컨텍스트

        Returns:
            AgentResult: 실행 결과
        """
        pass

    def execute_with_timing(self, prd: PRDContent, context: Dict[str, Any] = None) -> AgentResult:
        """타이밍과 함께 Agent 실행

        Args:
            prd: 파싱된 PRD
            context: 추가 컨텍스트

        Returns:
            AgentResult: 실행 결과 (소요 시간 포함)
        """
        import time

        start_time = time.time()

        try:
            result = self.execute(prd, context or {})
        except Exception as e:
            result = AgentResult(
                success=False,
                error=f"Agent execution failed: {str(e)}"
            )

        end_time = time.time()
        result.duration_ms = int((end_time - start_time) * 1000)

        return result

    def save_result(self, result: AgentResult, stage: str, session_id: str = None):
        """결과 저장

        Args:
            result: 실행 결과
            stage: 스테이지 이름
            session_id: 세션 ID
        """
        if session_id is None:
            session_id = datetime.now().strftime("%Y%m%d-%H%M%S")

        log_file = self.log_dir / f"agent-{stage}-{session_id}.json"

        log_entry = {
            "agent": self.name,
            "stage": stage,
            "session_id": session_id,
            "timestamp": datetime.now().isoformat(),
            "result": result.to_dict()
        }

        with open(log_file, "w", encoding="utf-8") as f:
            json.dump(log_entry, f, indent=2, ensure_ascii=False)

        self.log(f"Result saved: {log_file}", "info")


def load_prd(prd_path: str) -> PRDContent:
    """PRD 로드 헬퍼

    Args:
        prd_path: PRD 파일 경로

    Returns:
        PRDContent: 파싱된 PRD
    """
    return PRDContent.from_file(Path(prd_path))
