---
description: 멀티 프로젝트 팀 모드 실행 (tmux 분할 + 프로젝트별 워커 에이전트 spawn)
argument-hint: <project1>[:branch], <project2>[:branch], [project3[:branch]...]
---

# Team Mode

여러 프로젝트를 tmux 페인으로 분할하여 동시에 작업합니다.

**Arguments**: `$ARGUMENTS`

> 처음 사용하는 컴퓨터라면 먼저 `/team-mode-init`을 실행해 프로젝트를 매핑하세요.
> 매핑 정보는 `~/.claude/team-mode/registry.json`에 저장됩니다.

## 실행 절차

1. **인자 파싱**: `$ARGUMENTS`를 콤마(`,`) 또는 공백으로 split
   - 각 항목은 `project` 또는 `project:branch` 형식
   - 예: `api-a, api-b` → `["api-a", "api-b"]`
   - 예: `api-a:qa, api-b:qa` → branch 지정

2. **레지스트리 검증**: `~/.claude/team-mode/registry.json`에서 각 프로젝트 확인
   - 파일이 없으면 "`/team-mode-init`을 먼저 실행하세요" 안내 후 중단
   - 존재하지 않는 프로젝트가 있으면 등록된 목록을 보여주고 중단
   - 브랜치 지정 시 허용 목록(`branches`)에 있는지 검증

3. **스크립트 실행**: Bash 도구로 아래를 실행
   ```bash
   "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude}/scripts/spawn-team-mode.sh" <args...>
   ```
   인자는 공백 구분으로 전달 (예: `spawn-team-mode.sh api-a api-b`)

4. **사용자 안내**:
   - 현재 창(왼쪽) = 오케스트레이터 (지금 이 Claude)
   - 오른쪽 페인들 = 각 프로젝트 워커
   - 워커에게 작업 지시할 때는 `[AGENT_MODE]` 프리픽스 필수 (루프 방지)

## 예시

- `/team-mode api-a, api-b`
  → 3분할 (오케 + api-a[default] + api-b[default])

- `/team-mode api-a:qa, api-b:qa, api-c:qa`
  → 4분할 (오케 + 3개 워커, 모두 QA 브랜치)

- `/team-mode api-a`
  → 2분할 (오케 + api-a 단독)

## 오케스트레이터 동작 규약

워커에게 작업을 보낼 때:

```bash
# 1) 페인 ID 조회
PANE=$(tmux list-panes -F '#{pane_id} #{@agent_name}' | awk '$2=="api-a"{print $1}')

# 2) [AGENT_MODE] 프리픽스 + 명확한 지시
tmux send-keys -t "$PANE" "[AGENT_MODE] 현재 브랜치에서 git status 보여줘" Enter

# 3) 응답 확인
sleep 3
tmux capture-pane -t "$PANE" -p | tail -30
```

**금지사항**:
- 워커 응답을 다른 워커에게 그대로 forwarding 금지 (루프)
- `[AGENT_MODE]` 프리픽스 없이 워커 페인에 명령 전송 금지
- 워커끼리 직접 통신 금지 (모든 조율은 오케스트레이터 경유)
