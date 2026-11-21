"""Serve a Godot Web export over HTTP (file:// cannot load WebAssembly safely)."""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class Handler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map, ".wasm": "application/wasm", ".pck": "application/octet-stream"}

    def send_head(self):
        original = Path(self.translate_path(self.path))
        packed = original.with_name(original.name + ".gz")
        accepts_gzip = False
        for value in self.headers.get("Accept-Encoding", "").split(","):
            parts = [part.strip() for part in value.split(";")]
            if parts[0] == "gzip":
                try:
                    accepts_gzip = float(next((part[2:] for part in parts[1:] if part.startswith("q=")), "1")) > 0
                except ValueError:
                    pass
        if original.suffix in {".wasm", ".pck", ".js"} and accepts_gzip and original.is_file() and packed.is_file() and packed.stat().st_mtime >= original.stat().st_mtime:
            stream = packed.open("rb")
            self.send_response(200)
            self.send_header("Content-Type", self.guess_type(str(original)))
            self.send_header("Content-Encoding", "gzip")
            self.send_header("Vary", "Accept-Encoding")
            self.send_header("Content-Length", str(packed.stat().st_size))
            self.end_headers()
            return stream
        return super().send_head()

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1] / "build/web")
    parser.add_argument("--bind", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    root = args.root.resolve()
    if not (root / "index.html").is_file():
        raise SystemExit(f"Missing Web export: {root}/index.html")
    server = ThreadingHTTPServer((args.bind, args.port), partial(Handler, directory=str(root)))
    print(f"Serving {root} at http://{args.bind}:{args.port}/", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
