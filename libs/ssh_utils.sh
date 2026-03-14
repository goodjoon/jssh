#!/bin/bash
# ssh_utils.sh - SSH 연결 관련 유틸리티 모듈
# jssh-gum에서 사용하는 SSH 관련 함수들

# SSH 연결 함수
connect_ssh() {
    local user="$1"
    local ip="$2"
    local port="$3"
    local password="$4"
    local default_password="$5"
    local use_exec="${6:-false}"  # 추가 파라미터: exec 사용 여부
    
    # SSH 명령 구성
    local ssh_args=()
    
    # 포트 설정
    if [[ "$port" != "22" ]]; then
        ssh_args+=("-p" "$port")
    fi
    
    # 사용자@호스트 추가
    ssh_args+=("$user@$ip")
    
    # SSH 연결 실행 (Warp의 기본 SSH wrapper 사용)
    if [[ -n "$password" ]] && [[ "$password" != "$default_password" ]]; then
        # sshpass 사용 (설치되어 있는 경우)
        if command -v sshpass &> /dev/null; then
            if [[ "$use_exec" == "true" ]]; then
                # exec로 Warp SSH wrapper 사용
                exec sshpass -p "$password" command ssh "${ssh_args[@]}"
            else
                # 일반 실행
                sshpass -p "$password" command ssh "${ssh_args[@]}"
            fi
        else
            # sshpass 자동 설치 시도
            if ensure_sshpass; then
                # 설치 성공시 다시 시도
                if [[ "$use_exec" == "true" ]]; then
                    exec sshpass -p "$password" command ssh "${ssh_args[@]}"
                else
                    sshpass -p "$password" command ssh "${ssh_args[@]}"
                fi
            else
                # 설치 실패시 수동 입력 안내 및 직접 연결
                if command -v gum &> /dev/null; then
                    echo "현재는 패스워드를 수동으로 입력해야 합니다: $password" | gum style --foreground 46 --bold --align center
                else
                    echo "현재는 패스워드를 수동으로 입력해야 합니다: $password"
                fi
                echo ""
                
                if [[ "$use_exec" == "true" ]]; then
                    # exec로 Warp SSH wrapper 사용
                    exec command ssh "${ssh_args[@]}"
                else
                    # 일반 실행
                    command ssh "${ssh_args[@]}"
                fi
            fi
        fi
    else
        # 패스워드 없이 직접 연결 (키 기반 인증)
        if [[ "$use_exec" == "true" ]]; then
            # exec로 Warp SSH wrapper 사용 (Warp 기능 완전 보존)
            exec command ssh "${ssh_args[@]}"
        else
            # 일반 실행
            command ssh "${ssh_args[@]}"
        fi
    fi
}

# SSH 연결 함수 (exec 버전 - Warp 완전 호환)
connect_ssh_exec() {
    connect_ssh "$1" "$2" "$3" "$4" "$5" "true"
}

# SSH 연결 정보 검증
validate_ssh_info() {
    local ip="$1"
    local port="$2"
    local user="$3"
    
    # IP 주소 검증 (기본적인 형식 체크)
    if [[ ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && [[ ! "$ip" =~ ^[a-zA-Z0-9.-]+$ ]]; then
        return 1
    fi
    
    # 포트 검증
    if [[ ! "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 ]] || [[ "$port" -gt 65535 ]]; then
        return 1
    fi
    
    # 사용자명 검증
    if [[ -z "$user" ]]; then
        return 1
    fi
    
    return 0
}

# SSH 키 존재 확인
check_ssh_key() {
    local user="$1"
    local ip="$2"
    
    # SSH 키 파일들 확인
    local key_files=(
        "$HOME/.ssh/id_rsa"
        "$HOME/.ssh/id_ed25519"
        "$HOME/.ssh/id_ecdsa"
        "$HOME/.ssh/id_dsa"
    )
    
    for key_file in "${key_files[@]}"; do
        if [[ -f "$key_file" ]]; then
            return 0
        fi
    done
    
    return 1
}

# SSH 연결 테스트
test_ssh_connection() {
    local user="$1"
    local ip="$2"
    local port="$3"
    local timeout="${4:-5}"
    
    # 연결 테스트 (타임아웃 적용)
    timeout "$timeout" ssh -p "$port" -o ConnectTimeout="$timeout" -o BatchMode=yes -o StrictHostKeyChecking=no "$user@$ip" exit 2>/dev/null
    return $?
}
