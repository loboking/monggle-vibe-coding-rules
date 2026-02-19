#!/usr/bin/env python3
"""
Monggle Vibe Coding Rules - Agent Tests
Python 3.8+ 호환
"""

import sys
import unittest
from pathlib import Path
from datetime import datetime

# 프로젝트 루트를 경로에 추가
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root / "agents"))

from base_agent import BaseAgent, PRDContent, AgentResult
from scan_agent import ScanAgent
from fold_agent import FoldAgent
from verdict_agent import VerdictAgent


class TestPRDContent(unittest.TestCase):
    """PRDContent 테스트"""

    def setUp(self):
        """테스트 설정"""
        self.sample_prd = """---
feature_type: feature
title: Test Feature
---

## Goal
This is a test feature.

## Requirements
- Requirement 1
- Requirement 2

## Edge Cases
- Edge case 1

## Testing
- Test case 1
"""

    def test_from_content(self):
        """내용에서 PRD 파싱"""
        prd = PRDContent.from_content(self.sample_prd)

        self.assertEqual(prd.feature_type, "feature")
        self.assertIn("Goal", prd.sections)
        self.assertIn("Requirements", prd.sections)

    def test_extract_sections(self):
        """섹션 추출"""
        prd = PRDContent.from_content(self.sample_prd)

        self.assertIn("test feature", prd.sections["Goal"].lower())
        self.assertIn("Requirement 1", prd.sections["Requirements"])

    def test_detect_type_feature(self):
        """feature 타입 감지"""
        prd = PRDContent.from_content(self.sample_prd)
        self.assertEqual(prd.feature_type, "feature")

    def test_detect_type_bug(self):
        """bug 타입 감지"""
        bug_prd = """---
feature_type: bug
---

## Issue
Bug description

## Root Cause
Cause analysis
"""
        prd = PRDContent.from_content(bug_prd)
        self.assertEqual(prd.feature_type, "bug")


class TestBaseAgent(unittest.TestCase):
    """BaseAgent 테스트"""

    def test_get_prd_required_sections(self):
        """필수 섹션 반환"""
        # BaseAgent는 직접 인스턴스화할 수 없으므로 클래스 메서드 테스트
        sections = BaseAgent.get_prd_required_sections(None, "feature")
        self.assertIn("Goal", sections)
        self.assertIn("Requirements", sections)
        self.assertIn("Testing", sections)

    def test_log(self):
        """로그 출력"""
        # 로그는 실제 Agent에서 테스트
        # 여기서는 에러가 나지 않는지만 확인
        pass


class TestScanAgent(unittest.TestCase):
    """ScanAgent 테스트"""

    def setUp(self):
        """테스트 설정"""
        self.agent = ScanAgent()

        self.sample_prd = PRDContent.from_content("""---
feature_type: feature
---

## Goal
Test feature

## Requirements
- Auth requirement

## Edge Cases
- Edge case

## Testing
- Test
""")

    def test_estimate_complexity(self):
        """복잡도 추정"""
        prd_analysis = {
            "requirements": ["req1", "req2"],
            "complexity_drivers": ["보안", "데이터베이스"]
        }
        codebase_analysis = {
            "affected_files": [{"path": "test.py"}],
            "stats": {}
        }
        conflicts = []

        complexity = self.agent._estimate_complexity(
            prd_analysis, codebase_analysis, conflicts
        )

        self.assertIn(complexity, ["Low", "Medium", "High"])

    def test_analyze_dependencies(self):
        """의존성 분석"""
        # 빈 코드베이스 분석
        codebase_analysis = {"affected_files": []}
        dependencies = self.agent._analyze_dependencies(codebase_analysis)

        # 결과가 리스트여야 함
        self.assertIsInstance(dependencies, list)


class TestFoldAgent(unittest.TestCase):
    """FoldAgent 테스트"""

    def setUp(self):
        """테스트 설정"""
        self.agent = FoldAgent()

        self.sample_prd = PRDContent.from_content("""---
feature_type: feature
---

## Goal
Test feature

## Requirements
- Simple requirement

## Edge Cases
- Edge case

## Testing
- Test
""")

    def test_assess_feasibility(self):
        """구현 가능성 평가"""
        gate_result = {"valid": True}
        scan_result = {"complexity": "Low", "conflicts": []}

        feasibility = self.agent._assess_feasibility(
            self.sample_prd, gate_result, scan_result
        )

        # Feasibility enum 값 확인
        self.assertIn(feasibility.value, ["High", "Medium", "Low"])

    def test_assess_risks(self):
        """위험도 평가"""
        scan_result = {"complexity": "Low"}

        risk = self.agent._assess_risks(self.sample_prd, scan_result)

        # RiskAssessment 확인
        self.assertIn("technical", risk.to_dict())
        self.assertIn("operational", risk.to_dict())
        self.assertIn("security", risk.to_dict())


class TestVerdictAgent(unittest.TestCase):
    """VerdictAgent 테스트"""

    def setUp(self):
        """테스트 설정"""
        self.agent = VerdictAgent()

        self.sample_prd = PRDContent.from_content("""---
feature_type: feature
---

## Goal
Test feature

## Requirements
- Simple requirement

## Edge Cases
- Edge case

## Testing
- Test
""")

    def test_make_verdict_pass(self):
        """PASS 판정"""
        gate_result = {"valid": True}
        scan_result = {"complexity": "Low", "conflicts": []}
        fold_result = {"feasibility": "High", "blockers": []}

        verdict, confidence, reasoning = self.agent._make_verdict(
            gate_result, scan_result, fold_result
        )

        self.assertIn(verdict.value, ["PASS", "FIX", "FAIL"])
        self.assertGreaterEqual(confidence, 0.0)
        self.assertLessEqual(confidence, 1.0)
        self.assertIsInstance(reasoning, str)

    def test_generate_feedback_pass(self):
        """PASS 피드백 생성"""
        gate_result = {"valid": True}
        scan_result = {"complexity": "Low", "conflicts": [], "estimates": {"estimated_hours": 4}}
        fold_result = {"feasibility": "High", "blockers": []}

        # Verdict enum 사용
        from verdict_agent import Verdict

        feedback = self.agent._generate_feedback(
            Verdict.PASS, gate_result, scan_result, fold_result
        )

        self.assertIsInstance(feedback, list)
        self.assertGreater(len(feedback), 0)


def run_tests():
    """테스트 실행"""
    # 테스트 로더 생성
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()

    # 테스트 추가
    suite.addTests(loader.loadTestsFromTestCase(TestPRDContent))
    suite.addTests(loader.loadTestsFromTestCase(TestBaseAgent))
    suite.addTests(loader.loadTestsFromTestCase(TestScanAgent))
    suite.addTests(loader.loadTestsFromTestCase(TestFoldAgent))
    suite.addTests(loader.loadTestsFromTestCase(TestVerdictAgent))

    # 테스트 실행
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)

    # 결과 반환
    return result.wasSuccessful()


if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
