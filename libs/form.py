#!/usr/bin/env python3
"""
curses 기반 폼 편집기
Usage: form.py [--title TEXT] [--info TEXT] <label1> <value1> <is_password1> [...]
  is_password: "1" = 마스킹, "0" = 평문

종료:
  Enter → stdout에 한 줄씩 값 출력 후 exit 0
  ESC   → 아무것도 출력하지 않고 exit 1
"""

import curses
import os
import sys
import textwrap


PAD = 2  # 좌우 여백
GAP = 1  # 필드 간 세로 간격


def init_colors():
    curses.start_color()
    curses.use_default_colors()
    # 1: 제목        cyan bold
    # 2: 레이블       white
    # 3: 활성 필드    black on white
    # 4: 비활성 필드  dark gray text
    # 5: 푸터 힌트    yellow
    # 6: 구분선       dark gray
    # 7: info 박스    cyan (테두리)
    # 8: info 텍스트  white dim
    curses.init_pair(1, curses.COLOR_CYAN, -1)
    curses.init_pair(2, curses.COLOR_WHITE, -1)
    curses.init_pair(3, curses.COLOR_BLACK, curses.COLOR_WHITE)
    try:
        curses.init_pair(4, 8, -1)  # 256color gray
    except Exception:
        curses.init_pair(4, curses.COLOR_WHITE, -1)
    curses.init_pair(5, curses.COLOR_YELLOW, -1)
    curses.init_pair(6, curses.COLOR_BLACK, -1)
    curses.init_pair(7, curses.COLOR_CYAN, -1)
    curses.init_pair(8, curses.COLOR_WHITE, -1)


def dw(s):
    """동아시아 폭 고려 표시 너비"""
    import unicodedata

    w = 0
    for c in s:
        ea = unicodedata.east_asian_width(c)
        w += 2 if ea in ("W", "F") else 1
    return w


def wrap_info(text, max_w):
    """info 텍스트를 max_w 폭으로 줄바꿈. dw 기반."""
    lines = []
    for para in text.split("\\n"):
        if dw(para) <= max_w:
            lines.append(para)
        else:
            # 바이트 단위가 아닌 표시 폭 기준으로 직접 분할
            cur = ""
            cur_w = 0
            for ch in para:
                cw = 2 if dw(ch) == 2 else 1
                if cur_w + cw > max_w:
                    lines.append(cur)
                    cur = ch
                    cur_w = cw
                else:
                    cur += ch
                    cur_w += cw
            if cur:
                lines.append(cur)
    return lines


def draw_info_box(stdscr, y, x, box_w, lines, has_color):
    """info 박스 그리기. 실제 사용한 줄 수 반환."""
    attr_border = curses.color_pair(7) if has_color else 0
    attr_text = curses.color_pair(8) if has_color else 0

    inner_w = box_w - 4  # ╭ + space + ... + space + ╮

    # 상단: ╭─ ℹ ──────╮
    top_fill = "─" * max(0, box_w - 5)  # ╭─ ℹ + fill + ╮
    top = "╭─ ℹ " + top_fill + "╮"
    try:
        stdscr.addstr(y, x, top[:box_w], attr_border)
    except curses.error:
        pass

    row = y + 1
    for line in lines:
        padded = line.ljust(inner_w)[:inner_w]
        try:
            stdscr.addstr(row, x, "│ ", attr_border)
            stdscr.addstr(row, x + 2, padded, attr_text)
            stdscr.addstr(row, x + 2 + inner_w, " │", attr_border)
        except curses.error:
            pass
        row += 1

    # 하단: ╰──────────╯
    bot_fill = "─" * max(0, box_w - 2)
    bot = "╰" + bot_fill + "╯"
    try:
        stdscr.addstr(row, x, bot[:box_w], attr_border)
    except curses.error:
        pass

    return row - y + 1  # 박스 전체 높이 (상단 + 내용 줄 수 + 하단)


def run_form(stdscr, title, info, fields):
    """
    title : 상단 제목 문자열
    info  : 안내 박스 텍스트 (빈 문자열이면 박스 미표시). \\n 으로 줄바꿈.
    fields: list of (label, value, is_password)
    returns: list of str (edited values) or None if cancelled
    """
    curses.curs_set(1)
    if curses.has_colors():
        init_colors()

    values = [list(f[1]) for f in fields]
    cursors = [len(f[1]) for f in fields]
    current = 0
    label_w = max(dw(f[0]) for f in fields)

    while True:
        h, w = stdscr.getmaxyx()
        box_w = min(label_w + 40, w - PAD * 2)
        field_w = max(20, w - PAD * 2 - label_w - 5)  # [ ... ]

        stdscr.erase()

        # ── 제목 ──────────────────────────────────────────────
        attr_title = (
            (curses.color_pair(1) | curses.A_BOLD)
            if curses.has_colors()
            else curses.A_BOLD
        )
        try:
            stdscr.addstr(1, PAD, title, attr_title)
        except curses.error:
            pass

        sep = "─" * min(label_w + field_w + 6, w - PAD * 2)
        try:
            stdscr.addstr(
                2, PAD, sep, curses.color_pair(6) if curses.has_colors() else 0
            )
        except curses.error:
            pass

        # ── info 박스 ─────────────────────────────────────────
        fields_start_y = 3
        if info:
            inner_w = box_w - 4
            info_lines = wrap_info(info, inner_w)
            box_h = draw_info_box(
                stdscr, 3, PAD, box_w, info_lines, curses.has_colors()
            )
            fields_start_y = 3 + box_h + 1  # 박스 아래 한 줄 여백

        # ── 필드들 ────────────────────────────────────────────
        cursor_pos = None
        for i, (label, _, is_pwd) in enumerate(fields):
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
            disp = "●" * len(val_str) if is_pwd else val_str

            # 커서 주변으로 스크롤
            c = cursors[i]
            if len(disp) > field_w - 1:
                start = max(0, c - field_w + 2)
                disp_shown = disp[start : start + field_w - 1]
                adj_c = c - start
            else:
                disp_shown = disp
                adj_c = c

            # 필드 박스
            x = PAD + label_w + 3
            field_str = "[" + disp_shown.ljust(field_w) + "]"
            if i == current:
                attr_f = (
                    (curses.color_pair(3) | curses.A_BOLD)
                    if curses.has_colors()
                    else curses.A_REVERSE
                )
            else:
                attr_f = curses.color_pair(4) if curses.has_colors() else 0

            try:
                stdscr.addstr(y, x, field_str, attr_f)
            except curses.error:
                pass

            # 커서 위치 저장 (렌더링 완료 후 move)
            if i == current:
                adj_c_col = dw(disp_shown[:adj_c])
                cursor_pos = (y, x + 1 + adj_c_col)

        # ── 푸터 ──────────────────────────────────────────────
        footer_y = fields_start_y + len(fields) * (1 + GAP)
        try:
            stdscr.addstr(
                footer_y, PAD, sep, curses.color_pair(6) if curses.has_colors() else 0
            )
            hint = "Tab/↑↓: 필드 이동   Enter: 저장   ESC: 취소"
            stdscr.addstr(
                footer_y + 1,
                PAD,
                hint,
                curses.color_pair(5) if curses.has_colors() else 0,
            )
        except curses.error:
            pass

        # 모든 addstr 완료 후 커서 이동 (refresh 직전)
        if cursor_pos:
            try:
                stdscr.move(cursor_pos[0], cursor_pos[1])
            except curses.error:
                stdscr.move(0, 0)

        stdscr.refresh()

        # ── 입력 처리 ─────────────────────────────────────────
        try:
            ch = stdscr.get_wch()
        except Exception:
            continue

        code = ord(ch) if isinstance(ch, str) else ch

        if code == 27:  # ESC
            return None
        elif code in (10, 13):  # Enter → 저장
            return ["".join(v) for v in values]
        elif code == 9:  # Tab → 다음
            current = (current + 1) % len(fields)
        elif code == curses.KEY_BTAB:  # Shift-Tab → 이전
            current = (current - 1) % len(fields)
        elif code == curses.KEY_DOWN:
            current = (current + 1) % len(fields)
        elif code == curses.KEY_UP:
            current = (current - 1) % len(fields)
        elif code == curses.KEY_LEFT:
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


def main():
    args = sys.argv[1:]

    # --title / --info 옵션 파싱
    title = "  서버 편집  "
    info = ""
    filtered = []
    i = 0
    while i < len(args):
        if args[i] == "--title" and i + 1 < len(args):
            title = "  " + args[i + 1] + "  "
            i += 2
        elif args[i] == "--info" and i + 1 < len(args):
            info = args[i + 1]
            i += 2
        else:
            filtered.append(args[i])
            i += 1
    args = filtered

    if len(args) == 0 or len(args) % 3 != 0:
        sys.stderr.write(
            "Usage: form.py [--title TEXT] [--info TEXT] label value is_password [...]\n"
        )
        sys.exit(1)

    fields = []
    for i in range(0, len(args), 3):
        label = args[i]
        value = args[i + 1]
        is_pwd = args[i + 2] == "1"
        fields.append((label, value, is_pwd))

    # curses는 터미널 직접 사용, stdout은 bash $() 캡처용으로 보존
    tty_fd = os.open("/dev/tty", os.O_RDWR)
    old_in = os.dup(0)
    old_out = os.dup(1)
    os.dup2(tty_fd, 0)
    os.dup2(tty_fd, 1)
    os.close(tty_fd)

    result = curses.wrapper(run_form, title, info, fields)

    os.dup2(old_out, 1)
    os.close(old_out)
    os.dup2(old_in, 0)
    os.close(old_in)

    if result is None:
        sys.exit(1)

    for v in result:
        print(v)


if __name__ == "__main__":
    main()
