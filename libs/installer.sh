#!/bin/bash
# installer.sh - 필수 도구 설치 관리 모듈
# jssh-gum에서 사용하는 설치 관련 함수들

# OS 감지
detect_os() {
    case "$OSTYPE" in
        darwin*)  echo "macos" ;;
        linux*)   echo "linux" ;;
        msys*|cygwin*|mingw*) echo "windows" ;;
        *) echo "unknown" ;;
    esac
}

# 필수 도구 확인
check_required_tools() {
    local missing_tools=()
    
    # gum 확인
    if ! command -v gum &> /dev/null; then
        missing_tools+=("gum")
    fi
    
    # sshpass 확인 (선택사항이지만 권장)
    if ! command -v sshpass &> /dev/null; then
        missing_tools+=("sshpass")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}

# gum 설치
install_gum() {
    local os=$(detect_os)
    
    echo "~ gum 설치를 시작합니다..."
    echo ""
    
    case "$os" in
        "macos")
            install_gum_macos
            ;;
        "linux")
            install_gum_linux
            ;;
        "windows")
            install_gum_windows
            ;;
        *)
            echo "✗ 지원하지 않는 운영체제입니다."
            return 1
            ;;
    esac
}

# macOS에서 gum 설치
install_gum_macos() {
    if command -v brew &> /dev/null; then
        echo "+ Homebrew로 gum 설치 중..."
        if brew install gum; then
            echo "✓ gum 설치 완료!"
            return 0
        else
            echo "✗ Homebrew 설치 실패"
            return 1
        fi
    else
        echo "✗ Homebrew가 설치되지 않았습니다."
        echo "   Homebrew 설치: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        echo "   또는 수동 설치: https://github.com/charmbracelet/gum/releases"
        return 1
    fi
}

# Linux에서 gum 설치
install_gum_linux() {
    if command -v snap &> /dev/null; then
        echo "+ snap으로 gum 설치 중..."
        if sudo snap install gum; then
            echo "✓ gum 설치 완료!"
            return 0
        else
            echo "✗ snap 설치 실패"
        fi
    fi
    
    # apt-get 시도
    if command -v apt-get &> /dev/null; then
        echo "+ apt-get으로 gum 설치 중..."
        if sudo mkdir -p /etc/apt/keyrings && \
           curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg && \
           echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list && \
           sudo apt update && sudo apt install gum; then
            echo "✓ gum 설치 완료!"
            return 0
        else
            echo "✗ apt-get 설치 실패"
        fi
    fi
    
    # yum/dnf 시도
    if command -v yum &> /dev/null || command -v dnf &> /dev/null; then
        local pkg_manager="yum"
        command -v dnf &> /dev/null && pkg_manager="dnf"
        
        echo "+ $pkg_manager으로 gum 설치 중..."
        if sudo rpm --import https://repo.charm.sh/yum/gpg.key && \
           echo '[charm]
name=Charm
baseurl=https://repo.charm.sh/yum/
enabled=1
gpgcheck=1
gpgkey=https://repo.charm.sh/yum/gpg.key' | sudo tee /etc/yum.repos.d/charm.repo && \
           sudo $pkg_manager install gum; then
            echo "✓ gum 설치 완료!"
            return 0
        else
            echo "✗ $pkg_manager 설치 실패"
        fi
    fi
    
    echo "✗ 지원하는 패키지 관리자를 찾을 수 없습니다."
    echo "   수동 설치: https://github.com/charmbracelet/gum/releases"
    return 1
}

# Windows에서 gum 설치
install_gum_windows() {
    if command -v scoop &> /dev/null; then
        echo "+ Scoop으로 gum 설치 중..."
        if scoop install gum; then
            echo "✓ gum 설치 완료!"
            return 0
        else
            echo "✗ Scoop 설치 실패"
        fi
    fi
    
    if command -v choco &> /dev/null; then
        echo "+ Chocolatey로 gum 설치 중..."
        if choco install gum -y; then
            echo "✓ gum 설치 완료!"
            return 0
        else
            echo "✗ Chocolatey 설치 실패"
        fi
    fi
    
    if command -v winget &> /dev/null; then
        echo "+ winget으로 gum 설치 중..."
        if winget install charmbracelet.gum; then
            echo "✓ gum 설치 완료!"
            return 0
        else
            echo "✗ winget 설치 실패"
        fi
    fi
    
    echo "✗ 지원하는 패키지 관리자를 찾을 수 없습니다."
    echo "   Scoop 설치: iwr -useb get.scoop.sh | iex"
    echo "   Chocolatey 설치: https://chocolatey.org/install"
    echo "   또는 수동 설치: https://github.com/charmbracelet/gum/releases"
    return 1
}

# sshpass 설치
install_sshpass() {
    local os=$(detect_os)
    
    echo "~ sshpass 설치를 시작합니다..."
    echo ""
    
    case "$os" in
        "macos")
            install_sshpass_macos
            ;;
        "linux")
            install_sshpass_linux
            ;;
        "windows")
            install_sshpass_windows
            ;;
        *)
            echo "✗ 지원하지 않는 운영체제입니다."
            return 1
            ;;
    esac
}

# macOS에서 sshpass 설치
install_sshpass_macos() {
    if command -v brew &> /dev/null; then
        echo "+ Homebrew로 sshpass 설치 중..."
        if brew install hudochenkov/sshpass/sshpass; then
            echo "✓ sshpass 설치 완료!"
            return 0
        else
            echo "✗ Homebrew 설치 실패"
            return 1
        fi
    elif command -v port &> /dev/null; then
        echo "+ MacPorts로 sshpass 설치 중..."
        if sudo port install sshpass; then
            echo "✓ sshpass 설치 완료!"
            return 0
        else
            echo "✗ MacPorts 설치 실패"
            return 1
        fi
    else
        echo "✗ 패키지 관리자를 찾을 수 없습니다."
        echo "   Homebrew 설치 후 다시 시도하세요."
        return 1
    fi
}

# Linux에서 sshpass 설치
install_sshpass_linux() {
    if command -v apt-get &> /dev/null; then
        echo "+ apt-get으로 sshpass 설치 중..."
        if sudo apt-get update && sudo apt-get install -y sshpass; then
            echo "✓ sshpass 설치 완료!"
            return 0
        else
            echo "✗ apt-get 설치 실패"
            return 1
        fi
    elif command -v yum &> /dev/null; then
        echo "+ yum으로 sshpass 설치 중..."
        if sudo yum install -y sshpass; then
            echo "✓ sshpass 설치 완료!"
            return 0
        else
            echo "✗ yum 설치 실패"
            return 1
        fi
    elif command -v dnf &> /dev/null; then
        echo "+ dnf로 sshpass 설치 중..."
        if sudo dnf install -y sshpass; then
            echo "✓ sshpass 설치 완료!"
            return 0
        else
            echo "✗ dnf 설치 실패"
            return 1
        fi
    elif command -v pacman &> /dev/null; then
        echo "+ pacman으로 sshpass 설치 중..."
        if sudo pacman -S --noconfirm sshpass; then
            echo "✓ sshpass 설치 완료!"
            return 0
        else
            echo "✗ pacman 설치 실패"
            return 1
        fi
    elif command -v snap &> /dev/null; then
        echo "+ snap으로 sshpass 설치 중..."
        if sudo snap install sshpass; then
            echo "✓ sshpass 설치 완료!"
            return 0
        else
            echo "✗ snap 설치 실패"
            return 1
        fi
    else
        echo "✗ 지원하는 패키지 관리자를 찾을 수 없습니다."
        return 1
    fi
}

# Windows에서 sshpass 설치
install_sshpass_windows() {
    if [[ -n "$WSL_DISTRO_NAME" ]] || [[ -f /proc/version ]] && grep -q Microsoft /proc/version; then
        echo "» WSL 환경 감지, Linux 방식으로 설치합니다..."
        install_sshpass_linux
        return $?
    fi
    
    if command -v choco &> /dev/null; then
        echo "+ Chocolatey로 sshpass 설치 중..."
        if choco install sshpass -y; then
            echo "✓ sshpass 설치 완료!"
            return 0
        else
            echo "✗ Chocolatey 설치 실패"
            return 1
        fi
    elif command -v scoop &> /dev/null; then
        echo "+ Scoop으로 sshpass 설치 중..."
        if scoop install sshpass; then
            echo "✓ sshpass 설치 완료!"
            return 0
        else
            echo "✗ Scoop 설치 실패"
            return 1
        fi
    else
        echo "✗ Windows에서 sshpass 자동 설치를 지원하지 않습니다."
        echo "   다음 옵션을 고려해보세요:"
        echo "   1. WSL(Windows Subsystem for Linux) 사용"
        echo "   2. Git Bash + Chocolatey 사용"
        echo "   3. SSH 키 기반 인증 설정"
        return 1
    fi
}

# fzf 설치
install_fzf() {
    local os=$(detect_os)
    
    echo "~ fzf 설치를 시작합니다..."
    echo ""
    
    case "$os" in
        "macos")
            install_fzf_macos
            ;;
        "linux")
            install_fzf_linux
            ;;
        "windows")
            install_fzf_windows
            ;;
        *)
            echo "✗ 지원하지 않는 운영체제입니다."
            return 1
            ;;
    esac
}

# macOS에서 fzf 설치
install_fzf_macos() {
    if command -v brew &> /dev/null; then
        echo "+ Homebrew로 fzf 설치 중..."
        if brew install fzf; then
            echo "✓ fzf 설치 완료!"
            return 0
        else
            echo "✗ Homebrew 설치 실패"
            return 1
        fi
    else
        echo "✗ Homebrew가 설치되지 않았습니다."
        echo "   Homebrew 설치: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        return 1
    fi
}

# Linux에서 fzf 설치
install_fzf_linux() {
    # apt-get 시도
    if command -v apt-get &> /dev/null; then
        echo "+ apt-get으로 fzf 설치 중..."
        if sudo apt-get update && sudo apt-get install -y fzf; then
            echo "✓ fzf 설치 완료!"
            return 0
        else
            echo "✗ apt-get 설치 실패"
        fi
    fi
    
    # yum/dnf 시도
    if command -v yum &> /dev/null || command -v dnf &> /dev/null; then
        local pkg_manager="yum"
        command -v dnf &> /dev/null && pkg_manager="dnf"
        
        echo "+ $pkg_manager으로 fzf 설치 중..."
        if sudo $pkg_manager install -y fzf; then
            echo "✓ fzf 설치 완료!"
            return 0
        else
            echo "✗ $pkg_manager 설치 실패"
        fi
    fi
    
    # pacman 시도
    if command -v pacman &> /dev/null; then
        echo "+ pacman으로 fzf 설치 중..."
        if sudo pacman -S --noconfirm fzf; then
            echo "✓ fzf 설치 완료!"
            return 0
        else
            echo "✗ pacman 설치 실패"
        fi
    fi
    
    #snap 시도
    if command -v snap &> /dev/null; then
        echo "+ snap으로 fzf 설치 중..."
        if sudo snap install fzf; then
            echo "✓ fzf 설치 완료!"
            return 0
        else
            echo "✗ snap 설치 실패"
        fi
    fi
    
    # 직접 다운로드 (최후 수단)
    echo "+ git clone으로 fzf 설치 중..."
    if [[ -d "$HOME/.fzf" ]]; then
        echo "   기존 설치 발견, 업데이트..."
        cd "$HOME/.fzf" && git pull
    else
        git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
    fi
    "$HOME/.fzf/install" --all
    
    if command -v fzf &> /dev/null; then
        echo "✓ fzf 설치 완료!"
        return 0
    else
        echo "✗ fzf 설치 실패"
        return 1
    fi
}

# Windows에서 fzf 설치
install_fzf_windows() {
    if command -v scoop &> /dev/null; then
        echo "+ Scoop으로 fzf 설치 중..."
        if scoop install fzf; then
            echo "✓ fzf 설치 완료!"
            return 0
        else
            echo "✗ Scoop 설치 실패"
        fi
    fi
    
    if command -v choco &> /dev/null; then
        echo "+ Chocolatey로 fzf 설치 중..."
        if choco install fzf -y; then
            echo "✓ fzf 설치 완료!"
            return 0
        else
            echo "✗ Chocolatey 설치 실패"
        fi
    fi
    
    if command -v winget &> /dev/null; then
        echo "+ winget으로 fzf 설치 중..."
        if winget install junegunn.fzf; then
            echo "✓ fzf 설치 완료!"
            return 0
        else
            echo "✗ winget 설치 실패"
        fi
    fi
    
    # WSL 사용 가능 시 Linux 방식으로
    if [[ -n "$WSL_DISTRO_NAME" ]] || [[ -f /proc/version ]] && grep -q Microsoft /proc/version; then
        echo "» WSL 환경 감지, Linux 방식으로 설치합니다..."
        install_fzf_linux
        return $?
    fi
    
    echo "✗ Windows에서 fzf 자동 설치를 지원하지 않습니다."
    echo "   수동 설치: https://github.com/junegunn/fzf"
    return 1
}

# 자동 설치 마법사
auto_install_wizard() {
    echo "» jssh-gum 초기 설정"
    echo ""
    echo "필수 도구들의 설치 상태를 확인합니다..."
    echo ""
    
    local missing_tools=()
    local install_success=true

    # python3 확인 (설치 불가 — 안내만)
    if ! command -v python3 &> /dev/null; then
        echo "✗ python3가 설치되지 않았습니다. (필수)"
        echo "   macOS: brew install python3"
        echo "   Linux: sudo apt-get install python3"
        install_success=false
    else
        echo "✓ python3가 설치되어 있습니다."
    fi

    # gum 확인
    if ! command -v gum &> /dev/null; then
        missing_tools+=("gum")
        echo "✗ gum이 설치되지 않았습니다."
    else
        echo "✓ gum이 이미 설치되어 있습니다."
    fi

    # fzf 확인
    if ! command -v fzf &> /dev/null; then
        missing_tools+=("fzf")
        echo "✗ fzf가 설치되지 않았습니다."
    else
        echo "✓ fzf가 이미 설치되어 있습니다."
    fi

    # sshpass 확인 (선택사항)
    if ! command -v sshpass &> /dev/null; then
        missing_tools+=("sshpass")
        echo "!  sshpass가 설치되지 않았습니다. (선택사항)"
    else
        echo "✓ sshpass가 이미 설치되어 있습니다."
    fi
    
    echo ""
    
    # 설치가 필요한 경우
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo "다음 도구들의 설치가 필요합니다:"
        for tool in "${missing_tools[@]}"; do
            case "$tool" in
                "gum")     echo "  - gum: 터미널 UI 라이브러리 (필수)" ;;
                "fzf")     echo "  - fzf: 서버 목록 검색 UI (필수)" ;;
                "sshpass") echo "  - sshpass: SSH 패스워드 자동입력 (권장)" ;;
            esac
        done
        echo ""
        
        # 설치 진행
        for tool in "${missing_tools[@]}"; do
            case "$tool" in
                "gum")
                    echo "gum을 설치합니다..."
                    if install_gum; then
                        echo "✓ gum 설치 성공!"
                    else
                        echo "✗ gum 설치 실패!"
                        install_success=false
                    fi
                    ;;
                "fzf")
                    echo "fzf를 설치합니다..."
                    if install_fzf; then
                        echo "✓ fzf 설치 성공!"
                    else
                        echo "✗ fzf 설치 실패!"
                        install_success=false
                    fi
                    ;;
                "sshpass")
                    echo ""
                    echo "sshpass 설치는 선택사항입니다."
                    echo "(SSH 연결 시 패스워드 자동 입력을 위해 권장됩니다)"
                    echo ""
                    read -p "sshpass를 설치하시겠습니까? (y/N): " -n 1 -r
                    echo ""
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        if install_sshpass; then
                            echo "✓ sshpass 설치 성공!"
                        else
                            echo "✗ sshpass 설치 실패! (계속 진행 가능)"
                        fi
                    else
                        echo "»  sshpass 설치를 건너뜁니다."
                    fi
                    ;;
            esac
            echo ""
        done
        
        # 설치 결과 확인
        if $install_success && command -v gum &> /dev/null; then
            echo "✓ 필수 도구 설치가 완료되었습니다!"
            echo "   jssh-gum을 사용할 준비가 되었습니다."
            return 0
        else
            echo "✗ 일부 도구 설치에 실패했습니다."
            echo "   수동 설치 후 다시 시도해주세요."
            return 1
        fi
    else
        echo "✓ 모든 도구가 설치되어 있습니다!"
        return 0
    fi
}

# sshpass 설치 확인 및 자동 설치 (기존 호환성 유지)
ensure_sshpass() {
    if command -v sshpass &> /dev/null; then
        return 0
    fi
    
    if command -v gum &> /dev/null; then
        echo "→ sshpass가 설치되지 않았습니다." | gum style --foreground 39 --align center
        echo ""
        
        if gum confirm "sshpass를 자동으로 설치하시겠습니까?"; then
            echo ""
            if install_sshpass; then
                echo ""
                echo "✓ sshpass 설치가 완료되었습니다!" | gum style --foreground 46 --bold --align center
                echo "   이제 패스워드 자동 입력이 가능합니다." | gum style --foreground 8 --align center
                echo ""
                sleep 2
                return 0
            else
                echo ""
                echo "✗ sshpass 자동 설치에 실패했습니다." | gum style --foreground 196 --align center
                echo "   패스워드를 수동으로 입력해야 합니다." | gum style --foreground 8 --align center
                echo ""
                return 1
            fi
        else
            echo ""
            echo "»  자동 설치를 건너뜁니다." | gum style --foreground 8 --align center
            echo "   패스워드를 수동으로 입력해야 합니다." | gum style --foreground 8 --align center
            echo ""
            return 1
        fi
    else
        # gum이 없는 경우 일반 텍스트로 처리
        echo "→ sshpass가 설치되지 않았습니다."
        echo ""
        read -p "sshpass를 자동으로 설치하시겠습니까? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo ""
            if install_sshpass; then
                echo ""
                echo "✓ sshpass 설치가 완료되었습니다!"
                echo "   이제 패스워드 자동 입력이 가능합니다."
                echo ""
                sleep 2
                return 0
            else
                echo ""
                echo "✗ sshpass 자동 설치에 실패했습니다."
                echo "   패스워드를 수동으로 입력해야 합니다."
                echo ""
                return 1
            fi
        else
            echo ""
            echo "»  자동 설치를 건너뜁니다."
            echo "   패스워드를 수동으로 입력해야 합니다."
            echo ""
            return 1
        fi
    fi
}