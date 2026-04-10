# Auth Method Toggle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** jssh-gum 편집 폼에 "인증방식" 토글 필드를 추가하여 패스워드와 SSH 키 중 명시적으로 하나를 선택하게 하고, 그에 맞는 값만 저장합니다.

**Architecture:**
1. `libs/form.py` 파라미터를 확장하여 `type` 인자가 `choice:A,B` 패턴을 가질 수 있게 지원하고, 폼 내에서 좌우 방향키 및 스페이스바로 옵션을 순환 변경할 수 있게 합니다.
2. `jssh-gum` 스크립트에서 `add_server` 및 `edit_server` 로직 내에 '인증방식' 폼 파라미터를 추가하고 반환된 인증방식 값에 따라 불필요한 값을 초기화하여 `servers.list`를 안전하게 갱신합니다.

**Tech Stack:** Python 3 (curses), Bash

---

### Task 1: `libs/form.py`에 선택형(Toggle) 필드 추가

**Files:**
- Modify: `libs/form.py:126-170` (run_form 내 입력 처리부)
- Modify: `libs/form.py:190-210` (main 인자 파싱부)

- [ ] **Step 1: main 함수 인자 파싱부 수정 (`choice` 타입 지원)**
  - `fields.append((label, value, is_pwd))` 부분을 `fields.append((label, value, is_pwd, choices))` 구조로 확장합니다.

```python
    fields = []
    for i in range(0, len(args), 3):
        label = args[i]
        value = args[i + 1]
        type_arg = args[i + 2]
        
        is_pwd = False
        choices = None
        
        if type_arg == "1":
            is_pwd = True
        elif type_arg.startswith("choice:"):
            choices = type_arg.split(":", 1)[1].split(",")
            # 값이 choices에 없으면 첫번째 항목 강제 할당
            if value not in choices:
                value = choices[0]
                
        fields.append((label, value, is_pwd, choices))
```

- [ ] **Step 2: run_form 함수 시그니처 및 초기화 로직 수정**
  - `fields` 튜플 언패킹을 4개 변수로 늘립니다.

```python
def run_form(stdscr, title, info, fields):
# ...
    values = [list(f[1]) for f in fields]
    cursors = [len(f[1]) for f in fields]
```

- [ ] **Step 3: 필드 렌더링 로직 수정 (화살표 추가 및 선택형 지원)**
  - `run_form` 내 필드 그리는 반복문에 렌더링 조건을 추가합니다.

```python
        # ── 필드들 ────────────────────────────────────────────
        cursor_pos = None
        for i, (label, _, is_pwd, choices) in enumerate(fields):
            y = fields_start_y + i * (1 + GAP)
            if y >= h - 3:
                break

            # 레이블 (우측 정렬)
            label_pad = label_w - dw(label)
            lbl_str = " " * label_pad + label + " : "
            attr_lbl = curses.color_pair(2) if curses.has_colors() else 0
            try:
                stdscr.addstr(y, PAD, lbl_str, attr_lbl)
            except curses.error:
                pass

            # 값 문자열
            val_chars = values[i]
            val_str = "".join(val_chars)
            
            if choices is not None:
                disp = f"◀ {val_str} ▶"
            else:
                disp = "●" * len(val_str) if is_pwd else val_str
```

- [ ] **Step 4: 입력 처리(키보드 이벤트) 로직 수정 (선택형 필드 제어)**
  - 현재 필드가 `choices`를 가질 경우 좌우 방향키 및 스페이스바 조작으로 값을 순환시키도록 수정합니다.

```python
        # ── 입력 처리 ─────────────────────────────────────────
        try:
            ch = stdscr.get_wch()
        except Exception:
            continue

        code = ord(ch) if isinstance(ch, str) else ch
        
        cur_choices = fields[current][3]

        if code == 27:  # ESC
            return (None, 1)
        elif code in (10, 13):  # Enter → 저장
            return (["".join(v) for v in values], 0)
        elif code == 7: # Ctrl-G → SSH키 생성 (특별 종료 코드 7)
            return (["".join(v) for v in values], 7)
        elif code == 9:  # Tab → 다음
            current = (current + 1) % len(fields)
        elif code == curses.KEY_BTAB:  # Shift-Tab → 이전
            current = (current - 1) % len(fields)
        elif code == curses.KEY_DOWN:
            current = (current + 1) % len(fields)
        elif code == curses.KEY_UP:
            current = (current - 1) % len(fields)
        
        # 선택형 필드 조작
        elif cur_choices is not None:
            if code in (curses.KEY_LEFT, curses.KEY_RIGHT, 32):  # 방향키 또는 Space
                val_str = "".join(values[current])
                idx = cur_choices.index(val_str) if val_str in cur_choices else 0
                if code == curses.KEY_LEFT:
                    next_idx = (idx - 1) % len(cur_choices)
                else:
                    next_idx = (idx + 1) % len(cur_choices)
                values[current] = list(cur_choices[next_idx])
                cursors[current] = len(values[current])
        
        # 일반 필드 조작
        else:
            if code == curses.KEY_LEFT:
                if cursors[current] > 0:
                    cursors[current] -= 1
            elif code == curses.KEY_RIGHT:
                if cursors[current] < len(values[current]):
                    cursors[current] += 1
            elif code in (1,):  # Ctrl-A → 줄 처음
                cursors[current] = 0
            elif code in (5,):  # Ctrl-E → 줄 끝
                cursors[current] = len(values[current])
            elif code in (11,):  # Ctrl-K → 커서 이후 삭제
                values[current] = values[current][: cursors[current]]
            elif code in (21,):  # Ctrl-U → 전체 삭제
                values[current] = []
                cursors[current] = 0
            elif code in (127, curses.KEY_BACKSPACE, 8):  # Backspace
                if cursors[current] > 0:
                    del values[current][cursors[current] - 1]
                    cursors[current] -= 1
            elif code == curses.KEY_DC:  # Delete
                if cursors[current] < len(values[current]):
                    del values[current][cursors[current]]
            elif isinstance(ch, str) and (ch.isprintable() or ord(ch) > 127):
                values[current].insert(cursors[current], ch)
                cursors[current] += 1
```

- [ ] **Step 5: Commit `libs/form.py`**
```bash
git add libs/form.py
git commit -m "feat: form.py add choice type support for toggle fields"
```

---

### Task 2: `jssh-gum`에 인증방식 토글 적용 및 데이터 정리(Sanitize) 로직 추가

**Files:**
- Modify: `jssh-gum` (add_server, edit_server)

- [ ] **Step 1: add_server() 수정**
  - `인증방식` 파라미터 추가
  - 반환값 매핑 인덱스 업데이트 및 데이터 Sanitize 분기 처리

```bash
# jssh-gum 내 add_server 함수에서 form.py 호출부 수정:
        form_out=$(python3 "$LIBS_DIR/form.py" \
            --title "서버 추가" \
            --info  "$INFO_MSG" \
            "별칭"    "$cur_alias"    "0" \
            "구분"    "$cur_category" "0" \
            "호스트명" "$cur_hostname" "0" \
            "IP 주소" "$cur_ip"      "0" \
            "포트"    "$cur_port"    "0" \
            "사용자"  "$cur_user"    "0" \
            "인증방식" "패스워드"      "choice:패스워드,SSH 키" \
            "패스워드" "$cur_password" "1" \
            "SSH키"   "$cur_ssh_key" "0") && form_exit=0 || form_exit=$?

# 매핑 및 Sanitize:
    local new_alias new_category new_hostname new_ip new_port new_user new_auth new_password new_ssh_key
    new_alias=$(     printf '%s\n' "$form_out" | sed -n '1p')
    new_category=$(  printf '%s\n' "$form_out" | sed -n '2p')
    new_hostname=$(  printf '%s\n' "$form_out" | sed -n '3p')
    new_ip=$(        printf '%s\n' "$form_out" | sed -n '4p')
    new_port=$(      printf '%s\n' "$form_out" | sed -n '5p')
    new_user=$(      printf '%s\n' "$form_out" | sed -n '6p')
    new_auth=$(      printf '%s\n' "$form_out" | sed -n '7p')
    new_password=$(  printf '%s\n' "$form_out" | sed -n '8p')
    new_ssh_key=$(   printf '%s\n' "$form_out" | sed -n '9p')
    
    if [[ "$new_auth" == "패스워드" ]]; then
        new_ssh_key=""
    elif [[ "$new_auth" == "SSH 키" ]]; then
        new_password=""
    fi
```

- [ ] **Step 2: edit_server() 수정**
  - 초기값 `cur_auth` 계산: `cur_ssh_key`가 존재하면 `SSH 키`, 아니면 `패스워드`
  - `인증방식` 파라미터 폼 호출부에 추가
  - 반환값 매핑 인덱스 업데이트 및 데이터 Sanitize 로직

```bash
# edit_server 내 cur_auth 초기값 설정 (IFS read 직후):
    local cur_auth="패스워드"
    if [[ -n "$cur_ssh_key" ]]; then
        cur_auth="SSH 키"
    fi

# form 호출부 수정:
        form_out=$(python3 "$LIBS_DIR/form.py" \
            --title "서버 편집" \
            --info  "$INFO_MSG" \
            "별칭"    "$cur_alias"    "0" \
            "구분"    "$cur_category" "0" \
            "호스트명" "$cur_hostname" "0" \
            "IP 주소" "$cur_ip"      "0" \
            "포트"    "$cur_port"    "0" \
            "사용자"  "$cur_user"    "0" \
            "인증방식" "$cur_auth"    "choice:패스워드,SSH 키" \
            "패스워드" "$cur_password" "1" \
            "SSH키"   "$cur_ssh_key" "0") && form_exit=0 || form_exit=$?

# 매핑 및 Sanitize: (위 add_server와 동일하게 인덱스 +1 증가됨, 7p~9p)
        cur_alias=$(     printf '%s\n' "$form_out" | sed -n '1p')
        cur_category=$(  printf '%s\n' "$form_out" | sed -n '2p')
        cur_hostname=$(  printf '%s\n' "$form_out" | sed -n '3p')
        cur_ip=$(        printf '%s\n' "$form_out" | sed -n '4p')
        cur_port=$(      printf '%s\n' "$form_out" | sed -n '5p')
        cur_user=$(      printf '%s\n' "$form_out" | sed -n '6p')
        cur_auth=$(      printf '%s\n' "$form_out" | sed -n '7p')
        cur_password=$(  printf '%s\n' "$form_out" | sed -n '8p')
        cur_ssh_key=$(   printf '%s\n' "$form_out" | sed -n '9p')

        # Generate wizard에서 돌아온 경우 cur_auth 강제로 "SSH 키" 변경 (옵션 사항)
        if [[ "$wizard_exit" -eq 0 ]]; then
            cur_auth="SSH 키"
        fi

# 교체(sed/awk) 직전에 덮어쓰기 로직 반영:
    local final_password="$cur_password"
    local final_ssh_key="$cur_ssh_key"
    if [[ "$cur_auth" == "패스워드" ]]; then
        final_ssh_key=""
    elif [[ "$cur_auth" == "SSH 키" ]]; then
        final_password=""
    fi

    # sed/awk 에 들어가는 new 변수 업데이트
    -v new="${cur_alias}|${cur_category}|${cur_hostname}|${cur_ip}|${cur_port}|${cur_user}|${final_password}|${final_ssh_key}" \
```

- [ ] **Step 3: jssh-gum 내 INFO_MSG 도움말 보강**
  - "인증방식 항목은 스페이스바 또는 좌우 방향키로 변경할 수 있습니다." 문구를 기존 안내에 추가.

```bash
    local INFO_MSG="호스트명이 ~/.ssh/config 에 등록된 경우 IP 주소, 포트, 사용자, 패스워드는 생략할 수 있습니다.\n인증방식 필드에서는 좌우 방향키나 Space를 눌러 값을 변경하세요."
```

- [ ] **Step 4: Commit `jssh-gum`**
```bash
git add jssh-gum
git commit -m "feat: jssh-gum use auth toggle field in add/edit server forms"
```
