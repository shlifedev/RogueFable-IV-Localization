# Rogue Fable IV 한글패치 적용 스크립트 (멱등 - 여러 번 실행해도 안전)
# 제작: shlifedev  (shlifedev@gmail.com)
#
# 사용법: 이 파일을 우클릭 -> "PowerShell에서 실행"
#   - 게임이 업데이트되어 한글이 사라지면 다시 실행하면 복구됩니다.

$ErrorActionPreference = 'Stop'

# ── 화면 출력 도우미 ─────────────────────────────────────
function Write-Banner {
    Write-Host ""
    Write-Host "  ==================================================" -ForegroundColor DarkCyan
    Write-Host "        Rogue Fable IV   한글 패치 적용기" -ForegroundColor Cyan
    Write-Host "  --------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "        제작 :  shlifedev" -ForegroundColor Gray
    Write-Host "        문의 :  shlifedev@gmail.com" -ForegroundColor Gray
    Write-Host "  ==================================================" -ForegroundColor DarkCyan
    Write-Host ""
}

function Write-Step($n, $total, $msg) {
    Write-Host ("  [{0}/{1}] " -f $n, $total) -ForegroundColor Yellow -NoNewline
    Write-Host $msg -ForegroundColor White
}

function Write-Ok($msg) {
    Write-Host "        [완료] " -ForegroundColor Green -NoNewline
    Write-Host $msg -ForegroundColor Gray
}

function Write-Warn($msg) {
    Write-Host "        [주의] " -ForegroundColor Yellow -NoNewline
    Write-Host $msg -ForegroundColor Gray
}

# 자산이 없으면 git에서 복원 시도 (게임 무결성 검사 등으로 삭제된 경우 대비)
function Restore-IfMissing($relPath) {
    $full = Join-Path $repoRoot $relPath
    if (Test-Path $full) { return }
    Write-Warn "$relPath 없음 -> git에서 복원 시도..."
    try {
        & git -C $repoRoot checkout korean-patch -- $relPath 2>$null
        if (Test-Path $full) { Write-Ok "복원 완료: $relPath" }
        else { Write-Warn "복원 실패. mods 폴더를 다시 복사해 주세요: $relPath" }
    } catch {
        Write-Warn "git 사용 불가. mods 폴더를 다시 복사해 주세요: $relPath"
    }
}

# ── 본 작업 ──────────────────────────────────────────────
$exitCode = 0
try {
    Write-Banner

    $patchDir = $PSScriptRoot                          # ...\Rogue Fable IV\mods
    $repoRoot = Split-Path $patchDir -Parent           # ...\Rogue Fable IV (게임 설치 루트)
    $gameDir  = Join-Path $repoRoot 'rogue-fable-iv'   # index.html이 있는 폴더
    $index    = Join-Path $gameDir 'index.html'

    $snippet = @"

		<!-- 한글패치 (모든 UI 정의 이후 마지막 로드 / 런타임 주입) -->
		<script src='../mods/ko.js'></script>
		<script src='../mods/i18n.js'></script>
"@

    # [1/2] 패치 파일 확인
    Write-Step 1 2 "한글패치 파일 확인 중..."
    Start-Sleep -Milliseconds 250
    Restore-IfMissing 'mods/i18n.js'
    Restore-IfMissing 'mods/ko.js'
    Restore-IfMissing 'mods/cheat-menu.js'
    Restore-IfMissing 'mods/Galmuri11.woff2'
    Write-Ok "패치 파일 준비 완료"
    Start-Sleep -Milliseconds 350

    # [2/2] 게임(index.html)에 연결
    Write-Step 2 2 "게임에 한글패치 연결 중..."
    Start-Sleep -Milliseconds 250
    if (-not (Test-Path $index)) {
        throw "게임의 index.html을 찾을 수 없습니다. mods 폴더를 게임 설치 폴더 안에 두었는지 확인해 주세요.`n      ($index)"
    }

    $utf8 = New-Object System.Text.UTF8Encoding($false)   # BOM 없음
    $html = [IO.File]::ReadAllText($index, $utf8)

    if ($html -match 'mods/i18n\.js') {
        Write-Ok "이미 적용되어 있습니다."
    } else {
        $idx = $html.LastIndexOf('</body>')
        if ($idx -lt 0) {
            throw "index.html에서 </body>를 찾지 못했습니다. 수동 삽입이 필요합니다."
        }
        $html = $html.Substring(0, $idx) + $snippet + "`n`t" + $html.Substring($idx)
        [IO.File]::WriteAllText($index, $html, $utf8)
        Write-Ok "index.html에 한글패치를 연결했습니다."
    }

    Start-Sleep -Milliseconds 350
    Write-Host ""
    Write-Host "  ==================================================" -ForegroundColor DarkGreen
    Write-Host "   적용 완료! 게임을 실행하면 한글이 표시됩니다." -ForegroundColor Green
    Write-Host "   (게임 안에서 F9 키로 치트 / Tweak 메뉴를 열 수 있어요.)" -ForegroundColor DarkGray
    Write-Host "  ==================================================" -ForegroundColor DarkGreen
}
catch {
    Write-Host ""
    Write-Host "  [오류] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  문제가 계속되면 shlifedev@gmail.com 으로 문의해 주세요." -ForegroundColor DarkGray
    $exitCode = 1
}
finally {
    Write-Host ""
    Write-Host "  아무 키나 누르면 창이 닫힙니다..." -ForegroundColor DarkGray
    try { $null = $host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') } catch { Read-Host | Out-Null }
}

exit $exitCode
