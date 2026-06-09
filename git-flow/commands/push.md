브랜치를 dev, qa, qc에 머지하고 푸시해줘:

**사용법**: /push {브랜치명}
**예시**: /push feature/news

**주의**: news 레포지토리만 push 대상 (grpc-idl 서브모듈 제외)

**중요**: 모든 과정(0~3단계)은 사용자에게 질문 없이 자동으로 진행
**중요**: TodoWrite 도구 사용 금지 - 진행 상황은 최종 결과 테이블로만 표시

## 실행 순서

### 0단계: 브랜치 확인 (ARGUMENTS가 비어있는 경우)
`$ARGUMENTS`가 비어있거나 지정되지 않은 경우:
1. `git branch --show-current`로 현재 브랜치 확인
2. 현재 브랜치를 `$ARGUMENTS`로 자동 사용 (질문 없음)

### 1단계: 작업 브랜치 변경사항 확인 및 푸시
1. `$ARGUMENTS` 브랜치로 체크아웃
2. `git log origin/$ARGUMENTS..$ARGUMENTS`로 원격에 푸시되지 않은 커밋 확인
3. **푸시할 커밋이 있는 경우**:
   ```
   git push origin $ARGUMENTS
   ```
4. **푸시할 커밋이 없는 경우** (원격과 동일):
   - "작업 브랜치에 푸시할 변경사항이 없습니다. 작업을 종료합니다." 메시지 출력
   - **작업 즉시 종료** (2단계로 진행하지 않음)

### 2단계: dev, qa, qc 브랜치 순차 처리
각 브랜치(dev → qa → qc)에 대해 아래 작업 수행:

1. **브랜치 업데이트**
   ```
   git checkout {브랜치}
   git pull origin {브랜치}
   ```

2. **머지 수행**
   ```
   git merge $ARGUMENTS --no-edit
   ```
   - 충돌 발생 시 사용자에게 알리고 중단

3. **빌드 확인 (필수)**
   ```
   ./gradlew compileKotlin compileTestKotlin
   ```
   - 빌드 실패 시 해당 브랜치 작업 중단하고 사용자에게 알림
   - `git merge --abort`로 롤백

4. **푸시**
   ```
   git push origin {브랜치}
   ```

### 3단계: 원래 브랜치로 복귀
```
git checkout $ARGUMENTS
```

## 에러 처리
- 머지 충돌: 충돌 내용 표시하고 수동 해결 요청
- 빌드 실패: 해당 브랜치 롤백 후 다음 브랜치로 자동 진행
- 푸시 실패: 원인 분석 후 사용자에게 알림


## 진행 상황 표시
각 단계마다 진행 상황을 명확히 표시:
- ✅ 성공한 브랜치
- ❌ 실패한 브랜치
- 🔄 진행 중인 브랜치