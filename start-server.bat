@echo off
chcp 65001 >nul
echo ========================================
echo   潮汕奇遇记 - 游戏服务启动
echo   汕头 ^& 南澳岛 3天2夜之旅
echo ========================================
echo.
cd /d "%~dp0"

python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [X] 未找到 Python，请安装 Python 后重试
    pause
    exit /b 1
)

echo [OK] Python 已就绪
echo.

:: Detect LAN IP
set LAN_IP=
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4"') do (
    set "IP=%%a"
    set "IP=!IP: =!"
    if not defined LAN_IP set LAN_IP=!IP!
)
setlocal enabledelayedexpansion

if not defined LAN_IP (
    echo [!] 未检测到局域网IP，使用 localhost
    set LAN_IP=localhost
)

:: Generate LAN QR code
echo [*] 生成局域网二维码...
python -c "import qrcode; qrcode.make('http://!LAN_IP!:8080').save('qrcode-local.png'); print('QR码已保存: qrcode-local.png')" 2>nul
if %errorlevel% equ 0 (
    echo [OK] 二维码已生成: qrcode-local.png
) else (
    echo [!] 二维码生成失败，请手动安装: pip install qrcode Pillow
)

echo.
echo ========================================
echo   手机连接同一WiFi后:
echo     方法1: 微信扫描 qrcode-local.png
echo     方法2: 浏览器访问
echo               http:!LAN_IP!::8080
echo.
echo   按 Ctrl+C 停止服务
echo ========================================
echo.

python server\server.py
if %errorlevel% neq 0 (
    echo [!] WebSocket 服务端启动失败，使用简易 HTTP 服务...
    python -c "import http.server; import socketserver; handler=http.server.SimpleHTTPRequestHandler; handler.extensions_map['']='text/html'; handler.extensions_map['.html']='text/html'; handler.extensions_map['.js']='application/javascript'; handler.extensions_map['.css']='text/css'; handler.extensions_map['.json']='application/json'; httpd=socketserver.TCPServer(('0.0.0.0',8080),handler); print('HTTP 服务已启动在 0.0.0.0:8080'); httpd.serve_forever()"
)
endlocal
