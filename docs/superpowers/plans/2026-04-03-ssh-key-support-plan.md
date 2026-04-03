# SSH Key Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** jssh-gum에 SSH 키(-i) 옵션을 지정하여 접속하는 기능 추가

**Architecture:** 
1. `servers.list` 의 8번째 필드로 `ssh_key`를 추가.
2. `libs/form.py` 폼 필드 추가로 등록/수정 시 8번째 값 입력 가능하도록 함.
3. `jssh-gum` 메인 스크립트에서 fzf 목록, 폼 파싱, ssh_args 옵션 생성 로직에 8번째 필드(`ssh_key`) 반영.
4. `libs/ssh_utils.sh` 파라미터 시그니처와 명령어 조립부를 업데이트하여, ssh_key가 있을 경우 `-i` 옵션을 추가.

**Tech Stack:** Bash, Python 3 (curses), fzf, gum

---

### Task 1: `libs/form.py` 폼 인자 및 너비 조정

**Files:**
- Modify: `libs/form.py:165-200` (대략 메인 함수 인자 처리부)

- [ ] **Step 1: Usage 문구 업데이트**
  - "Usage: form.py [--title TEXT] [--info TEXT] <label1> <value1> <is_password1> [...]" 부분 확인 후, 8개의 필드가 들어가므로 딱히 로직을 수정할 필요는 없고 그대로 두거나, 필요한 경우 최대 너비(box_w) 관련 계산만 여유 있게 두기 위해 유지.
  *form.py는 가변 인자(label, value, is_pwd 3개씩)를 동적으로 파싱하므로 코드 수정이 사실상 불필요할 수 있다.*
  (확인 결과 `form.py`는 그대로 사용해도 무방하므로 이 테스크는 폼이 가변길이를 지원한다는 확인만 하고, 실제 스크립트 변경은 `jssh-gum`에서 수행한다.)

- [ ] **Step 2: Commit (Skip - no changes needed for form.py)**

---

### Task 2: `libs/ssh_utils.sh` 에 ssh_key 파라미터 및 `-i` 옵션 적용

**Files:**
- Modify: `libs/ssh_utils.sh:5-25`
- Modify: `libs/ssh_utils.sh:75-80`

- [ ] **Step 1: connect_ssh 함수 시그니처 수정**

```bash
# 파일: libs/ssh_utils.sh (connect_ssh 내)
connect_ssh() {
    local user="$1"
    local ip="$2"
    local port="$3"
    local password="$4"
    local default_password="$5"
    local use_exec="${6:-false}"
    local ssh_key="$7"  # 추가 파라미터: ssh key 경로
```

- [ ] **Step 2: ssh_args 에 -i 옵션 추가 로직 구현**

```bash
    # 포트 설정 아래, 또는 위 적절한 위치에 추가
    # SSH 키 설정
    if [[ -n "$ssh_key" ]]; then
        # ~를 홈 디렉토리로 확장 (필요 시)
        ssh_key="${ssh_key/#\~/$HOME}"
        ssh_args+=("-i" "$ssh_key")
    fi
```

- [ ] **Step 3: connect_ssh_exec 시그니처 수정**

```bash
# 파일: libs/ssh_utils.sh
connect_ssh_exec() {
    connect_ssh "$1" "$2" "$3" "$4" "$5" "true" "$6"
}
```

- [ ] **Step 4: Commit**
```bash
git add libs/ssh_utils.sh
git commit -m "feat: ssh_utils에 ssh_key(-i) 파라미터 지원 추가"
```

---

### Task 3: `jssh-gum` 서버 목록 표시(fzf)에 SSH 키 컬럼 추가

**Files:**
- Modify: `jssh-gum` (list_servers 함수 내부 파이썬 fzf 테이블 생성 로직)

- [ ] **Step 1: list_servers() 내 변수 파싱 수정**
`servers.list` 읽는 부분 수정
```bash
        # 기존:
        while IFS='|' read -r alias category hostname ip port user password; do
        # 변경:
        while IFS='|' read -r alias category hostname ip port user password ssh_key; do
```

- [ ] **Step 2: fzf용 python 테이블 데이터에 ssh_key 포함**
```bash
            # 기존:
            raw_lines+=("${alias}	${category}	${display_hostname}	${ip}	${port}	${display_user}")
            # 변경:
            local display_key="${ssh_key:-"-"}"
            raw_lines+=("${alias}	${category}	${display_hostname}	${ip}	${port}	${display_user}	${display_key}")
```

- [ ] **Step 3: python3 테이블 렌더러 수정**
`jssh-gum` 파일 내 `list_servers()` 파이썬 스크립트 수정.

```python
# 파이썬 스크립트 내부 MAX, 패딩, 헤더 부분에 key 컬럼 추가
MAX = {"alias": 26, "cat": 6, "host": 22, "ip": 18, "port": 4, "user": 10, "key": 16}
# ...
W_user = max(6,  min(MAX["user"],  max((dw(r[5]) for r in rows), default=6)))
W_key  = max(6,  min(MAX["key"],   max((dw(r[6]) if len(r)>6 else 1 for r in rows), default=6)))

hdr = (" " + pad("No.", W_no) + " │ " + pad("별칭", W_al) + " │ " +
       pad("구분", W_cat) + " │ " + pad("호스트명", W_host) + " │ " +
       pad("IP주소", W_ip) + " │ " + pad("포트", W_port) + " │ " +
       pad("사용자", W_user) + " │ " + pad("SSH키", W_key))
sep_row = (sep(W_no+2) + "┼" + sep(W_al+2) + "┼" + sep(W_cat+2) + "┼" +
           sep(W_host+2) + "┼" + sep(W_ip+2) + "┼" + sep(W_port+2) + "┼" +
           sep(W_user+2) + "┼" + sep(W_key+2))
```
row 생성부 수정
```python
# 기존 row 생성부
    disp_ip = r[3] if r[3] and r[3] != "-" else "(ssh cfg)"
    disp_key = r[6] if len(r)>6 and r[6] else "-"
    row = (" " + pad(str(i), W_no) + " │ " + pad(r[0], W_al) + " │ " +
           pad(r[1], W_cat) + " │ " + pad(r[2], W_host) + " │ " +
           pad(disp_ip, W_ip) + " │ " + pad(r[4], W_port) + " │ " +
           pad(r[5], W_user) + " │ " + pad(disp_key, W_key))
```

- [ ] **Step 4: Commit**
```bash
git add jssh-gum
git commit -m "feat: 서버 목록 fzf UI에 SSH 키 컬럼 추가"
```

---

### Task 4: `jssh-gum` 폼 입력(추가/편집) 시 SSH 키 처리

**Files:**
- Modify: `jssh-gum` (`add_server`, `edit_server`, `connect_to_server` 함수)

- [ ] **Step 1: add_server() 수정**
```bash
    # form.py 호출 시 8번째 필드 추가
        "사용자"  "$DEFAULT_USER" "0" \
        "패스워드" ""             "1" \
        "SSH키"   ""             "0") && form_exit=0 || form_exit=$?
    
    # 변수 매핑 추가
    local new_alias new_category new_hostname new_ip new_port new_user new_password new_ssh_key
    # ...
    new_password=$( printf '%s\n' "$form_out" | sed -n '7p')
    new_ssh_key=$(  printf '%s\n' "$form_out" | sed -n '8p')
    
    # 저장 형식 변경
    echo "$new_alias|$new_category|$new_hostname|$new_ip|$new_port|$new_user|$new_password|$new_ssh_key" >> "$SERVERS_FILE"
```

- [ ] **Step 2: edit_server() 수정**
```bash
    # 읽기 로직
    local cur_alias cur_category cur_hostname cur_ip cur_port cur_user cur_password cur_ssh_key
    IFS='|' read -r cur_alias cur_category cur_hostname cur_ip cur_port cur_user cur_password cur_ssh_key \
        <<< "$server_info"
        
    # form 호출 시 추가
        "사용자"  "$cur_user"    "0" \
        "패스워드" "$cur_password" "1" \
        "SSH키"   "$cur_ssh_key" "0") && form_exit=0 || form_exit=$?

    # 결과 매핑
    new_password=$( printf '%s\n' "$form_out" | sed -n '7p')
    new_ssh_key=$(  printf '%s\n' "$form_out" | sed -n '8p')
    
    # 교체 로직 
    awk -F'|' -v old="$cur_alias" \
        -v new="${new_alias}|${new_category}|${new_hostname}|${new_ip}|${new_port}|${new_user}|${new_password}|${new_ssh_key}" \
```

- [ ] **Step 3: connect_to_server() 수정**
```bash
    # 읽기
    IFS='|' read -r found_alias category hostname ip port user password ssh_key <<< "$server_info"
    
    # ssh_cmd 문자열에 키 추가 표시
    if [[ -n "$ssh_key" ]]; then
        ssh_cmd="$ssh_cmd -i $ssh_key"
    fi
    
    # 표시
    echo "서버: $found_alias ($category)"
    if [[ -n "$ssh_key" ]]; then
        echo "SSH 키: $ssh_key"
    fi
    
    # 함수 호출 (마지막 인자 추가)
        if [[ "${WARP_COMPATIBLE_MODE:-true}" == "true" ]]; then
            connect_ssh_exec "$user" "$ssh_target" "$port" "$password" "$DEFAULT_PASSWORD" "$ssh_key"
        else
            connect_ssh "$user" "$ssh_target" "$port" "$password" "$DEFAULT_PASSWORD" "false" "$ssh_key"
        fi
```

- [ ] **Step 4: Commit**
```bash
git add jssh-gum
git commit -m "feat: 서버 폼 입력 및 연결 로직에 SSH 키 반영"
```