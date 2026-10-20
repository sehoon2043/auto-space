# 자동 스페이스

게임 창에 스페이스를 일정 간격으로 눌러 주는 AutoHotkey v2 매크로입니다.
AUTO(T)가 꺼지면 다시 켜 주고, 켜질 때 새 버전이 있으면 스스로 업데이트합니다.

## 받기

[Releases](../../releases/latest)에서 `AutoSpace.exe`만 받아 실행하면 됩니다.
`wincapture.dll`은 exe 안에 들어 있어서, 같은 폴더에 없으면 처음 켤 때 꺼내 놓습니다.
(exe 이름은 바꿔도 됩니다. 업데이트는 지금 이름 그대로 바꿔 끼웁니다.)

## 쓰는 법

- **켜기/끄기:** 버튼 또는 F8, 종료는 F10
- **간격(초):** 스페이스 누르는 간격
- **백그라운드:** 게임 창이 뒤에 있어도 누릅니다
- **AUTO 유지:** 확인 간격마다 AUTO 버튼을 보고, 꺼진 것이 확실할 때만 T를 눌러 다시 켭니다.
  버튼이 안 보이거나 애매하면 아무것도 하지 않습니다. 게임 창이 가려져 있어도 되지만 최소화하면 확인하지 못합니다.
- **업데이트:** 켜질 때 자동으로 확인하고, [업데이트 확인] 버튼으로도 확인할 수 있습니다.

## 새 버전 올리기 (개발자)

0. 처음 한 번: `target.example.ahk`를 `target.ahk`로 복사해서 대상 창을 적습니다. `target.ahk`는 git에 올라가지 않습니다.
1. `자동스페이스.ahk`의 `APP_VERSION`을 올립니다 (예: `1.0.0` → `1.0.1`).
2. `릴리스.bat`을 실행하고 바뀐 점을 한 줄 적습니다.
   소스 커밋·푸시, exe 빌드, SHA-256 계산, GitHub 릴리스 생성까지 자동으로 합니다.

필요한 것: AutoHotkey v2 + Ahk2Exe, git, GitHub CLI(`gh auth login` 완료)

## 파일

| 파일 | 내용 |
|---|---|
| `자동스페이스.ahk` | 화면, 스페이스 누르기, AUTO 유지 |
| `target.example.ahk` | 대상 창 설정 예시 (`target.ahk`로 복사해서 사용) |
| `AutoCheck.ahk` | AUTO 버튼 켜짐/꺼짐 판정 (WGC 캡처, 안 되면 화면 픽셀) |
| `Update.ahk` | GitHub Releases 업데이트 확인·검증·교체 |
| `wincapture.dll` | 가려진 창 캡처 ([thqby/ahk2_lib](https://github.com/thqby/ahk2_lib), MIT) |
| `빌드.bat` | 이 폴더에 `자동스페이스.exe` 빌드 (시험용) |
| `릴리스.bat` / `release.ps1` | 새 버전 릴리스 |
