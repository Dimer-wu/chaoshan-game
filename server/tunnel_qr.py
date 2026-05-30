"""读取 SSH 隧道输出，提取 URL 并生成 QR 码"""
import sys
import re
import os
from datetime import datetime

os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

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
                qrcode.make(url).save('qrcode-public.png')
                print('')
                print('=' * 48)
                print(f'  公网地址: {url}')
                print(f'  生成时间: {datetime.now().strftime("%H:%M:%S")}')
                print('  QR码已保存: qrcode-public.png')
                print('  请将 qrcode-public.png 发到微信群')
                print('  手机微信扫码即可进入游戏!')
                print('=' * 48)
                print('')
            except ImportError:
                print('[!] qrcode 包未安装')
                print(f'    公网地址: {url}')
