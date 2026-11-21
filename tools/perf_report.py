"""Summarize soak evidence, retaining failed/contaminated runs instead of cherry-picking."""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def quantile(histogram, fraction):
    target = sum(histogram) * fraction
    count = 0
    for i, n in enumerate(histogram):
        count += n
        if count >= target:
            return i / 10 if i < len(histogram) - 1 else None
    return None


def summarize(tag):
    prefix = ROOT / "review" / ("soak_" + tag)
    manifest_path = Path(str(prefix) + "_manifest.json")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {}
    report_path = prefix.with_suffix(".json")
    report = json.loads(report_path.read_text(encoding="utf-8")) if report_path.exists() else {}
    result = {"tag": tag, "timing_valid": manifest.get("valid", False),
              "complete": report.get("complete", False), "reason": manifest.get("invalid_reason", "No terminal manifest"),
              "config": report.get("config", {}), "maps": [], "hub": report.get("hub", [])}
    for data in report.get("maps", []):
        windows = data["windows"]
        frames = sum(w["frames"] for w in windows)
        elapsed_ms = sum(w["avg_ms"] * w["frames"] for w in windows)
        hist = data.get("histogram_0_1_ms")
        previous_shots = data["start"].get("shots", 0)
        firing_gaps = []
        for window in windows:
            current_shots = window["state"].get("shots")
            if current_shots is not None:
                if window["avg_ms"] * window["frames"] > 9000 and current_shots - previous_shots < 20:
                    firing_gaps.append(window["at_s"])
                previous_shots = current_shots
        row = {"id": data["id"], "seconds": elapsed_ms / 1000, "frames": frames,
               "fps": frames * 1000 / elapsed_ms, "load_ms": data["load_ms"],
               "p95_ms_upper": quantile(hist, 0.95) if hist else None,
               "p99_ms_upper": quantile(hist, 0.99) if hist else None,
               "worst_window_p99_ms": max(w["p99_ms"] for w in windows),
               "max_ms": max(w["max_ms"] for w in windows),
               "over33": sum(w["over33"] for w in windows), "over45": sum(w["over45"] for w in windows),
               "over100": sum(w["over100"] for w in windows),
               "static_mb_first": windows[0]["memory"]["static_mb"],
               "static_mb_last": windows[-1]["memory"]["static_mb"],
               "firing_coverage_verified": "shots" in data["end"] and not firing_gaps,
               "firing_gap_windows_s": firing_gaps,
               "start_state": data["start"], "end_state": data["end"],
               "slowest": sorted((s for w in windows for s in w["slow"]), key=lambda s: -s["ms"])[:8]}
        result["maps"].append(row)
    process_path = Path(str(prefix) + "_process.jsonl")
    if process_path.exists():
        rows = [json.loads(line) for line in process_path.read_text(encoding="utf-8").splitlines() if line]
        if rows:
            result["peak_rss_mb"] = max(sum(p["rss_mb"] for p in r["processes"]) for r in rows)
            result["peak_private_mb"] = max(sum(p["private_mb"] for p in r["processes"]) for r in rows)
            result["max_system_cpu"] = max(r["system_cpu"] for r in rows)
            result["host_cpu_over90_samples"] = [{"at_s": r["at_s"], "system_cpu": r["system_cpu"]}
                                                   for r in rows if r["system_cpu"] >= 90]
    log_path = prefix.with_suffix(".log")
    if log_path.exists():
        result["errors_warnings"] = [line for line in log_path.read_text(encoding="utf-8", errors="replace").splitlines()
                                     if "ERROR:" in line or "WARNING:" in line or "] FAIL" in line]
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("tags", nargs="+")
    parser.add_argument("--output", type=Path, default=ROOT / "review/soak_summary.json")
    args = parser.parse_args()
    reports = [summarize(tag) for tag in args.tags]
    args.output.write_text(json.dumps(reports, indent=2, ensure_ascii=False), encoding="utf-8")
    for result in reports:
        print(result["tag"], "timing_valid=", result["timing_valid"], "complete=", result["complete"])
        for row in result["maps"]:
            print(f"  {row['id']}: {row['seconds']:.1f}s {row['fps']:.1f}FPS "
                  f"P99<={row['p99_ms_upper']}ms max={row['max_ms']:.1f}ms "
                  f">45={row['over45']} >100={row['over100']}")


if __name__ == "__main__":
    main()
