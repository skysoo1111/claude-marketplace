---
description: team-mode 프로젝트 레지스트리 생성 (워크스페이스 자동 스캔)
argument-hint: [workspace-root-path]
---

# Team Mode Init

이 컴퓨터의 워크스페이스를 스캔하여 `~/.claude/team-mode/registry.json`을 생성합니다.

**Arguments**: `$ARGUMENTS` (워크스페이스 루트 경로, 생략 시 질문)

## 실행 절차

1. **워크스페이스 루트 결정**
   - `$ARGUMENTS`가 있으면 그 경로 사용
   - 없으면 사용자에게 "프로젝트들이 모여있는 워크스페이스 루트 경로를 알려주세요" 질문
   - 경로의 `~`는 `$HOME`으로 확장, 디렉토리 존재 확인

2. **git 레포 자동 스캔**: Bash로 워크스페이스 1단계 하위의 git 레포를 찾는다
   ```bash
   ROOT="<워크스페이스 루트>"
   for d in "$ROOT"/*/; do
     [ -d "$d/.git" ] || continue
     name=$(basename "$d")
     cur=$(git -C "$d" branch --show-current 2>/dev/null)
     branches=$(git -C "$d" branch -r 2>/dev/null | sed 's#.*origin/##' | grep -v HEAD | sort -u | tr '\n' ' ')
     echo "DIR=$name | CURRENT=$cur | REMOTE_BRANCHES=$branches"
   done
   ```

3. **매핑 제안**: 스캔 결과로 각 레포에 대해 다음을 제안하고 사용자 확인을 받는다
   - **short name**: 디렉토리명을 간결하게 (예: `my-org-backend-web-service` → `web`). 사용자가 수정 가능
   - **branches**: 원격 브랜치 중 배포 브랜치(dev/qa/qc/main 등)를 후보로 제시
   - **default_branch**: 현재 브랜치 또는 dev 우선
   - 등록에서 제외할 레포가 있으면 빼도 됨

4. **registry.json 작성**: `~/.claude/team-mode/registry.json`에 아래 형식으로 저장
   - 디렉토리가 없으면 `mkdir -p ~/.claude/team-mode` 먼저 실행
   - `dir`은 워크스페이스 루트 기준 상대경로(디렉토리명)로 저장

   ```json
   {
     "_workspace_root": "<워크스페이스 루트 절대경로>",
     "_branch_conventions": {
       "default": ["dev", "qa", "qc", "main"]
     },
     "projects": {
       "<short-name>": {
         "dir": "<디렉토리명>",
         "description": "<간단 설명, 비워도 됨>",
         "branches": ["dev", "qa", "qc", "main"],
         "default_branch": "dev"
       }
     }
   }
   ```

5. **결과 안내**: 등록된 프로젝트 목록을 테이블로 보여주고
   "이제 `/team-mode <project1>, <project2>` 로 실행할 수 있습니다" 안내

## 주의
- 기존 `~/.claude/team-mode/registry.json`이 있으면 덮어쓰기 전에 사용자에게 확인
- 프로젝트마다 배포 브랜치 규칙이 다르면 해당 프로젝트의 `branches`/`default_branch`를 개별 지정
