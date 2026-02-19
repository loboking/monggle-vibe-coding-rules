# Feature PRD: Team Mode System

> monggle-vibe-coding-rules에 모드 시스템(solo/team)을 추가하여,
> solo 모드에서는 PRD를 선택적으로, team 모드에서는 필수적으로 사용할 수 있게 합니다.

---

## Front Matter

```yaml
---
feature_name: "Team Mode System"
feature_type: "feature"
priority: "high"
points: [TM-1, TM-2]
dependencies: []
assignee: ""
estimated_hours: "6"
tags: ["configuration", "mode", "flexibility"]
---
```

---

## Goal

현재 모든 상황에서 PRD가 필수인 엄격한 규칙을 유연하게 만들어,
- **Solo 모드**: 개인 프로젝트에서 빠르게 작업 가능 (PRD 선택적)
- **Team 모드**: 팀 프로젝트에서 PRD 강제 (품질 보장)

---

## Requirements

### 기능적 요구사항

1. **monggle.config.yaml 생성**
   - 프로젝트 루트에 monggle.config.yaml 설정 파일 생성
   - `mode: solo` | `mode: team` 설정 지원
   - 기본값은 `solo`

2. **설정 로더 구현** (`scripts/load_config.py`)
   - monggle.config.yaml 파싱
   - 기본값 제공 (파일 없으면 solo 모드)
   - 환경변수 `MONGGLE_MODE`로 오버라이드 가능

3. **Hook 개선** (`.claude/hooks/pre-tool-use.sh`)
   - 현재 모드 확인 (load_config.py 호출)
   - Solo 모드: PRD 없어도 경고만 하고 통과
   - Team 모드: PRD 필수 (기존 동작)

4. **CLI 도구** (`.claude/commands/mode.sh`)
   - `/mode` - 현재 모드 표시
   - `/mode solo` - solo 모드로 변경
   - `/mode team` - team 모드로 변경

### 비기능적 요구사항

- **성능**: 설정 로딩 < 100ms
- **호환성**: 기존 settings.json과 충돌 없음
- **이전성**: 파일 없으면 기존 동작 (solo 모드) 유지

---

## Tech Stack

**Python 3.8+**
- `pathlib.Path` - 경로 처리
- `yaml` 파싱 - 간단한 파서 직접 구현 (PyYAML 의존성 회피)

**Bash**
- Hook 개선
- mode.sh CLI

---

## Implementation Plan

### Phase 1: 설정 파일 구조

```yaml
# monggle.config.yaml
mode: solo  # solo | team

# 선택적 설정 (미래 확장용)
prd_required: false  # mode에 따라 자동 설정
agents_enabled: ["gate", "scan", "fold", "verdict", "patch", "trace"]
```

### Phase 2: 설정 로더 구현

**`scripts/load_config.py`**:
```python
#!/usr/bin/env python3
"""Monggle Configuration Loader"""

import os
import sys
from pathlib import Path

def load_config(project_root: Path) -> dict:
    """설정 로드

    Returns:
        dict: {'mode': 'solo', 'prd_required': False, ...}
    """
    config_file = project_root / "monggle.config.yaml"

    # 기본값
    config = {
        'mode': 'solo',
        'prd_required': False,
        'agents_enabled': ['gate', 'scan', 'fold', 'verdict', 'patch', 'trace']
    }

    # 환경변수 오버라이드
    if os.getenv('MONGGLE_MODE'):
        config['mode'] = os.getenv('MONGGLE_MODE')
        config['prd_required'] = (config['mode'] == 'team')
        return config

    # 파일 파싱
    if not config_file.exists():
        return config

    # 간단한 YAML 파싱
    try:
        content = config_file.read_text()
        for line in content.split('\n'):
            if ':' in line and not line.strip().startswith('#'):
                key, value = line.split(':', 1)
                key = key.strip()
                value = value.strip()

                if value.startswith('"') or value.startswith("'"):
                    value = value[1:-1]
                elif value.lower() == 'true':
                    value = True
                elif value.lower() == 'false':
                    value = False

                config[key] = value

        # prd_required 자동 계산
        if config['mode'] == 'team':
            config['prd_required'] = True

    except Exception as e:
        print(f"[WARN] Config parse error: {e}", file=sys.stderr)

    return config

if __name__ == '__main__':
    import json
    root = Path.cwd()
    if len(sys.argv) > 1:
        root = Path(sys.argv[1])

    config = load_config(root)
    print(json.dumps(config))
```

### Phase 3: Hook 개선

**`.claude/hooks/pre-tool-use.sh`** 변경 사항:
```bash
# main() 함수 시작 부분에 추가
local config_mode=""
local prd_required=""

# 설정 로드 (Python)
if $PYTHON_CMD "$SCRIPT_DIR/scripts/load_config.py" "$PROJECT_ROOT" > /tmp/monggle_config.$$; then
    config_mode=$(grep -o '"mode":[[:space:]]*"[^"]*"' /tmp/monggle_config.$$ | cut -d'"' -f4)
    prd_required=$(grep -o '"prd_required":[[:space:]]*[^,}]*' /tmp/monggle_config.$$ | cut -d':' -f2 | tr -d ' ')
    rm -f /tmp/monggle_config.$$
fi

# Solo 모드면 PRD 선택적
if [[ "$prd_required" == "false" ]] || [[ "$config_mode" == "solo" ]]; then
    if [[ ! -f "$prd_file" ]]; then
        log_warning "Solo mode: PRD not required (but recommended)"
        return 0
    fi
fi
```

### Phase 4: Mode CLI

**`.claude/commands/mode.sh`**:
```bash
#!/bin/bash
# Mode management CLI

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/monggle.config.yaml"

show_mode() {
    if [[ -f "$CONFIG_FILE" ]]; then
        grep "^mode:" "$CONFIG_FILE" | awk '{print $2}'
    else
        echo "solo (default)"
    fi
}

set_mode() {
    local new_mode="$1"

    if [[ "$new_mode" != "solo" ]] && [[ "$new_mode" != "team" ]]; then
        echo "Invalid mode: $new_mode (use: solo | team)"
        exit 1
    fi

    mkdir -p "$(dirname "$CONFIG_FILE")"
    echo "mode: $new_mode" > "$CONFIG_FILE"

    if [[ "$new_mode" == "team" ]]; then
        echo "prd_required: true" >> "$CONFIG_FILE"
    else
        echo "prd_required: false" >> "$CONFIG_FILE"
    fi

    echo "Mode set to: $new_mode"
}

case "${1:-}" in
    solo)
        set_mode "solo"
        ;;
    team)
        set_mode "team"
        ;;
    "")
        show_mode
        ;;
    *)
        echo "Usage: /mode [solo|team]"
        exit 1
        ;;
esac
```

---

## Edge Cases

1. **설정 파일 손상 시**: 기본값(solo) 사용, 경고 로그
2. **환경변수 충돌**: 환경변수가 파일보다 우선
3. **Git merge 충돌**: monggle.config.yaml merge strategy 지정

---

## Testing

### 단위 테스트
- 설정 로더: 파일 없음, 손상됨, 유효함
- 모드 전환: solo ↔ team

### 통합 테스트
- Solo 모드에서 PRD 없이 작업
- Team 모드에서 PRD 강제

---

## Success Criteria

- [x] monggle.config.yaml 구조 정의
- [ ] load_config.py 구현
- [ ] pre-tool-use.sh 개선
- [ ] mode.sh CLI 구현
- [ ] install.sh에 통합 (기본값 solo로 초기화)
- [ ] 테스트 통과

---

## Rollback Plan

문제 발생 시:
1. monggle.config.yaml 삭제하면 기존 동작(solo)으로 복귀
2. Hook은 파일 없으면 solo로 처리하므로 안전

---

## File Changes

**생성:**
- `monggle.config.yaml` (설정 템플릿)
- `scripts/load_config.py`
- `.claude/commands/mode.sh`

**수정:**
- `.claude/hooks/pre-tool-use.sh` (모드 확인 로직 추가)
- `install.sh` (monggle.config.yaml 초기화)

---

## Notes

### 왜 Enterprise 모드 제거?
- 실제 사용 사례 적음
- Solo와 Team으로 충분
- 단순화 유지

### 왜 Agent 선택 제거?
- 현재 모든 Agent가 핵심 기능
- 향후 필요시 추가 가능

### Git 동기화는?
- monggle.config.yaml은 Git으로 관리
- `.gitignore`에 제외하지 않음
- 팀원 간 자동 공유
