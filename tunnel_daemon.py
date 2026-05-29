"""
SSH tunnel daemon - keeps a public tunnel alive via localhost.run
"""
import subprocess
import sys
import time
import re

SSH_CMD = [
    'ssh', '-o', 'StrictHostKeyChecking=no',
    '-o', 'UserKnownHostsFile=/dev/null',
    '-o', 'ServerAliveInterval=30',
    '-o', 'ExitOnForwardFailure=yes',
    '-R', '80:localhost:8080',
    'nokey@localhost.run'
]

def run_tunnel():
    proc = subprocess.Popen(
        SSH_CMD,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True
    )
    url = None
    for line in proc.stdout:
        sys.stdout.write(line)
        sys.stdout.flush()
        m = re.search(r'https://([a-z0-9]+\.lhr\.life)', line)
        if m:
            url = m.group(0)
            print(f'\n=== PUBLIC URL: {url} ===\n', flush=True)
    proc.wait()
    return url

if __name__ == '__main__':
    print('Starting SSH tunnel daemon...', flush=True)
    while True:
        url = run_tunnel()
        print(f'Tunnel disconnected. Reconnecting in 5s...', flush=True)
        time.sleep(5)
