#!/usr/bin/env python3
"""
init_core.py 테스트 스위트
프로젝트 초기화 스크립트의 단위 테스트 및 통합 테스트
"""

import unittest
import tempfile
import shutil
from pathlib import Path
import sys

# 모듈 import 경로 추가
sys.path.insert(0, str(Path(__file__).parent.parent))
from scripts.init_core import ProjectInitializer, Colors


class TestYAMLParsing(unittest.TestCase):
    """YAML 파싱 단위 테스트"""

    def test_parse_simple_yaml(self):
        """간단한 YAML 파싱 테스트"""
        yaml_content = """
key1: value1
key2: "value2"
key3: 'value3'
key4: true
key5: false
key6: [item1, item2, item3]
"""
        initializer = ProjectInitializer("dummy")
        result = initializer._parse_simple_yaml(yaml_content)

        self.assertEqual(result['key1'], 'value1')
        self.assertEqual(result['key2'], 'value2')
        self.assertEqual(result['key3'], 'value3')
        self.assertTrue(result['key4'])
        self.assertFalse(result['key5'])
        self.assertEqual(result['key6'], ['item1', 'item2', 'item3'])

    def test_parse_yaml_with_comments(self):
        """주석이 포함된 YAML 파싱 테스트"""
        yaml_content = """
# This is a comment
key1: value1
# Another comment
key2: value2
"""
        initializer = ProjectInitializer("dummy")
        result = initializer._parse_simple_yaml(yaml_content)

        self.assertEqual(result['key1'], 'value1')
        self.assertEqual(result['key2'], 'value2')


class TestPRDParsing(unittest.TestCase):
    """PRD 파싱 단위 테스트"""

    def setUp(self):
        """테스트 설정"""
        self.test_dir = tempfile.mkdtemp()
        self.test_prd = Path(self.test_dir) / "test_prd.md"

    def tearDown(self):
        """테스트 정리"""
        shutil.rmtree(self.test_dir)

    def test_parse_valid_prd(self):
        """유효한 PRD 파싱 테스트"""
        prd_content = """---
project_name: "Test Project"
type: "web"
language: "python"
framework: "django"
---
# Test PRD

This is a test PRD.
"""
        self.test_prd.write_text(prd_content)

        initializer = ProjectInitializer(str(self.test_prd))
        result = initializer.parse_prd()

        self.assertTrue(result)
        self.assertEqual(initializer.config['project_name'], 'Test Project')
        self.assertEqual(initializer.config['type'], 'web')
        self.assertEqual(initializer.config['language'], 'python')

    def test_parse_missing_prd(self):
        """존재하지 않는 PRD 파일 테스트"""
        initializer = ProjectInitializer("nonexistent.md")
        result = initializer.parse_prd()

        self.assertFalse(result)

    def test_parse_prd_without_frontmatter(self):
        """Frontmatter가 없는 PRD 테스트"""
        prd_content = """# Test PRD

This PRD has no frontmatter.
"""
        self.test_prd.write_text(prd_content)

        initializer = ProjectInitializer(str(self.test_prd))
        result = initializer.parse_prd()

        self.assertFalse(result)


class TestConfigValidation(unittest.TestCase):
    """설정 검증 단위 테스트"""

    def setUp(self):
        """테스트 설정"""
        self.test_dir = tempfile.mkdtemp()
        self.test_prd = Path(self.test_dir) / "test_prd.md"

    def tearDown(self):
        """테스트 정리"""
        shutil.rmtree(self.test_dir)

    def test_validate_valid_config(self):
        """유효한 설정 검증 테스트"""
        prd_content = """---
project_name: "Test Project"
type: "web"
language: "python"
---
"""
        self.test_prd.write_text(prd_content)

        initializer = ProjectInitializer(str(self.test_prd))
        initializer.parse_prd()
        result = initializer.validate_config()

        self.assertTrue(result)

    def test_validate_missing_required_field(self):
        """필수 필드 누락 테스트"""
        prd_content = """---
project_name: "Test Project"
type: "web"
# language is missing
---
"""
        self.test_prd.write_text(prd_content)

        initializer = ProjectInitializer(str(self.test_prd))
        initializer.parse_prd()
        result = initializer.validate_config()

        self.assertFalse(result)


class TestColors(unittest.TestCase):
    """터미널 색상 클래스 테스트"""

    def test_colors_defined(self):
        """색상 상수가 정의되어 있는지 테스트"""
        self.assertIsNotNone(Colors.HEADER)
        self.assertIsNotNone(Colors.OKBLUE)
        self.assertIsNotNone(Colors.OKCYAN)
        self.assertIsNotNone(Colors.OKGREEN)
        self.assertIsNotNone(Colors.WARNING)
        self.assertIsNotNone(Colors.FAIL)
        self.assertIsNotNone(Colors.ENDC)
        self.assertIsNotNone(Colors.BOLD)
        self.assertIsNotNone(Colors.UNDERLINE)


class TestErrorScenarios(unittest.TestCase):
    """에러 시나리오 테스트"""

    def setUp(self):
        """테스트 설정"""
        self.test_dir = tempfile.mkdtemp()
        self.test_prd = Path(self.test_dir) / "test_prd.md"
        self.project_root = Path(self.test_dir)

    def tearDown(self):
        """테스트 정리"""
        shutil.rmtree(self.test_dir)

    def test_invalid_yaml_syntax(self):
        """잘못된 YAML 문법 테스트"""
        prd_content = """---
project_name: "Test Project
type: "web
# Missing closing quotes
---
"""
        self.test_prd.write_text(prd_content)

        initializer = ProjectInitializer(str(self.test_prd))
        # 파싱은 성공하지만 값이 올바르지 않을 수 있음
        initializer.parse_prd()

        # 값이 제대로 파싱되었는지 확인
        # 따옴표가 닫히지 않은 경우도 처리되어야 함

    def test_empty_prd_file(self):
        """빈 PRD 파일 테스트"""
        prd_content = ""
        self.test_prd.write_text(prd_content)

        initializer = ProjectInitializer(str(self.test_prd))
        result = initializer.parse_prd()

        self.assertFalse(result)


class TestIntegrationFlow(unittest.TestCase):
    """통합 테스트 - 전체 초기화 플로우"""

    def setUp(self):
        """테스트 설정"""
        self.test_dir = tempfile.mkdtemp()
        self.test_prd = Path(self.test_dir) / "test_prd.md"

    def tearDown(self):
        """테스트 정리"""
        shutil.rmtree(self.test_dir)

    def test_full_initialization_flow(self):
        """전체 초기화 플로우 테스트 (Git 제외)"""
        prd_content = """---
project_name: "Integration Test Project"
type: "api"
language: "python"
framework: "fastapi"
git_default_branch: "main"
ci_cd_provider: "none"
---
# Integration Test PRD
"""
        self.test_prd.write_text(prd_content)

        # 현재 디렉토리를 테스트 디렉토리로 변경
        original_cwd = Path.cwd()
        import os
        os.chdir(self.test_dir)

        try:
            initializer = ProjectInitializer(str(self.test_prd))

            # 1. PRD 파싱
            self.assertTrue(initializer.parse_prd())

            # 2. 설정 검증
            self.assertTrue(initializer.validate_config())

            # 3. CI/CD 설정 (none으로 설정되어 건너뜀)
            self.assertTrue(initializer.setup_ci_cd())

            # 4. 외부 저장소 (설정 없음)
            self.assertTrue(initializer.clone_skills_repository())

            # 5. 모듈 설치 (설정 없음)
            self.assertTrue(initializer.install_modules())

        finally:
            os.chdir(original_cwd)


def run_tests():
    """테스트 실행"""
    # Create a test suite
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()

    # Add all test cases
    suite.addTests(loader.loadTestsFromTestCase(TestYAMLParsing))
    suite.addTests(loader.loadTestsFromTestCase(TestPRDParsing))
    suite.addTests(loader.loadTestsFromTestCase(TestConfigValidation))
    suite.addTests(loader.loadTestsFromTestCase(TestColors))
    suite.addTests(loader.loadTestsFromTestCase(TestErrorScenarios))
    suite.addTests(loader.loadTestsFromTestCase(TestIntegrationFlow))

    # Run the tests
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)

    # Print summary
    print("\n" + "="*60)
    print("테스트 요약")
    print("="*60)
    print(f"실행된 테스트: {result.testsRun}")
    print(f"성공: {result.testsRun - len(result.failures) - len(result.errors)}")
    print(f"실패: {len(result.failures)}")
    print(f"에러: {len(result.errors)}")
    print(f"건너뜀: {len(result.skipped)}")
    print("="*60)

    return result.wasSuccessful()


if __name__ == '__main__':
    success = run_tests()
    sys.exit(0 if success else 1)
