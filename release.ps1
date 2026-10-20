# 자동 스페이스 릴리스 (릴리스.bat 이 부른다)
# 1) 자동스페이스.ahk 의 APP_VERSION 으로 v태그를 정한다 (이미 있으면 멈춤)
# 2) 바뀐 소스를 커밋해서 GitHub 에 올린다
# 3) dist\AutoSpace.exe 를 빌드하고 SHA-256 을 latest.txt 에 적는다
# 4) GitHub 릴리스를 만들고 AutoSpace.exe, wincapture.dll, latest.txt 를 올린다
# 사람들이 쓰는 매크로는 켜질 때 latest.txt 를 보고 새 버전을 받는다. (Update.ahk)
# -Notes 를 주면 바뀐 점을 묻지 않는다.
param([string]$Notes)

# git/gh 는 정상일 때도 stderr 에 쓰므로 Stop 으로 두면 PowerShell 5.1 이 오류로 친다. 종료 코드로 판단한다.
$ErrorActionPreference = 'Continue'
$root = $PSScriptRoot
$main = Join-Path $root '자동스페이스.ahk'
$ahk2exe = 'C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe'
$ahkBase = 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe'
$gh = (Get-Command gh -ErrorAction SilentlyContinue).Source
if (-not $gh) { $gh = 'C:\Program Files\GitHub CLI\gh.exe' }

function Fail($msg) { Write-Host "`n[실패] $msg" -ForegroundColor Red; exit 1 }

$src = Get-Content $main -Raw -Encoding UTF8
if ($src -notmatch 'APP_VERSION := "(\d+\.\d+\.\d+)"') { Fail '자동스페이스.ahk 에서 APP_VERSION 을 못 찾았어요.' }
$ver = $Matches[1]
$tag = "v$ver"
$upd = Get-Content (Join-Path $root 'Update.ahk') -Raw -Encoding UTF8
if ($upd -notmatch 'UPDATE_REPO := "([^"]+)"') { Fail 'Update.ahk 에서 UPDATE_REPO 를 못 찾았어요.' }
$repo = $Matches[1]
if (-not (Test-Path (Join-Path $root 'target.ahk'))) { Fail 'target.ahk 가 없어요. target.example.ahk 를 복사해서 대상 창을 적어 주세요.' }

Write-Host "자동 스페이스 $tag 을(를) $repo 에 올립니다."
& $gh release view $tag --repo $repo 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) { Fail "$tag 은(는) 이미 올라가 있어요. 자동스페이스.ahk 의 APP_VERSION 을 올린 뒤 다시 하세요." }

if ($PSBoundParameters.ContainsKey('Notes')) {
    $notes = $Notes
} else {
    $notes = Read-Host '바뀐 점 (한 줄, 그냥 엔터면 생략)'
}
if (-not $notes) { $notes = '' }

# 소스 올리기
Push-Location $root
try {
    git add -A
    git diff --cached --quiet
    if ($LASTEXITCODE -ne 0) {
        $msg = "$tag"
        if ($notes) { $msg = "${tag}: $notes" }
        git commit -q -m $msg
        if ($LASTEXITCODE -ne 0) { Fail 'git 커밋 실패' }
    }
    git push -q origin HEAD
    if ($LASTEXITCODE -ne 0) { Fail 'git push 실패' }
} finally {
    Pop-Location
}

# 빌드
$dist = Join-Path $root 'dist'
try {
    if (Test-Path $dist) { Remove-Item $dist -Recurse -Force -ErrorAction Stop }
    New-Item -ItemType Directory $dist -ErrorAction Stop | Out-Null
} catch {
    Fail "dist 폴더를 못 만들었어요: $_"
}
$exe = Join-Path $dist 'AutoSpace.exe'
Start-Process $ahk2exe -ArgumentList "/in `"$main`" /out `"$exe`" /base `"$ahkBase`" /silent" -Wait -NoNewWindow
if (-not (Test-Path $exe)) { Fail 'exe 빌드 실패' }
$dll = Join-Path $dist 'wincapture.dll'
Copy-Item (Join-Path $root 'wincapture.dll') $dll
if (-not (Test-Path $dll)) { Fail 'wincapture.dll 복사 실패' }

$lines = @(
    "version=$ver",
    "AutoSpace.exe=$((Get-FileHash $exe -Algorithm SHA256).Hash.ToLower())",
    "wincapture.dll=$((Get-FileHash $dll -Algorithm SHA256).Hash.ToLower())",
    "notes=$notes"
)
$latest = Join-Path $dist 'latest.txt'
[IO.File]::WriteAllText($latest, ($lines -join "`n") + "`n", (New-Object Text.UTF8Encoding $false))

# 릴리스
$body = "자동 스페이스 $tag"
if ($notes) { $body = $notes }
& $gh release create $tag $exe $dll $latest --repo $repo --title "자동 스페이스 $tag" --notes $body
if ($LASTEXITCODE -ne 0) { Fail 'GitHub 릴리스 생성 실패' }
Write-Host "`n완료: https://github.com/$repo/releases/tag/$tag" -ForegroundColor Green
