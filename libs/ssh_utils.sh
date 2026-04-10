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
    local ssh_key="$7"  # 추가 파라미터: ssh key 경로
    
    # SSH 명령 구성 (자동 접속 시 호스트 키 검사 및 로그 레벨 최적화)
    local ssh_args=("-o" "StrictHostKeyChecking=no" "-o" "UserKnownHostsFile=/dev/null" "-o" "LogLevel=ERROR")
    
    # 포트 설정 (비어있거나 22이면 기본값 사용)
    if [[ -n "$port" && "$port" != "22" ]]; then
        ssh_args+=("-p" "$port")
    fi
    
    # SSH 키 설정
    if [[ -n "$ssh_key" ]]; then
        # ~를 홈 디렉토리로 확장
        ssh_key="${ssh_key/#\~/$HOME}"
        ssh_args+=("-i" "$ssh_key")
    fi
    
    # 사용자@호스트 추가 (user 비어있으면 SSH config에 위임)
    if [[ -n "$user" ]]; then
        ssh_args+=("$user@$ip")
    else
        ssh_args+=("$ip")
    fi
    
    # SSH 연결 실행
    if [[ -n "$password" ]] && [[ "$password" != "$default_password" ]]; then
        # sshpass 사용 (설치되어 있는 경우)
        if command -v sshpass &> /dev/null; then
            # 임시 파일로 stderr 캡처
            local err_file=$(mktemp)
            
            # 연결 시도 (비로그인 방식으로 먼저 테스트하거나 직접 실행 후 결과 확인)
            # 여기서는 사용자 경험을 위해 직접 실행하되 exec 대신 일반 실행으로 결과를 가로챕니다.
            sshpass -p "$password" command ssh "${ssh_args[@]}" 2> "$err_file"
            local exit_code=$?
            local err_msg=$(cat "$err_file")
            rm -f "$err_file"

            if [[ $exit_code -ne 0 ]]; then
                echo ""
                if command -v gum &> /dev/null; then
                    case $exit_code in
                        5) gum style --foreground 196 --bold --border double --margin "1 2" --padding "1 2" "❌ 연결 실패: 비밀번호가 틀렸습니다." "입력된 정보를 다시 확인해 주세요." ;;
                        6) gum style --foreground 196 --bold --border double --margin "1 2" --padding "1 2" "❌ 연결 실패: 호스트 키 확인 오류 (Host Key Verification Failed)" "기존 known_hosts 기록과 충돌이 발생했습니다." ;;
                        *) gum style --foreground 196 --bold --border double --margin "1 2" --padding "1 2" "❌ 연결 실패 (에러 코드: $exit_code)" "$err_msg" ;;
                    esac
                else
                    case $exit_code in
                        5) echo "❌ 연결 실패: 비밀번호가 틀렸습니다." ;;
                        *) echo "❌ 연결 실패: $err_msg (에러 코드: $exit_code)" ;;
                    esac
                fi
                return $exit_code
            fi
        else
            # sshpass 자동 설치 시도
            if ensure_sshpass; then
                # 설치 성공시 재귀 호출 (일반 실행)
                connect_ssh "$user" "$ip" "$port" "$password" "$default_password" "false" "$ssh_key"
                return $?
            else
                # ... (생략된 기존 코드)
                echo "현재는 패스워드를 수동으로 입력해야 합니다."
                if [[ "$use_exec" == "true" ]]; then
                    exec ssh "${ssh_args[@]}"
                else
                    command ssh "${ssh_args[@]}"
                fi
            fi
        fi
    else
        # 패스워드 없이 직접 연결 (키 기반 인증)
        ssh_args+=("-o" "PasswordAuthentication=no")

        # Pre-flight 검사 (BatchMode로 패스워드 프롬프트 없이 실패시키기)
        local err_file=$(mktemp)
        command ssh -o BatchMode=yes "${ssh_args[@]}" true 2> "$err_file"
        local exit_code=$?
        local err_msg=$(cat "$err_file")
        rm -f "$err_file"

        if [[ $exit_code -ne 0 ]]; then
            # Permission denied (publickey) 에러인지 확인
            if [[ "$err_msg" == *"Permission denied"* && "$err_msg" == *"publickey"* ]]; then
                echo ""
                # gum 이 있는지 확인
                if command -v gum &> /dev/null; then
                    gum style --foreground 196 --bold "❌ 키 인증 실패: 서버에 공개키가 등록되지 않았습니다."
                    echo ""
                    
                    # 공개키 경로 유추 (.pub)
                    local pub_key="${ssh_key}.pub"
                    
                    if [[ -f "$pub_key" ]]; then
                        if gum confirm "지금 서버에 내 공개키($pub_key)를 등록(ssh-copy-id) 하시겠습니까?"; then
                            echo ""
                            gum style --foreground 39 "ℹ️ 원격 서버의 패스워드를 한 번 입력해 주셔야 합니다."
                            
                            # 대상 재구성
                            local ssh_target="$ip"
                            if [[ -n "$user" ]]; then
                                ssh_target="$user@$ip"
                            fi
                            
                            # 포트 옵션 처리
                            local port_opt=""
                            if [[ -n "$port" && "$port" != "22" ]]; then
                                port_opt="-p $port"
                            fi

                            # ssh-copy-id 실행
                            if command ssh-copy-id -i "$pub_key" $port_opt "$ssh_target"; then
                                echo ""
                                gum style --foreground 46 --bold "✅ 공개키 등록 성공! 접속을 시도합니다..."
                                sleep 1
                            else
                                echo ""
                                gum style --foreground 196 --bold "❌ 공개키 등록에 실패했습니다."
                                return 1
                            fi
                        else
                            echo ""
                            gum style --foreground 240 "접속을 취소했습니다."
                            return 1
                        fi
                    else
                        gum style --foreground 214 "공개키($pub_key) 파일을 찾을 수 없어 자동 등록을 진행할 수 없습니다."
                        return 1
                    fi
                else
                    echo "❌ 연결 실패: 서버에 공개키가 없습니다. (ssh-copy-id 필요)"
                    return 1
                fi
            else
                # 다른 에러인 경우 에러 메시지 출력
                echo ""
                if command -v gum &> /dev/null; then
                    gum style --foreground 196 --bold --border double --margin "1 2" --padding "1 2" "❌ 연결 실패 (에러 코드: $exit_code)" "$err_msg"
                else
                    echo "❌ 연결 실패: $err_msg (에러 코드: $exit_code)"
                fi
                return $exit_code
            fi
        fi

        # Pre-flight 성공 또는 ssh-copy-id 성공 후 실제 세션 연결
        if [[ "$use_exec" == "true" ]]; then
            exec ssh "${ssh_args[@]}"
        else
            command ssh "${ssh_args[@]}"
        fi
    fi
}

# SSH 연결 함수 (exec 버전 - Warp 완전 호환)
connect_ssh_exec() {
    # 1: user, 2: ip, 3: port, 4: pwd, 5: default_pwd, 6: ssh_key
    connect_ssh "$1" "$2" "$3" "$4" "$5" "true" "$6"
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
