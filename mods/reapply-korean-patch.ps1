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

# ── 온라인 번역 업데이트 (선택 / best-effort) ────────────
# 공개 배포처(GitHub)의 번역 JS만 받아 로컬과 다르면 교체. 폰트는 대상 아님.
$RawBase = 'https://raw.githubusercontent.com/shlifedev/RogueFable-IV-Localization/main/mods'

# 다운로드본이 올바른 JS인지 확인 (404 HTML/빈 파일이 로컬을 덮어쓰는 것 방지)
function Test-Download($file, $name) {
    if (-not (Test-Path $file)) { return $false }
    if ((Get-Item $file).Length -le 0) { return $false }
    $head = Get-Content $file -TotalCount 1 -ErrorAction SilentlyContinue
    if ($head -and $head.TrimStart().StartsWith('<')) { return $false }   # HTML 오류 페이지
    switch ($name) {
        'ko.js'   { if (-not (Select-String -Path $file -Pattern 'window.KO' -Quiet)) { return $false } }
        'i18n.js' { if (-not (Select-String -Path $file -Pattern 'Galmuri'   -Quiet)) { return $false } }
    }
    return $true
}

function Invoke-OnlineUpdate($modsDir) {
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
    $updated = @()
    $failed  = $false
    foreach ($f in @('ko.js', 'i18n.js', 'cheat-menu.js')) {
        $localPath = Join-Path $modsDir $f
        $tmp = [IO.Path]::GetTempFileName()
        try {
            Invoke-WebRequest -Uri "$RawBase/$f" -OutFile $tmp -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
        } catch {
            Write-Warn "$f 내려받기 실패 (네트워크/서버)"
            $failed = $true; Remove-Item $tmp -ErrorAction SilentlyContinue; continue
        }
        if (-not (Test-Download $tmp $f)) {
            Write-Warn "$f 응답이 올바르지 않아 건너뜁니다."
            $failed = $true; Remove-Item $tmp -ErrorAction SilentlyContinue; continue
        }
        $same = $false
        if (Test-Path $localPath) {
            $same = ((Get-FileHash $tmp).Hash -eq (Get-FileHash $localPath).Hash)
        }
        if ($same) { Remove-Item $tmp -ErrorAction SilentlyContinue; continue }
        if (Test-Path $localPath) { Copy-Item $localPath "$localPath.bak" -Force }
        Copy-Item $tmp $localPath -Force          # 다운로드본(UTF-8) 그대로 교체
        Remove-Item $tmp -ErrorAction SilentlyContinue
        $updated += $f
    }

    if ($updated.Count -gt 0) {
        Write-Ok ("번역을 최신으로 업데이트했습니다: " + ($updated -join ', '))
    } elseif ($failed) {
        Write-Warn "일부 파일을 받지 못했습니다. 기존 번역으로 진행합니다."
    } else {
        Write-Ok "이미 최신 번역입니다."
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

    # [1/3] 최신 한글 번역 확인 (선택 / 기본=건너뜀)
    Write-Step 1 3 "최신 한글 번역 확인 (선택)"
    $ans = ''
    try { $ans = Read-Host "        인터넷에서 최신 한글 번역을 확인할까요? (y/N)" } catch { $ans = '' }
    if ($ans -match '^(y|yes)$') {
        try { Invoke-OnlineUpdate $patchDir } catch { Write-Warn "업데이트 중 문제가 발생해 건너뜁니다. 기존 번역으로 진행합니다." }
    } else {
        Write-Ok "포함된 번역으로 진행합니다."
    }
    Start-Sleep -Milliseconds 250

    # [2/3] 패치 파일 확인
    Write-Step 2 3 "한글패치 파일 확인 중..."
    Start-Sleep -Milliseconds 250
    Restore-IfMissing 'mods/i18n.js'
    Restore-IfMissing 'mods/ko.js'
    Restore-IfMissing 'mods/cheat-menu.js'
    Restore-IfMissing 'mods/Galmuri11.woff2'
    Write-Ok "패치 파일 준비 완료"
    Start-Sleep -Milliseconds 350

    # [3/3] 게임(index.html)에 연결
    Write-Step 3 3 "게임에 한글패치 연결 중..."
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
