#!/bin/bash

# Warp 오프라인 서버 설정 스크립트
# 인터넷에 연결되지 않는 서버에서 Warp 기능을 사용하기 위한 최소한의 설정

echo "🚀 Warp 오프라인 서버 설정을 시작합니다..."

# 현재 사용 중인 셸 감지
CURRENT_SHELL=$(basename "$SHELL")
case "$CURRENT_SHELL" in
    "bash")
        SHELL_RC="$HOME/.bashrc"
        ;;
    "zsh")
        SHELL_RC="$HOME/.zshrc"
        ;;
    *)
        SHELL_RC="$HOME/.profile"
        ;;
esac

echo "감지된 셸: $CURRENT_SHELL"
echo "설정 파일: $SHELL_RC"

# Warp 디렉토리 생성
mkdir -p "$HOME/.warp"

# 기본 Warp 초기화 스크립트 생성
cat > "$HOME/.warp/warp-init.sh" << 'EOF'
#!/bin/bash
# Warp 원격 세션 초기화 스크립트

# Warp 환경 변수 설정
export WARP_IS_REMOTE_SESSION=1
export WARP_REMOTE_INIT=1

# 터미널 식별
if [[ -n "$TERM_PROGRAM" ]] && [[ "$TERM_PROGRAM" == "WarpTerminal" ]]; then
    export WARP_TERMINAL_DETECTED=1
fi

# LC_TERMINAL 변수가 있으면 Warp로 설정
if [[ -n "$LC_TERMINAL" ]] && [[ "$LC_TERMINAL" == "WarpTerminal" ]]; then
    export WARP_TERMINAL_DETECTED=1
fi

# Warp 기능 활성화를 위한 기본 설정
if [[ "$WARP_TERMINAL_DETECTED" == "1" ]]; then
    # 프롬프트 개선
    export PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
    
    # 히스토리 설정 (Warp와 호환)
    export HISTSIZE=10000
    export HISTFILESIZE=20000
    export HISTCONTROL=ignoredups:erasedups
    
    # 명령어 완성 개선
    shopt -s histappend 2>/dev/null || true
    shopt -s checkwinsize 2>/dev/null || true
    
    echo "✅ Warp 원격 세션이 초기화되었습니다!"
fi
EOF

# 실행 권한 부여
chmod +x "$HOME/.warp/warp-init.sh"

# 셸 설정 파일에 Warp 초기화 코드 추가
if ! grep -q "WARP-BOOTSTRAP" "$SHELL_RC" 2>/dev/null; then
    echo "" >> "$SHELL_RC"
    echo "### WARP-BOOTSTRAP-BEGIN ###" >> "$SHELL_RC"
    echo "if [ -r \"\$HOME/.warp/warp-init.sh\" ]; then . \"\$HOME/.warp/warp-init.sh\"; fi" >> "$SHELL_RC"
    echo "### WARP-BOOTSTRAP-END ###" >> "$SHELL_RC"
    echo "✅ $SHELL_RC에 Warp 설정이 추가되었습니다."
else
    echo "ℹ️  Warp 설정이 이미 존재합니다."
fi

echo ""
echo "🎉 설정 완료!"
echo ""
echo "다음 단계:"
echo "1. 현재 SSH 세션을 종료하세요: exit"
echo "2. 로컬에서 다시 jssh-gum으로 접속하세요"
echo "3. Warp에서 'warpify' 하겠냐고 물어보면 'y'를 선택하세요"
echo ""
echo "설정이 즉시 적용되려면 다음 명령어를 실행하세요:"
echo "source $SHELL_RC"
