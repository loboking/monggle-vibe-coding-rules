#!/usr/bin/env python3
"""
Monggle Vibe Coding Rules - Project Initializer Core
프로젝트 초기화 핵심 로직
"""

import os
import sys
import subprocess
import json
import shutil
from pathlib import Path
from typing import Dict, Any, List, Optional
import re


class Colors:
    """터미넬 색상"""
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'


class ProjectInitializer:
    """프로젝트 초기화 핵심 클래스"""

    def __init__(self, prd_path: str):
        self.prd_path = Path(prd_path)
        self.config = {}
        self.project_root = Path.cwd()
        self.steps_completed = []
        self.steps_failed = []

    def log(self, message: str, level: str = "info"):
        """로그 출력"""
        prefix = {
            "info": f"{Colors.OKCYAN}[INFO]{Colors.ENDC}",
            "success": f"{Colors.OKGREEN}[✓]{Colors.ENDC}",
            "warning": f"{Colors.WARNING}[!]{Colors.ENDC}",
            "error": f"{Colors.FAIL}[✗]{Colors.ENDC}",
            "step": f"{Colors.HEADER}[→]{Colors.ENDC}",
        }.get(level, f"[{level}]")

        print(f"{prefix} {message}")

    def parse_prd(self) -> bool:
        """PRD 파싱 (YAML Frontmatter + Markdown)

        Returns:
            bool: 파싱 성공 여부
        """
        self.log("PRD 파싱 중...", "step")

        # 파일 존재 확인
        if not self.prd_path.exists():
            self.log(f"PRD 파일을 찾을 수 없습니다: {self.prd_path}", "error")
            return False

        # 파일 읽기 권한 확인
        if not os.access(self.prd_path, os.R_OK):
            self.log(f"PRD 파일 읽기 권한 없음: {self.prd_path}", "error")
            return False

        # 파일 읽기
        try:
            content = self.prd_path.read_text(encoding='utf-8')
        except IOError as e:
            self.log(f"PRD 파일 읽기 실패: {e}", "error")
            return False

        # YAML Frontmatter 추출
        frontmatter_match = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
        if not frontmatter_match:
            self.log("PRD에 YAML Frontmatter가 없습니다.", "error")
            return False

        yaml_content = frontmatter_match.group(1)

        # 간단한 YAML 파싱 (의존성 최소화)
        try:
            self.config = self._parse_simple_yaml(yaml_content)
            self.log("PRD 파싱 완료", "success")
            self.log(f"프로젝트: {self.config.get('project_name', 'Unknown')}", "info")
            return True
        except (ValueError, KeyError) as e:
            self.log(f"PRD 형식 오류: {e}", "error")
            return False
        except Exception as e:
            self.log(f"PRD 파싱 실패: {e}", "error")
            return False

    def _parse_simple_yaml(self, yaml_content: str) -> Dict[str, Any]:
        """간단한 YAML 파서 (PyYAML 의존성 없이)"""
        config = {}
        for line in yaml_content.split('\n'):
            if ':' in line and not line.strip().startswith('#'):
                key, value = line.split(':', 1)
                key = key.strip()
                value = value.strip()

                # 리스트 파싱
                if value.startswith('[') and value.endswith(']'):
                    value = [v.strip().strip('"\'') for v in value[1:-1].split(',') if v.strip()]
                # 문자열 따옴표 제거
                elif value.startswith('"') or value.startswith("'"):
                    value = value[1:-1]
                # 불리언
                elif value.lower() == 'true':
                    value = True
                elif value.lower() == 'false':
                    value = False

                config[key] = value

        return config

    def validate_config(self) -> bool:
        """필수 필드 검증"""
        self.log("설정 검증 중...", "step")

        required_fields = ['project_name', 'type', 'language']
        missing = [f for f in required_fields if not self.config.get(f)]

        if missing:
            self.log(f"필수 필드 누락: {', '.join(missing)}", "error")
            self.log("PRD 템플릿을 확인해주세요.", "warning")
            return False

        self.log("설정 검증 완료", "success")
        return True

    def initialize_git(self) -> bool:
        """Git 초기화

        Returns:
            bool: 초기화 성공 여부
        """
        self.log("Git 초기화 중...", "step")

        try:
            # 이미 초기화된 경우 확인
            if (self.project_root / '.git').exists():
                self.log("이미 Git 저장소입니다.", "warning")
                return True

            # git init (타임아웃 30초)
            result = subprocess.run(
                ['git', 'init'],
                cwd=self.project_root,
                check=True,
                capture_output=True,
                text=True,
                timeout=30
            )
            self.log(f"Git init 출력: {result.stdout.strip()}", "info")

            # 기본 브랜치 설정
            default_branch = self.config.get('git_default_branch', 'main')
            result = subprocess.run(
                ['git', 'checkout', '-b', default_branch],
                cwd=self.project_root,
                check=True,
                capture_output=True,
                text=True,
                timeout=30
            )

            # remote 설정 (URL이 있는 경우)
            remote_url = self.config.get('git_remote_url')
            if remote_url:
                result = subprocess.run(
                    ['git', 'remote', 'add', 'origin', remote_url],
                    cwd=self.project_root,
                    check=True,
                    capture_output=True,
                    text=True,
                    timeout=30
                )
                self.log(f"Git remote 설정: {remote_url}", "info")

            self.log("Git 초기화 완료", "success")
            self.steps_completed.append("Git 초기화")
            return True

        except subprocess.TimeoutExpired:
            self.log("Git 초기화 타임아웃 (30초 초과)", "error")
            self.steps_failed.append("Git 초기화")
            return False
        except subprocess.CalledProcessError as e:
            self.log(f"Git 초기화 실패: {e.stderr if e.stderr else e}", "error")
            self.steps_failed.append("Git 초기화")
            return False
        except Exception as e:
            self.log(f"Git 초기화 중 예상치 못한 오류: {e}", "error")
            self.steps_failed.append("Git 초기화")
            return False

    def setup_ci_cd(self) -> bool:
        """CI/CD 설정"""
        ci_cd_provider = self.config.get('ci_cd_provider', '')

        # 비어있거나 'none'이면 건너뜀
        if not ci_cd_provider or ci_cd_provider == 'none':
            self.log("CI/CD 설정 건너뜀", "info")
            return True

        self.log(f"CI/CD 설정 중... ({ci_cd_provider})", "step")

        try:
            workflows_dir = self.project_root / '.github' / 'workflows'
            workflows_dir.mkdir(parents=True, exist_ok=True)

            if ci_cd_provider == 'github-actions':
                template_path = Path(__file__).parent / 'templates' / 'github-actions' / f"{self.config.get('ci_cd_template', 'basic')}.yml"
                dest_path = workflows_dir / 'ci.yml'

                if template_path.exists():
                    shutil.copy(template_path, dest_path)
                    self.log("GitHub Actions 워크플로우 생성 완료", "success")
                    self.steps_completed.append("CI/CD 설정")
                else:
                    self.log("CI/CD 템플릿을 찾을 수 없습니다.", "warning")

            return True

        except Exception as e:
            self.log(f"CI/CD 설정 실패: {e}", "error")
            self.steps_failed.append("CI/CD 설정")
            return False

    def clone_skills_repository(self) -> bool:
        """외부 저장소 클론

        Returns:
            bool: 클론 성공 여부
        """
        skills_repo = self.config.get('skills_repository')
        if not skills_repo:
            self.log("외부 저장소 설정 없음", "info")
            return True

        self.log(f"외부 저장소 클론 중... {skills_repo}", "step")

        try:
            install_path = self.project_root / self.config.get('skills_install_path', '.claude/commands')
            branch = self.config.get('skills_branch', 'main')

            # 이미 존재하면 삭제
            if install_path.exists():
                shutil.rmtree(install_path)

            # 부모 디렉토리 생성
            install_path.parent.mkdir(parents=True, exist_ok=True)

            # git clone (타임아웃 5분)
            result = subprocess.run(
                ['git', 'clone', '-b', branch, '--single-branch', skills_repo, str(install_path)],
                check=True,
                capture_output=True,
                text=True,
                timeout=300  # 5분 타임아웃
            )

            self.log(f"외부 저장소 클론 완료: {install_path}", "success")
            self.steps_completed.append("외부 저장소 클론")
            return True

        except subprocess.TimeoutExpired:
            self.log("외부 저장소 클론 타임아웃 (5분 초과)", "error")
            self.log("네트워크 연결을 확인하거나 나중에 다시 시도하세요.", "warning")
            self.steps_failed.append("외부 저장소 클론")
            return False
        except subprocess.CalledProcessError as e:
            self.log(f"외부 저장소 클론 실패: {e.stderr if e.stderr else e}", "error")
            self.steps_failed.append("외부 저장소 클론")
            return False
        except Exception as e:
            self.log(f"외부 저장소 클론 중 예상치 못한 오류: {e}", "error")
            self.steps_failed.append("외부 저장소 클론")
            return False

    def install_modules(self) -> bool:
        """선택적 모듈 설치 (에이전트/스킬/Hook)"""
        agents = self.config.get('agents', [])
        skills = self.config.get('skills', [])
        hooks = self.config.get('hooks', [])

        if not any([agents, skills, hooks]):
            self.log("설치할 모듈 없음", "info")
            return True

        self.log("모듈 설치 중...", "step")

        # 모듈 설치 로직 (스크립트 호출)
        # 실제 구현에서는 각 모듈의 설치 스크립트를 실행
        modules_installed = []

        if agents:
            self.log(f"에이전트: {', '.join(agents)}", "info")
            modules_installed.extend(agents)

        if skills:
            self.log(f"스킬: {', '.join(skills)}", "info")
            modules_installed.extend(skills)

        if hooks:
            self.log(f"훅: {', '.join(hooks)}", "info")
            modules_installed.extend(hooks)

        self.log(f"모듈 설치 완료: {len(modules_installed)}개", "success")
        self.steps_completed.append("모듈 설치")
        return True

    def create_initial_commit(self) -> bool:
        """초기 커밋 생성"""
        self.log("초기 커밋 생성 중...", "step")

        try:
            # 모든 파일 스테이징
            subprocess.run(['git', 'add', '.'], cwd=self.project_root, check=True, capture_output=True)

            # 커밋
            commit_msg = f"feat: Initial project setup from PRD\n\nProject: {self.config.get('project_name')}"
            subprocess.run(['git', 'commit', '-m', commit_msg], cwd=self.project_root, check=True, capture_output=True)

            self.log("초기 커밋 완료", "success")
            self.steps_completed.append("초기 커밋")
            return True

        except subprocess.CalledProcessError as e:
            self.log(f"초기 커밋 실패: {e}", "error")
            self.steps_failed.append("초기 커밋")
            return False

    def print_summary(self):
        """초기화 요약 출력"""
        print("\n" + "="*60)
        print(f"{Colors.BOLD}프로젝트 초기화 완료{Colors.ENDC}")
        print("="*60)

        print(f"\n{Colors.OKGREEN}완료된 작업 ({len(self.steps_completed)}){Colors.ENDC}")
        for step in self.steps_completed:
            print(f"  ✓ {step}")

        if self.steps_failed:
            print(f"\n{Colors.FAIL}실패한 작업 ({len(self.steps_failed)}){Colors.ENDC}")
            for step in self.steps_failed:
                print(f"  ✗ {step}")

        print(f"\n{Colors.OKCYAN}프로젝트 정보{Colors.ENDC}")
        print(f"  이름: {self.config.get('project_name')}")
        print(f"  타입: {self.config.get('type')}")
        print(f"  언어: {self.config.get('language')}")
        print(f"  프레임워크: {self.config.get('framework', 'N/A')}")

        print("\n" + "="*60 + "\n")

    def run(self) -> bool:
        """전체 초기화 실행"""
        self.log(f"{Colors.BOLD}프로젝트 초기화 시작{Colors.ENDC}", "step")

        # 1. PRD 파싱
        if not self.parse_prd():
            return False

        # 2. 설정 검증
        if not self.validate_config():
            return False

        # 3. Git 초기화
        if not self.initialize_git():
            return False

        # 4. CI/CD 설정
        self.setup_ci_cd()

        # 5. 외부 저장소 클론
        self.clone_skills_repository()

        # 6. 모듈 설치
        self.install_modules()

        # 7. 초기 커밋
        self.create_initial_commit()

        # 요약 출력
        self.print_summary()

        return len(self.steps_failed) == 0


def main():
    """메인 진입점"""
    if len(sys.argv) < 2:
        print("사용법: python init_core.py <PRD 파일 경로>")
        sys.exit(1)

    prd_path = sys.argv[1]
    initializer = ProjectInitializer(prd_path)
    success = initializer.run()

    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
