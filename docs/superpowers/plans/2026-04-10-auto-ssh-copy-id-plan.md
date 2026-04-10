# Auto ssh-copy-id Suggestion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** SSH 키 연결이 `Permission denied (publickey)`로 실패할 경우, 사용자의 공개키를 서버에 자동으로 등록(`ssh-copy-id`)하도록 제안하는 기능 구현.

**Architecture:**
1. `libs/ssh_utils.sh` 내의 키 기반 연결 로직(`else` 분기)에 Pre-flight 검사를 추가.
2. `BatchMode=yes`와 `true` 명령어를 조합하여 실제 터미널 접속 전에 키 인증 여부만 빠르게 확인(exit code 및 stderr 메시지 분석).
3. 실패 사유가 `publickey` 관련인 경우 사용자에게 `gum confirm`으로 동의를 구하고, 동의 시 `$ssh_key.pub` 파일을 이용하여 `ssh-copy-id`를 실행.

**Tech Stack:** Bash

---

### Task 1: `libs/ssh_utils.sh`에 Auto ssh-copy-id 로직 구현

**Files:**
- Modify: `libs/ssh_utils.sh:75-100` (키 기반 인증 분기)

- [ ] **Step 1: 키 기반 접속 로직을 Pre-flight 방식으로 수정**

```bash
# 파일: libs/ssh_utils.sh
# 기존 else 이후 (패스워드 없이 직접 연결 (키 기반 인증) 부분)를 다음과 같이 변경

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
```

- [ ] **Step 2: Commit `libs/ssh_utils.sh`**
```bash
git add libs/ssh_utils.sh
git commit -m "feat: prompt to auto-run ssh-copy-id on publickey permission denied"
```