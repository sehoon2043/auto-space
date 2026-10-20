#Requires AutoHotkey v2.0
#SingleInstance Force
;@Ahk2Exe-SetName 자동 스페이스
;@Ahk2Exe-SetDescription 자동 스페이스
; 자동 스페이스: 게임 창에 스페이스를 일정 간격으로 보낸다.
; 어떤 창인지는 target.ahk 의 GAME 에 적는다 (git 에 올리지 않는 파일, target.example.ahk 참고).
; 게임 창이 맨 앞이면 SendInput(스캔코드)으로 누른다.
; 게임 창이 뒤에 있으면 Unity가 포커스를 잃고 키보드를 꺼 버리므로, 가짜 포커스 메시지
; (WM_ACTIVATEAPP/WM_ACTIVATE/WM_SETFOCUS)를 먼저 보내고 창 메시지로 스페이스를 보낸다.
; [백그라운드]를 끄면 예전처럼 게임 창이 맨 앞일 때만 누르고, [켜기] 때 게임 창을 앞으로 가져온다.
; [AUTO 유지]를 켜 두면 확인 간격마다 AUTO(T) 버튼 색을 보고, 꺼져 있으면 T를 눌러 다시 켠다. (AutoCheck.ahk)
; 게임 창이 가려져 있어도 확인하려면 wincapture.dll 이 이 파일(exe)과 같은 폴더에 있어야 한다. 최소화는 안 된다.
; 켜질 때 GitHub 에 새 버전이 있는지 보고, 있으면 물어본 뒤 스스로 바꿔 끼우고 다시 켜진다. (Update.ahk)
; F8: 켜기/끄기   F10: 종료

APP_VERSION := "1.0.0"  ; 릴리스.bat 이 이 값으로 v태그를 만든다. 릴리스마다 올릴 것.

SetTitleMatchMode 1  ; GAME 의 창 제목은 앞부분만 맞으면 된다
GAME := ""           ; target.ahk 가 채운다
#Include *i %A_ScriptDir%\target.ahk
#Include %A_ScriptDir%\AutoCheck.ahk
#Include %A_ScriptDir%\Update.ahk

WM_ACTIVATEAPP := 0x001C, WM_ACTIVATE := 0x0006, WM_SETFOCUS := 0x0007
WM_KEYDOWN := 0x0100, WM_KEYUP := 0x0101, WM_CHAR := 0x0102

isOn := false
count := 0
status := "꺼짐"
interval := 1.5
autoInterval := 5
autoStatus := ""
autoFixed := 0
gameHwnd := 0

g := Gui("+AlwaysOnTop", "자동 스페이스 v" APP_VERSION)
g.MarginX := 12
g.MarginY := 10
g.SetFont("s9", "맑은 고딕")
lblGame := g.AddText("w250")
g.SetFont("s11 bold")
lblStatus := g.AddText("w250 y+6")
g.SetFont("s9 norm")
lblCount := g.AddText("w250")

g.AddText("y+12 Section", "간격(초)")
edInterval := g.AddEdit("x+6 ys-3 w50", "1.5")
chkTop := g.AddCheckbox("x+60 ys Checked", "항상 위")
chkTop.OnEvent("Click", (*) => g.Opt((chkTop.Value ? "+" : "-") "AlwaysOnTop"))
chkBg := g.AddCheckbox("xm y+10 Checked", "백그라운드 (게임 창이 뒤에 있어도 누르기)")
chkAuto := g.AddCheckbox("xm y+8 Checked", "AUTO 유지 (AUTO(T)가 꺼지면 다시 켜기)")
g.AddText("xm+16 y+8 Section", "확인 간격(초)")
edAutoInterval := g.AddEdit("x+6 ys-3 w50", "5")
lblAuto := g.AddText("xm+16 w234 y+6 cGray")

g.SetFont("s12 bold")
btn := g.AddButton("xm y+12 w250 h44", "켜기")
btn.OnEvent("Click", ToggleFromButton)
g.SetFont("s9 norm")
g.AddButton("w250", "종료").OnEvent("Click", (*) => ExitApp())
g.AddText("w250 Center cGray", "F8 = 켜기/끄기, F10 = 종료")
g.AddText("w160 y+6 Section cGray", "v" APP_VERSION)
g.AddButton("x+0 ys-4 w90 h22", "업데이트 확인").OnEvent("Click", (*) => CheckForUpdate())
g.OnEvent("Close", (*) => ExitApp())

Refresh()
g.Show()
SetTimer Refresh, 200

CleanupUpdateFiles()
SetTimer CleanupUpdateFiles, -5000          ; 방금 끝난 예전 exe 가 아직 안 닫혔을 수 있다
SetTimer () => CheckForUpdate(true), -1500  ; 창이 뜬 뒤에 조용히 확인

F8:: {
    SetOn(!isOn)
    KeyWait "F8"  ; 꾹 누르고 있어도 한 번만 토글
}
F10::ExitApp

SetOn(value) {
    global isOn, count, status, autoStatus, autoFixed
    isOn := value
    autoStatus := ""
    if value {
        count := 0
        autoFixed := 0
        status := "켜짐"
        SetTimer Worker, Round(interval * 1000)
        SetTimer AutoWorker, Round(autoInterval * 1000)
    } else {
        status := "꺼짐"
        SetTimer Worker, 0
        SetTimer AutoWorker, 0
    }
}

ToggleFromButton(*) {
    global gameHwnd
    if isOn {
        SetOn(false)
        return
    }
    if !gameHwnd || !WinExist("ahk_id " gameHwnd)
        gameHwnd := FindGame()
    SetOn(true)
    ; 포그라운드 전용일 땐 버튼을 누른 순간 이 창이 맨 앞이라 게임으로 포커스를 넘겨 줘야 바로 눌린다 (최소화돼 있으면 복원)
    if gameHwnd && !chkBg.Value
        WinActivate "ahk_id " gameHwnd
}

Worker() {
    global gameHwnd, count, status
    Critical  ; AutoWorker 의 T 누르기와 키 입력이 섞이지 않게
    if !gameHwnd || !WinExist("ahk_id " gameHwnd) {
        gameHwnd := FindGame()
        if !gameHwnd {
            status := "게임 창을 찾는 중..."
            return
        }
    }
    if !WinActive("ahk_id " gameHwnd) {
        if !chkBg.Value {
            status := "켜짐 - 게임 창이 맨 앞이 아니라 쉬는 중"
            return
        }
        if PostKey(gameHwnd, 0x20, 0x39, 0x20) {
            count += 1
            status := "켜짐 - 백그라운드로 누르는 중"
        } else {
            status := "켜짐 - 창 메시지 전송 실패 (재시도 중)"
        }
        return
    }
    if PressKey(0x39) {
        count += 1
        status := "켜짐 - 누르는 중"
    } else {
        SetOn(false)
        status := "키를 보낼 권한 없음 → 관리자 권한으로 실행"
    }
}

; AUTO(T) 버튼이 꺼져 있으면 T를 눌러 다시 켠다
AutoWorker() {
    global autoStatus, autoFixed
    Critical
    if !chkAuto.Value {
        autoStatus := ""
        return
    }
    if !gameHwnd || !WinExist("ahk_id " gameHwnd)
        return  ; 게임 창은 Worker 가 찾는다
    active := WinActive("ahk_id " gameHwnd)
    if !active && !chkBg.Value {
        autoStatus := "AUTO: 게임 창이 맨 앞이 아니라 쉬는 중"
        return
    }
    st := CheckAuto(gameHwnd)
    if st = "off" {
        Sleep 700  ; 화면이 잠깐 바뀐 것일 수 있어 한 번 더 본다
        st := CheckAuto(gameHwnd)
    }
    if st = "on" {
        autoStatus := "AUTO: 켜져 있음"
    } else if st = "minimized" {
        autoStatus := "AUTO: 게임 창이 최소화돼서 확인 못 함"
    } else if st = "hidden" {
        autoStatus := "AUTO: 버튼이 가려져서 확인 못 함 (WGC 안 됨)"
    } else if st = "" {
        autoStatus := "AUTO: 버튼을 못 찾음 (메뉴·로딩 중?)"
    } else {
        ; 확인하는 사이 게임 창이 앞/뒤로 바뀌었을 수 있어 다시 본다
        if WinActive("ahk_id " gameHwnd)
            ok := PressKey(0x14)
        else
            ok := PostKey(gameHwnd, 0x54, 0x14, 0x74)  ; VK_T, 스캔코드 0x14, 't'
        if ok {
            autoFixed += 1
            autoStatus := "AUTO: 꺼져 있어서 다시 켬 (" autoFixed "회)"
        } else {
            autoStatus := "AUTO: 꺼져 있는데 T 전송 실패 (재시도 중)"
        }
    }
}

; space.py 의 press()와 같은 방식: 스캔코드를 SendInput으로 누르고 50ms 뒤 뗀다 (0x39 = 스페이스, 0x14 = T)
PressKey(scan) {
    static size := A_PtrSize = 8 ? 40 : 28  ; sizeof(INPUT)
    inp := Buffer(size, 0)
    NumPut("UInt", 1, inp, 0)                           ; INPUT_KEYBOARD
    NumPut("UShort", scan, inp, A_PtrSize + 2)          ; wScan
    NumPut("UInt", 0x0008, inp, A_PtrSize + 4)          ; KEYEVENTF_SCANCODE
    if DllCall("SendInput", "UInt", 1, "Ptr", inp, "Int", size, "UInt") != 1
        return false
    Sleep 50
    NumPut("UInt", 0x0008 | 0x0002, inp, A_PtrSize + 4) ; + KEYEVENTF_KEYUP
    DllCall("SendInput", "UInt", 1, "Ptr", inp, "Int", size, "UInt")
    return true
}

; 가짜 포커스 방식: 게임에게 활성 창이라고 속인 뒤 창 메시지로 키를 보낸다
; 스페이스 = PostKey(hwnd, 0x20, 0x39, 0x20)
PostKey(hwnd, vk, scan, ch) {
    target := "ahk_id " hwnd
    lp := (scan << 16) | 1
    try {
        PostMessage WM_ACTIVATEAPP, 1, 0, , target
        PostMessage WM_ACTIVATE, 1, 0, , target
        PostMessage WM_SETFOCUS, 0, 0, , target
        Sleep 30
        PostMessage WM_KEYDOWN, vk, lp, , target
        PostMessage WM_CHAR, ch, lp, , target
        Sleep 50
        PostMessage WM_KEYUP, vk, lp | 0xC0000000, , target
    } catch {
        return false
    }
    return true
}

Refresh() {
    global interval, autoInterval
    v := Trim(edInterval.Value)
    if IsNumber(v) {
        v := Max(0.3, v + 0)
        if v != interval {
            interval := v
            if isOn
                SetTimer Worker, Round(interval * 1000)
        }
    }
    v := Trim(edAutoInterval.Value)
    if IsNumber(v) {
        v := Max(2, v + 0)  ; T를 누른 뒤 버튼 색이 바뀔 시간을 준다
        if v != autoInterval {
            autoInterval := v
            if isOn
                SetTimer AutoWorker, Round(autoInterval * 1000)
        }
    }

    if GAME = ""
        SetText(lblGame, "대상 창 설정(target.ahk)이 없어요", "cRed")
    else if FindGame()
        SetText(lblGame, "게임 창: 찾음", "cGreen")
    else
        SetText(lblGame, "게임 창: 없음 (게임을 켜 주세요)", "cRed")
    SetText(lblStatus, status)
    SetText(lblCount, "누른 횟수: " count)
    SetText(lblAuto, autoStatus)
    SetText(btn, isOn ? "끄기" : "켜기")
}

; GAME 창의 hwnd. 설정이 비어 있으면 아무 창이나 잡지 않게 0
FindGame() {
    if GAME = ""
        return 0
    return WinExist(GAME)
}

; 글자가 바뀔 때만 갱신해서 깜빡임을 막는다
SetText(ctrl, text, color := "") {
    if ctrl.Text = text
        return
    if color
        ctrl.SetFont(color)
    ctrl.Text := text
}
