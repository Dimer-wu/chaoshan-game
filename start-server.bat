@echo off
chcp 65001 >nul
echo ========================================
echo   潮汕奇遇记 - 游戏服务启动
echo   汕头 ^& 南澳岛 3天2夜之旅
echo ========================================
echo.
cd /d "%~dp0"

REM Try Python first
python --version >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] 使用 Python 启动服务
    echo.
    echo 手机连接同一WiFi后访问:
    for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4"') do (
        set ip=%%a
        setlocal enabledelayedexpansion
        echo    http:!ip: =!::8080
        echo.
        echo 扫描游戏目录下的 qrcode-local.png 即可
        echo.
        echo 按 Ctrl+C 停止服务
        echo ========================================
        python -c "import http.server; import socketserver; handler=http.server.SimpleHTTPRequestHandler; handler.extensions_map['']='text/html'; handler.extensions_map['.html']='text/html'; handler.extensions_map['.js']='application/javascript'; handler.extensions_map['.css']='text/css'; handler.extensions_map['.json']='application/json'; httpd=socketserver.TCPServer(('0.0.0.0',8080),handler); print('服务已启动在 0.0.0.0:8080'); httpd.serve_forever()"
        endlocal
    )
) else (
    echo [!] 未找到 Python，尝试使用 Node.js...
    node --version >nul 2>&1
    if %errorlevel% equ 0 (
        cd server
        echo [OK] 使用 Node.js 启动服务
        node server.js
    ) else (
        echo [X] 未找到 Python 或 Node.js
        echo     请安装 Python 或 Node.js 后重试
        pause
    )
)
