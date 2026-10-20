@echo off
chcp 65001 > nul
cd /d "%~dp0"
"C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe" /in "자동스페이스.ahk" /out "자동스페이스.exe" /base "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
echo 빌드 완료: 자동스페이스.exe
pause
