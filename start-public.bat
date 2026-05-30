@echo off
title 潮汕奇遇记 - 公网版
echo ========================================
echo   潮汕奇遇记  公网版
echo   汕头 ^& 南澳岛 3天2夜之旅
echo ========================================
echo.

cd /d "%~dp0"

:: Check Python
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [X] 未找到 Python！请先安装 Python
    pause
    exit /b
)
echo [OK] Python 就绪

:: Check qrcode
python -c "import qrcode" >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] 正在安装 qrcode...
    pip install qrcode Pillow -q
    if %errorlevel% neq 0 (
        echo [X] qrcode 安装失败！请手动执行: pip install qrcode Pillow
        pause
        exit /b
    )
)
echo [OK] qrcode 就绪

:: Start HTTP server
echo [*] 启动 HTTP 服务...
start "潮汕HTTP" /min cmd /c "cd /d \"%~dp0\" && python server\server.py"
timeout /t 3 >nul

:: Verify
powershell -Command "try{$r=Invoke-WebRequest -Uri http://localhost:8080 -TimeoutSec 3 -UseBasicParsing;exit 0}catch{exit 1}" >nul 2>&1
if %errorlevel% neq 0 (
    echo [X] HTTP 服务启动失败！
    echo    请先手动运行 python server\server.py 检查错误
    pause
    exit /b
)
echo [OK] HTTP 服务运行中 :8080

:: Tunnel
echo.
echo ========================================
echo   启动公网隧道，连通后自动生成 QR 码
echo   按 Ctrl+C 停止
echo ========================================
echo.

:loop
echo [%time%] 建立隧道连接...
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o ServerAliveInterval=30 -o ExitOnForwardFailure=yes -R 80:localhost:8080 nokey@localhost.run 2>&1 | python server\tunnel_qr.py

echo.
echo [!] 隧道断开 (%time%)，5秒后重连...
timeout /t 5 >nul
goto loop
