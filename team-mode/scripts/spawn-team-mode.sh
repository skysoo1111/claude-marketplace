#!/usr/bin/env bash
# spawn-team-mode.sh
#
# Multi-project team mode launcher (portable)
# Usage:
#   spawn-team-mode.sh <project1>[:branch] <project2>[:branch] [project3[:branch]...]
#
# Examples:
#   spawn-team-mode.sh api-a api-b
#   spawn-team-mode.sh api-a:qa api-b:qa
#
# Registry: $HOME/.claude/team-mode/registry.json  (generate with /team-mode-init)

set -euo pipefail

# ─────────────────────────────────────────────────────────────
# Config
# ─────────────────────────────────────────────────────────────
REGISTRY="${TEAM_MODE_REGISTRY:-$HOME/.claude/team-mode/registry.json}"
WORKER_BOOT_WAIT=4   # claude CLI 부팅 대기 (초)
MAX_WORKERS=4        # 화면 분할 한계

# ─────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────
die() { echo "❌ $*" >&2; exit 1; }
info() { echo "▶ $*"; }
ok() { echo "✅ $*"; }

usage() {
  cat <<EOF
Usage: $(basename "$0") <project1>[:branch] [project2[:branch]] ...

Available projects:
$(jq -r '.projects | to_entries[] | "  - \(.key) (default: \(.value.default_branch))"' "$REGISTRY")

Examples:
  $(basename "$0") $(jq -r '.projects | keys[0:2] | join(" ")' "$REGISTRY" 2>/dev/null || echo "projA projB")
EOF
  exit 1
}

# ─────────────────────────────────────────────────────────────
# Validations
# ─────────────────────────────────────────────────────────────
[ -z "${TMUX:-}" ] && die "tmux 세션 내에서 실행해야 합니다."
command -v jq >/dev/null 2>&1 || die "jq가 필요합니다. (brew install jq / apt install jq)"
command -v tmux >/dev/null 2>&1 || die "tmux가 필요합니다."
if [ ! -f "$REGISTRY" ]; then
  die "registry가 없습니다: $REGISTRY
   → 먼저 '/team-mode-init' 으로 프로젝트를 매핑하세요."
fi

# 워크스페이스 루트는 registry에서 읽음 (하드코딩 제거)
WORKSPACE_ROOT=$(jq -r '._workspace_root // empty' "$REGISTRY")
[ -z "$WORKSPACE_ROOT" ] && die "registry에 '_workspace_root'가 없습니다. /team-mode-init 으로 다시 생성하세요."
WORKSPACE_ROOT="${WORKSPACE_ROOT/#\~/$HOME}"   # ~ 확장
[ -d "$WORKSPACE_ROOT" ] || die "워크스페이스 루트가 존재하지 않습니다: $WORKSPACE_ROOT"

[ "$#" -lt 1 ] && usage
[ "$#" -gt "$MAX_WORKERS" ] && die "워커는 최대 ${MAX_WORKERS}개까지 지원합니다. (현재: $#)"

# ─────────────────────────────────────────────────────────────
# Parse args & validate projects
# ─────────────────────────────────────────────────────────────
declare -a NAMES PATHS BRANCHES

for arg in "$@"; do
  name="${arg%%:*}"
  branch="${arg#*:}"
  [ "$branch" = "$arg" ] && branch=""  # 콜론 없으면 빈 값

  # registry에서 조회
  dir=$(jq -r --arg k "$name" '.projects[$k].dir // empty' "$REGISTRY")
  [ -z "$dir" ] && die "'$name' 프로젝트를 registry에서 찾을 수 없습니다. (/team-mode-init 으로 등록)"

  # 브랜치 미지정 시 default 사용
  if [ -z "$branch" ]; then
    branch=$(jq -r --arg k "$name" '.projects[$k].default_branch' "$REGISTRY")
  elif [[ "$branch" == */* ]]; then
    # prefix 가 포함된 작업 브랜치(feature/* 등): 검증 스킵
    info "작업 브랜치로 인식: $branch"
  else
    # 지정된 브랜치가 허용 목록에 있는지 검증
    valid=$(jq -r --arg k "$name" --arg b "$branch" \
      '.projects[$k].branches | index($b) // empty' "$REGISTRY")
    if [ -z "$valid" ]; then
      allowed=$(jq -r --arg k "$name" '.projects[$k].branches | join(", ")' "$REGISTRY")
      die "'$name' 프로젝트의 브랜치 '$branch'는 허용되지 않습니다. 허용: $allowed"
    fi
  fi

  # dir 이 절대경로면 그대로, 아니면 워크스페이스 루트 기준 상대경로
  case "$dir" in
    /*) full_path="$dir" ;;
    *)  full_path="$WORKSPACE_ROOT/$dir" ;;
  esac
  [ -d "$full_path" ] || die "경로가 존재하지 않음: $full_path"

  NAMES+=("$name")
  PATHS+=("$full_path")
  BRANCHES+=("$branch")
done

NUM_WORKERS=${#NAMES[@]}

# ─────────────────────────────────────────────────────────────
# 워커 부팅 프롬프트 (임시 파일로 quote 안전하게)
# ─────────────────────────────────────────────────────────────
make_worker_prompt() {
  local project_name="$1"
  local branch="$2"
  local work_dir="$3"
  local tmpfile
  tmpfile=$(mktemp -t team-mode-prompt.XXXXXX)
  cat > "$tmpfile" <<EOF
[AGENT_MODE] 당신은 '${project_name}' 프로젝트의 워커 에이전트입니다.

작업 디렉토리: ${work_dir}
현재 브랜치: ${branch}

규약:
1. 오케스트레이터로부터 [AGENT_MODE] 프리픽스가 붙은 메시지로 작업을 받습니다
2. 모든 응답은 간결하게, 작업 결과만 보고합니다
3. 다른 페인이나 에이전트에게 직접 메시지를 보내지 않습니다 (루프 방지)
4. 작업 전 \`git status\` 및 \`git branch --show-current\`로 상태를 확인하세요
5. 위험 명령(rm, git push, git reset --hard, --force, --no-verify, git checkout/restore .)은 직접 실행하지 마세요. 필요할 때는 "권한 필요: <명령>" 형태로 오케스트레이터에 보고하세요. 오케가 사용자 확인 후 직접 실행합니다.
6. 자세한 규약은 project-worker 에이전트 정의를 따르세요.

준비되면 "워커 [${project_name}] 준비 완료" 라고만 응답하세요.
EOF
  echo "$tmpfile"
}

# ─────────────────────────────────────────────────────────────
# tmux layout 구성
# ─────────────────────────────────────────────────────────────
ORCHESTRATOR_PANE=$(tmux display-message -p '#{pane_id}')

# 현재 페인 = 오케스트레이터
tmux select-pane -t "$ORCHESTRATOR_PANE" -T "orchestrator"
tmux set-option -p -t "$ORCHESTRATOR_PANE" @agent_name "orchestrator"

info "오케스트레이터: $ORCHESTRATOR_PANE"

# 오른쪽에 첫 워커 페인 생성 (좌우 분할)
tmux split-window -h -t "$ORCHESTRATOR_PANE" -c "${PATHS[0]}"
declare -a WORKER_PANES
WORKER_PANES+=("$(tmux display-message -p '#{pane_id}')")

# 추가 워커는 오른쪽을 세로로 계속 분할
for ((i=1; i<NUM_WORKERS; i++)); do
  prev_pane="${WORKER_PANES[$((i-1))]}"
  tmux split-window -v -t "$prev_pane" -c "${PATHS[$i]}"
  WORKER_PANES+=("$(tmux display-message -p '#{pane_id}')")
done

# 오른쪽 페인들 균등 분배 (워커가 2개 이상일 때만)
if [ "$NUM_WORKERS" -ge 2 ]; then
  tmux select-layout -t "$ORCHESTRATOR_PANE" main-vertical
  # main-vertical은 좌측을 메인으로 두고 우측을 균등 분할
  tmux resize-pane -t "$ORCHESTRATOR_PANE" -x 40%
fi

# ─────────────────────────────────────────────────────────────
# 각 워커 페인 셋업: 브랜치 체크아웃 + claude 실행 + 프롬프트 주입
# ─────────────────────────────────────────────────────────────
for ((i=0; i<NUM_WORKERS; i++)); do
  pane="${WORKER_PANES[$i]}"
  name="${NAMES[$i]}"
  path="${PATHS[$i]}"
  branch="${BRANCHES[$i]}"

  tmux select-pane -t "$pane" -T "$name [$branch]"
  tmux set-option -p -t "$pane" @agent_name "$name"
  tmux set-option -p -t "$pane" @project_branch "$branch"
  tmux set-option -p -t "$pane" @project_path "$path"

  info "워커 [$name] → $pane (브랜치: $branch)"

  # 브랜치 체크아웃 (실패해도 진행)
  tmux send-keys -t "$pane" "git fetch --quiet && git checkout '$branch' 2>/dev/null || echo '⚠️  브랜치 체크아웃 실패: $branch (수동 처리 필요)'" Enter

  # claude 실행 (워커는 bypassPermissions 모드)
  tmux send-keys -t "$pane" "claude --permission-mode bypassPermissions" Enter

  # 부팅 대기
  sleep "$WORKER_BOOT_WAIT"

  # 프롬프트 주입 (임시 파일 사용)
  prompt_file=$(make_worker_prompt "$name" "$branch" "$path")
  tmux send-keys -t "$pane" "$(cat "$prompt_file")" Enter
  rm -f "$prompt_file"
done

# ─────────────────────────────────────────────────────────────
# 마무리
# ─────────────────────────────────────────────────────────────
tmux select-pane -t "$ORCHESTRATOR_PANE"

echo
ok "Team mode ready"
echo
echo "📋 구성:"
echo "   오케스트레이터 (현재 페인)"
for ((i=0; i<NUM_WORKERS; i++)); do
  echo "   └─ ${NAMES[$i]} [${BRANCHES[$i]}] @ ${PATHS[$i]}"
done
echo
echo "💡 워커에게 작업 지시:"
echo "   tmux send-keys -t <pane> '[AGENT_MODE] <작업 내용>' Enter"
echo "   페인 ID 조회: tmux list-panes -F '#{pane_id} #{@agent_name}'"
