#!/bin/bash
# 개선된 Warp 원격 세션 초기화 스크립트

# 디버그 모드 (필요시 활성화)
# set -x

echo "🔍 Warp 환경 변수 확인 중..."

# 환경 변수 출력 (디버깅용)
echo "TERM_PROGRAM: ${TERM_PROGRAM:-'(없음)'}"
echo "TERM_PROGRAM_VERSION: ${TERM_PROGRAM_VERSION:-'(없음)'}"
echo "LC_TERMINAL: ${LC_TERMINAL:-'(없음)'}"
echo "LC_TERMINAL_VERSION: ${LC_TERMINAL_VERSION:-'(없음)'}"

# Warp 관련 변수들 확인
env | grep -E '^WARP_' | while read line; do
    echo "$line"
done

# Warp 터미널 감지 개선
WARP_DETECTED=0

# 1. TERM_PROGRAM 확인
if [[ "$TERM_PROGRAM" == "WarpTerminal" ]]; then
    echo "✅ TERM_PROGRAM으로 Warp 감지됨"
    WARP_DETECTED=1
fi

# 2. LC_TERMINAL 확인
if [[ "$LC_TERMINAL" == "WarpTerminal" ]]; then
    echo "✅ LC_TERMINAL로 Warp 감지됨"
    WARP_DETECTED=1
fi

# 3. 환경 변수 패턴 확인
if env | grep -q "^WARP_"; then
    echo "✅ WARP_ 환경 변수 감지됨"
    WARP_DETECTED=1
fi

# 4. SSH 클라이언트 정보 확인
if [[ -n "$SSH_CLIENT" ]] || [[ -n "$SSH_CONNECTION" ]]; then
    echo "📡 SSH 연결 감지됨: $SSH_CLIENT"
fi

# Warp 기능 활성화
if [[ $WARP_DETECTED -eq 1 ]]; then
    echo "🚀 Warp 원격 세션 초기화 중..."
    
    # 환경 변수 설정
    export WARP_IS_REMOTE_SESSION=1
    export WARP_REMOTE_INIT=1
    export WARP_TERMINAL_DETECTED=1
    
    # 프롬프트 개선 (Warp 호환)
    if [[ -n "$BASH_VERSION" ]]; then
        export PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
        
        # Bash 옵션
        shopt -s histappend 2>/dev/null || true
        shopt -s checkwinsize 2>/dev/null || true
        shopt -s cmdhist 2>/dev/null || true
    elif [[ -n "$ZSH_VERSION" ]]; then
        export PROMPT='%F{green}%n@%m%f:%F{blue}%~%f%# '
    fi
    
    # 히스토리 설정
    export HISTSIZE=10000
    export HISTFILESIZE=20000
    export HISTCONTROL=ignoredups:erasedups
    
    # Warp와 호환되는 별칭들
    alias ll='ls -alF'
    alias la='ls -A'
    alias l='ls -CF'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
    
    echo "✅ Warp 원격 세션이 성공적으로 초기화되었습니다!"
    echo "🎯 이제 Warp의 기능들을 사용할 수 있습니다."
    
    # Warp 클라이언트에게 알림 (선택적)
    if command -v curl >/dev/null 2>&1; then
        # 인터넷 연결이 있는 경우에만 (타임아웃 짧게)
        timeout 2 curl -s "https://api.warp.dev/ping" >/dev/null 2>&1 && echo "🌐 Warp 서비스와 연결됨"
    fi
    
else
    echo "⚠️  Warp 터미널이 감지되지 않았습니다."
    echo "   SSH 클라이언트 설정에서 SendEnv가 올바르게 설정되었는지 확인하세요."
    echo "   ~/.ssh/config에 다음 설정이 있어야 합니다:"
    echo "   Host *"
    echo "       SendEnv TERM_PROGRAM TERM_PROGRAM_VERSION"
    echo "       SendEnv WARP_*"
    echo "       SendEnv LC_TERMINAL LC_TERMINAL_VERSION"
fi

echo ""
echo "🔧 현재 터미널 정보:"
echo "   SHELL: $SHELL"
echo "   TERM: $TERM"
echo "   COLUMNS: $COLUMNS"
echo "   LINES: $LINES"
echo ""
