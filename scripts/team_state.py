#!/usr/bin/env python3
"""
Team State Management System

Tracks team and agent status in real-time.

Features:
- Real-time state tracking
- Audit logging (event trail)
- File system locking (fcntl)
- Zombie state cleanup
"""

import fcntl
import json
import os
import threading
import time
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any, Dict, List, Optional
from dataclasses import dataclass, asdict
from enum import Enum


class TeamStatus(Enum):
    """팀 상태"""
    CREATED = "created"
    IDLE = "idle"           # 대기 중
    BUSY = "busy"           # 작업 중
    QUEUED = "queued"       # 대기열에 있음
    ARCHIVED = "archived"   # 보관됨
    ERROR = "error"         # 오류 발생


class AgentStatus(Enum):
    """에이전트 상태"""
    IDLE = "idle"
    RUNNING = "running"
    WAITING = "waiting"
    COMPLETED = "completed"
    FAILED = "failed"


@dataclass
class TaskState:
    """작업 상태"""
    task_id: str
    description: str
    status: str  # pending, running, completed, failed
    progress: int  # 0-100
    agent: str
    started_at: Optional[str] = None
    completed_at: Optional[str] = None
    error: Optional[str] = None


@dataclass
class TeamState:
    """팀 상태"""
    name: str
    status: str
    current_task: Optional[TaskState] = None
    queue: List[Dict] = None
    stats: Dict = None
    locked_by: Optional[str] = None
    locked_at: Optional[str] = None

    def __post_init__(self):
        if self.queue is None:
            self.queue = []
        if self.stats is None:
            self.stats = {
                "total_jobs": 0,
                "success_rate": 0.0,
                "avg_duration": 0.0,
                "last_job": None
            }


class TeamStateManager:
    """팀 상태 관리자"""

    def __init__(self, project_root: Optional[Path] = None):
        if project_root is None:
            project_root = Path(__file__).parent.parent
        self.project_root = Path(project_root)
        self.teams_dir = self.project_root / ".claude" / "teams"
        self.state_dir = self.teams_dir / "state"
        self.history_dir = self.teams_dir / "history"
        self.state_dir.mkdir(parents=True, exist_ok=True)
        self.history_dir.mkdir(parents=True, exist_ok=True)

        self._lock = threading.Lock()
        self._states: Dict[str, TeamState] = {}
        self._load_all_states()

    def _audit_log(self, team_name: str, old_status: str, new_status: str, task_desc: str = "", session: str = ""):
        """감사 로그 기록"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M")
        log_file = self.history_dir / f"{team_name}_audit.log"

        parts = [f"[{timestamp}]", f"{old_status.upper()} -> {new_status.upper()}"]
        if task_desc:
            parts.append(f"Task: {task_desc}")
        if session:
            parts.append(f"Session: {session[-4:]}")  # 세션 ID 뒤 4자리만

        log_line = " | ".join(parts) + "\n"

        with open(log_file, 'a') as f:
            f.write(log_line)

    def _state_file(self, team_name: str) -> Path:
        return self.state_dir / f"{team_name}_state.json"

    def _load_all_states(self):
        """모든 팀 상태 로드 (lock 없이 호출됨)"""
        for state_file in self.state_dir.glob("*_state.json"):
            team_name = state_file.stem.replace("_state", "")
            try:
                with open(state_file, 'r') as f:
                    data = json.load(f)
                    self._states[team_name] = self._parse_state(data)
            except (json.JSONDecodeError, OSError, KeyError, ValueError) as e:
                print(f"[WARN] Failed to load state for {team_name}: {e}", flush=True)

    def _parse_state(self, data: Dict) -> TeamState:
        """상태 데이터 파싱"""
        current_task = None
        if data.get("current_task"):
            task_data = data["current_task"]
            current_task = TaskState(**task_data)

        return TeamState(
            name=data["name"],
            status=data["status"],
            current_task=current_task,
            queue=data.get("queue", []),
            stats=data.get("stats", {}),
            locked_by=data.get("locked_by"),
            locked_at=data.get("locked_at")
        )

    def get_state(self, team_name: str) -> Optional[TeamState]:
        """팀 상태 조회"""
        with self._lock:
            return self._get_state_unlocked(team_name)

    def _get_state_unlocked(self, team_name: str) -> Optional[TeamState]:
        """팀 상태 조회 (내부용, lock 없이)"""
        # 메모리에 없으면 파일에서 로드 시도
        if team_name not in self._states:
            state_file = self._state_file(team_name)
            if state_file.exists():
                try:
                    with open(state_file, 'r') as f:
                        data = json.load(f)
                        self._states[team_name] = self._parse_state(data)
                except (json.JSONDecodeError, OSError, KeyError, ValueError) as e:
                    print(f"[WARN] Failed to load state for {team_name}: {e}", flush=True)
                    return None
            else:
                # 팀 설정 파일이 있으면 초기 상태 생성
                config_file = self.teams_dir / f"{team_name}.json"
                if config_file.exists():
                    self._states[team_name] = TeamState(
                        name=team_name,
                        status=TeamStatus.IDLE.value
                    )
                else:
                    return None
        return self._states.get(team_name)

    def set_status(self, team_name: str, status: TeamStatus):
        """팀 상태 변경"""
        with self._lock:
            state = self._get_state_unlocked(team_name)
            if state:
                old_status = state.status
                state.status = status.value
                self._save_state(team_name, old_status)

    def set_current_task(self, team_name: str, task: TaskState, session_id: str = ""):
        """현재 작업 설정"""
        with self._lock:
            state = self._get_state_unlocked(team_name)
            if state:
                old_status = state.status
                state.current_task = task
                state.status = TeamStatus.BUSY.value
                if session_id:
                    state.locked_by = session_id
                    state.locked_at = datetime.now().isoformat()
                self._save_state(team_name, old_status)

    def update_progress(self, team_name: str, progress: int):
        """진행률 업데이트"""
        with self._lock:
            state = self._get_state_unlocked(team_name)
            if state and state.current_task:
                state.current_task.progress = min(100, max(0, progress))
                old_status = state.status
                if progress >= 100:
                    state.current_task.status = "completed"
                    state.current_task.completed_at = datetime.now().isoformat()
                    state.status = TeamStatus.IDLE.value
                self._save_state(team_name, old_status)

    def add_to_queue(self, team_name: str, task: Dict):
        """대기열에 작업 추가"""
        with self._lock:
            state = self._get_state_unlocked(team_name)
            if state:
                state.queue.append(task)
                if state.status == TeamStatus.IDLE.value:
                    state.status = TeamStatus.QUEUED.value
                self._save_state(team_name)

    def get_next_task(self, team_name: str) -> Optional[Dict]:
        """대기열에서 다음 작업 가져오기"""
        with self._lock:
            state = self._get_state_unlocked(team_name)
            if state and state.queue:
                return state.queue.pop(0)
            return None

    def complete_task(self, team_name: str, success: bool = True):
        """작업 완료 처리"""
        with self._lock:
            state = self._get_state_unlocked(team_name)
            if state:
                state.stats["total_jobs"] += 1
                if success:
                    # 성공률 업데이트
                    total = state.stats["total_jobs"]
                    current_rate = state.stats.get("success_count", 0)
                    success_count = current_rate + 1
                    state.stats["success_count"] = success_count
                    state.stats["success_rate"] = success_count / total
                state.stats["last_job"] = datetime.now().isoformat()
                state.current_task = None
                state.status = TeamStatus.IDLE.value
                state.locked_by = None
                state.locked_at = None
                self._save_state(team_name)

    def acquire_lock(self, team_name: str, session_id: str) -> bool:
        """팀 잠금 획득 (프로세스 간 원자적)"""
        with self._lock:
            state = self._get_state_unlocked(team_name)
            if not state:
                return False

            # 프로세스 간 배타 락을 잡은 채로 디스크 상태를 다시 읽어
            # read-modify-write 전체를 원자적으로 수행
            state_file = self._state_file(team_name)
            lock_file = state_file.with_suffix(state_file.suffix + ".lock")
            with open(lock_file, 'w') as lf:
                fcntl.flock(lf.fileno(), fcntl.LOCK_EX)
                try:
                    # 디스크의 최신 상태로 갱신 (다른 프로세스가 쓴 락 반영)
                    if state_file.exists():
                        try:
                            with open(state_file, 'r') as f:
                                data = json.load(f)
                            state = self._parse_state(data)
                            self._states[team_name] = state
                        except (json.JSONDecodeError, OSError, KeyError, ValueError):
                            pass

                    # 이미 잠겨있으면 확인
                    if state.locked_by:
                        # 같은 세션이면 OK
                        if state.locked_by == session_id:
                            return True
                        # 잠금 시간 확인 (30분 타임아웃)
                        if state.locked_at:
                            locked_time = datetime.fromisoformat(state.locked_at)
                            if datetime.now() - locked_time < timedelta(minutes=30):
                                return False
                            # 타임아웃이면 잠금 해제
                            state.locked_by = None
                            state.locked_at = None

                    state.locked_by = session_id
                    state.locked_at = datetime.now().isoformat()
                    self._write_state_locked(team_name)
                    return True
                finally:
                    fcntl.flock(lf.fileno(), fcntl.LOCK_UN)

    def release_lock(self, team_name: str, session_id: str) -> bool:
        """팀 잠금 해제"""
        with self._lock:
            state = self._get_state_unlocked(team_name)
            if state and state.locked_by == session_id:
                state.locked_by = None
                state.locked_at = None
                self._save_state(team_name)
                return True
            return False

    def get_all_states(self) -> Dict[str, TeamState]:
        """모든 팀 상태 조회"""
        with self._lock:
            # 등록된 팀 모두 확인
            result = {}
            for team_file in self.teams_dir.glob("*.json"):
                if not team_file.name.endswith("_state.json"):
                    team_name = team_file.stem
                    # 내부 함수 사용 (데드락 방지)
                    state = self._get_state_unlocked(team_name)
                    if state:
                        result[team_name] = state
            return result

    def _write_state_locked(self, team_name: str):
        """상태를 원자적으로 디스크에 기록 (flock은 호출자가 보유한다고 가정)"""
        state = self._states.get(team_name)
        if not state:
            return

        data = {
            "name": state.name,
            "status": state.status,
            "current_task": asdict(state.current_task) if state.current_task else None,
            "queue": state.queue,
            "stats": state.stats,
            "locked_by": state.locked_by,
            "locked_at": state.locked_at,
            "updated_at": datetime.now().isoformat()
        }

        state_file = self._state_file(team_name)
        # 원자적 쓰기 (temp + os.replace)
        tmp_file = state_file.with_suffix(state_file.suffix + ".tmp")
        with open(tmp_file, 'w') as f:
            f.write(json.dumps(data, indent=2, ensure_ascii=False))
            f.flush()
            os.fsync(f.fileno())  # 디스크에 강제 쓰기
        os.replace(tmp_file, state_file)  # 원자적 교체

    def _save_state(self, team_name: str, old_status: str = None):
        """상태 저장 (파일 시스템 락 포함)"""
        state = self._states.get(team_name)
        if not state:
            return

        state_file = self._state_file(team_name)

        # 파일 시스템 락 (fcntl) + 원자적 쓰기
        lock_file = state_file.with_suffix(state_file.suffix + ".lock")
        with open(lock_file, 'w') as lf:
            fcntl.flock(lf.fileno(), fcntl.LOCK_EX)  # 배타적 락
            try:
                self._write_state_locked(team_name)
            finally:
                fcntl.flock(lf.fileno(), fcntl.LOCK_UN)  # 락 해제

        # 감사 로그 (상태 변경 시)
        if old_status and old_status != state.status:
            task_desc = state.current_task.description if state.current_task else ""
            session = state.locked_by or ""
            self._audit_log(team_name, old_status, state.status, task_desc, session)


class StatusFormatter:
    """상태 출력 포맷터"""

    @staticmethod
    def format_team_status(state: TeamState) -> str:
        """팀 상태 포맷"""
        status_emoji = {
            "idle": "🟢",
            "busy": "🔵",
            "queued": "🟡",
            "error": "🔴",
            "created": "⚪",
            "archived": "⚫"
        }
        emoji = status_emoji.get(state.status, "⚪")

        lines = [
            f"  {emoji} {state.name:<20} {state.status.upper():<10}"
        ]

        if state.current_task:
            task = state.current_task
            progress_bar = "█" * (task.progress // 10) + "░" * (10 - task.progress // 10)
            lines.append(f"     ├─ Task: {task.description}")
            lines.append(f"     ├─ Progress: [{progress_bar}] {task.progress}%")
            if task.agent:
                lines.append(f"     ├─ Agent: {task.agent}")
        elif state.queue:
            lines.append(f"     ├─ Queue: {len(state.queue)} tasks pending")
        elif state.stats.get("last_job"):
            lines.append(f"     └─ Last job: {state.stats['last_job']}")

        return "\n".join(lines)

    @staticmethod
    def format_summary(states: Dict[str, TeamState]) -> str:
        """요약 포맷"""
        total = len(states)
        busy = sum(1 for s in states.values() if s.status == "busy")
        idle = sum(1 for s in states.values() if s.status == "idle")
        queued = sum(1 for s in states.values() if s.status == "queued")

        total_jobs = sum(s.stats.get("total_jobs", 0) for s in states.values())
        success_rate = 0
        if total_jobs > 0:
            success_jobs = sum(s.stats.get("success_count", 0) for s in states.values())
            success_rate = (success_jobs / total_jobs) * 100

        lines = [
            "",
            "┌─────────────────────────────────────────────────────────────────┐",
            "│  📊 Session Statistics                                              │",
            "├─────────────────────────────────────────────────────────────────┤",
            f"│  Total teams   : {total}                                                   │",
            f"│  Active        : {busy} 🔵                                               │",
            f"│  Idle          : {idle} 🟢                                               │",
            f"│  Queued        : {queued} 🟡                                               │",
            f"│  Total jobs    : {total_jobs}                                                   │",
            f"│  Success rate  : {success_rate:.1f}%                                                │",
            "└─────────────────────────────────────────────────────────────────┘",
            ""
        ]

        return "\n".join(lines)


def main():
    """메인 - CLI 인터페이스"""
    import argparse

    parser = argparse.ArgumentParser(description="Team Status Monitor")
    parser.add_argument("--verbose", "-v", action="store_true", help="상세 출력")
    parser.add_argument("--json", action="store_true", help="JSON 출력")
    parser.add_argument("--queue", action="store_true", help="대기열 상세 출력")
    parser.add_argument("--team", type=str, help="특정 팀만 조회")
    parser.add_argument("--lock", type=str, help="팀 잠금 획득")
    parser.add_argument("--unlock", type=str, help="팀 잠금 해제")

    args = parser.parse_args()

    manager = TeamStateManager()

    # 잠금/해제 명령
    if args.lock:
        import uuid
        session_id = os.environ.get("SESSION_ID", f"cli-{uuid.uuid4().hex[:8]}")
        if manager.acquire_lock(args.lock, session_id):
            print(f"✓ Acquired lock on {args.lock}")
        else:
            print(f"✗ Failed to acquire lock on {args.lock} (already locked)")
            state = manager.get_state(args.lock)
            if state and state.locked_by:
                print(f"  Locked by: {state.locked_by}")
        return

    if args.unlock:
        session_id = os.environ.get("SESSION_ID", "")
        if manager.release_lock(args.unlock, session_id):
            print(f"✓ Released lock on {args.unlock}")
        else:
            print(f"✗ Failed to release lock on {args.unlock}")
        return

    # 상태 조회
    if args.team:
        state = manager.get_state(args.team)
        if not state:
            print(f"✗ Team not found: {args.team}")
            return

        if args.json:
            print(json.dumps(asdict(state), indent=2, default=str))
        else:
            print(f"\n🏢 {state.name}")
            print(StatusFormatter.format_team_status(state))
            if args.verbose:
                print(f"\n📊 Statistics:")
                for k, v in state.stats.items():
                    print(f"  {k}: {v}")
    else:
        states = manager.get_all_states()

        if args.json:
            output = {name: asdict(state) for name, state in states.items()}
            print(json.dumps(output, indent=2, default=str))
        else:
            print("🏢 Active Teams")
            print("┌─────────────────────────────────────────────────────────────────┐")
            for name, state in states.items():
                print(StatusFormatter.format_team_status(state))
                if args.verbose and state.queue:
                    print(f"     📋 Queue:")
                    for i, task in enumerate(state.queue[:5], 1):
                        print(f"        {i}. {task.get('description', 'No description')}")
                    if len(state.queue) > 5:
                        print(f"        ... and {len(state.queue) - 5} more")
                print()

            print(StatusFormatter.format_summary(states))


if __name__ == "__main__":
    main()
