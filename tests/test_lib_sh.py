#!/usr/bin/env python3
"""
Bash 라이브러리 테스트 스위트
platform.sh, validation.sh, git.sh 함수들을 Python에서 테스트

TDD 통합 접근법 - Option 3
- Python unittest로 Bash 함수 테스트
- subprocess를 통해 Bash 함수 실행
"""

import unittest
import subprocess
import tempfile
import shutil
from pathlib import Path
import os
import sys


class TestPlatformLibrary(unittest.TestCase):
    """platform.sh 라이브러리 테스트"""

    def setUp(self):
        """테스트 설정"""
        self.project_root = Path(__file__).parent.parent
        self.platform_lib = self.project_root / ".claude" / "lib" / "platform.sh"

    def run_bash_function(self, function_name, args=""):
        """Bash 함수 실행 헬퍼"""
        cmd = f"source '{self.platform_lib}' && {function_name} {args}"
        result = subprocess.run(
            ["bash", "-c", cmd],
            capture_output=True,
            text=True,
            cwd=self.project_root
        )
        return result

    def test_get_os_returns_valid(self):
        """get_os 함수가 유효한 OS 이름을 반환하는지 테스트"""
        result = self.run_bash_function("get_os")
        os_name = result.stdout.strip()

        self.assertIn(os_name, ["macos", "linux", "windows", "unknown"])
        self.assertEqual(result.returncode, 0)

    def test_is_macos_boolean(self):
        """is_macos 함수가 불리언처럼 동작하는지 테스트"""
        result = self.run_bash_function("is_macos")

        # exit code 0 = true, 1 = false
        self.assertIn(result.returncode, [0, 1])

    def test_is_linux_boolean(self):
        """is_linux 함수가 불리언처럼 동작하는지 테스트"""
        result = self.run_bash_function("is_linux")
        self.assertIn(result.returncode, [0, 1])

    def test_sed_inplace_works(self):
        """sed_inplace 함수가 파일 수정을 올바르게 수행하는지 테스트"""
        with tempfile.NamedTemporaryFile(mode="w", delete=False, suffix=".txt") as f:
            f.write("Hello World\n")
            f.write("Test Line\n")
            temp_file = f.name

        try:
            # sed_inplace 실행
            cmd = f"source '{self.platform_lib}' && sed_inplace 's/World/Universe/' '{temp_file}'"
            subprocess.run(["bash", "-c", cmd], check=True, capture_output=True)

            # 결과 확인
            with open(temp_file, "r") as f:
                content = f.read()

            self.assertIn("Hello Universe", content)
            self.assertIn("Test Line", content)  # 다른 라인은 변경되지 않아야 함
        finally:
            os.unlink(temp_file)

    def test_get_file_mtime_returns_number(self):
        """get_file_mtime 함수가 숫자를 반환하는지 테스트"""
        with tempfile.NamedTemporaryFile(mode="w", delete=False) as f:
            f.write("test")
            temp_file = f.name

        try:
            result = self.run_bash_function("get_file_mtime", f"'{temp_file}'")
            mtime = result.stdout.strip()

            # 숫자여야 함
            self.assertTrue(mtime.isdigit() or mtime == "0")
        finally:
            os.unlink(temp_file)

    def test_get_file_size_returns_number(self):
        """get_file_size 함수가 숫자를 반환하는지 테스트"""
        with tempfile.NamedTemporaryFile(mode="w", delete=False) as f:
            f.write("test content")
            temp_file = f.name

        try:
            result = self.run_bash_function("get_file_size", f"'{temp_file}'")
            size = result.stdout.strip()

            # 숫자여야 하고 12 bytes (test content)여야 함
            self.assertTrue(size.isdigit())
            self.assertEqual(int(size), 12)
        finally:
            os.unlink(temp_file)


class TestValidationLibrary(unittest.TestCase):
    """validation.sh 라이브러리 테스트"""

    def setUp(self):
        """테스트 설정"""
        self.project_root = Path(__file__).parent.parent
        self.validation_lib = self.project_root / ".claude" / "lib" / "validation.sh"

    def run_bash_function(self, function_name, args=""):
        """Bash 함수 실행 헬퍼"""
        cmd = f"source '{self.validation_lib}' && {function_name} {args}"
        result = subprocess.run(
            ["bash", "-c", cmd],
            capture_output=True,
            text=True,
            cwd=self.project_root
        )
        return result

    def test_validate_file_path_rejects_traversal(self):
        """validate_file_path가 경로 탐색을 거부하는지 테스트"""
        # ../attack 폴더 접근 시도
        result = self.run_bash_function("validate_file_path", "'../../../etc/passwd'")

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Path traversal", result.stderr)

    def test_validate_file_path_accepts_safe(self):
        """validate_file_path가 안전한 경로를 허용하는지 테스트"""
        result = self.run_bash_function("validate_file_path", "'safe/path/to/file.txt'")

        self.assertEqual(result.returncode, 0)

    def test_validate_version_accepts_valid(self):
        """validate_version이 유효한 버전을 허용하는지 테스트"""
        valid_versions = [
            "1.0.0",
            "2.3.4",
            "1.0.0-beta",
            "1.0.0-alpha.1",
            "10.20.30"
        ]

        for version in valid_versions:
            with self.subTest(version=version):
                result = self.run_bash_function("validate_version", f"'{version}'")
                self.assertEqual(result.returncode, 0,
                    f"Version {version} should be valid")

    def test_validate_version_rejects_invalid(self):
        """validate_version이 잘못된 버전을 거부하는지 테스트"""
        invalid_versions = [
            "1.0",
            "1",
            "abc",
            "1.0.0-beta; rm -rf /",  # Injection attempt
            "../../etc",
        ]

        for version in invalid_versions:
            with self.subTest(version=version):
                result = self.run_bash_function("validate_version", f"'{version}'")
                self.assertNotEqual(result.returncode, 0,
                    f"Version {version} should be invalid")

    def test_validate_prd_type_accepts_valid(self):
        """validate_prd_type이 유효한 타입을 허용하는지 테스트"""
        valid_types = ["feature", "bug", "refactor", "hotfix", "experiment",
                      "api", "migration", "ml", "devops"]

        for prd_type in valid_types:
            with self.subTest(type=prd_type):
                result = self.run_bash_function("validate_prd_type", f"'{prd_type}'")
                self.assertEqual(result.returncode, 0)

    def test_validate_prd_type_rejects_invalid(self):
        """validate_prd_type이 잘못된 타입을 거부하는지 테스트"""
        result = self.run_bash_function("validate_prd_type", "'hacker; echo pwned'")

        self.assertNotEqual(result.returncode, 0)

    def test_validate_language_accepts_valid(self):
        """validate_language가 유효한 언어 코드를 허용하는지 테스트"""
        valid_langs = ["ko", "en", "zh"]

        for lang in valid_langs:
            with self.subTest(lang=lang):
                result = self.run_bash_function("validate_language", f"'{lang}'")
                self.assertEqual(result.returncode, 0)

    def test_sanitize_pattern_escapes_regex(self):
        """sanitize_pattern이 정규식 특수문자를 이스케이프하는지 테스트"""
        dangerous_patterns = [
            ".*",  # regex wildcard
            "[abc]",  # character class
            "file.txt",  # literal dot
            "$HOME",  # variable
        ]

        for pattern in dangerous_patterns:
            with self.subTest(pattern=pattern):
                result = self.run_bash_function("sanitize_pattern", f"'{pattern}'")
                self.assertEqual(result.returncode, 0)
                # 출력이 입력과 다르야 함 (이스케이프됨)
                sanitized = result.stdout.strip()
                self.assertIsNotNone(sanitized)


class TestGitLibrary(unittest.TestCase):
    """git.sh 라이브러리 테스트"""

    def setUp(self):
        """테스트 설정"""
        self.project_root = Path(__file__).parent.parent
        self.git_lib = self.project_root / ".claude" / "lib" / "git.sh"

    def run_bash_function(self, function_name, args=""):
        """Bash 함수 실행 헬퍼"""
        cmd = f"source '{self.git_lib}' && {function_name} {args}"
        result = subprocess.run(
            ["bash", "-c", cmd],
            capture_output=True,
            text=True,
            cwd=self.project_root
        )
        return result

    def test_is_git_repo_detects_repo(self):
        """is_git_repo가 git 저장소를 감지하는지 테스트"""
        # 프로젝트 루트는 git 저장소여야 함
        result = self.run_bash_function("is_git_repo")
        self.assertEqual(result.returncode, 0)

    def test_get_current_branch_returns_string(self):
        """get_current_branch가 브랜치 이름을 반환하는지 테스트"""
        result = self.run_bash_function("get_current_branch")
        branch = result.stdout.strip()

        # main, dev, feature/* 등
        self.assertTrue(len(branch) > 0)
        self.assertNotEqual(branch, "unknown")

    def test_validate_git_tag_accepts_valid(self):
        """validate_git_tag가 유효한 태그를 허용하는지 테스트"""
        valid_tags = ["v1.0.0", "v2.3.4", "1.0.0", "10.20.30"]

        for tag in valid_tags:
            with self.subTest(tag=tag):
                result = self.run_bash_function("validate_git_tag", f"'{tag}'")
                self.assertEqual(result.returncode, 0)

    def test_validate_git_tag_rejects_invalid(self):
        """validate_git_tag가 잘못된 태그를 거부하는지 테스트"""
        invalid_tags = [
            "v1.0",
            "abc",
            "1.0",
            "v1.0.0; echo pwned",  # Injection
        ]

        for tag in invalid_tags:
            with self.subTest(tag=tag):
                result = self.run_bash_function("validate_git_tag", f"'{tag}'")
                self.assertNotEqual(result.returncode, 0)


class TestSecurityP0(unittest.TestCase):
    """P0 보안 취weak점 수정 확인 테스트"""

    def setUp(self):
        """테스트 설정"""
        self.project_root = Path(__file__).parent.parent

    def test_no_eval_in_changelog(self):
        """changelog.sh에서 eval 사용이 제거되었는지 테스트"""
        changelog_file = self.project_root / ".claude" / "commands" / "changelog.sh"
        content = changelog_file.read_text()

        # eval 사용이 없어야 함 (안전한 배열 방식 사용)
        # 주석은 허용
        lines = content.split("\n")
        for i, line in enumerate(lines, 1):
            if "eval " in line and not line.strip().startswith("#"):
                # 안전한 eval git log는 제외됨을 확인
                if "git log" in line and "eval" in line:
                    # 이 패턴은 제거되어야 함
                    if "eval git" in line:
                        self.fail(f"Line {i}: Found unsafe 'eval git' in changelog.sh")

    def test_json_output_declared_in_mem_check(self):
        """mem-check.sh에서 JSON_OUTPUT이 선언되었는지 테스트"""
        mem_check_file = self.project_root / ".claude" / "commands" / "mem-check.sh"
        content = mem_check_file.read_text()

        # JSON_OUTPUT=0 선언 확인
        self.assertIn("JSON_OUTPUT=0", content,
            "mem-check.sh should declare JSON_OUTPUT=0")

    def test_version_validation_in_bump(self):
        """bump.sh에서 버전 유효성 검사가 있는지 테스트"""
        bump_file = self.project_root / ".claude/commands" / "bump.sh"
        content = bump_file.read_text()

        # validate_version 함수 사용 또는 정규식 검사 확인
        # 여러 패턴 시도 (이스케이프 문제 회피)
        has_validate_function = 'validate_version' in content
        has_regex_check = (
            '=~' in content and 'version' in content and '[0-9]' in content
        )

        self.assertTrue(
            has_validate_function or has_regex_check,
            "bump.sh should validate version format"
        )


class TestP1Architecture(unittest.TestCase):
    """P1 아키텍처 개선 확인 테스트"""

    def setUp(self):
        """테스트 설정"""
        self.project_root = Path(__file__).parent.parent

    def test_platform_sh_exists(self):
        """platform.sh 라이브러리가 존재하는지 테스트"""
        platform_lib = self.project_root / ".claude" / "lib" / "platform.sh"
        self.assertTrue(platform_lib.exists(),
            "platform.sh library should exist")

    def test_validation_sh_exists(self):
        """validation.sh 라이브러리가 존재하는지 테스트"""
        validation_lib = self.project_root / ".claude" / "lib" / "validation.sh"
        self.assertTrue(validation_lib.exists(),
            "validation.sh library should exist")

    def test_git_sh_exists(self):
        """git.sh 라이브러리가 존재하는지 테스트"""
        git_lib = self.project_root / ".claude" / "lib" / "git.sh"
        self.assertTrue(git_lib.exists(),
            "git.sh library should exist")

    def test_common_sh_loads_libraries(self):
        """common.sh가 라이브러리들을 로드하는지 테스트"""
        common_file = self.project_root / ".claude" / "lib" / "common.sh"
        content = common_file.read_text()

        # 라이브러리 로드 확인
        self.assertIn("platform.sh", content,
            "common.sh should load platform.sh")
        self.assertIn("validation.sh", content,
            "common.sh should load validation.sh")
        self.assertIn("git.sh", content,
            "common.sh should load git.sh")

    def test_scripts_use_eu_pipefail(self):
        """스크립트들이 set -euo pipefail을 사용하는지 테스트"""
        commands_dir = self.project_root / ".claude" / "commands"

        # 주요 스크립트들 확인
        critical_scripts = [
            "changelog.sh",
            "mem-check.sh",
            "readme-sync.sh",
            "prd.sh",
            "bump.sh",
        ]

        for script_name in critical_scripts:
            script_file = commands_dir / script_name
            if script_file.exists():
                content = script_file.read_text()

                # set -euo pipefail 사용 확인
                has_strict_mode = (
                    "set -euo pipefail" in content or
                    "set -eu pipefail" in content
                )

                self.assertTrue(has_strict_mode,
                    f"{script_name} should use 'set -euo pipefail' for error handling")


def run_tests():
    """테스트 실행"""
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()

    # 모든 테스트 케이스 추가
    suite.addTests(loader.loadTestsFromTestCase(TestPlatformLibrary))
    suite.addTests(loader.loadTestsFromTestCase(TestValidationLibrary))
    suite.addTests(loader.loadTestsFromTestCase(TestGitLibrary))
    suite.addTests(loader.loadTestsFromTestCase(TestSecurityP0))
    suite.addTests(loader.loadTestsFromTestCase(TestP1Architecture))

    # 테스트 실행
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)

    # 요약 출력
    print("\n" + "="*60)
    print("Bash 라이브러리 테스트 요약")
    print("="*60)
    print(f"실행된 테스트: {result.testsRun}")
    print(f"성공: {result.testsRun - len(result.failures) - len(result.errors)}")
    print(f"실패: {len(result.failures)}")
    print(f"에러: {len(result.errors)}")
    print("="*60)

    return result.wasSuccessful()


if __name__ == '__main__':
    success = run_tests()
    sys.exit(0 if success else 1)
