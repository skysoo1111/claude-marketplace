# claude-marketplace

Claude Code 커스텀 플러그인 마켓플레이스. git 워크플로우, 멀티 프로젝트 오케스트레이션, 블로그 자동화 플러그인을 제공합니다.

## 마켓플레이스 등록

```
/plugin marketplace add skysoo1111/claude-marketplace
```

등록하면 `skysoo-marketplace`라는 이름으로 추가됩니다. 이후 원하는 플러그인을 설치하세요.

```
/plugin install git-flow@skysoo-marketplace
/plugin install team-mode@skysoo-marketplace
/plugin install blog-post@skysoo-marketplace
```

> 설치 직후 `/reload-plugins`를 실행해야 커맨드가 활성화됩니다.
> repo 내용이 갱신되면 `/plugin marketplace update skysoo-marketplace`로 최신화합니다.

플러그인 커맨드는 `플러그인명:커맨드명` 으로 네임스페이싱됩니다. 예: `/team-mode:team-mode-init`, `/blog-post:blog-post`.

---

## 1. git-flow

commit과 배포 브랜치 머지/푸시를 자동화하는 git 워크플로우 커맨드 모음.

### 선행 조건
- git 저장소 안에서 실행
- 빌드 검증 단계가 `./gradlew compileKotlin compileTestKotlin`를 사용 → **Kotlin/Gradle 프로젝트 전용** (다른 스택은 해당 라인 수정 필요)
- `/push`는 대상 저장소에 `dev`, `qa`, `qc` 브랜치가 존재해야 함

### 커맨드

| 커맨드 | 기능 |
|--------|------|
| `/commit` | 변경 파일 분석 → 빌드 검증 → 커밋 메시지 자동 작성 후 커밋 |
| `/push {브랜치명}` | 작업 브랜치를 `dev → qa → qc` 순서로 머지하고 각 단계 빌드 후 푸시 |

### 실행 방법
```
/commit
/push feature/news        # 인자 생략 시 현재 브랜치 사용
```

### 동작 상세
- **/commit**: `git status`/`git diff`로 변경 분석 → `.yml`/`.yaml`/`.xml`/`.log` 파일은 커밋 포함 여부 질문 → 빌드 성공 확인 후 `feat({브랜치명}): 요약` 형식으로 커밋
- **/push**: 작업 브랜치 푸시 → `dev`, `qa`, `qc`를 차례로 pull·merge·빌드·push. 빌드 실패 시 해당 브랜치 롤백(`git merge --abort`)

---

## 2. team-mode

여러 프로젝트를 tmux 페인으로 분할해 동시에 작업하는 멀티 프로젝트 오케스트레이션. 각 프로젝트마다 워커 에이전트(`project-worker`)를 띄우고, 메인 세션이 오케스트레이터가 됩니다.

### 선행 조건
- `tmux`, `jq` 설치 (`brew install tmux jq` 또는 `apt install tmux jq`)
- **tmux 세션 안에서 실행**해야 함
- 최초 1회 `/team-mode:team-mode-init`으로 프로젝트 매핑 생성 필요 → `~/.claude/team-mode/registry.json`

### 커맨드

| 커맨드 | 기능 |
|--------|------|
| `/team-mode:team-mode-init [워크스페이스경로]` | 워크스페이스 하위 git 레포를 자동 스캔해 registry.json 생성 |
| `/team-mode:team-mode <p1>, <p2>[:branch] ...` | 등록된 프로젝트들을 tmux로 분할하고 워커 에이전트 spawn (최대 4개) |

### 실행 방법
```
# 최초 1회: 프로젝트 매핑 (각 컴퓨터에서 자기 경로로)
/team-mode:team-mode-init ~/Documents/workspace

# 실행: 브랜치 생략 시 default_branch 사용
/team-mode:team-mode api-a, api-b
/team-mode:team-mode api-a:qa, api-b:qa, api-c:qa
```

### 동작 상세
- `registry.json`의 `_workspace_root` 기준으로 각 프로젝트 경로를 해석 (각 컴퓨터에서 init으로 직접 생성하므로 머신마다 경로가 달라도 됨)
- 오케스트레이터가 워커에게 작업 지시 시 `[AGENT_MODE]` 프리픽스 필수 (루프 방지)
- 워커는 `bypassPermissions` 모드로 실행되며 위험 명령은 오케스트레이터에 보고

---

## 3. blog-post

검색 → 작성 → 게시까지 자동화하는 블로그 포스팅 파이프라인. orchestrator가 search-agent(자료 수집)와 writer-agent(Jekyll 포스트 작성)를 순차 실행하고, 완성된 글을 블로그 저장소에 push합니다.

### 선행 조건
- 환경변수 **`BLOG_REPO_PATH`** 설정 (게시할 블로그 git 저장소). 미설정 시 실행 중단
  ```bash
  export BLOG_REPO_PATH="https://github.com/<user>/<user>.github.io.git"
  ```
- 기본 검색 엔진 **Google(WebSearch)** 은 별도 설치 없이 동작
- (옵션) Exa 엔진 사용 시 Exa MCP 서버 설치 — 아래 참고

### 커맨드

| 커맨드 | 기능 |
|--------|------|
| `/blog-post:blog-post <카테고리\|URL> [옵션]` | 카테고리 검색 또는 URL 내용 기반으로 블로그 포스트 자동 작성·게시 |

### 옵션 / 실행 모드

| 입력 형태 | 모드 | 설명 |
|-----------|------|------|
| `/blog-post:blog-post "카테고리"` | 카테고리 (Google·기본) | 별도 옵션 없이 Google 웹서치로 자료 수집 |
| `/blog-post:blog-post "카테고리" --engine google` | 카테고리 (Google) | 기본과 동일, 엔진 명시 |
| `/blog-post:blog-post "카테고리" --engine exa` | 카테고리 (Exa) | Exa MCP로 더 풍부한 검색/크롤링 (MCP 필요) |
| `/blog-post:blog-post https://example.com/article` | URL | 해당 URL 내용을 그대로 포스팅 |

```
/blog-post:blog-post "Kotlin 코루틴"
/blog-post:blog-post "MSA 아키텍처" --engine google
/blog-post:blog-post "Spring Boot" --engine exa
/blog-post:blog-post https://example.com/some-article
```

### 검색 엔진 확장 (Exa MCP)

`--engine` 옵션으로 검색 엔진을 바꿀 수 있습니다. **기본 Google 외에 별도 MCP 서버를 추가하면 다양한 엔진을 사용할 수 있습니다.** 현재 지원되는 추가 엔진은 Exa입니다.

```bash
# Exa MCP 서버 설치 (mcp__exa__web_search_advanced_exa, mcp__exa__crawling_exa 도구 제공)
claude mcp add exa --env EXA_API_KEY=<your-key> -- npx -y exa-mcp-server
```

설치 후 `--engine exa`로 실행하면 Exa 기반 검색이 사용됩니다.
> Exa MCP가 설치돼 있지 않으면 search-agent가 **자동으로 Google 엔진으로 폴백**하므로 명령 자체는 실패하지 않습니다.

### 동작 상세
- 파이프라인은 `scripts/spawn-blog-agents.sh`가 `claude --dangerously-skip-permissions --agent blog-post:orchestrator`로 자율 실행
- 자율 에이전트가 파일 작성 및 `git push`까지 수행하므로 **공개 블로그에 실제 게시**됨 (되돌리기 어려운 외부 작업)
- 포함 에이전트: `orchestrator`(총괄), `search-agent`(자료 수집), `writer-agent`(Jekyll 작성)

---

## 업데이트 / 제거

```
/plugin marketplace update skysoo-marketplace   # repo 최신 반영
/plugin uninstall <플러그인명>                   # 개별 제거
```
