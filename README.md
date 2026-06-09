# claude-marketplace

Claude Code 커스텀 커맨드 마켓플레이스.

## 설치

```
/plugin marketplace add skysoo1111/claude-marketplace
/plugin install git-flow@skysoo-marketplace
```

설치 후 `/plugin` 메뉴에서 활성화하면 커맨드를 바로 사용할 수 있습니다.

## 플러그인

### git-flow

commit과 push(dev/qa/qc 머지)를 자동화하는 git 워크플로우 커맨드 모음.

- `/commit` — 변경 파일 분석 후 빌드 확인하고 자동 커밋
- `/push {브랜치명}` — 작업 브랜치를 dev → qa → qc에 순차 머지/푸시

### team-mode

여러 프로젝트를 tmux 페인으로 분할해 동시 작업하는 멀티 프로젝트 오케스트레이션.

```
/plugin install team-mode@skysoo-marketplace
```

- `/team-mode-init [워크스페이스경로]` — 워크스페이스를 스캔해 프로젝트 매핑(`~/.claude/team-mode/registry.json`) 생성. **최초 1회 필수**
- `/team-mode <project1>, <project2>[:branch]` — 등록된 프로젝트들을 tmux 페인으로 분할하고 각 페인에 워커 에이전트 spawn

**요구사항**: `tmux`, `jq`, tmux 세션 내 실행. 프로젝트 경로는 각 컴퓨터에서 `/team-mode-init`으로 직접 매핑합니다.

## 업데이트

```
/plugin marketplace update skysoo-marketplace
```
