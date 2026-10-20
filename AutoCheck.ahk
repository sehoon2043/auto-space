; AUTO(T) 버튼이 켜져 있는지 화면 픽셀로 판정한다. (자동스페이스.ahk 에서 #Include)
; 꺼짐 = 흰 글씨 "AUTO", 켜짐 = 주황 글씨 + 주황 동그라미 테두리.
; 기준 화면(클라이언트 1318x741)에서 버튼 중심은 오른쪽 아래 모서리에서 (139, 42) 떨어져 있다.
; 창 크기가 바뀌면 UI 배율이 높이를 따르는지 너비를 따르는지 몰라서 세 가지 배율(높이/너비/중간)을 모두 확인한다.

AUTO_REF_W := 1318, AUTO_REF_H := 741
AUTO_FROM_RIGHT := 139, AUTO_FROM_BOTTOM := 42
AUTO_RING := 18    ; 주황 테두리까지 들어가는 반지름 (기준 화면 픽셀)

; 꺼진 버튼의 "AU/TO" 글자 모양 (기준 화면 픽셀, 글자 중심은 버튼 중심에서 (+7, +1))
; # = 흰 글씨여야 하는 곳, . = 어두운 버튼 바탕이어야 하는 곳, 공백 = 안 봄
; 버튼이 안 보일 때(메뉴·로딩·연출) 밝은 바닥이나 흰 글씨를 꺼짐으로 착각해서 T를 누르는 일을 막는다.
AUTO_OFF_SHAPE := [
    "..................."
  , "....   ...  ...  .."
  , "... ###...##...##.."
  , "...#### ..##...##.."
  , "...##.##..##...##.."
  , ".. ##.##..##...##.."
  , "..###### .##...##.."
  , "..#######.##.  ##.."
  , ". ##...##.#######.."
  , ".   ...  ..      .."
  , "..................."
  , ". ####### #######.."
  , ". #######.#######.."
  , "....## ...##...##.."
  , "....## ...##...##.."
  , "....## ...##...##.."
  , "....## ...##...##.."
  , "....## ...#######.."
  , "....## ... ######.."
  , "..................."
]

; 클라이언트 크기(w, h)에서 버튼 중심이 있을 만한 곳 목록 [{x, y, s}] (클라이언트 좌표)
AutoCandidates(w, h) {
    sH := h / AUTO_REF_H, sW := w / AUTO_REF_W
    list := []
    for s in [sH, sW, Sqrt(sH * sW)] {
        dup := false
        for c in list
            if Abs(c.s - s) < 0.02
                dup := true
        if !dup
            list.Push({x: Round(w - AUTO_FROM_RIGHT * s), y: Round(h - AUTO_FROM_BOTTOM * s), s: s})
    }
    return list
}

; 후보들을 모두 덮는 사각형 {x, y, w, h} (클라이언트 좌표) - 이만큼만 캡처하면 된다
; ring = 후보 중심에서 볼 반지름 (기준 화면 픽셀)
AutoBounds(cands, ring := AUTO_RING) {
    x1 := 99999, y1 := 99999, x2 := -99999, y2 := -99999
    for c in cands {
        r := Ceil(ring * c.s) + 1
        x1 := Min(x1, c.x - r), y1 := Min(y1, c.y - r)
        x2 := Max(x2, c.x + r), y2 := Max(y2, c.y + r)
    }
    return {x: x1, y: y1, w: x2 - x1 + 1, h: y2 - y1 + 1}
}

; 한 후보 위치를 판정: "on" / "off" / "" (AUTO 버튼으로 안 보임)
AutoClassify(img, cx, cy, s) {
    r := Round(AUTO_RING * s), warm := 0, n := 0
    loop 2 * r + 1 {
        y := cy - r + A_Index - 1
        loop 2 * r + 1 {
            n += 1
            if IsWarm(ImgPixel(img, cx - r + A_Index - 1, y))
                warm += 1
        }
    }
    if warm >= n * 0.12
        return "on"
    if warm > n * 0.03
        return ""
    if MatchShape(img, cx + Round(7 * s), cy + Round(s), s, AUTO_OFF_SHAPE, IsDark)
        return "off"
    return ""
}

; (lx, ly)를 틀(rows) 중심으로 놓고 맞춰 본다. 위치가 1~2픽셀 어긋나도 되게 주변도 본다.
; 흰 글씨 자리 70% 이상이 밝고, 바탕 자리 85% 이상이 isBg 여야 맞은 것으로 본다.
MatchShape(img, lx, ly, s, rows, isBg) {
    j := Max(2, Round(2 * s))
    for phase in [[0, 0], [0.5, 0], [0, 0.5], [0.5, 0.5]] {  ; 반 픽셀 어긋남
        shape := ShapeAt(rows, s, phase)
        if !shape.light.Length || !shape.dark.Length
            continue
        loop 2 * j + 1 {
            oy := ly - j + A_Index - 1
            loop 2 * j + 1 {
                ox := lx - j + A_Index - 1
                hit := 0
                for p in shape.light
                    if IsLight(ImgPixel(img, ox + p[1], oy + p[2]))
                        hit += 1
                if hit < shape.light.Length * 0.7
                    continue
                hit := 0
                for p in shape.dark
                    if isBg(ImgPixel(img, ox + p[1], oy + p[2]))
                        hit += 1
                if hit >= shape.dark.Length * 0.85
                    return true
            }
        }
    }
    return false
}

; 틀(rows)을 배율 s로 줄이거나 키운 픽셀 목록 {light, dark} (틀 중심 기준 [u, v])
; 화면 픽셀 하나가 덮는 틀 칸들을 4x4로 훑어서, 3/4 이상이 # 이면 밝아야 할 곳, 전부 . 이면 바탕이어야 할 곳.
; 창이 작아지면 2픽셀 굵기 글씨가 1픽셀대로 뭉개지므로 틀도 같이 줄여야 맞는다.
ShapeAt(rows, s, phase) {
    static cache := Map()
    key := ObjPtr(rows) "|" Round(s, 3) "|" phase[1] "|" phase[2]
    if cache.Has(key)
        return cache[key]
    light := [], dark := []
    r := Ceil(Max(rows.Length, StrLen(rows[1])) / 2 * s) + 1
    loop 2 * r + 1 {
        v := A_Index - 1 - r
        loop 2 * r + 1 {
            u := A_Index - 1 - r
            n := 0, nl := 0, nd := 0
            loop 4 {
                ty := Floor((v + phase[2] - 0.5 + (A_Index - 0.5) / 4) / s + 0.5)
                loop 4 {
                    tx := Floor((u + phase[1] - 0.5 + (A_Index - 0.5) / 4) / s + 0.5)
                    ch := ShapeCell(rows, tx, ty)
                    n += 1
                    if ch = "#"
                        nl += 1
                    else if ch = "."
                        nd += 1
                }
            }
            if nl >= n * 0.75
                light.Push([u, v])
            else if nd = n
                dark.Push([u, v])
        }
    }
    cache[key] := {light: light, dark: dark}
    return cache[key]
}

; 틀 중심에서 (dx, dy) 떨어진 칸 글자. 틀 밖은 " "(안 봄)
ShapeCell(rows, dx, dy) {
    row := dy + (rows.Length + 1) // 2, col := dx + (StrLen(rows[1]) + 1) // 2
    if row < 1 || row > rows.Length || col < 1 || col > StrLen(rows[row])
        return " "
    return SubStr(rows[row], col, 1)
}

; 후보 중 하나라도 켜짐이면 켜짐 (켜진 걸 꺼짐으로 잘못 보고 T를 눌러 끄는 일을 막는다)
AutoJudge(img, cands) {
    off := false
    for c in cands {
        st := AutoClassify(img, c.x, c.y, c.s)
        if st = "on"
            return "on"
        if st = "off"
            off := true
    }
    return off ? "off" : ""
}

IsWarm(c) {
    r := (c >> 16) & 0xFF, g := (c >> 8) & 0xFF, b := c & 0xFF
    return r >= 180 && g >= 90 && r - b >= 90
}

; 밝은 무채색 (창이 작아지면 글씨가 바탕과 섞여 회색이 되므로 120부터 본다)
IsLight(c) {
    r := (c >> 16) & 0xFF, g := (c >> 8) & 0xFF, b := c & 0xFF
    return Min(r, g, b) >= 120 && Max(r, g, b) - Min(r, g, b) <= 50
}

IsDark(c) {
    return Max((c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF) < 100
}

; img = {buf, w, h, x0, y0}: 32비트 BGRA 픽셀, (x0, y0)는 buf 왼쪽 위의 클라이언트 좌표
ImgPixel(img, x, y) {
    x -= img.x0, y -= img.y0
    if x < 0 || y < 0 || x >= img.w || y >= img.h
        return 0
    return NumGet(img.buf, (y * img.w + x) * 4, "UInt")
}

; 화면 사각형(스크린 좌표)을 그대로 복사한다. 다른 창에 가려진 부분은 그 창이 찍힌다.
CaptureScreen(sx, sy, w, h) {
    hdcScreen := DllCall("GetDC", "Ptr", 0, "Ptr")
    hdcMem := DllCall("CreateCompatibleDC", "Ptr", hdcScreen, "Ptr")
    bi := Buffer(40, 0)
    NumPut("UInt", 40, bi, 0)
    NumPut("Int", w, bi, 4)
    NumPut("Int", -h, bi, 8)       ; 위에서 아래 순서
    NumPut("UShort", 1, bi, 12)
    NumPut("UShort", 32, bi, 14)
    bits := 0
    hbm := DllCall("CreateDIBSection", "Ptr", hdcMem, "Ptr", bi, "UInt", 0, "Ptr*", &bits, "Ptr", 0, "UInt", 0, "Ptr")
    old := DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hbm, "Ptr")
    DllCall("BitBlt", "Ptr", hdcMem, "Int", 0, "Int", 0, "Int", w, "Int", h
        , "Ptr", hdcScreen, "Int", sx, "Int", sy, "UInt", 0x00CC0020)  ; SRCCOPY
    buf := Buffer(w * h * 4)
    DllCall("RtlMoveMemory", "Ptr", buf, "Ptr", bits, "UPtr", w * h * 4)
    DllCall("SelectObject", "Ptr", hdcMem, "Ptr", old)
    DllCall("DeleteObject", "Ptr", hbm)
    DllCall("DeleteDC", "Ptr", hdcMem)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)
    return {buf: buf, w: w, h: h}
}

; 가려진 게임 창도 찍을 수 있게 Windows Graphics Capture(WGC)를 먼저 쓴다. (PrintWindow는 게임이 막는다)
; thqby/ahk2_lib 의 wincapture.dll (MIT)을 이 스크립트(exe)와 같은 폴더에 둔다.
; DLL이 없거나 WGC가 실패하면 예전처럼 화면에 보이는 픽셀로 본다. 최소화된 창은 WGC로도 못 찍는다.
wgc := {dll: 0, failed: false, ptr: 0, hwnd: 0}

; 게임 클라이언트 영역 전체 프레임 {bits, pitch, w, h}. 못 찍으면 0
; 프레임은 다음 wgc_capture 전까지만 유효하다.
WgcCapture(hwnd) {
    if wgc.failed
        return 0
    if !wgc.dll {
        wgc.dll := DllCall("LoadLibrary", "Str", A_ScriptDir "\wincapture.dll", "Ptr")
        if !wgc.dll {
            wgc.failed := true
            return 0
        }
    }
    if wgc.ptr && wgc.hwnd != hwnd
        WgcFree()
    if !wgc.ptr {
        wgc.ptr := DllCall("wincapture\wgc_init_window", "Ptr", hwnd, "Int", 0, "Ptr")  ; 0 = 찍을 때만 프레임을 받는다
        if !wgc.ptr
            return 0
        wgc.hwnd := hwnd
        DllCall("wincapture\wgc_isBorderRequired", "Ptr", wgc.ptr, "Int", 0)  ; 노란 캡처 테두리 끄기
    }
    data := Buffer(32, 0)
    if DllCall("wincapture\wgc_capture", "Ptr", wgc.ptr, "Ptr", 1, "Ptr", data, "Int") != 0 {  ; 1 = 클라이언트 영역
        WgcFree()  ; 창이 새로 만들어졌을 수 있다 - 다음에 새로 연다
        return 0
    }
    return {bits: NumGet(data, 0, "Ptr"), pitch: NumGet(data, A_PtrSize, "UInt")
        , w: NumGet(data, A_PtrSize + 4, "Int"), h: NumGet(data, A_PtrSize + 8, "Int")}
}

WgcFree() {
    if wgc.ptr
        DllCall("wincapture\wgc_free", "Ptr", wgc.ptr)
    wgc.ptr := 0, wgc.hwnd := 0
}

; 프레임에서 사각형 b(클라이언트 좌표)만 잘라 img 로 복사한다
CopyFrame(f, b) {
    x1 := Max(0, b.x), y1 := Max(0, b.y)
    w := Min(f.w, b.x + b.w) - x1, h := Min(f.h, b.y + b.h) - y1
    if w <= 0 || h <= 0
        return {buf: Buffer(4), w: 0, h: 0, x0: 0, y0: 0}
    buf := Buffer(w * h * 4)
    loop h
        DllCall("RtlMoveMemory", "Ptr", buf.Ptr + (A_Index - 1) * w * 4
            , "Ptr", f.bits + (y1 + A_Index - 1) * f.pitch + x1 * 4, "UPtr", w * 4)
    return {buf: buf, w: w, h: h, x0: x1, y0: y1}
}

; 게임 창의 AUTO 버튼 상태: "on" / "off" / ""(버튼을 못 찾음) / "minimized"
; / "hidden"(WGC를 못 써서 화면으로 봤는데 버튼 자리가 다른 창에 가려짐)
CheckAuto(hwnd) {
    cap := CaptureAround(hwnd, AutoCandidates, AUTO_RING)
    if !IsObject(cap)
        return cap
    return AutoJudge(cap.img, cap.cands)
}

; 게임 창에서 후보 위치들(candsFn(w, h)) 주변 반지름 ring 만큼만 잘라 온다.
; {img, cands} 또는 "minimized" / "hidden"(WGC를 못 써서 화면으로 봤는데 그 자리가 다른 창에 가려짐)
CaptureAround(hwnd, candsFn, ring) {
    if DllCall("IsIconic", "Ptr", hwnd)
        return "minimized"
    WinGetClientPos &gx, &gy, &gw, &gh, "ahk_id " hwnd
    loop 2 {  ; 실패하거나 창 크기가 바뀐 직후면 세션을 새로 열어 한 번 더
        f := WgcCapture(hwnd)
        if !f
            continue
        if Abs(f.w - gw) > 2 || Abs(f.h - gh) > 2 {
            WgcFree()
            continue
        }
        cands := candsFn(f.w, f.h)
        img := CopyFrame(f, AutoBounds(cands, ring))
        ; wgc_releaseTexture 는 부르지 않는다. 다음 캡처가 같은 프레임이면 DLL 이 새로 복사하지 않고
        ; 지난 텍스처를 그대로 읽는데, 비워 두면 그 자리에서 0xc0000005 로 죽는다. (AUTO·문파 도움 확인이 연달아 찍을 때)
        return {img: img, cands: cands}
    }

    cands := candsFn(gw, gh)
    b := AutoBounds(cands, ring)
    ; 버튼 자리 네 귀퉁이와 가운데가 전부 게임 창이어야 화면 픽셀을 믿을 수 있다
    for p in [[b.x, b.y], [b.x + b.w - 1, b.y], [b.x, b.y + b.h - 1], [b.x + b.w - 1, b.y + b.h - 1]
            , [b.x + b.w // 2, b.y + b.h // 2]] {
        sx := gx + p[1], sy := gy + p[2]
        h := DllCall("WindowFromPoint", "Int64", (sy << 32) | (sx & 0xFFFFFFFF), "Ptr")
        if !h || DllCall("GetAncestor", "Ptr", h, "UInt", 2, "Ptr") != hwnd  ; GA_ROOT
            return "hidden"
    }
    img := CaptureScreen(gx + b.x, gy + b.y, b.w, b.h)
    img.x0 := b.x, img.y0 := b.y
    return {img: img, cands: cands}
}
