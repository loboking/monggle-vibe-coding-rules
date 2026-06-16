#!/usr/bin/env python3
"""
Monggle Vibe Coding Rules - Base Agent
모든 Agent의 기본 클래스 제공
시냅스 메모리 자동 주입 기능 포함
"""

import os
import json
from pathlib import Path
from typing import Dict, Any, Optional, List
from datetime import datetime
from abc import ABC, abstractmethod
from dataclasses import dataclass


@dataclass
class PRDContent:
    """PRD 컨텐츠 데이터 클래스"""
    feature_type: str = "feature"
    title: str = ""
    description: str = ""
    acceptance_criteria: List[str] = None
    technical_notes: List[str] = None
    raw_content: str = ""

    @classmethod
    def from_file(cls, path: Path) -> "PRDContent":
        """파일에서 PRD 로드"""
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()

        prd = cls(raw_content=content)

        # YAML 프론트매터 파싱
        lines = content.split("\n")
        frontmatter_lines = []
        body_lines = lines

        # 프론트매터는 파일 첫 줄이 '---'일 때만 인정 (마크다운 수평선 오인식 방지)
        if lines and lines[0].strip() == "---":
            for i in range(1, len(lines)):
                if lines[i].strip() == "---":
                    frontmatter_lines = lines[1:i]
                    body_lines = lines[i + 1:]
                    break

        # 프론트매터 파싱
        for line in frontmatter_lines:
            if ":" in line:
                key, value = line.split(":", 1)
                key = key.strip()
                value = value.strip().strip('"').strip("'")
                if key == "type" or key == "feature_type":
                    prd.feature_type = value
                elif key == "title":
                    prd.title = value

        prd.description = "\n".join(body_lines).strip()
        return prd


@dataclass
class AgentResult:
    """에이전트 실행 결과"""
    success: bool
    data: Dict[str, Any] = None
    error: Optional[str] = None
    execution_time: float = 0.0

    def __post_init__(self):
        if self.data is None:
            self.data = {}


class BaseAgent(ABC):
    """모든 에이전트의 기본 클래스"""

    def __init__(self, project_root: Path):
        """초기화

        Args:
            project_root: 프로젝트 루트 경로
        """
        self.project_root = Path(project_root)
        self.log_dir = self.project_root / "logs"
        self.log_dir.mkdir(exist_ok=True)

    @property
    @abstractmethod
    def agent_name(self) -> str:
        """에이전트 이름 (추상 프로퍼티)"""
        pass

    @abstractmethod
    def execute(self, prd: PRDContent, context: Dict[str, Any]) -> AgentResult:
        """에이전트 실행 로직 (추상 메서드)

        Args:
            prd: PRD 컨텐츠
            context: 실행 컨텍스트 (시냅스 메모리 포함)

        Returns:
            AgentResult: 실행 결과
        """
        pass

    def _build_system_prompt(self, prd: PRDContent, context: Dict[str, Any]) -> str:
        """시스템 프롬프트 생성

        Args:
            prd: PRD 컨텐츠
            context: 실행 컨텍스트

        Returns:
            str: 시스템 프롬프트
        """
        # 기본 시스템 프롬프트
        prompt = f"""# Vibe Coding Agent: {self.agent_name}

You are a specialized AI agent for the Vibe Coding Rules system.

## Current Task
- Type: {prd.feature_type}
- Title: {prd.title or 'N/A'}

## Instructions
Follow the Vibe Coding Rules v2.4 guidelines:
- Token-efficient output (diff-only preferred)
- Code-first approach
- No unnecessary features or changes
"""

        # 🧠 시냅스 메모리 주입 (v3.5)
        synapse_memory = context.get("synapse_memory", "")
        if synapse_memory:
            prompt += f"""
{synapse_memory}

IMPORTANT: Use the above synapse memory to inform your decisions about:
1. Which files to target for modification
2. Previous patterns and approaches that worked
3. Context from related past work
"""

        # PRD 설명 추가
        if prd.description:
            prompt += f"""

## PRD Description
{prd.description[:2000]}...
"""

        return prompt

    def execute_with_timing(self, prd: PRDContent, context: Dict[str, Any]) -> AgentResult:
        """타이밍 측정 포함 실행

        Args:
            prd: PRD 컨텐츠
            context: 실행 컨텍스트

        Returns:
            AgentResult: 실행 결과 (실행 시간 포함)
        """
        start_time = datetime.now()

        try:
            # 시냅스 메모리 로깅
            if context.get("synapse_memory"):
                print(f"  🧠 [{self.agent_name}] 시냅스 메모리 사용 중...")

            result = self.execute(prd, context)
            result.execution_time = (datetime.now() - start_time).total_seconds()
            return result

        except Exception as e:
            execution_time = (datetime.now() - start_time).total_seconds()
            return AgentResult(
                success=False,
                error=str(e),
                execution_time=execution_time
            )

    def log(self, message: str, level: str = "info"):
        """로그 출력"""
        prefix_map = {
            "info": f"[{self.agent_name}]",
            "warning": f"[{self.agent_name}] ⚠️",
            "error": f"[{self.agent_name}] ❌",
            "success": f"[{self.agent_name}] ✓",
        }
        prefix = prefix_map.get(level, f"[{self.agent_name}]")
        print(f"{prefix} {message}")

    def save_result(self, data: Dict[str, Any], stage: str):
        """결과 저장

        Args:
            data: 저장할 데이터
            stage: 스테이지 이름
        """
        result_file = self.log_dir / f"{stage}_result.json"
        with open(result_file, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)


class ScanAgent(BaseAgent):
    """Scan 단계 에이전트 - 코드베이스 분석"""

    @property
    def agent_name(self) -> str:
        return "ScanAgent"

    def execute(self, prd: PRDContent, context: Dict[str, Any]) -> AgentResult:
        """코드베이스 스캔 실행"""
        self.log(f"Scanning codebase for: {prd.title or prd.feature_type}")

        # 기본 스캔 로직
        try:
            affected_files = self._scan_files(prd)
            complexity = self._assess_complexity(affected_files)

            return AgentResult(
                success=True,
                data={
                    "affected_files": affected_files,
                    "complexity": complexity,
                    "prd_type": prd.feature_type,
                }
            )
        except Exception as e:
            return AgentResult(success=False, error=str(e))

    def _scan_files(self, prd: PRDContent) -> List[str]:
        """PRD와 관련된 파일 스캔"""
        # 간단 구현: 프로젝트의 주요 파일 목록 반환
        files = []
        for ext in [".py", ".kt", ".ts", ".tsx", ".js", ".jsx"]:
            files.extend(str(p) for p in self.project_root.rglob(f"*{ext}") if p.is_file())
        return files[:50]  # 최대 50개

    def _assess_complexity(self, files: List[str]) -> str:
        """복잡도 평가"""
        if len(files) < 10:
            return "Low"
        elif len(files) < 30:
            return "Medium"
        else:
            return "High"


class FoldAgent(BaseAgent):
    """Fold 단계 에이전트 - 요구사항 종합"""

    @property
    def agent_name(self) -> str:
        return "FoldAgent"

    def execute(self, prd: PRDContent, context: Dict[str, Any]) -> AgentResult:
        """요구사항 종합 실행"""
        self.log("Folding requirements...")

        scan_result = context.get("scan_result", {})

        return AgentResult(
            success=True,
            data={
                "feasibility": "High",
                "approach": "Standard implementation",
                "risk_assessment": {
                    "technical": "Low",
                    "operational": "Low"
                },
                "affected_files_count": len(scan_result.get("affected_files", [])),
            }
        )


class VerdictAgent(BaseAgent):
    """Verdict 단계 에이전트 - 최종 판단"""

    @property
    def agent_name(self) -> str:
        return "VerdictAgent"

    def execute(self, prd: PRDContent, context: Dict[str, Any]) -> AgentResult:
        """최종 판단 실행"""
        self.log("Evaluating PRD completeness...")

        # PRD 완성도 평가
        has_title = bool(prd.title)
        has_description = bool(prd.description and len(prd.description) > 100)

        confidence = 0.5
        if has_title:
            confidence += 0.2
        if has_description:
            confidence += 0.3

        verdict = "PASS" if confidence >= 0.9 else ("FIX" if confidence >= 0.5 else "FAIL")

        feedback = []
        if not has_title:
            feedback.append("Add a clear title to the PRD")
        if not has_description:
            feedback.append("Expand the description with more details")

        return AgentResult(
            success=True,
            data={
                "verdict": verdict,
                "confidence": confidence,
                "reasoning": f"PRD completeness score: {confidence:.2f}",
                "feedback": feedback,
            }
        )


class PatchAgent(BaseAgent):
    """Patch 단계 에이전트 - 구현"""

    @property
    def agent_name(self) -> str:
        return "PatchAgent"

    def execute(self, prd: PRDContent, context: Dict[str, Any]) -> AgentResult:
        """구현 실행"""
        self.log("Preparing implementation plan...")

        # 시냅스 메모리에서 타겟 파일 추론
        synapse = context.get("synapse_memory", "")
        target_files = []

        if synapse:
            # 과거 작업에서 언급된 파일 추론
            import re
            file_mentions = re.findall(r'[\w-]+\.(?:py|kt|ts|tsx|js)', synapse)
            target_files = list(set(file_mentions))[:5]

        return AgentResult(
            success=True,
            data={
                "implementation_plan": "Ready for implementation",
                "target_files": target_files,
                "synapse_used": bool(synapse),
            }
        )


class TraceAgent(BaseAgent):
    """Trace 단계 에이전트 - 로깅"""

    @property
    def agent_name(self) -> str:
        return "TraceAgent"

    def execute(self, prd: PRDContent, context: Dict[str, Any]) -> AgentResult:
        """로그 기록"""
        session_id = context.get("session_id", "unknown")

        self.log(f"Recording trace for session: {session_id}")

        return AgentResult(
            success=True,
            data={
                "session_id": session_id,
                "timestamp": datetime.now().isoformat(),
                "agent": self.agent_name,
            }
        )
