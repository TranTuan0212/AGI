@echo off
title Push Card Game Engine to GitHub
cd /d "%~dp0"
echo ========================================================
echo   DANG DAY MA NGUON LEN GITHUB (TranTuan0212/AGI)
echo ========================================================
echo.
git push -u origin main
echo.
if %ERRORLEVEL% EQU 0 (
    echo ========================================================
    echo   [THANH CONG] Da day toan bo ma nguon len GitHub!
    echo ========================================================
) else (
    echo ========================================================
    echo   [CHUYEN TIENG] Neu co loi, kiem tra lai quyen truy cap.
    echo ========================================================
)
echo.
pause
