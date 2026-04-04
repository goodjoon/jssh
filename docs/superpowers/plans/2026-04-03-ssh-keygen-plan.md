# SSH Key Generation (Ctrl-G) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `jssh-gum` 서버 추가/편집 폼에서 단축키 `Ctrl-G`를 눌러 새로운 SSH 키를 즉시 생성하고 폼에 적용하는 기능 구현

**Architecture:** 
1. `libs/form.py`의 UI에 힌트를 추가하고, `Ctrl-G` 이벤트를 감지하여 특별한 종료 코드(7)와 함께 현재 폼 데이터를 반환하도록 한다.
2. `jssh-gum` 메인 스크립트에서 폼 호출을 루프(while)로 감싸, 종료 코드가 7일 경우 `gum input` 기반의 키 생성 마법사를 실행하고, 완료 시 생성된 키 경로를 변수에 담아 폼을 다시 열도록 한다.
3. 키 생성 마법사는 경로, 파일명, 코멘트를 입력받고 디렉토리 생성 및 `ssh-keygen` 명령을 수행한다.

**Tech Stack:** Bash, Python 3 (curses), gum, ssh-keygen

---

### Task 1: `libs/form.py` 이벤트 및 종료 코드 수정

**Files:**
- Modify: `libs/form.py`

- [ ] **Step 1: UI 힌트 추가**

```python
# libs/form.py 의 footer 부분 (대략 180~185 라인 근처) 수정
        # ── 푸터 ──────────────────────────────────────────────
        footer_y = fields_start_y + len(fields) * (1 + GAP)
        try:
            stdscr.addstr(
                footer_y, PAD, sep, curses.color_pair(6) if curses.has_colors() else 0
            )
            hint = "Tab/↑↓: 필드 이동   Enter: 저장   ESC: 취소   Ctrl-G: SSH키 생성"
            stdscr.addstr(
                footer_y + 1,
                PAD,
                hint,
                curses.color_pair(5) if curses.has_colors() else 0,
            )
        except curses.error:
            pass
```

- [ ] **Step 2: Ctrl-G 이벤트 핸들링 추가**

```python
# libs/form.py 의 입력 처리 부분 (대략 210~220 라인 근처) 수정
        if code == 27:  # ESC
            return (None, 1)
        elif code in (10, 13):  # Enter → 저장
            return (["".join(v) for v in values], 0)
        elif code == 7: # Ctrl-G → SSH키 신규생성 요청
            return (["".join(v) for v in values], 7)
        elif code == 9:  # Tab → 다음
```

- [ ] **Step 3: 반환값 및 메인 종료 코드 처리 수정**

`run_form`에서 변경된 반환 형식을 메인에서 처리하도록 수정합니다. (run_form 의 리턴 타입이 원래 list of str 이었으므로, 튜플을 리턴하게 수정된 것을 반영)

```python
# libs/form.py 의 main 함수 하단부 (curses.wrapper 부분) 수정

    result = curses.wrapper(run_form, title, info, fields)

    os.dup2(old_out, 1)
    os.close(old_out)
    os.dup2(old_in, 0)
    os.close(old_in)

    if isinstance(result, tuple):
        result_data, exit_code = result
    else:
        result_data = result
        exit_code = 1 if result is None else 0

    if result_data is None:
        sys.exit(exit_code)

    for v in result_data:
        print(v)
        
    sys.exit(exit_code)
```

- [ ] **Step 4: Commit**
```bash
git add libs/form.py
git commit -m "feat: form.py에 Ctrl-G 단축키 및 종료 코드 7 반환 로직 추가"
```

---

### Task 2: `jssh-gum` 마법사 함수 구현

**Files:**
- Modify: `jssh-gum`

- [ ] **Step 1: 마법사 함수 추가**

파일 상단, 기존 함수들(예: `add_server` 앞)의 적절한 위치에 추가합니다.

```bash
# SSH 키 생성 마법사
generate_ssh_key_wizard() {
    clear
    show_info "🔑 SSH 키 신규 생성"
    echo ""
    
    # 1. 파일 이름 입력
    echo "새로운 SSH 키 파일 이름을 입력하세요 (예: id_ed25519_new)"
    local key_name
    key_name=$(gum input --placeholder "파일 이름")
    [[ -z "$key_name" ]] && return 1

    # 2. 접속 ID 입력
    echo ""
    echo "SSH 접속 ID (코멘트)를 입력하세요 (예: my-server-key)"
    local key_comment
    key_comment=$(gum input --placeholder "접속 ID")
    [[ -z "$key_comment" ]] && key_comment="jssh-key"

    # 3. 경로 입력
    echo ""
    echo "저장할 경로를 입력하세요 (기본값: ~/.ssh)"
    local key_dir
    key_dir=$(gum input --placeholder "~/.ssh" --value "~/.ssh")
    [[ -z "$key_dir" ]] && key_dir="~/.ssh"
    
    # 경로 변환 (~ 확장)
    local eval_dir="${key_dir/#\~/$HOME}"
    
    # 디렉토리 생성
    if [[ ! -d "$eval_dir" ]]; then
        echo ""
        show_info "디렉토리가 존재하지 않습니다. 생성합니다: $eval_dir"
        mkdir -p "$eval_dir"
    fi
    
    local full_path="$eval_dir/$key_name"
    
    # 파일 존재 여부 확인
    if [[ -f "$full_path" ]]; then
        echo ""
        show_error "경고: 파일이 이미 존재합니다 ($full_path)"
        sleep 2
        return 1
    fi
    
    echo ""
    show_info "키를 생성하는 중입니다..."
    # 키 생성 실행
    if ssh-keygen -t ed25519 -C "$key_comment" -f "$full_path" -N ""; then
        echo ""
        show_success "SSH 키가 성공적으로 생성되었습니다!"
        # 변환 전의 경로 문자열(~ 유지)로 리턴하여 폼에 예쁘게 보이도록 함
        echo "$key_dir/$key_name"
        sleep 2
        return 0
    else
        echo ""
        show_error "키 생성에 실패했습니다."
        sleep 2
        return 1
    fi
}
```

- [ ] **Step 2: Commit**
```bash
git add jssh-gum
git commit -m "feat: jssh-gum에 SSH 키 생성 마법사 추가"
```

---

### Task 3: `jssh-gum` add_server 폼 루프 적용

**Files:**
- Modify: `jssh-gum` (`add_server` 함수)

- [ ] **Step 1: add_server 로직을 while 루프로 감싸기**

```bash
# jssh-gum 파일 수정 (add_server() 함수 내)
    local INFO_MSG="호스트명이 ~/.ssh/config 에 등록된 경우 IP 주소, 포트, 사용자, 패스워드는 생략할 수 있습니다."

    local form_out form_exit
    local cur_alias="" cur_category="" cur_hostname="" cur_ip="" cur_port="$DEFAULT_PORT" cur_user="$DEFAULT_USER" cur_password="" cur_ssh_key=""

    while true; do
        form_out=$(python3 "$LIBS_DIR/form.py" \
            --title "서버 추가" \
            --info  "$INFO_MSG" \
            "별칭"    "$cur_alias"    "0" \
            "구분"    "$cur_category" "0" \
            "호스트명" "$cur_hostname" "0" \
            "IP 주소" "$cur_ip"      "0" \
            "포트"    "$cur_port"    "0" \
            "사용자"  "$cur_user"    "0" \
            "패스워드" "$cur_password" "1" \
            "SSH키"   "$cur_ssh_key" "0") && form_exit=0 || form_exit=$?

        if [[ "$form_exit" -eq 1 ]]; then
            return 0   # ESC → 목록으로 복귀
        fi

        # 값 갱신 (저장 전이나 마법사 이동 전 현재 값 유지)
        cur_alias=$(    printf '%s\n' "$form_out" | sed -n '1p')
        cur_category=$( printf '%s\n' "$form_out" | sed -n '2p')
        cur_hostname=$( printf '%s\n' "$form_out" | sed -n '3p')
        cur_ip=$(       printf '%s\n' "$form_out" | sed -n '4p')
        cur_port=$(     printf '%s\n' "$form_out" | sed -n '5p')
        cur_user=$(     printf '%s\n' "$form_out" | sed -n '6p')
        cur_password=$( printf '%s\n' "$form_out" | sed -n '7p')
        cur_ssh_key=$(  printf '%s\n' "$form_out" | sed -n '8p')

        if [[ "$form_exit" -eq 7 ]]; then
            # Ctrl-G: 키 생성 마법사 실행
            local generated_key wizard_exit
            generated_key=$(generate_ssh_key_wizard) && wizard_exit=0 || wizard_exit=$?
            
            if [[ $wizard_exit -eq 0 && -n "$generated_key" ]]; then
                cur_ssh_key=$(printf '%s\n' "$generated_key" | tail -n 1)
            fi
            continue # 폼 다시 열기
        fi

        if [[ "$form_exit" -eq 0 ]]; then
            break # Enter -> 저장
        fi
    done
```

- [ ] **Step 2: add_server 하단 저장 로직 변수 매핑 수정**
기존 `new_alias` 등의 변수를 `cur_alias` 등으로 모두 변경합니다.

```bash
    # 별칭 필수 확인
    if [[ -z "$cur_alias" ]]; then
        show_error "별칭은 필수입니다."
        sleep 1
        return
    fi

    # 중복 확인
    if awk -F'|' -v a="$cur_alias" '$1 == a { exit 0 } END { exit 1 }' "$SERVERS_FILE" 2>/dev/null; then
        show_error "이미 존재하는 별칭입니다: $cur_alias"
        sleep 1
        return
    fi

    # 기본값 적용
    [[ -z "$cur_port" ]]     && cur_port="$DEFAULT_PORT"
    [[ -z "$cur_user" ]]     && cur_user="$DEFAULT_USER"
    [[ -z "$cur_password" ]] && cur_password="$DEFAULT_PASSWORD"

    echo "$cur_alias|$cur_category|$cur_hostname|$cur_ip|$cur_port|$cur_user|$cur_password|$cur_ssh_key" >> "$SERVERS_FILE"
    show_success "'$cur_alias' 서버가 추가되었습니다."
    sleep 1
```

- [ ] **Step 3: Commit**
```bash
git add jssh-gum
git commit -m "feat: add_server 에 SSH 키 생성 폼 루프(Ctrl-G) 연동"
```

---

### Task 4: `jssh-gum` edit_server 폼 루프 적용

**Files:**
- Modify: `jssh-gum` (`edit_server` 함수)

- [ ] **Step 1: edit_server 폼 로직을 루프로 감싸기**

```bash
# edit_server() 함수 내 form 호출 부분 수정
    local cur_alias cur_category cur_hostname cur_ip cur_port cur_user cur_password cur_ssh_key
    IFS='|' read -r cur_alias cur_category cur_hostname cur_ip cur_port cur_user cur_password cur_ssh_key \
        <<< "$server_info"
    
    local original_alias="$cur_alias" # 변경 감지를 위해 원본 백업
    local form_out form_exit

    while true; do
        form_out=$(python3 "$LIBS_DIR/form.py" \
            --title "서버 편집" \
            --info  "$INFO_MSG" \
            "별칭"    "$cur_alias"    "0" \
            "구분"    "$cur_category" "0" \
            "호스트명" "$cur_hostname" "0" \
            "IP 주소" "$cur_ip"      "0" \
            "포트"    "$cur_port"    "0" \
            "사용자"  "$cur_user"    "0" \
            "패스워드" "$cur_password" "1" \
            "SSH키"   "$cur_ssh_key" "0") && form_exit=0 || form_exit=$?

        if [[ "$form_exit" -eq 1 ]]; then
            return 0   # ESC → 목록으로 복귀
        fi

        # 폼 데이터 갱신
        cur_alias=$(    printf '%s\n' "$form_out" | sed -n '1p')
        cur_category=$( printf '%s\n' "$form_out" | sed -n '2p')
        cur_hostname=$( printf '%s\n' "$form_out" | sed -n '3p')
        cur_ip=$(       printf '%s\n' "$form_out" | sed -n '4p')
        cur_port=$(     printf '%s\n' "$form_out" | sed -n '5p')
        cur_user=$(     printf '%s\n' "$form_out" | sed -n '6p')
        cur_password=$( printf '%s\n' "$form_out" | sed -n '7p')
        cur_ssh_key=$(  printf '%s\n' "$form_out" | sed -n '8p')

        if [[ "$form_exit" -eq 7 ]]; then
            # Ctrl-G: 키 생성 마법사 실행
            local generated_key wizard_exit
            generated_key=$(generate_ssh_key_wizard) && wizard_exit=0 || wizard_exit=$?
            
            if [[ $wizard_exit -eq 0 && -n "$generated_key" ]]; then
                cur_ssh_key=$(printf '%s\n' "$generated_key" | tail -n 1)
            fi
            continue # 폼 다시 열기
        fi

        if [[ "$form_exit" -eq 0 ]]; then
            break # Enter -> 저장
        fi
    done
```

- [ ] **Step 2: edit_server 하단 저장 로직 변수 매핑 수정**
```bash
    [[ -z "$cur_alias" ]]   && cur_alias="$original_alias"
    [[ -z "$cur_port" ]]    && cur_port="$DEFAULT_PORT"

    # 별칭 변경 시 중복 확인
    if [[ "$cur_alias" != "$original_alias" ]]; then
        if awk -F'|' -v a="$cur_alias" '$1 == a { exit 0 } END { exit 1 }' "$SERVERS_FILE" 2>/dev/null; then
            show_error "이미 존재하는 별칭입니다: $cur_alias"
            sleep 1
            return
        fi
    fi

    # 파일 업데이트 (awk: 첫 번째 필드가 일치하는 행만 교체)
    awk -F'|' -v old="$original_alias" \
        -v new="${cur_alias}|${cur_category}|${cur_hostname}|${cur_ip}|${cur_port}|${cur_user}|${cur_password}|${cur_ssh_key}" \
        '$1 == old { print new; next } { print }' \
        "$SERVERS_FILE" > "${SERVERS_FILE}.tmp" \
        && mv "${SERVERS_FILE}.tmp" "$SERVERS_FILE"

    show_success "'${cur_alias}' 저장되었습니다."
    sleep 1
```

- [ ] **Step 3: Commit**
```bash
git add jssh-gum
git commit -m "feat: edit_server 에 SSH 키 생성 폼 루프(Ctrl-G) 연동"
```