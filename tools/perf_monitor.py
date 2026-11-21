"""Exclusive Godot soak run with bounded telemetry and source provenance.

python tools/perf_monitor.py --tag baseline --maps ironbelt --duration 300
python tools/perf_monitor.py --tag acceptance --duration 300
"""
import argparse
import hashlib
import json
import shutil
import subprocess
import time
from pathlib import Path

import psutil


ROOT = Path(__file__).resolve().parents[1]
PATCHED_EXE = ROOT / "build/runtime-patched/template_debug-source/godot.windows.template_debug.x86_64.llvm.console.exe"
EXE = PATCHED_EXE if PATCHED_EXE.exists() else Path(r"D:\123\tmp\godot472\Godot_v4.7.2-stable_win64_console.exe")


def godot_processes():
    result = []
    for p in psutil.process_iter(["name"]):
        if "godot" not in (p.info["name"] or "").lower():
            continue
        try:
            if p.status() != psutil.STATUS_STOPPED:
                result.append(p)
        except psutil.NoSuchProcess:
            pass
    return result


def source_hashes(project):
    files = [project / "project.godot"]
    for folder in ["scripts", "tests", "shaders", "data", "scenes", "assets"]:
        files.extend(p for p in (project / folder).rglob("*") if p.is_file())
    return {str(p.relative_to(project)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}


def engine_hashes(executable):
    files = [executable.resolve()]
    for suffix in [".console.exe", "_console.exe"]:
        if executable.name.endswith(suffix):
            runtime = executable.with_name(executable.name[:-len(suffix)] + ".exe")
            if runtime.exists():
                files.append(runtime.resolve())
    return {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in files}


def freeze_project(tag, snapshot_dir):
    """Own copies, including imports; edits in the workspace cannot change this run."""
    snapshot_dir.mkdir(parents=True, exist_ok=True)
    required = sum(p.stat().st_size for folder in ["scripts", "tests", "shaders", "data", "scenes", "assets", ".godot/imported"]
                   for p in (ROOT / folder).rglob("*") if p.is_file())
    if shutil.disk_usage(snapshot_dir).free < required + 1024 ** 3:
        raise SystemExit("Insufficient snapshot space (including 1 GiB reserve); use --snapshot-dir on another drive")
    destination = snapshot_dir / ("soak_source_" + tag)
    destination.mkdir()  # Never overwrite an earlier evidence snapshot.
    (destination / ".gdignore").touch()
    before = source_hashes(ROOT)
    for folder in ["scripts", "tests", "shaders", "data", "scenes", "assets"]:
        shutil.copytree(ROOT / folder, destination / folder)
    shutil.copy2(ROOT / "project.godot", destination / "project.godot")
    (destination / ".godot").mkdir()
    shutil.copytree(ROOT / ".godot/imported", destination / ".godot/imported")
    for name in ["global_script_class_cache.cfg", "uid_cache.bin"]:
        src = ROOT / ".godot" / name
        if src.exists():
            shutil.copy2(src, destination / ".godot" / name)
    (destination / "review").mkdir()
    copied = source_hashes(destination)
    after = source_hashes(ROOT)
    changed = [p for p in before.keys() | after.keys() | copied.keys()
               if before.get(p) != copied.get(p) or before.get(p) != after.get(p)]
    if changed:
        raise SystemExit(f"Source changed while freezing; snapshot not tested: {changed}")
    return destination


def pause_preview(p, paused):
    try:
        cmd = p.cmdline()
        if "--path" not in cmd or "--editor" in cmd or "--headless" in cmd:
            return False
        if Path(cmd[cmd.index("--path") + 1]).resolve() != ROOT:
            return False
        p.suspend()
        paused[p.pid] = p
        print(f"Temporarily paused workspace preview {p.pid}", flush=True)
        return True
    except (psutil.NoSuchProcess, psutil.AccessDenied):
        return False


def host_cpu_counters():
    result = {}
    for process in psutil.process_iter(["name", "cpu_times"]):
        times = process.info["cpu_times"]
        if process.pid and times is not None:
            result[process.pid] = (process.info["name"], times.user + times.system)
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--tag", required=True)
    parser.add_argument("--maps", default="greyport,ironbelt,dustfield,redlake,canyon,bayport")
    parser.add_argument("--duration", type=int, default=300)
    parser.add_argument("--resolution", default="1920x1080")
    parser.add_argument("--engine", type=Path, default=EXE)
    parser.add_argument("--project", type=Path, default=ROOT)
    parser.add_argument("--snapshot", action="store_true")
    parser.add_argument("--snapshot-dir", type=Path, default=ROOT / "review")
    parser.add_argument("--pause-previews", action="store_true")
    parser.add_argument("--wait-idle", type=int, default=180)
    parser.add_argument("--profile", action="store_true", help="Add script instrumentation; diagnostic timing only")
    parser.add_argument("--host-profile", action="store_true", help="Record top process CPU users during host saturation")
    args = parser.parse_args()
    if not args.tag.replace("_", "").replace("-", "").isalnum():
        raise SystemExit("Tag must be alphanumeric with optional underscores/dashes")
    review = ROOT / "review"
    review.mkdir(exist_ok=True)
    if (review / f"soak_{args.tag}_manifest.json").exists():
        raise SystemExit("Tag already exists; choose a new evidence tag")
    project = freeze_project(args.tag, args.snapshot_dir.resolve()) if args.snapshot else args.project.resolve()
    provenance = {"started_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"), "sources": source_hashes(project),
                  "project": str(project), "engine": str(args.engine.resolve()),
                  "engine_sha256": hashlib.sha256(args.engine.read_bytes()).hexdigest(),
                  "engine_files": engine_hashes(args.engine),
                  "config": {k: str(v) if isinstance(v, Path) else v for k, v in vars(args).items()},
                  "phase": "waiting", "valid": False}
    manifest = review / f"soak_{args.tag}_manifest.json"
    manifest.write_text(json.dumps(provenance, indent=2), encoding="utf-8")
    cmd = [str(args.engine.resolve()), "--path", str(project), "--windowed", "--resolution", args.resolution,
           "--", "--perf_soak", "--tag=" + args.tag, "--maps=" + args.maps,
           "--duration=" + str(args.duration), "--sample-size=" + args.resolution]
    if args.profile:
        cmd.append("--profile=1")
    owned = set()
    paused = {}
    interference = []
    reason = ""
    try:
        idle_deadline = time.monotonic() + args.wait_idle
        while True:
            active = godot_processes()
            if args.pause_previews:
                active = [p for p in active if not pause_preview(p, paused)]
            if not active:
                break
            if time.monotonic() >= idle_deadline:
                provenance["phase"] = "not_started"
                provenance["invalid_reason"] = "Another Godot test/editor remains active; no sample started"
                manifest.write_text(json.dumps(provenance, indent=2), encoding="utf-8")
                raise SystemExit("Another Godot test/editor remains active; no sample started")
            time.sleep(2)
        return run(args, project, review, manifest, provenance, cmd, owned, paused, interference, reason)
    finally:
        for p in paused.values():
            try:
                p.resume()
                print(f"Resumed workspace preview {p.pid}", flush=True)
            except psutil.NoSuchProcess:
                pass


def run(args, project, review, manifest, provenance, cmd, owned, paused, interference, reason):
    provenance["phase"] = "running"
    manifest.write_text(json.dumps(provenance, indent=2), encoding="utf-8")
    with (review / f"soak_{args.tag}.log").open("w", encoding="utf-8") as log, \
            (review / f"soak_{args.tag}_process.jsonl").open("w", encoding="utf-8") as telemetry:
        process = subprocess.Popen(cmd, cwd=project, stdout=log, stderr=subprocess.STDOUT,
                                   creationflags=subprocess.CREATE_NO_WINDOW)
        parent_process = psutil.Process(process.pid)
        owned.add(process.pid)
        start = time.monotonic()
        deadline = start + args.duration * len(args.maps.split(",")) + 600
        psutil.cpu_percent()
        tracked = {}
        host_previous = host_cpu_counters() if args.host_profile else {}
        host_at = start
        try:
            while process.poll() is None:
                try:
                    children = parent_process.children(recursive=True)
                    owned.update(p.pid for p in children)
                except psutil.NoSuchProcess:
                    children = []
                other = [p for p in godot_processes() if p.pid not in owned]
                # The console wrapper may launch its render child between the two
                # process snapshots. Verify ancestry before declaring contention.
                external = []
                for p in other:
                    try:
                        if any(parent.pid in owned for parent in p.parents()):
                            owned.add(p.pid)
                        else:
                            external.append(p)
                    except psutil.NoSuchProcess:
                        pass
                other = external
                if other:
                    interference.append({"at_s": time.monotonic() - start, "pids": [p.pid for p in other]})
                    if args.pause_previews:
                        for p in other:
                            pause_preview(p, paused)
                if time.monotonic() > deadline:
                    reason = "Deadline exceeded"
                    break
                samples = []
                for p in [parent_process, *children]:
                    try:
                        if p.pid not in tracked:
                            tracked[p.pid] = p
                            p.cpu_percent()
                        p = tracked[p.pid]
                        mem = p.memory_info()
                        samples.append({"pid": p.pid, "rss_mb": mem.rss / 1048576,
                                        "private_mb": getattr(mem, "private", mem.vms) / 1048576,
                                        "cpu_percent": p.cpu_percent(), "threads": p.num_threads()})
                    except psutil.NoSuchProcess:
                        pass
                now = time.monotonic()
                sample = {"at_s": now - start, "system_cpu": psutil.cpu_percent(), "processes": samples}
                if args.host_profile:
                    current_host = host_cpu_counters()
                    if sample["system_cpu"] >= 85:
                        usage = [{"pid": pid, "name": name, "cpu_percent": (cpu - host_previous[pid][1]) * 100 / max(0.001, now - host_at)}
                                 for pid, (name, cpu) in current_host.items() if pid in host_previous and pid not in owned]
                        sample["host_top_cpu"] = sorted(usage, key=lambda entry: -entry["cpu_percent"])[:5]
                    host_previous = current_host
                    host_at = now
                telemetry.write(json.dumps(sample) + "\n")
                telemetry.flush()
                time.sleep(2)
        finally:
            if process.poll() is None:
                for pid in owned:
                    try:
                        psutil.Process(pid).terminate()
                    except psutil.NoSuchProcess:
                        pass
                process.wait(timeout=20)
        provenance["exit_code"] = process.returncode
        provenance["elapsed_s"] = time.monotonic() - start
    after = source_hashes(project)
    provenance["changed_sources"] = [p for p in provenance["sources"].keys() | after.keys() if after.get(p) != provenance["sources"].get(p)]
    provenance["engine_changed"] = engine_hashes(args.engine) != provenance["engine_files"]
    if provenance["engine_changed"]:
        reason = reason or "Engine executable changed during the run"
    provenance["interference"] = interference
    provenance["paused_previews"] = list(paused)
    if interference:
        reason = reason or "Concurrent Godot activity; functional completion only, timing not accepted"
    if project != ROOT:
        for suffix in [".json", ".jsonl"]:
            src = project / "review" / f"soak_{args.tag}{suffix}"
            if src.exists():
                shutil.copy2(src, review / src.name)
    result_file = review / f"soak_{args.tag}.json"
    complete = result_file.exists() and json.loads(result_file.read_text(encoding="utf-8")).get("complete", False)
    runtime_log = (review / f"soak_{args.tag}.log").read_text(encoding="utf-8", errors="replace")
    provenance["runtime_errors"] = [line for line in runtime_log.splitlines() if "ERROR:" in line]
    if not reason and provenance["runtime_errors"]:
        reason = "Runtime errors were logged; see runtime_errors"
    if not reason and (process.returncode != 0 or not complete):
        reason = f"Test failed or incomplete (exit {process.returncode}); see soak_{args.tag}.log"
    provenance["valid"] = not reason and process.returncode == 0 and complete and not provenance["changed_sources"]
    provenance["phase"] = "finished"
    provenance["invalid_reason"] = reason
    manifest.write_text(json.dumps(provenance, indent=2), encoding="utf-8")
    print(json.dumps({k: provenance[k] for k in ["valid", "exit_code", "elapsed_s", "changed_sources", "invalid_reason"]}), flush=True)
    return 0 if provenance["valid"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
