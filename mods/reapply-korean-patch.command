#!/bin/bash
# Rogue Fable IV 한글패치 적용 스크립트 (macOS / 멱등 - 여러 번 실행해도 안전)
# 제작: shlifedev  (shlifedev@gmail.com)
#
# 사용법:
#   1) 이 'mods' 폴더를 게임 앱 안의 다음 위치에 넣습니다 (윈도우의 게임 루트에 해당):
#        Rogue Fable IV/RogueFableIV.app/Contents/Resources/app.nw/
#        (RogueFableIV.app 우클릭 -> "패키지 내용 보기" 로 들어갈 수 있습니다.)
#   2) 이 파일(reapply-korean-patch.command)을 더블클릭하면 터미널에서 실행됩니다.
#      - 더블클릭이 안 되면: 우클릭 -> "열기" 를 선택하거나,
#        터미널에서  chmod +x "이 파일"  후 다시 실행해 주세요.
#   - 게임이 업데이트되어 한글이 사라지면 다시 실행하면 복구됩니다.

set -euo pipefail

# UTF-8 출력 보장
export LC_ALL="${LC_ALL:-en_US.UTF-8}"
export LANG="${LANG:-en_US.UTF-8}"

# ── 색상 ─────────────────────────────────────────────────
if [ -t 1 ]; then
    C_CYAN=$'\033[36m'; C_DCYAN=$'\033[36;2m'; C_GRAY=$'\033[90m'
    C_YELLOW=$'\033[33m'; C_GREEN=$'\033[32m'; C_DGREEN=$'\033[32;2m'
    C_RED=$'\033[31m'; C_WHITE=$'\033[97m'; C_RESET=$'\033[0m'
else
    C_CYAN=''; C_DCYAN=''; C_GRAY=''; C_YELLOW=''; C_GREEN=''
    C_DGREEN=''; C_RED=''; C_WHITE=''; C_RESET=''
fi

write_banner() {
    printf '\n'
    printf '  %s==================================================%s\n' "$C_DCYAN" "$C_RESET"
    printf '        %sRogue Fable IV   한글 패치 적용기%s\n' "$C_CYAN" "$C_RESET"
    printf '  %s--------------------------------------------------%s\n' "$C_DCYAN" "$C_RESET"
    printf '        %s제작 :  shlifedev%s\n' "$C_GRAY" "$C_RESET"
    printf '        %s문의 :  shlifedev@gmail.com%s\n' "$C_GRAY" "$C_RESET"
    printf '  %s==================================================%s\n' "$C_DCYAN" "$C_RESET"
    printf '\n'
}
write_step() { printf '  %s[%s/%s]%s %s%s%s\n' "$C_YELLOW" "$1" "$2" "$C_RESET" "$C_WHITE" "$3" "$C_RESET"; }
write_ok()   { printf '        %s[완료]%s %s%s%s\n' "$C_GREEN" "$C_RESET" "$C_GRAY" "$1" "$C_RESET"; }
write_warn() { printf '        %s[주의]%s %s%s%s\n' "$C_YELLOW" "$C_RESET" "$C_GRAY" "$1" "$C_RESET"; }

pause_exit() {
    printf '\n  %s아무 키나 누르면 창이 닫힙니다...%s\n' "$C_GRAY" "$C_RESET"
    read -r -n 1 -s _ 2>/dev/null || read -r _ 2>/dev/null || true
    exit "${1:-0}"
}

fail() {
    printf '\n  %s[오류] %s%s\n' "$C_RED" "$1" "$C_RESET"
    printf '  %s문제가 계속되면 shlifedev@gmail.com 으로 문의해 주세요.%s\n' "$C_GRAY" "$C_RESET"
    pause_exit 1
}

# 자산이 없으면 git에서 복원 시도 (게임 무결성 검사 등으로 삭제된 경우 대비)
restore_if_missing() {
    local rel="$1" full="$REPO_ROOT/$1"
    [ -e "$full" ] && return 0
    write_warn "$rel 없음 -> git에서 복원 시도..."
    if command -v git >/dev/null 2>&1 && git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        if git -C "$REPO_ROOT" checkout korean-patch -- "$rel" >/dev/null 2>&1 && [ -e "$full" ]; then
            write_ok "복원 완료: $rel"; return 0
        fi
    fi
    write_warn "복원 실패. mods 폴더를 다시 복사해 주세요: $rel"
}

# ── 온라인 번역 업데이트 (선택 / best-effort) ────────────
# 공개 배포처(GitHub)의 번역 JS만 받아 로컬과 다르면 교체. 폰트는 대상 아님.
RAW_BASE="https://raw.githubusercontent.com/shlifedev/RogueFable-IV-Localization/main/mods"

# 다운로드본이 올바른 JS인지 확인 (404 HTML/빈 파일이 로컬을 덮어쓰는 것 방지)
validate_download() {
    local file="$1" name="$2" first
    [ -s "$file" ] || return 1                 # 비어있지 않음
    first="$(head -c1 "$file")"
    [ "$first" = "<" ] && return 1             # '<' 로 시작 = HTML 오류 페이지
    case "$name" in
        ko.js)   grep -q "window.KO" "$file" || return 1 ;;
        i18n.js) grep -q "Galmuri"   "$file" || return 1 ;;
    esac
    return 0
}

online_update() {
    if ! command -v curl >/dev/null 2>&1; then
        write_warn "curl을 찾을 수 없어 업데이트를 건너뜁니다."
        return 0
    fi
    local updated="" failed=0 f local_path tmp
    for f in ko.js i18n.js cheat-menu.js; do
        local_path="$SCRIPT_DIR/$f"
        tmp="$(mktemp "${TMPDIR:-/tmp}/rfiv_dl.XXXXXX")"
        if ! curl -fsSL --max-time 15 -o "$tmp" "$RAW_BASE/$f" 2>/dev/null; then
            write_warn "$f 내려받기 실패 (네트워크/서버)"
            failed=1; rm -f "$tmp"; continue
        fi
        if ! validate_download "$tmp" "$f"; then
            write_warn "$f 응답이 올바르지 않아 건너뜁니다."
            failed=1; rm -f "$tmp"; continue
        fi
        if [ -f "$local_path" ] && cmp -s "$tmp" "$local_path"; then
            rm -f "$tmp"; continue             # 로컬과 동일 -> 변경 없음
        fi
        [ -f "$local_path" ] && cp "$local_path" "$local_path.bak"
        cat "$tmp" > "$local_path"             # UTF-8 그대로 보존
        rm -f "$tmp"
        updated="$updated $f"
    done

    if [ -n "$updated" ]; then
        write_ok "번역을 최신으로 업데이트했습니다:$updated"
    elif [ "$failed" -eq 1 ]; then
        write_warn "일부 파일을 받지 못했습니다. 기존 번역으로 진행합니다."
    else
        write_ok "이미 최신 번역입니다."
    fi
}

# ── 본 작업 ──────────────────────────────────────────────
write_banner

# 스크립트 자신의 절대 경로 -> mods 폴더
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # .../app.nw/mods
REPO_ROOT="$(dirname "$SCRIPT_DIR")"                          # .../app.nw  (게임 루트)
GAME_DIR="$REPO_ROOT/rogue-fable-iv"                          # index.html이 있는 폴더
INDEX="$GAME_DIR/index.html"

# [1/3] 최신 한글 번역 확인 (선택 / 기본=건너뜀)
write_step 1 3 "최신 한글 번역 확인 (선택)"
ans=""
if [ -t 0 ]; then
    printf '        %s인터넷에서 최신 한글 번역을 확인할까요? (y/N): %s' "$C_WHITE" "$C_RESET"
    read -r ans || ans=""
fi
case "$ans" in
    y|Y|yes|YES|Yes) online_update || true ;;
    *)               write_ok "포함된 번역으로 진행합니다." ;;
esac
sleep 0.25

# [2/3] 패치 파일 확인
write_step 2 3 "한글패치 파일 확인 중..."
sleep 0.25
restore_if_missing "mods/i18n.js"
restore_if_missing "mods/ko.js"
restore_if_missing "mods/cheat-menu.js"
restore_if_missing "mods/Galmuri11.woff2"
write_ok "패치 파일 준비 완료"
sleep 0.35

# [3/3] 게임(index.html)에 연결
write_step 3 3 "게임에 한글패치 연결 중..."
sleep 0.25
if [ ! -f "$INDEX" ]; then
    fail "게임의 index.html을 찾을 수 없습니다.
      이 mods 폴더를  RogueFableIV.app/Contents/Resources/app.nw/  안에 두었는지 확인해 주세요.
      (찾는 위치: $INDEX)"
fi

if grep -q "mods/i18n\.js" "$INDEX"; then
    write_ok "이미 적용되어 있습니다."
else
    if ! grep -q "</body>" "$INDEX"; then
        fail "index.html에서 </body>를 찾지 못했습니다. 수동 삽입이 필요합니다."
    fi

    # </body> (마지막 등장) 앞에 스니펫 주입 — UTF-8 / BOM 없음 유지
    # (macOS 기본 awk는 -v 값에 줄바꿈을 못 받으므로 스니펫을 임시 파일로 전달)
    SNIP_FILE="$(mktemp "${TMPDIR:-/tmp}/rfiv_snip.XXXXXX")"
    printf '\n\t\t<!-- 한글패치 (모든 UI 정의 이후 마지막 로드 / 런타임 주입) -->\n\t\t<script src='\''../mods/ko.js'\''></script>\n\t\t<script src='\''../mods/i18n.js'\''></script>\n' > "$SNIP_FILE"

    TMP="$(mktemp "${TMPDIR:-/tmp}/rfiv_index.XXXXXX")"
    awk -v snipfile="$SNIP_FILE" '
        BEGIN { snip=""; while ((getline l < snipfile) > 0) snip = snip l "\n" }
        { lines[NR]=$0; if ($0 ~ /<\/body>/) last=NR }
        END {
            for (i=1; i<=NR; i++) {
                if (i==last) printf "%s", snip
                print lines[i]
            }
        }
    ' "$INDEX" > "$TMP"

    # 원본 권한 유지하며 교체
    cat "$TMP" > "$INDEX"
    rm -f "$TMP" "$SNIP_FILE"
    write_ok "index.html에 한글패치를 연결했습니다."
fi

sleep 0.35
printf '\n'
printf '  %s==================================================%s\n' "$C_DGREEN" "$C_RESET"
printf '   %s적용 완료! 게임을 실행하면 한글이 표시됩니다.%s\n' "$C_GREEN" "$C_RESET"
printf '   %s(게임 안에서 F9 키로 치트 / Tweak 메뉴를 열 수 있어요.)%s\n' "$C_GRAY" "$C_RESET"
printf '  %s==================================================%s\n' "$C_DGREEN" "$C_RESET"

pause_exit 0
