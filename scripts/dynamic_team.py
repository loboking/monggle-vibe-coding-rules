#!/usr/bin/env python3
"""
Monggle - 동적 팀 구성 시스템 (Dynamic Team Builder)
요청을 분석하여 필요한 에이전트를 동적으로 구성합니다.

Usage:
    python3 scripts/dynamic_team.py "보안 점검해줘"
    python3 scripts/dynamic_team.py --list-teams
    python3 scripts/dynamic_team.py --show-team security
"""

import sys
import json
from pathlib import Path
from typing import Optional

PROJECT_ROOT = Path(__file__).parent.parent
TEAMS_DIR = PROJECT_ROOT / ".claude" / "teams"


def analyze_intent(request: str) -> str:
    """
    요청 텍스트에서 의도(Intent)를 분석합니다.
    """
    request_lower = request.lower()

    # 우선순위별 키워드 매칭 (보안이 최우선)
    intent_keywords = {
        "security": (["security", "secure", "vulnerability", "audit", "injection", "xss", "csrf", "auth", "password", "hack", "attack",
                      "취약점", "보안", "해킹", "인젝션", "취약"], 10),
        "frontend": (["frontend", "css", "style", "ui", "component", "react", "vue", "angular", "html", "layout", "responsive",
                       "프론트", "화면", "스타일", "레이아웃"], 5),
        "backend": (["backend", "api", "server", "endpoint", "rest", "graphql", "controller", "service", "fastapi", "django",
                      "백엔드", "서버", "엔드포인트"], 5),
        "database": (["database", "db", "migration", "schema", "orm", "transaction",
                      "데이터베이스", "마이그레이션", "스키마"], 3),
        "debug": (["bug", "error", "crash", "issue", "fix", "debug", "broken", "not working",
                   "버그", "오류", "에러", "수정", "디버그"], 5),
        "performance": (["performance", "slow", "optimize", "speed", "latency", "fast", "bottleneck",
                         "성능", "느린", "최적화", "병목"], 5),
        "testing": (["test", "testing", "spec", "coverage", "unit test",
                      "테스트", "검증"], 3),
        "devops": (["deploy", "ci", "cd", "pipeline", "release", "docker", "k8s",
                    "배포", "릴리즈"], 3),
    }

    # 가장 높은 우선순위 * 점수 = 가장 높은 것 선택
    best_intent = "general"
    best_score = 0

    for intent, (keywords, priority) in intent_keywords.items():
        score = sum(1 for kw in keywords if kw in request_lower) * priority
        if score > best_score:
            best_intent = intent
            best_score = score

    return best_intent


def load_team_template(intent: str) -> Optional[dict]:
    """
    의도에 해당하는 팀 템플릿을 로드합니다.
    """
    team_file = TEAMS_DIR / f"{intent}.json"

    if team_file.exists():
        with open(team_file, "r", encoding="utf-8") as f:
            return json.load(f)

    # 기본 팀 (폴백)
    return {
        "intent": "general",
        "description": "일반적인 개발 작업",
        "agents": [
            {"name": "planner", "role": "설계자"},
            {"name": "coder", "role": "개발자"},
            {"name": "reviewer", "role": "검토자"},
        ],
        "max_retries": 3,
    }


def build_dynamic_graph(team_config: dict, context: dict) -> str:
    """
    팀 구성에서 LangGraph 워크플로우 코드를 동적으로 생성합니다.
    """
    agents = team_config.get("agents", [])
    workflow = team_config.get("workflow", "")

    # Mermaid 다이어그램 생성
    mermaid = "```mermaid\ngraph TD\n"

    # 노드 정의
    for i, agent in enumerate(agents):
        name = agent["name"]
        role = agent["role"]
        emoji = get_agent_emoji(agent["name"])
        # 노드 ID: 이름의 첫 글자 + 인덱스
        first_char = name[0].upper() if name else "N"
        node_id = f"N{first_char}{i}"
        mermaid += f"    {node_id}[{emoji} {name}<br/>{role}]\n"

    # 엣지 정의 (워크플로우 파싱)
    if workflow:
        # " → "로 분할되는 부분만 추출 (피드백 루프 제외)
        main_workflow = workflow.split("(")[0].strip()
        parts = [p.strip() for p in main_workflow.split(" → ") if p.strip()]

        for i in range(len(parts) - 1):
            from_part = parts[i].strip()
            to_part = parts[i + 1].strip()

            if not from_part or not to_part:
                continue

            # 에이전트 이름 추출
            from_name = from_part.split("(")[0].strip()
            to_name = to_part.split("(")[0].strip()

            # 에이전트 인덱스 찾기 (미등록 이름은 건너뜀)
            from_idx = next((i for i, a in enumerate(agents) if a["name"] == from_name), None)
            to_idx = next((i for i, a in enumerate(agents) if a["name"] == to_name), None)

            if from_idx is None or to_idx is None:
                continue

            from_first = agents[from_idx]["name"][0].upper()
            to_first = agents[to_idx]["name"][0].upper()
            from_node = f"N{from_first}{from_idx}"
            to_node = f"N{to_first}{to_idx}"

            # 병렬 처리 확인
            if " + " in to_part:
                parallel_names = to_part.split(" + ")
                for p_name in parallel_names:
                    p_name_clean = p_name.split("(")[0].strip()
                    if not p_name_clean:
                        continue
                    p_idx = next((i for i, a in enumerate(agents) if a["name"] == p_name_clean), None)
                    if p_idx is None:
                        continue
                    p_first = agents[p_idx]["name"][0].upper()
                    p_node = f"N{p_first}{p_idx}"
                    mermaid += f"    {from_node} --> {p_node}\n"
            else:
                mermaid += f"    {from_node} --> {to_node}\n"

        # 조건부 엣지 (롤백 루프)
        if "(에러시)" in workflow or "(error)" in workflow.lower():
            mermaid += "\n    %% 피드백 루프\n"
            # 마지막 에이전트에서 첫 번째 수정 가능 에이전트로
            last_agent = agents[-1]["name"]
            fixer_agent = agents[1]["name"] if len(agents) > 1 else agents[0]["name"]
            last_idx = len(agents) - 1
            fixer_idx = 1
            last_first = last_agent[0].upper()
            fixer_first = fixer_agent[0].upper()
            mermaid += f"    N{last_first}{last_idx} -.->|에러| N{fixer_first}{fixer_idx}\n"

    mermaid += "```\n"

    return mermaid


def get_agent_emoji(agent_name: str) -> str:
    """에이전트 이름에 맞는 이모지 반환"""
    emoji_map = {
        "security": "🔒",
        "scanner": "🔍",
        "analyzer": "📊",
        "fixer": "🔧",
        "specialist": "👨‍💻",
        "tester": "🧪",
        "designer": "📐",
        "coder": "💻",
        "developer": "👨‍💻",
        "reviewer": "👁️",
        "planner": "📋",
        "ui": "🎨",
        "css": "🎨",
        "js": "⚡",
        "debugger": "🐛",
        "api": "🌐",
        "backend": "⚙️",
        "database": "🗄️",
        "migration": "📦",
        "query": "📊",
        "cache": "⚡",
        "concurrency": "🔄",
        "profiler": "📈",
        "schema": "🗂️",
        "sql": "🐬",
        "data": "💾",
        "rollback": "⏪",
        "symptom": "🚨",
        "detective": "🕵️",
        "regression": "🔄",
        "benchmark": "🏁",
    }

    for key, emoji in emoji_map.items():
        if key in agent_name.lower():
            return emoji

    return "🤖"


def list_teams():
    """사용 가능한 모든 팀 목록 출력"""
    print("\n📋 사용 가능한 팀:\n")

    team_files = sorted(TEAMS_DIR.glob("*.json"))

    if not team_files:
        print("  (팀 템플릿이 없습니다)")
        return

    for team_file in team_files:
        with open(team_file, "r", encoding="utf-8") as f:
            config = json.load(f)

        intent = config["intent"]
        description = config.get("description", "")
        agents = config.get("agents", [])

        print(f"  📁 {intent}")
        print(f"     설명: {description}")
        print(f"     에이전트: {len(agents)}명 ({', '.join(a['name'] for a in agents)})")
        print()


def show_team(intent: str):
    """특정 팀 상세 정보 출력"""
    config = load_team_template(intent)

    if not config:
        print(f"❌ '{intent}' 팀을 찾을 수 없습니다.")
        print("📋 사용 가능한 팀: /list-teams")
        return

    print(f"\n👥 팀: {config['intent']}")
    print(f"📝 설명: {config.get('description', '')}")
    print(f"🔄 워크플로우: {config.get('workflow', '')}")
    print(f"🔁 최대 재시도: {config.get('max_retries', 3)}")
    print()

    print("🤖 에이전트 구성:")
    for i, agent in enumerate(config.get("agents", []), 1):
        emoji = get_agent_emoji(agent["name"])
        print(f"  {i}. {emoji} {agent['name']} ({agent['role']})")
        print(f"     설명: {agent.get('description', '')}")
        tools = agent.get('tools', [])
        if tools:
            print(f"     도구: {', '.join(tools)}")
        print()


def main():
    """메인"""
    import argparse

    parser = argparse.ArgumentParser(
        description="동적 팀 구성 시스템",
        epilog="""
Examples:
  %(prog)s "보안 점검해줘"           # 자동 팀 구성
  %(prog)s --list-teams              # 모든 팀 목록
  %(prog)s --show-team security      # 특정 팀 상세
        """
    )
    parser.add_argument(
        "request",
        nargs="?",
        help="작업 요청 (팀 자동 구성)"
    )
    parser.add_argument(
        "--list-teams",
        action="store_true",
        help="사용 가능한 모든 팀 목록"
    )
    parser.add_argument(
        "--show-team",
        type=str,
        metavar="INTENT",
        help="특정 팀 상세 정보"
    )

    args = parser.parse_args()

    # 팀 목록
    if args.list_teams:
        list_teams()
        return 0

    # 팀 상세
    if args.show_team:
        show_team(args.show_team)
        return 0

    # 요청 분석
    if not args.request:
        print("❌ 요청을 입력해주세요.")
        print("예: python dynamic_team.py \"보안 점검해줘\"")
        return 1

    request = args.request
    intent = analyze_intent(request)

    print(f"\n🔍 요청: {request}")
    print(f"📯 분석된 의도: {intent}")

    # 팀 로드
    config = load_team_template(intent)

    if not config:
        print(f"❌ '{intent}' 템플릿을 찾을 수 없습니다.")
        return 1

    # 팀 정보 출력
    print(f"\n👥 구성된 팀: {config['intent']}")
    print(f"📝 {config.get('description', '')}")
    print()

    # 에이전트 목록
    print("🤖 소집된 에이전트:")
    for i, agent in enumerate(config.get("agents", []), 1):
        emoji = get_agent_emoji(agent["name"])
        print(f"  {i}. {emoji} {agent['name']} - {agent['role']}")

    # 그래프 생성
    print()
    print("📊 팀 워크플로우:")
    print(build_dynamic_graph(config, {}))

    # 코드 생성 (LangGraph가 있으면)
    try:
        from langgraph.graph import StateGraph
        print("✅ LangGraph가 설치되어 있습니다. 실제 그래프를 생성할 수 있습니다!")
        print(f"🚀 실행: python scripts/langgraph_team.py --intent {intent}")
    except ImportError:
        print("⚠️ LangGraph가 설치되지 않았습니다.")
        print("📦 설치: pip install langgraph langchain-anthropic")

    return 0


if __name__ == "__main__":
    sys.exit(main())
