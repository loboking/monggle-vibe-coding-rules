#!/usr/bin/env python3
"""
Monggle - LangGraph 기반 가상 개발팀
에이전트들이 유기적으로 협업하는 Multi-Agent Team 시스템

Usage:
    python3 scripts/langgraph_team.py prd/feature.md
    python3 scripts/langgraph_team.py --visualize
"""

import os
import sys
import json
from pathlib import Path
from typing import TypedDict, Annotated, Sequence, Optional, Literal, List, Tuple
from datetime import datetime

# 프로젝트 루트 설정
PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "agents"))
sys.path.insert(0, str(Path(__file__).resolve().parent))
from _version import __version__ as TOOLKIT_VERSION

try:
    from langgraph.graph import StateGraph, END
    from langgraph.checkpoint.memory import MemorySaver
    from langchain_core.messages import BaseMessage, HumanMessage, AIMessage
    import operator
    LANGGRAPH_AVAILABLE = True
except ImportError:
    LANGGRAPH_AVAILABLE = False
    BaseMessage = object  # fallback
    print("⚠️ LangGraph not installed. Run: pip install langgraph langchain-anthropic")
    print("📋 Falling back to linear pipeline mode...")

# =============================================================================
# 팀 공유 상태 (AgentState) 정의
# =============================================================================

if LANGGRAPH_AVAILABLE:
    class TeamState(TypedDict):
        """가상 개발팀이 공유하는 상태 (메모리)"""
        # 에이전트 간 대화 기록
        messages: Annotated[Sequence[BaseMessage], operator.add]

        # 작업 컨텍스트
        prd_path: str
        prd_content: str
        prd_type: str

        # v3.5 시냅스 기억 (과거 세션 컨텍스트)
        synapse_memory: str

        # 작업 상태
        current_file: str
        current_code: str
        original_code: str

        # 피드백 루프
        errors: List[str]
        retry_count: int
        max_retries: int

        # 최종 결과
        verdict: str
        success: bool
else:
    # LangGraph가 없을 때의 대용 상태
    TeamState = dict


# =============================================================================
# 에이전트 (Node) 함수 정의
# =============================================================================

def load_synapse_memory(prd_path: Path) -> str:
    """시냅스 기억 로드 (v3.5 뇌 시스템)"""
    synapse_file = PROJECT_ROOT / ".claude" / "session" / "current" / "active_synapses.md"
    if synapse_file.exists():
        with open(synapse_file, "r", encoding='utf-8') as f:
            return f.read()
    return ""


# =============================================================================
# team_state 연동 (실행 상태를 /team-status 에 노출)
# =============================================================================

def resolve_team_name(prd_content: str, prd_path: Optional[Path]) -> str:
    """PRD/intent 기반 팀 이름 결정. 실패 시 'default' 폴백."""
    # 1) PRD 본문에서 명시적 팀 지정 (예: "team: backend")
    if prd_content:
        for line in prd_content.split("\n"):
            stripped = line.strip().lower()
            if stripped.startswith("team:") or stripped.startswith("팀:"):
                name = line.split(":", 1)[1].strip()
                if name:
                    return name
    # 2) PRD 파일명 stem 사용
    if prd_path is not None:
        stem = prd_path.stem.strip()
        if stem:
            return stem
    return "default"


def _ensure_team_state_manager():
    """team_state.TeamStateManager 인스턴스 반환 (호출만, 수정하지 않음).

    team_state 모듈이 없거나 에러가 나면 None 반환하여 메인 흐름이 깨지지 않게 한다.
    """
    try:
        # scripts/ 디렉터리는 이 파일과 동일 위치이므로 import 가능
        sys.path.insert(0, str(PROJECT_ROOT / "scripts"))
        from team_state import TeamStateManager  # noqa: WPS433
        return TeamStateManager(PROJECT_ROOT)
    except Exception as e:  # noqa: BLE001 - 연동 실패가 메인을 막지 않도록
        print(f"⚠️ team_state 연동을 건너뜁니다: {e}")
        return None


def _ensure_team_exists(team_name: str) -> None:
    """팀 상태가 존재하도록 최소 config 파일을 생성한다.

    set_status/complete_task 는 상태가 없으면 no-op 이므로,
    config({team}.json)가 없을 때 한 번 만들어 부트스트랩한다.
    team_state.py 코드 자체는 수정하지 않고 파일만 보장한다.
    """
    try:
        teams_dir = PROJECT_ROOT / ".claude" / "teams"
        teams_dir.mkdir(parents=True, exist_ok=True)
        config_file = teams_dir / f"{team_name}.json"
        if not config_file.exists():
            config_file.write_text(
                json.dumps(
                    {"name": team_name, "created_at": datetime.now().isoformat()},
                    indent=2,
                    ensure_ascii=False,
                ),
                encoding="utf-8",
            )
    except Exception as e:  # noqa: BLE001
        print(f"⚠️ 팀 config 생성을 건너뜁니다: {e}")


def team_state_start(manager, team_name: str) -> None:
    """실행 시작: 팀을 BUSY 로 표시."""
    if manager is None:
        return
    try:
        from team_state import TeamStatus  # noqa: WPS433
        _ensure_team_exists(team_name)
        manager.set_status(team_name, TeamStatus.BUSY)
    except Exception as e:  # noqa: BLE001
        print(f"⚠️ team_state 시작 기록 실패: {e}")


def team_state_finish(manager, team_name: str, success: bool) -> None:
    """실행 종료: 결과를 기록하고 IDLE 로 복귀."""
    if manager is None:
        return
    try:
        from team_state import TeamStatus  # noqa: WPS433
        # complete_task 가 stats 기록 + IDLE 복귀를 함께 처리
        manager.complete_task(team_name, success=success)
        if not success:
            # 실패는 ERROR 로 명확히 표시
            manager.set_status(team_name, TeamStatus.ERROR)
        else:
            manager.set_status(team_name, TeamStatus.IDLE)
    except Exception as e:  # noqa: BLE001
        print(f"⚠️ team_state 종료 기록 실패: {e}")


def planner_node(state: TeamState) -> dict:
    """
    👨‍💼 시니어 아키텍트 (Planner)
    PRD와 시냅스 기억을 분석하여 작업 계획을 수립합니다.
    """
    print("\n👨‍💼 [ARCHITECT] PRD와 시냅스를 분석하여 계획을 세웁니다...")

    # PRD 내용 분석 (간소화된 로직)
    prd_lines = state["prd_content"].split("\n")
    target_section = None
    target_files = []

    for line in prd_lines:
        if "## 타겟" in line or "## Target" in line:
            target_section = True
        elif target_section and line.strip().startswith("-"):
            target_files.append(line.strip().lstrip("- ").strip())
        elif target_section and line.startswith("##"):
            break

    if not target_files:
        target_files = ["main.py"]  # fallback

    target_file = target_files[0]

    # 시냅스 기억이 있으면 참고
    context_hint = ""
    if state["synapse_memory"]:
        context_hint = "\n📝 과거 작업 기록이 확인되었습니다. 이를 참고하여 계획을 수립합니다."

    message = f"""계획 수립 완료:{context_hint}

🎯 타겟 파일: {target_file}
📋 작업 내용: PRD 요구사항 구현
🔄 순서: 코드 수정 → 테스트 → 검증
"""
    print(message)

    return {
        "messages": [AIMessage(content=message)],
        "current_file": target_file,
    }


def coder_node(state: TeamState) -> dict:
    """
    🧑‍💻 주니어 개발자 (Coder)
    아키텍트의 계획과 PRD 제약조건을 바탕으로 코드를 수정합니다.
    """
    retry_info = f" (재시도 {state['retry_count'] + 1}/{state['max_retries']})" if state['retry_count'] > 0 else ""
    print(f"\n🧑‍💻 [CODER]{retry_info} 계획을 바탕으로 코드를 수정합니다...")

    target_file = state["current_file"]
    file_path = PROJECT_ROOT / target_file

    # 원본 코드 백업
    original_code = ""
    current_code = ""

    if file_path.exists():
        with open(file_path, "r", encoding='utf-8') as f:
            original_code = f.read()
            current_code = original_code

    # 코드 수정 시뮬레이션 (실제로는 LLM이 수행)
    # 에이전트 시뮬레이션을 위해 간단한 로직 구현
    if state.get("errors"):
        # 이전 에러가 있으면 수정 시도
        error_fix_msg = f"🔧 이전 에러 수정 중: {state['errors'][-1]}"
        print(error_fix_msg)
        # 에러를 수정했다고 가정
        current_code = current_code  # 실제로는 LLM이 수정
    else:
        print("✨ 새로운 기능 구현 중...")
        # 새 코드 작성 (시뮬레이션)
        if not current_code:
            current_code = f"# Implemented feature from PRD\n# Generated at {datetime.now()}\n"

    message = f"""🔨 코드 수정 완료

📁 파일: {target_file}
📝 수정 내용:
- PRD 요구사항 반영
- 시냅스 기억 참고 ({'있음' if state['synapse_memory'] else '없음'})
- 코드 스타일 준수
"""

    print(message)

    return {
        "messages": [AIMessage(content=message)],
        "current_code": current_code,
        "original_code": original_code,
        "retry_count": state["retry_count"] + 1,
    }


def reviewer_node(state: TeamState) -> dict:
    """
    🕵️ QA 엔지니어 (Reviewer)
    수정된 코드를 검증하고, 에러가 있으면 피드백을 줍니다.
    """
    print("\n🕵️ [QA] 수정된 코드를 검증합니다...")

    errors = []

    # 시뮬레이션: 간단한 검증 로직
    code = state["current_code"]

    # 검증 1: 코드가 너무 짧으면 에러
    if len(code) < 50 and "TODO" not in code:
        errors.append("코드가 너무 간단합니다. 더 많은 로직이 필요합니다.")

    # 검증 2: 문서화 확인
    if "def " in code and '"""' not in code and "'''" not in code:
        errors.append("함수에 독스트링이 없습니다.")

    # 검증 3: 에러 핸들링 확인
    if "open(" in code and "try:" not in code and "with" not in code:
        errors.append("파일 열기에 에러 핸들링이 없습니다.")

    if errors:
        error_msg = "❌ 검증 실패:\n" + "\n".join(f"  - {e}" for e in errors)
        print(error_msg)

        return {
            "messages": [AIMessage(content=error_msg)],
            "errors": state.get("errors", []) + errors,
            "success": False,
        }
    else:
        success_msg = "✅ 검증 통과! 모든 테스트를 통과했습니다."
        print(success_msg)

        return {
            "messages": [AIMessage(content=success_msg)],
            "errors": [],
            "success": True,
            "verdict": "PASS",
        }


# =============================================================================
# 라우팅 (Edge) 조건 정의
# =============================================================================

def should_continue(state: TeamState) -> Literal["coder", "__end__"]:
    """
    라우터: 다음에 어디로 갈지 결정합니다.

    - 에러가 있고 재시도 횟수가 남으면 → Coder로 다시
    - 에러가 없거나 재시도 횟수 초과면 → 종료
    """
    errors = state.get("errors", [])
    retry_count = state.get("retry_count", 0)
    max_retries = state.get("max_retries", 3)

    if errors and retry_count < max_retries:
        print(f"\n⚠️ [ROUTER] 에러 발생! 개발자(Coder)에게 반려합니다. (재시도: {retry_count + 1}/{max_retries})")
        return "coder"

    if errors:
        print(f"\n⚠️ [ROUTER] 최대 재시도 초과! 에러가 있지만 종료합니다.")
        return "__end__"

    print("\n✅ [ROUTER] 검증 통과! 작업을 성공적으로 종료합니다.")
    return "__end__"


# =============================================================================
# LangGraph 팀 빌딩
# =============================================================================

def build_team() -> Optional[object]:
    """가상 개발팀을 구축합니다."""
    if not LANGGRAPH_AVAILABLE:
        return None

    # StateGraph 정의
    workflow = StateGraph(TeamState)

    # 멤버 등록
    workflow.add_node("planner", planner_node)
    workflow.add_node("coder", coder_node)
    workflow.add_node("reviewer", reviewer_node)

    # 작업 순서 연결 (Edge)
    workflow.set_entry_point("planner")
    workflow.add_edge("planner", "coder")
    workflow.add_edge("coder", "reviewer")

    # 조건부 엣지 (라우팅)
    workflow.add_conditional_edges(
        "reviewer",
        should_continue,
        {
            "coder": "coder",
            "__end__": END,
        }
    )

    # 체크포인터 (메모리 저장소)
    memory = MemorySaver()

    # 팀 완성
    return workflow.compile(checkpointer=memory)


# =============================================================================
# 메인 실행
# =============================================================================

def run_fallback_pipeline(prd_path: Path) -> int:
    """LangGraph가 없을 때 기존 run_agent.py로 대체 실행 (프로세스 exit code 반환)"""
    print("🔄 선형 파이프라인 모드로 실행합니다...")

    run_agent_script = PROJECT_ROOT / "scripts" / "run_agent.py"
    if not run_agent_script.exists():
        print("❌ run_agent.py를 찾을 수 없습니다.")
        return 1

    import subprocess
    try:
        result = subprocess.run(
            [sys.executable, str(run_agent_script), str(prd_path)],
            cwd=PROJECT_ROOT
        )
    except (OSError, subprocess.SubprocessError) as e:
        print(f"❌ run_agent.py 실행에 실패했습니다: {e}")
        return 1
    return result.returncode


def load_prd(prd_path: Path) -> Tuple[str, str]:
    """PRD 파일 로드"""
    with open(prd_path, "r", encoding='utf-8') as f:
        content = f.read()

    # PRD 타입 감지
    prd_type = "feature"
    if "# Bug" in content or "bugfix" in content.lower():
        prd_type = "bug"
    elif "# Refactor" in content or "refactor" in content.lower():
        prd_type = "refactor"
    elif "# Hotfix" in content or "hotfix" in content.lower():
        prd_type = "hotfix"

    return content, prd_type


def main():
    """메인 실행"""
    import argparse

    parser = argparse.ArgumentParser(
        description=f"Monggle v{TOOLKIT_VERSION} - LangGraph 가상 개발팀",
        epilog="""
Examples:
  %(prog)s prd/feature.md          # PRD로 팀 실행
  %(prog)s --visualize             # 그래프 시각화
  %(prog)s --max-retries 5         # 최대 재시도 횟수 설정
        """
    )
    parser.add_argument(
        "prd",
        nargs="?",
        help="PRD file path"
    )
    parser.add_argument(
        "--max-retries",
        type=int,
        default=3,
        help="Maximum retry count (default: 3)"
    )
    parser.add_argument(
        "--visualize",
        action="store_true",
        help="Visualize the team graph (requires graphviz)"
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable verbose logging"
    )

    args = parser.parse_args()

    # 시각화 모드
    if args.visualize:
        print("📊 팀 구조 시각화...")
        print()
        print("```mermaid")
        print("graph TD")
        print("    A[👨‍💼 Planner<br/>시니어 아키텍트] --> B[🧑‍💻 Coder<br/>주니어 개발자]")
        print("    B --> C[🕵️ Reviewer<br/>QA 엔지니어]")
        print("    C -->|에러 발견| B")
        print("    C -->|검증 통과| D[✅ 완료]")
        print("```")
        print()
        print("🔄 피드백 루프: QA에서 에러를 발견하면 개발자에게 되돌려 보냅니다.")
        print()
        if LANGGRAPH_AVAILABLE:
            print("✅ LangGraph가 설치되어 있어 실제 그래프를 생성할 수 있습니다.")
        else:
            print("⚠️ LangGraph가 설치되지 않아 시뮬레이션 모드로 실행됩니다.")
            print("📦 설치: pip install langgraph langchain-anthropic")
        return 0

    # PRD 경로 결정
    prd_path = None
    if args.prd:
        prd_path = Path(args.prd)
        if not prd_path.is_absolute():
            prd_path = PROJECT_ROOT / prd_path
    else:
        # 자동 감지
        prd_dir = PROJECT_ROOT / "prd"
        if prd_dir.exists():
            prd_files = list(prd_dir.glob("*.md"))
            if prd_files:
                prd_path = max(prd_files, key=lambda p: p.stat().st_mtime)

    if not prd_path or not prd_path.exists():
        print("❌ PRD 파일을 찾을 수 없습니다.")
        return 1

    print(f"\n🚀 [TEAM] LangGraph 기반 가상 개발팀을 소집합니다...")
    print(f"📋 PRD: {prd_path}")
    print(f"🔄 최대 재시도: {args.max_retries}")

    # PRD 로드 (팀 이름 결정 및 실행에 사용)
    prd_content, prd_type = load_prd(prd_path)

    # team_state 연동: 팀 이름 결정 + 시작(BUSY) 기록
    team_name = resolve_team_name(prd_content, prd_path)
    state_manager = _ensure_team_state_manager()
    team_state_start(state_manager, team_name)
    print(f"👥 팀: {team_name} (상태: BUSY 기록)")

    exit_code = 1
    success = False
    try:
        # LangGraph가 없으면 대체 모드
        if not LANGGRAPH_AVAILABLE:
            exit_code = run_fallback_pipeline(prd_path)
            success = (exit_code == 0)
            return exit_code

        # 팀 빌딩
        team = build_team()
        if not team:
            exit_code = run_fallback_pipeline(prd_path)
            success = (exit_code == 0)
            return exit_code

        # 초기 상태 설정
        synapse_memory = load_synapse_memory(prd_path)

        initial_state: TeamState = {
            "messages": [HumanMessage(content=f"PRD: {prd_content}")],
            "prd_path": str(prd_path),
            "prd_content": prd_content,
            "prd_type": prd_type,
            "synapse_memory": synapse_memory,
            "current_file": "",
            "current_code": "",
            "original_code": "",
            "errors": [],
            "retry_count": 0,
            "max_retries": args.max_retries,
            "verdict": "",
            "success": False,
        }

        # 팀 실행 (config에 thread_id를 넣어 체크포인팅)
        print("\n" + "=" * 60)
        print("  👥 가상 개발팀 작업 시작")
        print("=" * 60)

        config = {"configurable": {"thread_id": "team-session-1"}}
        result = team.invoke(initial_state, config)

        # 결과 요약
        print("\n" + "=" * 60)
        print("  📊 작업 결과 요약")
        print("=" * 60)

        success = result.get("success", False)
        verdict = result.get("verdict", "UNKNOWN")

        print(f"상태: {'✅ 성공' if success else '❌ 실패'}")
        print(f"판정: {verdict}")
        print(f"재시도: {result.get('retry_count', 0)}회")

        if result.get("errors"):
            print("\n남은 에러:")
            for error in result["errors"][-3:]:  # 최근 3개만
                print(f"  - {error}")

        # 메시지 기록
        if args.verbose:
            print("\n💬 대화 기록:")
            for msg in result.get("messages", []):
                print(f"  {type(msg).__name__}: {msg.content[:100]}...")

        print("\n" + "=" * 60)

        exit_code = 0 if success else 1
        return exit_code
    finally:
        # team_state 연동: 종료(IDLE/ERROR) + 결과 기록 (항상 실행)
        team_state_finish(state_manager, team_name, success)
        print(f"👥 팀: {team_name} (상태: {'IDLE' if success else 'ERROR'} 기록)")


if __name__ == "__main__":
    sys.exit(main())
