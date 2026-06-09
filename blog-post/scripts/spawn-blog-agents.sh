#!/bin/bash
# 블로그 자동화 파이프라인 실행 스크립트 (Agent Teams 방식)
# 사용법 (카테고리 모드 · 기본 Google): ./spawn-blog-agents.sh "Kotlin 백엔드"
#                         (Exa 옵션):    ./spawn-blog-agents.sh --engine exa "Kotlin 백엔드"
# 사용법 (URL 모드):      ./spawn-blog-agents.sh --url "https://example.com/article"

set -e

# ── 인자 파싱 ─────────────────────────────────────────
MODE="category"
ENGINE="google"   # 기본 검색 엔진 (옵션: exa)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)    MODE="url";  TARGET="$2"; shift 2 ;;
    --engine) ENGINE="$2";              shift 2 ;;
    *)        TARGET="$1";              shift   ;;
  esac
done

TARGET="${TARGET:-"백엔드 개발"}"
# ──────────────────────────────────────────────────────

LOG_DIR="/tmp/blog-pipeline"
mkdir -p "$LOG_DIR"

echo "🚀 블로그 파이프라인 시작 (Agent Teams)"
echo "   모드: $MODE | 엔진: $ENGINE | 대상: $TARGET"

# ── 프롬프트 구성 ─────────────────────────────────────
if [[ "$MODE" == "url" ]]; then
  PROMPT="URL '$TARGET' 의 내용을 그대로 내 깃헙 블로그에 포스팅해줘.
search-agent teammate가 해당 URL을 fetch하고,
writer-agent teammate가 Jekyll 포맷으로 저장해줘."
elif [[ "$ENGINE" == "exa" ]]; then
  PROMPT="카테고리 '$TARGET' 에 대한 블로그 포스팅 파이프라인을 실행해줘.
search-agent teammate는 Exa MCP로 자료를 수집하고,
writer-agent teammate가 포스트를 작성해줘."
else
  PROMPT="카테고리 '$TARGET' 에 대한 블로그 포스팅 파이프라인을 실행해줘.
search-agent teammate는 Google WebSearch로 자료를 수집하고,
writer-agent teammate가 포스트를 작성해줘."
fi

# ── Agent Teams로 orchestrator 실행 ──────────────────
# 플러그인 설치 시 에이전트는 'blog-post:orchestrator'로 namespacing된다.
# 비(非)플러그인(로컬 ~/.claude/agents) 환경에서 돌릴 땐 BLOG_ORCHESTRATOR_AGENT=orchestrator 로 override.
ORCHESTRATOR_AGENT="${BLOG_ORCHESTRATOR_AGENT:-blog-post:orchestrator}"

export BLOG_REPO_PATH
export MODE
export ENGINE
export TARGET

echo "   에이전트: $ORCHESTRATOR_AGENT"

claude --dangerously-skip-permissions \
  --agent "$ORCHESTRATOR_AGENT" \
  "$PROMPT" \
  2>&1 | tee "$LOG_DIR/orchestrator.log"