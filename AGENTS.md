# 저장소 지침

## 프로젝트 구조와 모듈 구성
`jssh-gum`은 메인 실행 스크립트이며 초기 설정, 환경 파일 로드, gum 기반 메뉴 흐름을 담당합니다. 공통 셸 모듈은 `libs/` 아래에 있습니다. `ui_utils.sh`는 터미널 UI, `ssh_utils.sh`는 SSH 연결, `installer.sh`는 의존성 설치를 맡습니다. `libs/form.py`는 Python curses 기반 폼 편집기로, `add_server` / `edit_server`에서 `python3 libs/form.py` 형태로 직접 호출됩니다. 실행 중 사용하는 데이터 파일은 루트의 `default.conf`, `servers.list`입니다. `restore.sh`, `warp-offline-setup.sh`, `warp-remote-init-improved.sh`, `warp-bootstrap.sh`는 복구 또는 Warp 보조 스크립트입니다. `jssh-gum.bak`, `jssh-gum.tar.gz`는 백업 산출물로 보고 직접 수정하지 않습니다.

## servers.list 형식
파이프(`|`) 구분 8개 필드: `별칭|구분|hostname|ip|port|user|password|ssh_key`
- `ip`가 비어있으면 `hostname`을 SSH config alias로 사용 (ip/port/user 생략 가능)
- `ssh_key` 필드가 있으면 패스워드 인증 대신 `-i ssh_key` 옵션으로 연결
- 주석 행(`#`)과 빈 행은 무시됨

## 의존성 및 런타임 동작
- **필수**: `python3`, `gum`, `fzf` — 없으면 시작 시 자동 설치 마법사 실행
- **권장**: `sshpass` — 없으면 패스워드 자동입력 불가 (연결은 됨)
- `WARP_COMPATIBLE_MODE=true`(기본값): `exec ssh ...`로 셸 교체 → 연결 후 스크립트 종료
- `WARP_COMPATIBLE_MODE=false`: 일반 실행 → 연결 종료 후 메뉴로 복귀
- `default.conf`가 없으면 자동 생성됨, `servers.list`도 없으면 더미 예제로 자동 생성

## 빌드, 테스트, 개발 명령
이 저장소는 별도 빌드 시스템 없이 Bash 스크립트 중심으로 운영됩니다.

```bash
bash -n jssh-gum libs/*.sh restore.sh warp-*.sh
```

주요 스크립트와 보조 모듈의 Bash 문법을 검사합니다.

```bash
chmod +x jssh-gum
./jssh-gum
```

로컬에서 UI를 실행합니다. macOS에서는 먼저 `brew install gum`으로 `gum`을 설치합니다.

## 코딩 스타일과 네이밍 규칙
모든 스크립트는 `#!/bin/bash` 기준으로 작성합니다. 함수명은 `load_config`, `connect_ssh_exec`처럼 `snake_case`를 사용합니다. 들여쓰기는 공백 4칸, 설정 상수는 `CONFIG_FILE`, `DEFAULT_PORT`처럼 대문자를 유지합니다. 사용자 대상 메시지는 현재 코드와 같은 짧고 명확한 한글 문장을 우선합니다. 공통 로직은 `jssh-gum`에 누적하지 말고 `libs/`로 분리합니다. 단어 분리가 의도된 경우가 아니면 변수 확장은 항상 따옴표로 감쌉니다.

## 테스트 지침
자동화 테스트는 아직 없습니다. 변경 전후로 `bash -n` 검사를 수행하고, `./jssh-gum`에서 서버 목록 조회, 서버 추가, 검색, SSH 연결 시작까지 기본 흐름을 직접 점검합니다. 설정 로직을 수정했다면 기존 `default.conf` 사용 경로와 설정 파일 자동 생성 경로를 둘 다 확인해야 합니다.

## 커밋과 풀 리퀘스트 지침
현재 히스토리는 `서버들 추가`, `최초 커밋`처럼 짧고 직접적인 한글 제목을 사용합니다. 커밋은 한 가지 동작 변화에 집중하고, 명령형으로 간결하게 작성합니다. PR에는 사용자에게 보이는 변경점, `default.conf` 또는 `servers.list` 형식 변경 여부, 메뉴 UI 변경 시 터미널 캡처 이미지를 포함합니다.

## 보안과 설정 주의사항
실제 호스트, 계정, 비밀번호는 `servers.list`나 `default.conf`에 커밋하지 않습니다. 예시는 반드시 더미 값으로 작성하고, `sudo` 권한이나 SSH 자격 증명에 영향을 주는 새 의존성이 생기면 문서에 명시합니다.
