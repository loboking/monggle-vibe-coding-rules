#!/usr/bin/env python3
"""
Monggle Vibe Coding Rules - Scan Agent
PRD와 현재 코드베이스를 분석하여 영향 범위를 파악
Python 3.8+ 호환
"""

import os
import re
import subprocess
from pathlib import Path
from typing import Dict, Any, List, Optional, Set
from dataclasses import dataclass, field

from base_agent import BaseAgent, PRDContent, AgentResult


@dataclass
class FileInfo:
    """파일 정보"""
    path: str
    change_type: str  # create, modify, delete
    lines_estimate: int = 0
    risk: str = "Low"  # Low, Medium, High


@dataclass
class Dependency:
    """의존성 정보"""
    type: str  # module, library, service
    name: str
    version: Optional[str] = None
    critical: bool = False


class ScanAgent(BaseAgent):
    """Scan Agent - 코드베이스 영향 분석"""

    name = "scan"
    description = "Analyze codebase impact and dependencies"

    # 스캔 대상 파일 확장자
    SOURCE_EXTENSIONS = {
        ".py", ".js", ".ts", ".tsx", ".jsx",
        ".java", ".kt", ".go", ".rs", ".c", ".cpp",
        ".h", ".hpp", ".cs", ".swift", ".rb", ".php"
    }

    # 제외 디렉토리
    EXCLUDE_DIRS = {
        "node_modules", "vendor", ".git", "__pycache__",
        "dist", "build", "target", "bin", "obj",
        ".venv", "venv", ".env", "env"
    }

    # 제외 파일 패턴
    EXCLUDE_PATTERNS = {
        "*.min.js", "*.min.css", "*.bundle.js",
        "*.pyc", "*.pyo", "*.class", "*.o", "*.so",
        "*.log", "*.tmp", "*.bak", "*.swp"
    }

    def __init__(self, project_root: Path = None):
        super().__init__(project_root)
        self.scanned_files: Set[Path] = set()
        self.import_map: Dict[str, Set[str]] = {}

    def execute(self, prd: PRDContent, context: Dict[str, Any] = None) -> AgentResult:
        """Scan Agent 실행

        Args:
            prd: 파싱된 PRD
            context: 추가 컨텍스트

        Returns:
            AgentResult: 분석 결과
        """
        self.log(f"Starting scan for PRD type: {prd.feature_type}", "step")

        # 1. PRD 분석
        prd_analysis = self._analyze_prd(prd)

        # 2. 코드베이스 스캔
        codebase_analysis = self._scan_codebase(prd)

        # 3. 의존성 분석
        dependencies = self._analyze_dependencies(codebase_analysis)

        # 4. 충돌 포인트 식별
        conflicts = self._identify_conflicts(prd, codebase_analysis)

        # 5. 복잡도 추정
        complexity = self._estimate_complexity(prd_analysis, codebase_analysis, conflicts)

        # 6. 작업량 추정
        estimates = self._estimate_work(codebase_analysis, complexity)

        result_data = {
            "analysis": prd_analysis,
            "affected_files": [
                {
                    "path": f.path,
                    "change_type": f.change_type,
                    "lines_estimate": f.lines_estimate,
                    "risk": f.risk
                }
                for f in codebase_analysis.get("affected_files", [])
            ],
            "dependencies": [
                {
                    "type": d.type,
                    "name": d.name,
                    "version": d.version,
                    "critical": d.critical
                }
                for d in dependencies
            ],
            "conflicts": conflicts,
            "complexity": complexity,
            "estimates": estimates,
            "stats": codebase_analysis.get("stats", {})
        }

        return AgentResult(success=True, data=result_data)

    def _analyze_prd(self, prd: PRDContent) -> Dict[str, Any]:
        """PRD 분석

        Args:
            prd: 파싱된 PRD

        Returns:
            Dict: 분석 결과
        """
        self.log("Analyzing PRD...", "step")

        # 키워드 추출
        keywords = self._extract_keywords(prd.raw)

        # 기술 스택 추출
        tech_stack = prd.frontmatter.get("tech_stack", [])
        if isinstance(tech_stack, str):
            tech_stack = [tech_stack]

        # 복잡도 요인 분석
        complexity_drivers = self._identify_complexity_drivers(prd)

        return {
            "goal": prd.sections.get("Goal", ""),
            "requirements": self._parse_requirements(prd),
            "tech_stack": tech_stack,
            "keywords": keywords,
            "complexity_drivers": complexity_drivers,
            "feature_type": prd.feature_type
        }

    def _extract_keywords(self, content: str) -> List[str]:
        """내용에서 키워드 추출"""
        # 일반적인 기술 키워드 패턴
        patterns = [
            r"\b(API|REST|GraphQL|SQL|NoSQL|JWT|OAuth|HTTPS|HTTP|WebSocket)\b",
            r"\b(authentication|authorization|database|migration|schema)\b",
            r"\b(frontend|backend|microservice|monolithic)\b",
        ]

        keywords = set()
        for pattern in patterns:
            matches = re.findall(pattern, content, re.IGNORECASE)
            keywords.update(matches)

        return sorted(keywords)

    def _parse_requirements(self, prd: PRDContent) -> List[str]:
        """요구사항 파싱"""
        requirements_section = prd.sections.get("Requirements", "")
        if not requirements_section:
            return []

        # 리스트 형식 파싱
        lines = requirements_section.split("\n")
        requirements = []
        for line in lines:
            line = line.strip()
            if line.startswith("-") or line.startswith("*"):
                requirements.append(line[1:].strip())
            elif line and not line.startswith("#"):
                requirements.append(line)

        return requirements

    def _identify_complexity_drivers(self, prd: PRDContent) -> List[str]:
        """복잡도 요인 식별"""
        drivers = []
        content = prd.raw.lower()

        # 보안 관련
        if any(word in content for word in ["auth", "security", "jwt", "oauth", "password", "token"]):
            drivers.append("보안")

        # 데이터베이스 관련
        if any(word in content for word in ["database", "migration", "schema", "sql", "query"]):
            drivers.append("데이터베이스")

        # 외부 API
        if any(word in content for word in ["external", "api", "integration", "webhook"]):
            drivers.append("외부 API")

        # 비동기/이벤트
        if any(word in content for word in ["async", "queue", "worker", "background"]):
            drivers.append("비동기 처리")

        # UI/복잡성
        if any(word in content for word in ["ui", "component", "layout", "responsive"]):
            drivers.append("UI 복잡성")

        return drivers

    def _scan_codebase(self, prd: PRDContent) -> Dict[str, Any]:
        """코드베이스 스캔

        Args:
            prd: 파싱된 PRD

        Returns:
            Dict: 스캔 결과
        """
        self.log("Scanning codebase...", "step")

        # Git 상태 확인
        git_status = self._get_git_status()

        # 소스 파일 발견
        source_files = self._find_source_files()

        # 영향받을 파일 추정
        affected_files = self._estimate_affected_files(prd, source_files)

        # 통계
        stats = {
            "total_source_files": len(source_files),
            "scanned_files": len(self.scanned_files),
            "git_dirty": len(git_status.get("modified", [])) > 0
        }

        return {
            "affected_files": affected_files,
            "source_files": [str(f) for f in source_files],
            "git_status": git_status,
            "stats": stats
        }

    def _get_git_status(self) -> Dict[str, List[str]]:
        """Git 상태 확인"""
        try:
            result = subprocess.run(
                ["git", "status", "--porcelain"],
                cwd=self.project_root,
                capture_output=True,
                text=True,
                timeout=10
            )

            if result.returncode != 0:
                return {"modified": [], "added": [], "deleted": []}

            modified = []
            added = []
            deleted = []

            for line in result.stdout.splitlines():
                if not line:
                    continue

                status = line[:2]
                path = line[3:]

                if "M" in status:
                    modified.append(path)
                if "A" in status:
                    added.append(path)
                if "D" in status:
                    deleted.append(path)

            return {
                "modified": modified,
                "added": added,
                "deleted": deleted
            }

        except (subprocess.TimeoutExpired, FileNotFoundError):
            return {"modified": [], "added": [], "deleted": []}

    def _find_source_files(self) -> List[Path]:
        """소스 파일 찾기"""
        source_files = []

        for root, dirs, files in os.walk(self.project_root):
            # 제외 디렉토리 필터링
            dirs[:] = [d for d in dirs if d not in self.EXCLUDE_DIRS]

            for file in files:
                file_path = Path(root) / file

                # 확장자 확인
                if file_path.suffix.lower() in self.SOURCE_EXTENSIONS:
                    source_files.append(file_path)
                    self.scanned_files.add(file_path)

        return source_files

    def _estimate_affected_files(self, prd: PRDContent, source_files: List[Path]) -> List[FileInfo]:
        """영향받을 파일 추정

        Args:
            prd: 파싱된 PRD
            source_files: 소스 파일 목록

        Returns:
            List[FileInfo]: 영향받을 파일 목록
        """
        affected = []
        content = prd.raw.lower()

        # PRD에서 언급된 파일/모듈 패턴
        mentioned_patterns = self._extract_file_patterns(prd)

        for source_file in source_files:
            # 상대 경로
            rel_path = str(source_file.relative_to(self.project_root))

            # PRD에서 직접 언급된 파일
            if any(pattern in rel_path.lower() for pattern in mentioned_patterns):
                affected.append(FileInfo(
                    path=rel_path,
                    change_type="modify",
                    risk="Medium"
                ))
                continue

            # 키워드 기반 매칭
            if self._matches_keywords(content, rel_path):
                affected.append(FileInfo(
                    path=rel_path,
                    change_type="modify",
                    lines_estimate=50,
                    risk="Low"
                ))

        # 새로 생성될 파일 추정
        new_files = self._estimate_new_files(prd)
        for new_file in new_files:
            affected.append(FileInfo(
                path=new_file,
                change_type="create",
                lines_estimate=150,
                risk="Medium"
            ))

        return affected

    def _extract_file_patterns(self, prd: PRDContent) -> List[str]:
        """PRD에서 파일 패턴 추출"""
        patterns = []

        # 일반적인 패턴
        for line in prd.raw.split("\n"):
            # 파일 경로처럼 보이는 패턴
            matches = re.findall(r"[\w/]+\.(py|js|ts|java|kt|go)", line)
            patterns.extend(matches)

            # 모듈명
            matches = re.findall(r"\b(auth|user|product|order|payment|api|service|model|controller)\b", line.lower())
            patterns.extend(matches)

        return list(set(patterns))

    def _matches_keywords(self, content: str, file_path: str) -> bool:
        """키워드 기반 파일 매칭"""
        file_lower = file_path.lower()

        keyword_map = {
            "auth": ["auth", "login", "user"],
            "database": ["model", "entity", "schema", "migration"],
            "api": ["api", "controller", "route", "endpoint"],
            "test": ["test", "spec"],
        }

        for keyword, patterns in keyword_map.items():
            if keyword in content:
                if any(p in file_lower for p in patterns):
                    return True

        return False

    def _estimate_new_files(self, prd: PRDContent) -> List[str]:
        """새로 생성될 파일 추정"""
        new_files = []

        # PRD 타입별 기본 파일
        type_files = {
            "feature": ["src/services/new_feature.py", "tests/test_new_feature.py"],
            "bug": [],
            "refactor": [],
            "experiment": ["experiments/new_experiment.py"]
        }

        new_files.extend(type_files.get(prd.feature_type, []))

        # 기술 스택별 추가
        tech_stack = prd.frontmatter.get("tech_stack", [])
        if isinstance(tech_stack, str):
            tech_stack = [tech_stack]

        for tech in tech_stack:
            tech_lower = tech.lower()
            if "python" in tech_lower or "fastapi" in tech_lower:
                new_files.append("src/api/routes/new_route.py")
            elif "javascript" in tech_lower or "typescript" in tech_lower:
                new_files.append("src/components/NewComponent.tsx")

        return new_files

    def _analyze_dependencies(self, codebase_analysis: Dict[str, Any]) -> List[Dependency]:
        """의존성 분석"""
        self.log("Analyzing dependencies...", "step")

        dependencies = []

        # Python 패키지
        requirements_files = [
            self.project_root / "requirements.txt",
            self.project_root / "pyproject.toml",
            self.project_root / "setup.py",
            self.project_root / "Pipfile"
        ]

        for req_file in requirements_files:
            if req_file.exists():
                deps = self._parse_python_requirements(req_file)
                dependencies.extend(deps)

        # JavaScript 패키지
        package_files = [
            self.project_root / "package.json",
            self.project_root / "yarn.lock"
        ]

        for pkg_file in package_files:
            if pkg_file.exists():
                deps = self._parse_js_package(pkg_file)
                dependencies.extend(deps)

        return dependencies

    def _parse_python_requirements(self, req_file: Path) -> List[Dependency]:
        """Python requirements 파일 파싱"""
        dependencies = []

        try:
            content = req_file.read_text(encoding="utf-8")

            for line in content.split("\n"):
                line = line.strip()
                if not line or line.startswith("#"):
                    continue

                # 패키지명 추출
                name = line.split(">")[0].split("<")[0].split("=")[0].split("[")[0].strip()

                # 중요 패키지 식별
                critical_packages = {"pytest", "fastapi", "django", "flask", "sqlalchemy"}
                critical = name.lower() in critical_packages

                dependencies.append(Dependency(
                    type="library",
                    name=name,
                    critical=critical
                ))

        except Exception:
            pass

        return dependencies

    def _parse_js_package(self, pkg_file: Path) -> List[Dependency]:
        """JavaScript package.json 파싱"""
        dependencies = []

        try:
            import json
            content = pkg_file.read_text(encoding="utf-8")
            pkg_data = json.loads(content)

            deps = pkg_data.get("dependencies", {})
            dev_deps = pkg_data.get("devDependencies", {})

            all_deps = {**deps, **dev_deps}

            for name, version in all_deps.items():
                critical_packages = {"react", "vue", "angular", "express", "next"}
                critical = name.lower() in critical_packages

                dependencies.append(Dependency(
                    type="library",
                    name=name,
                    version=version,
                    critical=critical
                ))

        except Exception:
            pass

        return dependencies

    def _identify_conflicts(self, prd: PRDContent, codebase_analysis: Dict[str, Any]) -> List[str]:
        """잠재적 충돌 식별"""
        self.log("Identifying potential conflicts...", "step")

        conflicts = []

        # Git 충돌 상태 확인
        git_status = codebase_analysis.get("git_status", {})
        if git_status.get("modified"):
            conflicts.append(f"Git에 {len(git_status['modified'])}개의 수정된 파일 존재")

        # PRD 기반 충돌 분석
        content = prd.raw.lower()

        if "database" in content and "migration" not in content:
            conflicts.append("데이터베이스 변경이 있으나 마이그레이션 계획 없음")

        if "auth" in content and "security" not in content:
            conflicts.append("인증 기능 변경이 있으나 보안 검토 계획 없음")

        # 의존성 충돌
        affected_files = codebase_analysis.get("affected_files", [])
        high_risk_files = [f for f in affected_files if getattr(f, "risk", "Low") == "High"]
        if high_risk_files:
            conflicts.append(f"{len(high_risk_files)}개의 고위험 파일 변경 예정")

        return conflicts

    def _estimate_complexity(
        self,
        prd_analysis: Dict[str, Any],
        codebase_analysis: Dict[str, Any],
        conflicts: List[str]
    ) -> str:
        """복잡도 추정"""
        self.log("Estimating complexity...", "step")

        score = 0

        # 요구사항 수
        requirements = prd_analysis.get("requirements", [])
        score += min(len(requirements) * 2, 20)

        # 복잡도 요인
        complexity_drivers = prd_analysis.get("complexity_drivers", [])
        score += len(complexity_drivers) * 5

        # 영향 파일 수
        affected_files = codebase_analysis.get("affected_files", [])
        score += min(len(affected_files) * 2, 30)

        # 충돌 수
        score += len(conflicts) * 10

        # 복잡도 결정
        if score >= 50:
            return "High"
        elif score >= 25:
            return "Medium"
        else:
            return "Low"

    def _estimate_work(self, codebase_analysis: Dict[str, Any], complexity: str) -> Dict[str, Any]:
        """작업량 추정"""
        affected_files = codebase_analysis.get("affected_files", [])

        # 기본 라인 수 추정
        total_lines = sum(
            getattr(f, "lines_estimate", 50) for f in affected_files
        )

        # 복잡도별 시간 배수
        complexity_multiplier = {
            "Low": 1.0,
            "Medium": 1.5,
            "High": 2.5
        }

        base_hours = max(1, total_lines / 50)
        estimated_hours = int(base_hours * complexity_multiplier.get(complexity, 1.0))

        return {
            "files_to_change": len(affected_files),
            "lines_to_change": total_lines,
            "estimated_hours": estimated_hours
        }


# CLI 인터페이스
def main():
    """CLI 진입점"""
    import sys
    from pathlib import Path

    if len(sys.argv) < 2:
        print("Usage: python scan_agent.py <prd_file>")
        sys.exit(1)

    prd_path = Path(sys.argv[1])
    if not prd_path.exists():
        print(f"PRD file not found: {prd_path}")
        sys.exit(1)

    agent = ScanAgent()
    prd = PRDContent.from_file(prd_path)
    result = agent.execute_with_timing(prd)

    print("\n=== Scan Result ===")
    print(json.dumps(result.data, indent=2, ensure_ascii=False))
    print(f"\nDuration: {result.duration_ms}ms")

    sys.exit(0 if result.success else 1)


if __name__ == "__main__":
    main()
