# -*- coding: utf-8 -*-
"""
Colab 实例被回收后的一键重建工具（单步执行，不做任何阻塞等待）。

用法：
    python tools/colab_bootstrap.py <步骤>

步骤：
    bind      把服务端当前唯一 assignment 绑定为本地会话 gen
    drive     检查 Google Drive 挂载与 H3 权重是否可见
    prep      VM 侧克隆 ComfyUI、装依赖、装 cloudflared（后台跑）
    flag      查看 prep 是否完成
    service   软链 H3 权重并拉起 ComfyUI（后台跑）
    probe     探 ComfyUI 与本机权重链接状态
    tunnel    起 cloudflared 并打印公网地址（同时写回 tools/art_host.txt）
    refs      把三张参考立绘推到 ComfyUI input
    submit    按本地已落盘情况重新排队缺失任务

每一步只做一件事然后退出；需要等待时由调用方在两次调用之间穿插其他工作。
"""
import json
import os
import re
import subprocess
import sys
import urllib.request

ROOT = "D:/123/qianyuanshaonv"
VENV_PY = r"C:\Users\Administrator\AppData\Roaming\uv\tools\google-colab-cli\Scripts\python.exe"
SESSION = "gen"

BIND_CODE = """
from colab_cli.common import state
from colab_cli.state import SessionState

sessions, assignments = state.sync_sessions()
for a in assignments:
    s = SessionState(
        name='%s',
        token=a.runtime_proxy_info.token,
        url=a.runtime_proxy_info.url,
        endpoint=a.endpoint,
        token_expires_at=a.runtime_proxy_info.expires_at() if hasattr(a.runtime_proxy_info, 'expires_at') else None,
        variant=a.variant.name,
        accelerator=a.accelerator.value,
        machine_shape=a.machine_shape.name,
    )
    state.store.add(s)
    print('bound', a.endpoint, a.accelerator.value)
"""


def run(cmd, timeout=300):
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    out = (p.stdout or "") + (p.stderr or "")
    return p.returncode, out.strip()


def exec_remote(script, timeout=300):
    return run(["colab", "exec", "-s", SESSION, "--timeout", str(timeout - 60),
                "-f", os.path.join(ROOT, "review", script)], timeout=timeout)


def host_url():
    with open(os.path.join(ROOT, "tools", "art_host.txt"), encoding="utf-8") as f:
        return f.read().strip()


def step_bind():
    code = BIND_CODE % SESSION
    rc, out = run([VENV_PY, "-c", code])
    print(out)


def step_drive():
    rc, out = exec_remote("drvcheck.py", 180)
    print(out)


def step_prep():
    rc, out = exec_remote("prep2.py", 180)
    print(out)


def step_flag():
    rc, out = exec_remote("flagcheck.py", 180)
    print(out)


def step_service():
    rc, out = exec_remote("start_service.py", 300)
    print(out)


def step_probe():
    rc, out = exec_remote("svc_probe.py", 180)
    print(out)


def step_tunnel():
    rc, out = exec_remote("tunnel_launch.py", 180)
    print(out)
    rc, out = exec_remote("cf_check.py", 180)
    print(out)
    m = re.search(r"https://[a-z0-9-]+\.trycloudflare\.com", out)
    if not m:
        print("未拿到隧道地址")
        return
    url = m.group(0)
    with open(os.path.join(ROOT, "tools", "art_host.txt"), "w", encoding="utf-8") as f:
        f.write(url + "\n")
    print("art_host.txt ->", url)


def step_refs():
    base = host_url()
    pairs = [("kurumi.png", "kurumi_ref.png"), ("lina.png", "lina_ref.png"), ("laojiao.png", "mia_ref.png")]
    for src, dst in pairs:
        path = os.path.join(ROOT, "assets", "portraits", src)
        rc, out = run(["curl", "-s", "-m", "60", "-X", "POST", base + "/upload/image",
                       "-F", "image=@%s;filename=%s" % (path.replace("\\", "/"), dst),
                       "-F", "overwrite=true", "-F", "type=input"], timeout=120)
        print(dst, "->", out)


def step_submit():
    rc, out = run([sys.executable, os.path.join(ROOT, "tools", "h3_crew_batch.py")], timeout=600)
    print(out[-2000:])


STEPS = {
    "bind": step_bind,
    "drive": step_drive,
    "prep": step_prep,
    "flag": step_flag,
    "service": step_service,
    "probe": step_probe,
    "tunnel": step_tunnel,
    "refs": step_refs,
    "submit": step_submit,
}

if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in STEPS:
        print("步骤: " + " | ".join(STEPS))
        sys.exit(1)
    STEPS[sys.argv[1]]()
