# Rogue Fable IV 한글패치 재적용 스크립트 (멱등)
# 게임이 업데이트되면 index.html이 순정으로 덮어써져 한글패치 로드 줄이 사라진다.
# 이 스크립트는 (1) mods/ 자산이 없으면 git에서 복원하고 (2) index.html에 패치 로드 2줄을
# 없을 때만 다시 삽입한다. 여러 번 실행해도 안전하다.
#
# 사용법:  PowerShell에서  ./reapply-korean-patch.ps1   실행 (이 파일이 있는 mods 폴더 기준)

$ErrorActionPreference = 'Stop'

$patchDir = $PSScriptRoot                              # ...\Rogue Fable IV\mods
$repoRoot = Split-Path $patchDir -Parent               # ...\Rogue Fable IV (게임 설치 루트 = git 루트)
$gameDir  = Join-Path $repoRoot 'rogue-fable-iv'       # index.html이 있는 NW.js 앱 폴더
$index    = Join-Path $gameDir 'index.html'

$snippet = @"

		<!-- 한글패치 (모든 UI 정의 이후 마지막 로드 / 런타임 주입) -->
		<script src='../mods/ko.js'></script>
		<script src='../mods/i18n.js'></script>
"@

# 자산은 모두 루트 mods/ 아래에 있다. relPath는 repoRoot 기준(예: 'mods/i18n.js').
function Restore-IfMissing($relPath) {
    $full = Join-Path $repoRoot $relPath
    if (Test-Path $full) { return }
    Write-Host "[복원 필요] $relPath 가 없습니다. git에서 복원 시도..."
    try {
        & git -C $repoRoot checkout korean-patch -- $relPath 2>$null
        if (Test-Path $full) { Write-Host "  -> 복원 완료" }
        else { Write-Host "  -> 복원 실패(수동 복사 필요): $relPath" }
    } catch {
        Write-Host "  -> git 사용 불가. 수동 복사 필요: $relPath"
    }
}

# 1) mods/ 자산 존재 보장 (무결성 검사 등으로 삭제된 경우 대비):
Restore-IfMissing 'mods/i18n.js'
Restore-IfMissing 'mods/ko.js'
Restore-IfMissing 'mods/cheat-menu.js'      # 치트/Tweak 메뉴(F9). i18n.js가 동적 로드함.
Restore-IfMissing 'mods/Galmuri11.woff2'

# 2) index.html에 패치 로드 2줄이 없으면 </body> 직전에 삽입:
if (-not (Test-Path $index)) {
    Write-Host "오류: index.html을 찾을 수 없습니다: $index"
    exit 1
}

$utf8 = New-Object System.Text.UTF8Encoding($false)   # BOM 없음
$html = [IO.File]::ReadAllText($index, $utf8)

if ($html -match 'mods/i18n\.js') {
    Write-Host "이미 적용되어 있습니다. (index.html에 한글패치 로드 줄 존재)"
} else {
    $idx = $html.LastIndexOf('</body>')
    if ($idx -lt 0) {
        Write-Host "오류: index.html에서 </body>를 찾지 못했습니다. 수동 삽입이 필요합니다."
        exit 1
    }
    $html = $html.Substring(0, $idx) + $snippet + "`n	" + $html.Substring($idx)
    [IO.File]::WriteAllText($index, $html, $utf8)
    Write-Host "한글패치 로드 줄을 index.html에 다시 삽입했습니다."
}

Write-Host "완료. 게임을 실행하면 한글이 표시됩니다."
