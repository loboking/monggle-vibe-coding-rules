#!/usr/bin/env bash
# test_helper.sh - bats 테스트 헬퍼 함수
# Vibe Coding Rules v2.4

# 프로젝트 루트 경로
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 내보내기
export PROJECT_ROOT
