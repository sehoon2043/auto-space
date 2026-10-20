; GitHub Releases 로 자동 업데이트한다. (자동스페이스.ahk 에서 #Include)
; 릴리스.bat 이 릴리스마다 AutoSpace.exe, wincapture.dll, latest.txt 를 올린다.
; latest.txt 한 줄에 하나씩:  version=1.0.1 / AutoSpace.exe=<sha256> / wincapture.dll=<sha256> / notes=바뀐 점
; 받은 파일은 latest.txt 의 SHA-256 과 같을 때만 쓴다.
; 실행 중인 exe 와 불러온 dll 은 덮어쓸 수 없지만 이름은 바꿀 수 있어서,
; 지금 파일을 *.old 로 바꾸고 새 파일을 그 자리에 둔 뒤 새 exe 를 실행하고 끝낸다. *.old 는 다음 실행 때 지운다.

UPDATE_REPO := "sehoon2043/auto-space"
UPDATE_EXE_ASSET := "AutoSpace.exe"

; 최신 버전을 확인하고, 새 버전이 있으면 물어본 뒤 업데이트한다. silent 면 문제없을 때 아무 말도 안 한다.
CheckForUpdate(silent := false) {
    try {
        text := StrGet(HttpGet("https://github.com/" UPDATE_REPO "/releases/latest/download/latest.txt"), "UTF-8")
        m := ParseManifest(text)
    } catch as e {
        if !silent
            MsgBox "업데이트 정보를 못 받았어요.`n" e.Message, "자동 스페이스", "Icon!"
        return
    }
    if CompareVersion(m["version"], APP_VERSION) <= 0 {
        if !silent
            MsgBox "최신 버전이에요. (v" APP_VERSION ")", "자동 스페이스", "Iconi"
        return
    }
    msg := "새 버전 v" m["version"] " 이 있어요. (지금 v" APP_VERSION ")`n"
    if m.Has("notes") && m["notes"] != ""
        msg .= "`n" m["notes"] "`n"
    msg .= "`n지금 업데이트할까요? 매크로가 다시 시작돼요."
    if MsgBox(msg, "자동 스페이스 업데이트", "YesNo Iconi") != "Yes"
        return
    if !A_IsCompiled {
        MsgBox "스크립트(.ahk)로 실행 중이라 자동 교체는 안 해요. exe 로 실행하면 돼요.", "자동 스페이스", "Icon!"
        return
    }
    try {
        ApplyUpdate(m)
    } catch as e {
        MsgBox "업데이트 실패 - 지금 버전을 그대로 써요.`n" e.Message, "자동 스페이스", "Icon!"
        return
    }
    Run '"' A_ScriptFullPath '"'
    ExitApp
}

; 바뀐 파일만 받아서 해시를 확인하고 바꿔 끼운다. 중간에 실패하면 원래 파일로 되돌리고 예외를 던진다.
; base/files 는 테스트용 (기본: 그 버전의 GitHub 릴리스, [릴리스 파일 이름, 바꿀 파일 경로])
ApplyUpdate(m, base := "", files := "") {
    if base = ""
        base := "https://github.com/" UPDATE_REPO "/releases/download/v" m["version"] "/"
    if files = ""
        files := [[UPDATE_EXE_ASSET, A_ScriptFullPath], ["wincapture.dll", A_ScriptDir "\wincapture.dll"]]
    staged := []
    for f in files {
        want := m.Has(f[1]) ? StrLower(m[f[1]]) : ""
        if want = ""
            throw Error("latest.txt 에 " f[1] " 해시가 없어요")
        if FileExist(f[2]) && Sha256(FileRead(f[2], "RAW")) = want
            continue  ; 이미 같은 파일
        data := HttpGet(base f[1], 60000)
        if Sha256(data) != want
            throw Error(f[1] " 해시가 달라요 (받다가 깨졌거나 다른 파일)")
        tmp := f[2] ".new"
        FileOpen(tmp, "w").RawWrite(data)
        staged.Push({target: f[2], tmp: tmp, moved: false, placed: false})
    }
    try {
        for s in staged {
            if FileExist(s.target) {
                FileMove s.target, s.target ".old", true
                s.moved := true
            }
            FileMove s.tmp, s.target
            s.placed := true
        }
    } catch as e {
        for s in staged {
            if s.placed
                try FileDelete s.target
            if s.moved
                try FileMove s.target ".old", s.target, true
            try FileDelete s.tmp
        }
        throw e
    }
}

; 지난 업데이트가 남긴 *.old / *.new 를 지운다. 방금 끝난 예전 exe 가 아직 살아 있으면 못 지우니 나중에 한 번 더 부른다.
CleanupUpdateFiles() {
    loop files A_ScriptDir "\*.old"
        try FileDelete A_LoopFileFullPath
    loop files A_ScriptDir "\*.new"
        try FileDelete A_LoopFileFullPath
}

; "key=value" 줄들을 Map 으로. 빈 줄과 # 줄은 건너뛴다. notes 의 \n 은 줄바꿈.
ParseManifest(text) {
    m := Map()
    loop parse text, "`n", "`r" {
        line := Trim(A_LoopField)
        if line = "" || SubStr(line, 1, 1) = "#"
            continue
        p := InStr(line, "=")
        if !p
            continue
        m[Trim(SubStr(line, 1, p - 1))] := Trim(SubStr(line, p + 1))
    }
    if !m.Has("version") || !RegExMatch(m["version"], "^\d+(\.\d+)*$")
        throw Error("latest.txt 에 올바른 version 이 없어요")
    if m.Has("notes")
        m["notes"] := StrReplace(m["notes"], "\n", "`n")
    return m
}

; 1.2.10 > 1.2.9 처럼 숫자로 비교한다. a 가 크면 1, 같으면 0, 작으면 -1
CompareVersion(a, b) {
    pa := StrSplit(a, "."), pb := StrSplit(b, ".")
    loop Max(pa.Length, pb.Length) {
        x := A_Index <= pa.Length ? Integer(pa[A_Index]) : 0
        y := A_Index <= pb.Length ? Integer(pb[A_Index]) : 0
        if x != y
            return x > y ? 1 : -1
    }
    return 0
}

; GET 해서 본문을 Buffer 로. 200 이 아니면 예외. (리다이렉트는 WinHttp 가 따라간다)
HttpGet(url, timeout := 8000) {
    req := ComObject("WinHttp.WinHttpRequest.5.1")
    req.SetTimeouts(timeout, timeout, timeout, timeout)
    req.Open("GET", url, false)
    req.SetRequestHeader("User-Agent", "AutoSpace/" APP_VERSION)
    req.SetRequestHeader("Cache-Control", "no-cache")
    req.Send()
    if req.Status != 200
        throw Error("HTTP " req.Status " - " url)
    body := req.ResponseBody  ; VT_ARRAY|VT_UI1
    n := body.MaxIndex() + 1
    buf := Buffer(n)
    if n > 0
        DllCall("RtlMoveMemory", "Ptr", buf, "Ptr", NumGet(ComObjValue(body), 8 + A_PtrSize, "Ptr"), "UPtr", n)  ; SAFEARRAY.pvData
    return buf
}

; Buffer 의 SHA-256 (소문자 16진수)
Sha256(buf) {
    alg := 0
    if DllCall("bcrypt\BCryptOpenAlgorithmProvider", "Ptr*", &alg, "WStr", "SHA256", "Ptr", 0, "UInt", 0, "UInt")
        throw Error("SHA-256 을 못 열었어요")
    out := Buffer(32)
    st := DllCall("bcrypt\BCryptHash", "Ptr", alg, "Ptr", 0, "UInt", 0, "Ptr", buf, "UInt", buf.Size, "Ptr", out, "UInt", 32, "UInt")
    DllCall("bcrypt\BCryptCloseAlgorithmProvider", "Ptr", alg, "UInt", 0)
    if st
        throw Error("SHA-256 계산 실패")
    hex := ""
    loop 32
        hex .= Format("{:02x}", NumGet(out, A_Index - 1, "UChar"))
    return hex
}
