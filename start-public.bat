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
    start "潮汕HTTP" /min python server\server.py
    timeout /t 3 >nul
    echo [OK] HTTP 服务已启动
) else (
    echo [OK] HTTP 服务已运行
)

:: 2. Check qrcode package
echo [*] 检查 qrcode 包...
python -c "import qrcode" 2>nul
if errorlevel 1 (
    echo [!] qrcode 包未安装，正在安装...
    pip install qrcode Pillow -q
    if errorlevel 1 (
        echo [X] 安装失败，请手动执行: pip install qrcode Pillow
        pause
        exit /b 1
    )
)
echo [OK] qrcode 已就绪

:: 3. Start tunnel
echo.
echo [*] 启动公网隧道 (localhost.run)...
echo ================================================
echo.
echo   隧道启动后会自动生成二维码: qrcode-public.png
echo   手机微信扫码即可进入游戏
echo.
echo   注意: 隧道断开后会自动重连
echo         但URL会变化，需重新分发二维码
echo.
echo   按 Ctrl+C 可停止服务
echo ================================================
echo.

:loop
echo [%time%] 正在建立隧道连接...

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o ServerAliveInterval=30 -o ExitOnForwardFailure=yes -R 80:localhost:8080 nokey@localhost.run 2>&1 | python -c "
import sys, re, os, datetime
# CWD inherited from batch's cd /d
url = None
for line in sys.stdin:
    sys.stdout.write(line)
    sys.stdout.flush()
    if not url:
        m = re.search(r'https://([a-z0-9]+\.lhr\.life)', line)
        if m:
            url = m.group(0)
            try:
                import qrcode
                img = qrcode.make(url)
                img.save('qrcode-public.png')
                print('')
                print('=' * 48)
                print('  公网地址: ' + url)
                print('  生成时间: ' + datetime.datetime.now().strftime('%%H:%%M:%%S'))
                print('  QR码已保存: qrcode-public.png')
                print('  请将 qrcode-public.png 发到微信群')
                print('  手机微信扫码即可进入游戏!')
                print('=' * 48)
                print('')
            except ImportError:
                print('[!] qrcode 包未安装，无法生成二维码')
                print('    公网地址: ' + url)
"

echo.
echo [!] 隧道连接断开 (%time%)
echo ================================================
echo   5秒后自动重连...
echo   注意: 新URL会不同，需重新生成和分发二维码
echo   如需停止, 请按 Ctrl+C 然后关闭窗口
echo ================================================
timeout /t 5 >nul
goto loop
