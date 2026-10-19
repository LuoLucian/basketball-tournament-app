# -*- coding: utf-8 -*-
"""通用远程执行：上传本地脚本到服务器并以 sudo 执行。
用法: PW='密码' python remote_run.py <host> <user> <本地脚本> [脚本参数...]
"""
import os, sys, time, paramiko

host, user, local = sys.argv[1], sys.argv[2], sys.argv[3]
args = ' '.join(f'"{a}"' if ' ' in a else a for a in sys.argv[4:])
pw = os.environ['PW']
REMOTE = '/tmp/' + os.path.basename(local)

cli = paramiko.SSHClient()
cli.set_missing_host_key_policy(paramiko.AutoAddPolicy())
cli.connect(host, port=22, username=user, password=pw, timeout=20,
            allow_agent=False, look_for_keys=False)
sftp = cli.open_sftp(); sftp.put(local, REMOTE); sftp.close()
print(f'--> 已上传 {REMOTE}')

cmd = f"sudo -S -p '' bash {REMOTE} {args}".strip()
stdin, stdout, stderr = cli.exec_command(cmd, timeout=600, get_pty=True)
stdin.write(pw + '\n'); stdin.flush()

buf = ''
while True:
    if stdout.channel.recv_ready():
        chunk = stdout.channel.recv(4096).decode(errors='replace')
        buf += chunk
        sys.stdout.write(chunk); sys.stdout.flush()
    elif stdout.channel.exit_status_ready():
        while stdout.channel.recv_ready():
            chunk = stdout.channel.recv(65536).decode(errors='replace')
            buf += chunk; sys.stdout.write(chunk)
        break
    else:
        time.sleep(0.25)
rc = stdout.channel.recv_exit_status()
cli.close()
print(f'\n--> 退出码: {rc}')
sys.exit(0 if rc == 0 else 1)
