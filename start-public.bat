@echo off
chcp 65001 >nul
cd /d "%~dp0"
title 潮汕奇遇记 - 公网隧道

echo.
echo ========================================
echo       潮汕奇遇记
echo       汕头 ^& 南澳岛 3天2夜之旅
echo       公网版
echo ========================================
echo.

:: 1. Check if HTTP server is running
echo [*] 检查 HTTP 服务...
powershell -Command "try{$r=Invoke-WebRequest -Uri http://localhost:8080 -TimeoutSec 3 -UseBasicParsing;exit 0}catch{exit 1}" >nul 2>&1
if errorlevel 1 (
    echo [!] HTTP 服务未启动，正在启动...
    start "潮汕HTTP" /min python -c "import http.server,socketserver,os;os.chdir(r'%~dp0');h=http.server.SimpleHTTPRequestHandler;h.extensions_map['']='text/html';h.extensions_map['.html']='text/html';h.extensions_map['.js']='application/javascript';s=socketserver.TCPServer(('0.0.0.0',8080),h);print('HTTP 服务启动成功');s.serve_forever()"
    timeout /t 3 >nul
    echo [OK] HTTP 服务已启动
) else (
    echo [OK] HTTP 服务已运行
)

:: 2. Generate QR code when tunnel connects
echo.
echo [*] 启动公网隧道 (localhost.run)...
echo ================================================
echo.
echo   隧道启动后会自动生成二维码: qrcode-public.png
echo   手机扫码即可进入游戏
echo.
echo   按 Ctrl+C 可停止服务
echo ================================================
echo.

:loop
echo [%time%] 正在建立隧道连接...

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o ServerAliveInterval=30 -o ExitOnForwardFailure=yes -R 80:localhost:8080 nokey@localhost.run 2>&1 | python -c "
import sys, re, os
os.chdir(r'%~dp0')
url = None
for line in sys.stdin:
    sys.stdout.write(line)
    sys.stdout.flush()
    if not url:
        m = re.search(r'https://([a-z0-9]+\.lhr\.life)', line)
        if m:
            url = m.group(0)
            import qrcode
            qrcode.make(url).save('qrcode-public.png')
            print('')
            print('=' * 48)
            print('  公网地址: ' + url)
            print('  QR码已保存: qrcode-public.png')
            print('  手机扫描二维码即可进入游戏!')
            print('=' * 48)
            print('')
"

echo.
echo [!] 隧道连接断开 (%time%)
echo ================================================
echo   5秒后自动重连...
echo   如需停止, 请按 Ctrl+C 然后关闭窗口
echo ================================================
timeout /t 5 >nul
goto loop
