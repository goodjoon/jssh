#!/bin/bash
# ui_utils.sh - UI 관련 유틸리티 모듈
# jssh-gum에서 사용하는 UI 관련 함수들

# 메인 헤더 출력
show_header() {
    if command -v gum &> /dev/null; then
        echo "◆ jssh-gum SSH 서버 관리자 ◆" | gum style --foreground 212 --border double --align center --width 60 --padding 1
    else
        echo "◆ jssh-gum SSH 서버 관리자 ◆"
    fi
}

# 성공 메시지 출력
show_success() {
    local message="$1"
    if command -v gum &> /dev/null; then
        echo "$message" | gum style --foreground 46 --bold --align center
    else
        echo "✓ $message"
    fi
}

# 에러 메시지 출력
show_error() {
    local message="$1"
    if command -v gum &> /dev/null; then
        echo "$message" | gum style --foreground 196 --align center
    else
        echo "✗ $message"
    fi
}

# 정보 메시지 출력
show_info() {
    local message="$1"
    if command -v gum &> /dev/null; then
        echo "$message" | gum style --foreground 39 --bold
    else
        echo "→ $message"
    fi
}

# 경고 메시지 출력
show_warning() {
    local message="$1"
    if command -v gum &> /dev/null; then
        echo "$message" | gum style --foreground 220 --bold
    else
        echo "! $message"
    fi
}

# 확인 대화상자
confirm_dialog() {
    local message="$1"
    if command -v gum &> /dev/null; then
        gum confirm "$message"
    else
        read -p "$message (y/N): " -n 1 -r
        echo ""
        [[ $REPLY =~ ^[Yy]$ ]]
    fi
}

# 입력 대화상자
input_dialog() {
    local prompt="$1"
    local placeholder="$2"
    local width="${3:-50}"
    
    if command -v gum &> /dev/null; then
        gum input --placeholder "$placeholder" --prompt "$prompt " --width "$width"
    else
        read -p "$prompt " input_value
        echo "$input_value"
    fi
}

# 패스워드 입력 대화상자
password_dialog() {
    local prompt="$1"
    local placeholder="$2"
    local width="${3:-50}"
    
    if command -v gum &> /dev/null; then
        gum input --password --placeholder "$placeholder" --prompt "$prompt " --width "$width"
    else
        read -s -p "$prompt " password_value
        echo ""
        echo "$password_value"
    fi
}

# 선택 메뉴
choose_menu() {
    local options="$1"
    local header="$2"
    local height="${3:-10}"
    
    if command -v gum &> /dev/null; then
        echo -e "$options" | gum choose --header "$header" --height "$height"
    else
        echo "$header"
        echo ""
        local IFS=$'\n'
        local option_array=($options)
        local i=1
        for option in "${option_array[@]}"; do
            echo "$i) $option"
            ((i++))
        done
        echo ""
        read -p "선택하세요 (1-$((i-1))): " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le $((i-1)) ]]; then
            echo "${option_array[$((choice-1))]}"
        fi
    fi
}

# 필터 검색
filter_menu() {
    local items="$1"
    local placeholder="$2"
    local height="${3:-20}"
    local header="${4:-검색}"
    
    if command -v gum &> /dev/null; then
        echo -e "$items" | gum filter --placeholder "$placeholder" --height "$height" --header "$header"
    else
        echo "$header"
        echo ""
        read -p "$placeholder " search_term
        echo -e "$items" | grep -i "$search_term" | head -1
    fi
}

# 테이블 출력
show_table() {
    local data="$1"
    local separator="${2:-|}"
    local widths="$3"
    
    if command -v gum &> /dev/null && [[ -n "$widths" ]]; then
        echo -e "$data" | gum table \
            --separator "$separator" \
            --border thick \
            --border.foreground 39 \
            --header.foreground 212 \
            --header.background 235 \
            --cell.foreground 255 \
            --widths "$widths"
    else
        echo -e "$data" | column -t -s "$separator"
    fi
}

# 진행 상황 표시
show_progress() {
    local message="$1"
    local step="$2"
    local total="$3"
    
    if command -v gum &> /dev/null; then
        echo "$message" | gum style --foreground 39 --bold
        if [[ -n "$step" ]] && [[ -n "$total" ]]; then
            echo "진행: $step/$total" | gum style --foreground 8
        fi
    else
        if [[ -n "$step" ]] && [[ -n "$total" ]]; then
            echo "[$step/$total] $message"
        else
            echo "$message"
        fi
    fi
}

# 대기 입력
wait_for_input() {
    local message="${1:-계속하려면 Enter를 누르세요...}"

    if command -v gum &> /dev/null; then
        gum input --placeholder "$message" || true
    else
        read -p "$message" -r || true
    fi
}

# 통합 테이블 + 실시간 검색
interactive_table() {
    local data="$1"
    local separator="${2:-|}"
    local placeholder="${3:-? 검색어를 입력하세요...}"
    local height="${4:-20}"
    
    if ! command -v gum &> /dev/null; then
        echo -e "$data" | column -t -s "$separator"
        return
    fi
    
    # 헤더 제거하고 데이터만 추출
    local table_data=$(echo -e "$data" | tail -n +2)
    
    # gum filter로 실시간 검색 가능한 테이블
    echo -e "$table_data" | gum filter \
        --placeholder "$placeholder" \
        --height "$height" \
        --no-limit \
        --indicator="→ " \
        --match.foreground=46 \
        --text.foreground=255
}