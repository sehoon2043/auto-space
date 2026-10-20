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
; [자동 문파 도움]을 켜 두면 확인 간격마다 왼쪽 문파 도움 아이콘(주황 바탕 흰 주먹)을 찾고, 떠 있으면 클릭한다. (IconCheck.ahk, PostClick)
; 스페이스 간격, AUTO 확인 간격, 문파 도움 확인 간격은 각각 따로 정한다.
; 게임 창이 가려져 있어도 확인하려면 wincapture.dll 이 이 파일(exe)과 같은 폴더에 있어야 한다. 최소화는 안 된다.
; wincapture.dll 은 exe 안에 같이 들어 있어서, 없으면 켜질 때 꺼내 놓는다.
; 켜질 때와 30분마다 GitHub 에 새 버전이 있는지 보고, 있으면 묻지 않고 바꿔 끼운 뒤 다시 켜진다. (Update.ahk)
; 다시 켜질 때 켜짐 상태와 설정을 인자로 넘겨서 그대로 이어 간다. (ResumeArgs)
; F8: 켜기/끄기   F10: 종료

APP_VERSION := "1.0.5"  ; 릴리스.bat 이 이 값으로 v태그를 만든다. 릴리스마다 올릴 것.

; exe 하나만 받아도 되게 dll 을 꺼내 놓는다. 폴더에 쓸 수 없으면 화면 픽셀 방식으로 돌아간다. (AutoCheck.ahk)
; (Ahk2Exe 는 줄이 FileInstall 로 시작해야 파일을 exe 에 넣는다)
if !FileExist(A_ScriptDir "\wincapture.dll") {
    try {
        FileInstall "wincapture.dll", A_ScriptDir "\wincapture.dll"
    }
}

SetTitleMatchMode 1  ; GAME 의 창 제목은 앞부분만 맞으면 된다
GAME := ""           ; target.ahk 가 채운다
#Include *i %A_ScriptDir%\target.ahk
#Include %A_ScriptDir%\AutoCheck.ahk
#Include %A_ScriptDir%\IconCheck.ahk
#Include %A_ScriptDir%\Update.ahk

WM_ACTIVATEAPP := 0x001C, WM_ACTIVATE := 0x0006, WM_SETFOCUS := 0x0007
WM_KEYDOWN := 0x0100, WM_KEYUP := 0x0101, WM_CHAR := 0x0102
WM_MOUSEMOVE := 0x0200, WM_LBUTTONDOWN := 0x0201, WM_LBUTTONUP := 0x0202

isOn := false
APP_TITLE := "자동 스페이스"  ; 창 제목이 잘리지 않게 버전은 아래쪽에만 적는다
count := 0
spaceNote := ""      ; 스페이스를 못 누를 때 이유 (잘 누르면 "")
lastSpace := 0       ; 마지막으로 스페이스를 누른 A_TickCount
interval := 1.5
autoInterval := 5
autoStatus := ""
autoFixed := 0
nextAuto := 0        ; 다음 AUTO 확인 A_TickCount
iconInterval := 5
iconStatus := ""
iconClicked := 0
nextIcon := 0        ; 다음 아이콘 확인 A_TickCount
gameHwnd := 0

W := 280  ; 창 안쪽 너비
g := Gui("+AlwaysOnTop", APP_TITLE)
g.MarginX := 12
g.MarginY := 10
g.SetFont("s9", "맑은 고딕")

; 맨 위 띠: 동작 중(초록) / 쉬는 중(주황) / 꺼짐(회색)을 색으로 바로 알 수 있게
g.SetFont("s13 bold")
lblBanner := g.AddText("xm w" W " h40 Center 0x200 cWhite Background9E9E9E", "○ 꺼짐")  ; 0x200 = 세로 가운데
g.SetFont("s9 norm")
lblGame := g.AddText("xm y+6 w" W)

g.SetFont("bold")
g.AddGroupBox("xm y+8 w" W " h70 Section", "스페이스")
g.SetFont("norm")
g.AddText("xs+12 ys+24", "누르는 간격(초)")
edInterval := g.AddEdit("x+6 yp-3 w50", "1.5")
lblSpace := g.AddText("xs+12 ys+48 w" (W - 24) " cGray")

g.SetFont("bold")
g.AddGroupBox("xm ys+78 w" W " h70 Section", "AUTO 유지 (꺼지면 T로 다시 켜기)")
g.SetFont("norm")
chkAuto := g.AddCheckbox("xs+12 ys+24 Checked", "사용")
g.AddText("x+16 yp", "확인 간격(초)")
edAutoInterval := g.AddEdit("x+6 yp-3 w50", "5")
lblAuto := g.AddText("xs+12 ys+48 w" (W - 24) " cGray")

g.SetFont("bold")
g.AddGroupBox("xm ys+78 w" W " h88 Section", "자동 문파 도움 (아이콘이 뜨면 클릭)")
g.SetFont("norm")
chkIcon := g.AddCheckbox("xs+12 ys+24 Checked", "사용")
g.AddText("x+16 yp", "확인 간격(초)")
edIconInterval := g.AddEdit("x+6 yp-3 w50", "5")
lblIcon := g.AddText("xs+12 ys+48 w" (W - 24) " cGray")
g.AddText("xs+12 ys+66 w" (W - 24) " cGray", "※ 누를 때 마우스 커서가 잠깐 튈 수 있어요")

chkBg := g.AddCheckbox("xm ys+98 Checked", "백그라운드 (게임 창이 뒤에 있어도 동작)")
chkTop := g.AddCheckbox("xm y+6 Checked", "항상 위")
chkTop.OnEvent("Click", (*) => g.Opt((chkTop.Value ? "+" : "-") "AlwaysOnTop"))

g.SetFont("s12 bold")
btn := g.AddButton("xm y+10 w" W " h44", "켜기")
btn.OnEvent("Click", ToggleFromButton)
g.SetFont("s9 norm")
g.AddButton("xm w" W, "종료").OnEvent("Click", (*) => ExitApp())
g.AddText("xm w" W " Center cGray", "F8 = 켜기/끄기, F10 = 종료")
g.AddText("xm y+8 w" (W - 90) " Section cGray", "v" APP_VERSION)
g.AddButton("x+0 ys-4 w90 h22", "업데이트 확인").OnEvent("Click", (*) => CheckForUpdate(ShowUpdateStatus, ResumeArgs))
lblUpdate := g.AddText("xm w" W " cGray")
g.OnEvent("Close", (*) => ExitApp())

; 업데이트로 다시 켜졌으면 예전 설정과 켜짐 상태를 이어 간다 (ResumeArgs 가 만든 인자)
resumeOn := false
if A_Args.Length = 9 && A_Args[1] = "--resume" {
    edInterval.Value := A_Args[3]
    chkAuto.Value := A_Args[4]
    edAutoInterval.Value := A_Args[5]
    chkIcon.Value := A_Args[6]
    edIconInterval.Value := A_Args[7]
    chkBg.Value := A_Args[8]
    chkTop.Value := A_Args[9]
    g.Opt((chkTop.Value ? "+" : "-") "AlwaysOnTop")
    resumeOn := A_Args[2] = "1"
}

Refresh()  ; 간격 칸 값을 변수로 읽어 들인다
g.Show()
SetTimer Refresh, 200

; 게임이 일반 권한 프로그램의 창 메시지를 막아서, 관리자 권한이 아니면 키도 클릭도 안 들어간다
if !A_IsAdmin {
    msg := "관리자 권한으로 실행해 주세요.`n일반 권한으로는 게임에 스페이스·T·클릭이 들어가지 않아요.`n`n지금 관리자 권한으로 다시 켤까요?"
    if MsgBox(msg, APP_TITLE, "YesNo Icon! Owner" g.Hwnd) = "Yes" {
        args := ""
        for a in A_Args
            args .= " " a
        try {
            Run '*RunAs "' A_ScriptFullPath '"' args
            ExitApp
        }
        ; 권한 창에서 [아니요]를 누르면 여기로 와서 일반 권한으로 계속한다
    }
}
if resumeOn {
    gameHwnd := FindGame()
    SetOn(true)
}

UPDATE_EVERY_MIN := 30
CleanupUpdateFiles()
SetTimer CleanupUpdateFiles, -5000          ; 방금 끝난 예전 exe 가 아직 안 닫혔을 수 있다
SetTimer () => CheckForUpdate(ShowUpdateStatus, ResumeArgs), -1500  ; 창이 뜬 뒤에 확인
SetTimer () => CheckForUpdate(ShowUpdateStatus, ResumeArgs), UPDATE_EVERY_MIN * 60000

F8:: {
    SetOn(!isOn)
    KeyWait "F8"  ; 꾹 누르고 있어도 한 번만 토글
}
F10::ExitApp

SetOn(value) {
    global isOn, count, spaceNote, lastSpace, autoStatus, autoFixed, iconStatus, iconClicked
    isOn := value
    autoStatus := ""
    iconStatus := ""
    if value {
        count := 0
        spaceNote := ""
        lastSpace := 0
        autoFixed := 0
        iconClicked := 0
        SetTimer Worker, Round(interval * 1000)
        StartTimer("auto")
        StartTimer("icon")
    } else {
        SetTimer Worker, 0
        SetTimer AutoWorker, 0
        SetTimer IconWorker, 0
    }
}

; 확인 타이머("auto" / "icon")를 (다시) 걸고, 화면에 "다음 확인 n초 후"를 보여 줄 수 있게 예정 시각을 적어 둔다
StartTimer(which) {
    global nextAuto, nextIcon
    if which = "auto" {
        ms := Round(autoInterval * 1000)
        SetTimer AutoWorker, ms
        nextAuto := A_TickCount + ms
    } else {
        ms := Round(iconInterval * 1000)
        SetTimer IconWorker, ms
        nextIcon := A_TickCount + ms
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
    global gameHwnd, count, spaceNote, lastSpace
    Critical  ; AutoWorker 의 T 누르기, IconWorker 의 클릭과 섞이지 않게
    if !gameHwnd || !WinExist("ahk_id " gameHwnd) {
        gameHwnd := FindGame()
        if !gameHwnd {
            spaceNote := "게임 창을 찾는 중"
            return
        }
    }
    if !WinActive("ahk_id " gameHwnd) {
        if !chkBg.Value {
            spaceNote := "쉬는 중 (게임 창이 맨 앞이 아님)"
            return
        }
        ok := PostKey(gameHwnd, 0x20, 0x39, 0x20)
        spaceNote := ok ? "" : "전송 실패 (관리자 권한 필요?)"
    } else {
        ok := PressKey(0x39)
        if !ok {
            SetOn(false)
            spaceNote := "키를 보낼 권한 없음 → 관리자 권한으로 실행"
            return
        }
        spaceNote := ""
    }
    if ok {
        count += 1
        lastSpace := A_TickCount
    }
}

; AUTO 확인과 아이콘 누르기를 지금 해도 되는지: 되면 "", 안 되면 쉬는 이유
WaitReason() {
    if !gameHwnd || !WinExist("ahk_id " gameHwnd)
        return "게임 창을 찾는 중"  ; 게임 창은 Worker 가 찾는다
    if !chkBg.Value && !WinActive("ahk_id " gameHwnd)
        return "쉬는 중 (게임 창이 맨 앞이 아님)"
    return ""
}

; AUTO(T) 버튼이 꺼져 있으면 T를 눌러 다시 켠다
AutoWorker() {
    global autoStatus, autoFixed, nextAuto
    Critical
    nextAuto := A_TickCount + Round(autoInterval * 1000)
    if !chkAuto.Value {
        autoStatus := ""
        return
    }
    why := WaitReason()
    if why != "" {
        autoStatus := why
        return
    }
    st := CheckAuto(gameHwnd)
    if st = "off" {
        Sleep 700  ; 화면이 잠깐 바뀐 것일 수 있어 한 번 더 본다
        st := CheckAuto(gameHwnd)
    }
    if st = "on" {
        autoStatus := "켜져 있음"
    } else if st = "minimized" {
        autoStatus := "게임 창이 최소화돼서 확인 못 함"
    } else if st = "hidden" {
        autoStatus := "버튼이 가려져서 확인 못 함 (WGC 안 됨)"
    } else if st = "" {
        autoStatus := "버튼을 못 찾음 (메뉴·로딩 중?)"
    } else {
        ; 확인하는 사이 게임 창이 앞/뒤로 바뀌었을 수 있어 다시 본다
        if WinActive("ahk_id " gameHwnd)
            ok := PressKey(0x14)
        else
            ok := PostKey(gameHwnd, 0x54, 0x14, 0x74)  ; VK_T, 스캔코드 0x14, 't'
        if ok {
            autoFixed += 1
            autoStatus := "꺼져 있어서 다시 켬 (" autoFixed "회)"
        } else {
            autoStatus := "꺼져 있는데 T 전송 실패 (재시도)"
        }
    }
}

; 문파 도움 아이콘이 떠 있으면 마우스로 누른다 (PostClick: 게임 창이 뒤에 있어도 된다)
IconWorker() {
    global iconStatus, iconClicked, nextIcon
    Critical
    nextIcon := A_TickCount + Round(iconInterval * 1000)
    if !chkIcon.Value {
        iconStatus := ""
        return
    }
    why := WaitReason()
    if why != "" {
        iconStatus := why
        return
    }
    pos := FindIcon(gameHwnd)
    if IsObject(pos) {
        if PostClick(gameHwnd, pos.x, pos.y) {
            iconClicked += 1
            iconStatus := "떠 있어서 누름 (" iconClicked "회)"
        } else {
            iconStatus := "떠 있는데 못 누름 (재시도)"
        }
    } else if pos = "minimized" {
        iconStatus := "게임 창이 최소화돼서 확인 못 함"
    } else if pos = "hidden" {
        iconStatus := "자리가 가려져서 확인 못 함 (WGC 안 됨)"
    } else {
        iconStatus := "안 떠 있음 (" iconClicked "회 누름)"
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

; 같은 가짜 포커스 방식으로 클라이언트 좌표 (x, y)를 왼쪽 클릭한다
; 게임은 클릭 위치를 메시지가 아니라 프레임마다 읽는 실제 커서 위치로 정한다. 메시지만 보내면 커서가 있던 곳(땅)을 누른 것으로 친다.
; 그래서 실제 커서를 그 자리로 옮겼다가 약 0.05초 뒤 되돌린다. 게임 창이 다른 창에 가려져 있어도 된다.
; 이동/누름/뗌이 각각 다른 프레임에 처리돼야 해서 사이마다 15ms 쉰다. (우편 아이콘 시험: 15ms 15/15, 10ms 10/10, 한 번에 보내면 실패)
; AHK Sleep 은 15.6ms 단위라 Windows Sleep 을 1ms 해상도로 쓴다.
; 사용자가 마우스 버튼을 누르고 있으면(드래그 중) 커서를 뺏지 않고 다음 확인 때 다시 한다.
PostClick(hwnd, x, y) {
    target := "ahk_id " hwnd
    if GetKeyState("LButton", "P") || GetKeyState("RButton", "P")
        return false
    lp := (y << 16) | (x & 0xFFFF)
    pt := Buffer(8, 0)
    DllCall("GetCursorPos", "Ptr", pt)
    WinGetClientPos &gx, &gy, , , target
    ok := true
    DllCall("winmm\timeBeginPeriod", "UInt", 1)
    try {
        PostMessage WM_ACTIVATEAPP, 1, 0, , target
        PostMessage WM_ACTIVATE, 1, 0, , target
        PostMessage WM_SETFOCUS, 0, 0, , target
        Sleep 30
        DllCall("SetCursorPos", "Int", gx + x, "Int", gy + y)
        PostMessage WM_MOUSEMOVE, 0, lp, , target
        DllCall("Sleep", "UInt", 15)
        PostMessage WM_LBUTTONDOWN, 1, lp, , target  ; 1 = MK_LBUTTON
        DllCall("Sleep", "UInt", 15)
        PostMessage WM_LBUTTONUP, 0, lp, , target
        DllCall("Sleep", "UInt", 15)
    } catch {
        ok := false
    }
    DllCall("SetCursorPos", "Int", NumGet(pt, 0, "Int"), "Int", NumGet(pt, 4, "Int"))
    DllCall("winmm\timeEndPeriod", "UInt", 1)
    return ok
}

Refresh() {
    global interval, autoInterval, iconInterval
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
                StartTimer("auto")
        }
    }
    v := Trim(edIconInterval.Value)
    if IsNumber(v) {
        v := Max(2, v + 0)  ; 누른 뒤 아이콘이 사라질 시간을 준다
        if v != iconInterval {
            iconInterval := v
            if isOn
                StartTimer("icon")
        }
    }

    found := FindGame()
    if !A_IsAdmin
        SetText(lblGame, "관리자 권한이 아니에요 → 관리자로 실행하세요", "cRed")
    else if GAME = ""
        SetText(lblGame, "대상 창 설정(target.ahk)이 없어요", "cRed")
    else if found
        SetText(lblGame, "게임 창: 찾음", "cGreen")
    else
        SetText(lblGame, "게임 창: 없음 (게임을 켜 주세요)", "cRed")

    ; 맨 위 띠와 창 제목: 색만 봐도 켜졌는지 알 수 있게
    if !isOn {
        SetBanner("○ 꺼짐", "9E9E9E")
    } else if !found {
        SetBanner("● 켜짐 - 게임 창을 찾는 중", "EF6C00")
    } else if !chkBg.Value && !WinActive("ahk_id " found) {
        SetBanner("● 켜짐 - 쉬는 중", "EF6C00")
    } else {
        SetBanner("● 동작 중", "2E7D32")
    }
    title := isOn ? APP_TITLE " - 동작 중" : APP_TITLE
    if g.Title != title
        g.Title := title

    text := count "회 누름"
    if spaceNote != ""
        text := spaceNote " · " text
    else if isOn && lastSpace
        text .= " · 마지막 " Format("{:.1f}", (A_TickCount - lastSpace) / 1000) "초 전"
    SetText(lblSpace, text)
    SetText(lblAuto, CheckLine(chkAuto.Value, autoStatus, nextAuto))
    SetText(lblIcon, CheckLine(chkIcon.Value, iconStatus, nextIcon))
    SetText(btn, isOn ? "끄기" : "켜기")
}

; AUTO/아이콘 상자의 상태 줄: 마지막 확인 결과 + 다음 확인까지 남은 시간
CheckLine(enabled, text, next) {
    if !enabled
        return "사용 안 함"
    if !isOn
        return "멈춤"
    left := Max(0, Ceil((next - A_TickCount) / 1000))
    return (text = "" ? "확인 전" : text) " · " left "초 뒤 확인"
}

; 맨 위 띠의 글자와 바탕색 (바뀔 때만 다시 그린다)
SetBanner(text, color) {
    static lastColor := "9E9E9E"
    if lblBanner.Text != text
        lblBanner.Text := text
    if color != lastColor {
        lblBanner.Opt("+Background" color)
        lblBanner.Redraw()
        lastColor := color
    }
}

; 업데이트 뒤 새 exe 에 넘길 인자: --resume 켜짐 스페이스간격 AUTO사용 AUTO간격 문파사용 문파간격 백그라운드 항상위
ResumeArgs() {
    return "--resume " (isOn ? 1 : 0) " " interval " " chkAuto.Value " " autoInterval " "
        . chkIcon.Value " " iconInterval " " chkBg.Value " " chkTop.Value
}

; 업데이트 확인 결과를 버튼 아래 줄에 보여 준다 (Update.ahk 가 부른다)
ShowUpdateStatus(text) {
    SetText(lblUpdate, text)
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
