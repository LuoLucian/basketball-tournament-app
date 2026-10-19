# -*- coding: utf-8 -*-
"""远程配置香港中转服务器：上传 setup_server_v2.sh 并以 sudo 执行。
用法: PW='密码' python remote_setup.py <host> <user> <domain>
"""
import os, sys, time, paramiko

host = sys.argv[1]
user = sys.argv[2]
domain = sys.argv[3]
pw = os.environ['PW']
LOCAL = r'F:/项目/basketball-app/deploy-hk-proxy/setup_server_v2.sh'
REMOTE = '/tmp/setup_server_v2.sh'

cli = paramiko.SSHClient()
cli.set_missing_host_key_policy(paramiko.AutoAddPolicy())
print(f'--> 连接 {user}@{host}:22 ...')
cli.connect(host, port=22, username=user, password=pw, timeout=20,
            allow_agent=False, look_for_keys=False)
print('--> 已登录')

# 1) 基本信息与 sudo 能力
stdin, stdout, stderr = cli.exec_command('id; lsb_release -d 2>/dev/null; sudo -n true && echo SUDO_NOPASS || echo SUDO_NEED_PASS')
print(stdout.read().decode(errors='replace').strip())

# 2) 上传脚本
sftp = cli.open_sftp()
sftp.put(LOCAL, REMOTE)
sftp.close()
print(f'--> 已上传安装脚本到 {REMOTE}')

# 3) 以 sudo 执行（密码从 stdin 喂给 sudo -S）
cmd = f"sudo -S -p '' bash {REMOTE} {domain}"
print(f'--> 执行: {cmd}')
stdin, stdout, stderr = cli.exec_command(cmd, timeout=900, get_pty=True)
stdin.write(pw + '\n')
stdin.flush()
CH = paramiko.channel.Channel
while True:
    if stdout.channel.recv_ready():
        sys.stdout.write(stdout.channel.recv(4096).decode(errors='replace'))
        sys.stdout.flush()
    elif stdout.channel.exit_status_ready():
        rest = stdout.channel.recv(65536).decode(errors='replace') if stdout.channel.recv_ready() else ''
        sys.stdout.write(rest)
        break
    else:
        time.sleep(0.3)
rc = stdout.channel.recv_exit_status()
print(f'\n--> 退出码: {rc}')
cli.close()
sys.exit(0 if rc == 0 else 1)
