---
description: 블로그 자동 작성 파이프라인 실행 (orchestrator → search-agent → writer-agent)
argument-hint: <카테고리 | URL> [--engine google|exa]
---

# blog-post

블로그 자동 작성 파이프라인을 실행한다.
플러그인의 `scripts/spawn-blog-agents.sh`를 통해 orchestrator → search-agent → writer-agent 순으로 실행된다.

검색 엔진은 **기본값이 Google(WebSearch)** 이며, 별도 MCP 설치 없이 동작한다.
**Exa는 옵션**으로, `--engine exa`를 줄 때만 사용된다.

## Usage
```
/blog-post [카테고리]                          # 카테고리 기반 검색 (기본: Google)
/blog-post [카테고리] --engine google          # Google 웹서치로 검색 (기본과 동일)
/blog-post [카테고리] --engine exa             # Exa MCP로 검색 (추가 엔진)
/blog-post [URL]                               # 특정 URL 내용을 그대로 포스팅
```

## Examples
```
/blog-post "Kotlin 코루틴"                      # 기본 Google 엔진
/blog-post "MSA 아키텍처" --engine google
/blog-post "Spring Boot" --engine exa           # Exa 엔진 (아래 사전 요건 참고)
/blog-post https://example.com/some-article
```

## Exa 엔진 추가 사용법 (옵션)

기본 Google 대신 Exa로 더 풍부한 검색/크롤링을 쓰려면:

1. **Exa MCP 서버 설치** — `mcp__exa__web_search_advanced_exa`, `mcp__exa__crawling_exa` 도구가 필요하다.
   ```bash
   claude mcp add exa --env EXA_API_KEY=<your-key> -- npx -y exa-mcp-server
   ```
2. 설치 확인 후 `--engine exa` 옵션으로 실행:
   ```
   /blog-post "Kotlin 코루틴" --engine exa
   ```
   > Exa MCP가 없으면 search-agent가 자동으로 Google 엔진으로 폴백한다.

## Arguments
- `$ARGUMENTS` : 카테고리, URL, 옵션 포함 전체 문자열

## Steps

### 1. 환경 확인
```bash
: "${BLOG_REPO_PATH:?'BLOG_REPO_PATH 환경변수가 설정되지 않았습니다.'}"
```

### 2. 인자 파싱 및 모드 분기

`$ARGUMENTS`를 파싱하여 아래 규칙으로 분기한다:

- `http://` 또는 `https://`로 시작하면 → **URL 모드**
- `--engine exa` 포함 → **카테고리 모드 (Exa)**
- 그 외(옵션 없음 또는 `--engine google`) → **카테고리 모드 (Google · 기본)**

스크립트 경로는 플러그인 루트를 기준으로 한다:
```bash
SPAWN="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude}/scripts/spawn-blog-agents.sh"
```

#### URL 모드
```bash
bash "$SPAWN" --url "{URL}"
```

#### 카테고리 모드 (Google · 기본)
```bash
bash "$SPAWN" --engine google "{카테고리}"   # --engine 생략 시에도 google
```

#### 카테고리 모드 (Exa · 옵션)
```bash
bash "$SPAWN" --engine exa "{카테고리}"
```
