"""Precompress Godot payloads; keep originals for hosts without gzip_static."""
import argparse
import gzip
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("root", nargs="?", type=Path, default=Path(__file__).resolve().parents[1] / "build/web")
    args = parser.parse_args()
    total = compressed = 0
    for path in args.root.iterdir():
        if path.suffix not in {".wasm", ".pck", ".js"}:
            continue
        data = path.read_bytes()
        encoded = gzip.compress(data, compresslevel=6, mtime=0)
        path.with_name(path.name + ".gz").write_bytes(encoded)
        total += len(data)
        compressed += len(encoded)
        print(f"{path.name}: {len(data)/1048576:.1f} -> {len(encoded)/1048576:.1f} MiB")
    print(f"Total payload: {total/1048576:.1f} -> {compressed/1048576:.1f} MiB")


if __name__ == "__main__":
    main()
