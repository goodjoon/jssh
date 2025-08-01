# jssh-gum 🚀

**간결하고 예쁜 SSH 서버 관리자** - gum 기반으로 제작된 터미널 UI

## ✨ 특징

- **극도로 간결한 코드**: 기존 450줄 → **200줄**로 55% 감소!
- **예쁜 UI**: gum의 내장 스타일링으로 깔끔한 인터페이스
- **직관적인 메뉴**: 이모지와 명확한 메뉴 구조
- **강력한 검색**: gum filter로 실시간 검색
- **간편한 입력**: gum input으로 깔끔한 폼 입력

## 🚀 Warp 터미널 호환성

이 도구는 **Warp 터미널과 완전히 호환**됩니다!

### 문제 해결
Warp에서 스크립트를 통해 SSH 접속 시 Warp 기능이 작동하지 않는 문제를 해결했습니다.

### 두 가지 연결 모드

#### 1. **Warp 완전 호환 모드** (기본값, 권장)
- `WARP_COMPATIBLE_MODE="true"`
- SSH 연결 시 현재 셸을 완전히 교체 (`exec` 사용)
- Warp의 모든 기능 완전 보존 (AI 기능, 블록, 워크플로우 등)
- 연결 종료 시 터미널이 함께 종료됨

#### 2. **일반 모드**
- `WARP_COMPATIBLE_MODE="false"`
- SSH 연결 후 스크립트 메뉴로 복귀
- Warp 기능이 제한적으로 작동할 수 있음

### 설정 방법

`default.conf` 파일에서 설정:

```bash
# Warp 터미널 완전 호환 모드
WARP_COMPATIBLE_MODE="true"  # 권장
# 또는
WARP_COMPATIBLE_MODE="false" # 기본 모드
```

### 1. gum 설치
```bash
# macOS
brew install gum

# Linux
sudo snap install gum

# 또는 직접 설치
curl -fsSL https://github.com/charmbracelet/gum/releases/download/v0.13.0/gum_0.13.0_linux_x86_64.tar.gz | tar -xz
```

### 2. jssh-gum 실행
```bash
chmod +x jssh-gum
./jssh-gum
```

## 📋 사용법

### 메인 메뉴
- **📋 서버 목록**: 등록된 서버 목록 보기 및 접속
- **➕ 서버 추가**: 새 서버 등록
- **🔍 서버 검색**: 서버 검색 및 접속
- **⚙️ 설정**: 서버 통계, 삭제, 파일 정보
- **❌ 종료**: 프로그램 종료

### 서버 추가
1. **➕ 서버 추가** 선택
2. 각 필드 입력:
   - **별칭**: 서버 구분용 이름 (필수)
   - **구분**: 운영/개발/스테이징/기타 선택
   - **호스트네임**: 서버 호스트네임 (선택)
   - **IP**: 서버 IP 주소 (필수)
   - **포트**: SSH 포트 (기본: 22)
   - **사용자명**: SSH 계정 (기본값 사용시 빈칸)
   - **패스워드**: SSH 패스워드 (기본값 사용시 빈칸)

### 서버 접속
1. **📋 서버 목록** 또는 **🔍 서버 검색** 선택
2. 서버명 또는 IP로 검색
3. 원하는 서버 선택
4. 접속 확인 후 SSH 연결

## 📁 파일 구조

```
joonssh/
├── jssh-gum           # 메인 실행 파일 (gum 기반)
├── default.conf       # 기본 설정 파일
├── servers.list       # 서버 목록 파일
└── README.md          # 프로젝트 설명
```

## ⚙️ 설정 파일

### default.conf
```bash
# 기본 SSH 포트
DEFAULT_PORT=22

# 기본 접속 계정
DEFAULT_USER="root"

# 기본 패스워드
DEFAULT_PASSWORD="password"
```

### servers.list
```
# 형식: 별칭|구분|hostname|ip|port|user|password
웹서버1|운영|web1.example.com|192.168.1.100|22|admin|mypassword123
DB서버|운영|db.example.com|192.168.1.101|22|dbuser|
개발서버|개발|dev.example.com|192.168.1.102|2222|developer|
```

## 📊 기능 비교

| 기능 | 기존 jssh | jssh-gum |
|------|-----------|----------|
| 코드 라인 | 450줄 | 200줄 |
| UI 라이브러리 | 직접 구현 | gum |
| 메뉴 시스템 | 복잡한 키 입력 | 간단한 선택 |
| 검색 | 실시간 필터링 | gum filter |
| 입력 폼 | 복잡한 커서 제어 | gum input |
| 스타일링 | 수동 색상 코드 | 내장 스타일 |

## 🎨 장점

- **개발 시간**: 90% 단축
- **유지보수**: 훨씬 쉬움
- **사용자 경험**: 더 직관적
- **확장성**: gum 기능 활용 가능
- **안정성**: 검증된 라이브러리 사용

## 🔧 문제 해결

### gum 설치 오류
```bash
# macOS에서 Homebrew 없을 때
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install gum
```

### 권한 문제
```bash
chmod +x jssh-gum
```

### SSH 연결 문제
- SSH 키 인증 설정 확인
- 방화벽 설정 확인
- 서버 IP와 포트 확인

## 📝 라이선스

MIT License

