# FZF Navigation Enhancement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `jssh-gum`의 메인 화면 `fzf` 서버 목록에 무한 스크롤(`--cycle`)과 페이지 이동(`--bind 'left:page-up,right:page-down'`) 기능을 추가합니다.

**Architecture:**
1. `jssh-gum` 파일의 `list_servers()` 함수 안에서 `fzf` 명령어를 구성하는 부분에 인자를 추가.
2. 추가할 인자: `--cycle` 및 `--bind='left:page-up,right:page-down'`

**Tech Stack:** Bash, fzf

---

### Task 1: `jssh-gum` 메인 메뉴 `fzf` 네비게이션 옵션 추가

**Files:**
- Modify: `jssh-gum:330-345` (대략적인 fzf 호출 부분)

- [ ] **Step 1: list_servers() 내 fzf 옵션 수정**
  `jssh-gum` 파일 내 `list_servers` 함수 내부의 `fzf` 호출 파이프라인에 옵션을 추가합니다.

```bash
# 파일: jssh-gum
# 기존 (대략 330줄 부근):
        local selected
        selected=$(
            printf '%s\n' "$fzf_input" \
            | fzf \
                --delimiter='§' \
                --with-nth='2..' \
                --header="${HDR_ROW}"$'\n'"${SEP_ROW}" \
                --header-lines=0 \
                --footer="$FOOTER" \
                --expect='ctrl-a,ctrl-d,ctrl-e,ctrl-o,ctrl-s' \
                --prompt='  검색: ' \
                --pointer='▶' \
                --layout=reverse \
                --border=rounded \
                --no-sort \
                --no-info \
                --exact \
                --query="$search_query")
# 변경: --cycle 와 --bind 추가
        local selected
        selected=$(
            printf '%s\n' "$fzf_input" \
            | fzf \
                --delimiter='§' \
                --with-nth='2..' \
                --header="${HDR_ROW}"$'\n'"${SEP_ROW}" \
                --header-lines=0 \
                --footer="$FOOTER" \
                --expect='ctrl-a,ctrl-d,ctrl-e,ctrl-o,ctrl-s' \
                --prompt='  검색: ' \
                --pointer='▶' \
                --layout=reverse \
                --border=rounded \
                --no-sort \
                --no-info \
                --exact \
                --cycle \
                --bind='left:page-up,right:page-down' \
                --query="$search_query")
```

- [ ] **Step 2: Commit `jssh-gum`**
```bash
git add jssh-gum
git commit -m "feat: enhance fzf navigation with cycle and page up/down bindings"
```