"""Launch an isolated Godot test, send Windows close, require actual process exit."""
import argparse
import ctypes as C
from ctypes import wintypes as W
import json
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
u = C.WinDLL('user32', use_last_error=True)
CALLBACK = C.WINFUNCTYPE(W.BOOL, W.HWND, W.LPARAM)
u.PostMessageW.argtypes = [W.HWND, W.UINT, W.WPARAM, W.LPARAM]
u.GetWindowThreadProcessId.argtypes = [W.HWND, C.POINTER(W.DWORD)]
u.IsWindowVisible.argtypes = [W.HWND]
u.SetForegroundWindow.argtypes = [W.HWND]
u.GetForegroundWindow.restype = W.HWND

class KEYBDINPUT(C.Structure):
    _fields_ = [('wVk',W.WORD), ('wScan',W.WORD), ('dwFlags',W.DWORD), ('time',W.DWORD), ('dwExtraInfo',C.c_size_t)]

class MOUSEINPUT(C.Structure):
    _fields_ = [('dx',W.LONG), ('dy',W.LONG), ('mouseData',W.DWORD), ('dwFlags',W.DWORD), ('time',W.DWORD), ('dwExtraInfo',C.c_size_t)]

class INPUT_UNION(C.Union):
    _fields_ = [('ki',KEYBDINPUT), ('mi',MOUSEINPUT)]

class INPUT(C.Structure):
    _fields_ = [('type',W.DWORD), ('data',INPUT_UNION)]

u.SendInput.argtypes = [W.UINT, C.POINTER(INPUT), C.c_int]

def alt_f4(hwnd):
    if u.GetForegroundWindow() != hwnd:
        raise RuntimeError('Game not foreground; refusing to send keys to another app')
    events = (INPUT*4)()
    for event,(key,flags) in zip(events,[(0x12,0),(0x73,0),(0x73,2),(0x12,2)]):
        event.type = 1
        event.data.ki = KEYBDINPUT(key,0,flags,0,0)
    if u.SendInput(4,events,C.sizeof(INPUT)) != 4:
        raise C.WinError(C.get_last_error())

def window_for(pid):
    found = []
    @CALLBACK
    def visit(hwnd, _):
        owner = W.DWORD()
        u.GetWindowThreadProcessId(hwnd, C.byref(owner))
        if owner.value == pid and u.IsWindowVisible(hwnd): found.append(hwnd)
        return True
    u.EnumWindows(visit, 0)
    return found[0] if found else None

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--scenario', default='menu')
    parser.add_argument('--tag', default='latest')
    parser.add_argument('--engine', type=Path, default=ROOT/'build/runtime-patched/template_debug-source/godot.exe')
    parser.add_argument('--mode', choices=['close','system-close','altf4'], default='altf4')
    parser.add_argument('--windowed', action='store_true')
    args = parser.parse_args()
    stem = ROOT/'review'/('exit_'+args.tag+'_'+args.scenario)
    log = stem.with_suffix('.log')
    cmd = [str(args.engine), '--path', str(ROOT), '--log-file', str(log)]
    if not args.windowed: cmd += ['--fullscreen']
    cmd += ['--', '--exit_probe', '--scenario='+args.scenario]
    proc = subprocess.Popen(cmd, cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print('started', proc.pid, args.scenario, flush=True)
    result = {'pid':proc.pid, 'scenario':args.scenario, 'engine':str(args.engine), 'mode':args.mode}
    start = time.monotonic()
    ready = False
    while time.monotonic()-start < 100 and proc.poll() is None:
        if log.exists() and '[exit_probe] READY' in log.read_text(encoding='utf-8', errors='replace'):
            ready = True
            break
        time.sleep(.2)
    result['ready'] = ready
    if ready:
        hwnd = window_for(proc.pid)
        if not hwnd: raise RuntimeError('No visible game window')
        u.SetForegroundWindow(hwnd)
        time.sleep(.2)
        start = time.monotonic()
        if args.mode == 'system-close':
            # Windows SC_CLOSE is the system command emitted by Alt+F4.
            u.PostMessageW(hwnd, 0x0112, 0xF060, 0)
        elif args.mode == 'altf4':
            try:
                alt_f4(hwnd)
            except RuntimeError as error:
                # Record loss of focus as a failed keyboard test, then close only
                # the test's own window; never send Alt+F4 to another app.
                result['input_error'] = str(error)
                u.PostMessageW(hwnd, 0x0010, 0, 0)
        else: u.PostMessageW(hwnd, 0x0010, 0, 0)
        try:
            proc.wait(timeout=12)
            result.update(exit_code=proc.returncode, exit_seconds=time.monotonic()-start)
        except subprocess.TimeoutExpired:
            result.update(hung=True, exit_seconds=time.monotonic()-start)
    else: result['exit_code'] = proc.poll()
    log_text = log.read_text(encoding='utf-8',errors='replace') if log.exists() else ''
    result['errors'] = [line for line in log_text.splitlines() if 'ERROR:' in line or 'SCRIPT ERROR' in line]
    result['passed'] = ready and not result.get('hung', False) and not result.get('input_error') and proc.poll() == 0 and not result['errors']
    stem.with_suffix('.json').write_text(json.dumps(result,indent=2), encoding='utf-8')
    print(json.dumps(result),flush=True)
    # Leave a hung process available for stack capture, never count a forced kill as success.
    return 0 if result['passed'] else 1

if __name__ == '__main__': raise SystemExit(main())
