"""Local static frontend server; deployment should use the supplied reverse-proxy policy."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from functools import partial
from pathlib import Path
import json
import os

CSP = ("default-src 'self'; script-src 'self' 'wasm-unsafe-eval' https://*.razorpay.com https://*.razorpay.in; "
       "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; "
       "font-src 'self' data: https://fonts.gstatic.com; "
       "img-src 'self' data: blob: https://*.razorpay.com https://*.razorpay.in; "
       "connect-src 'self' http://127.0.0.1:8000 http://127.0.0.1:5000 http://127.0.0.1:5001 https://*.razorpay.com https://*.razorpay.in https://*.trycloudflare.com https: http:; "
       "frame-src https://*.razorpay.com https://*.razorpay.in; "
       "worker-src 'self' blob:; object-src 'none'; base-uri 'self'; frame-ancestors 'none'")

class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Content-Security-Policy', CSP)
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Referrer-Policy', 'no-referrer')
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def do_GET(self):
        clean_path = self.path.split('?')[0].rstrip('/')
        if clean_path in ('/env.json', '/config.json'):
            backend_url = os.environ.get("BACKEND_URL") or os.environ.get("API_BASE_URL") or ""
            if not backend_url:
                for env_path in (
                    Path(__file__).resolve().parents[1] / 'frontend' / '.env',
                    Path(__file__).resolve().parents[1] / '.env',
                    Path(__file__).resolve().parents[1] / 'backend' / '.env',
                ):
                    if env_path.exists():
                        try:
                            for line in env_path.read_text(encoding='utf-8').splitlines():
                                line = line.strip()
                                if line.startswith('BACKEND_URL=') and not line.startswith('#'):
                                    backend_url = line.split('=', 1)[1].strip().strip('"').strip("'")
                                    break
                        except Exception:
                            pass
                    if backend_url:
                        break
            if not backend_url:
                backend_url = "http://127.0.0.1:8000"
            payload = json.dumps({'BACKEND_URL': backend_url}).encode('utf-8')
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('Content-Length', str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            return
        return super().do_GET()

if __name__ == '__main__':
    root = Path(__file__).resolve().parents[1] / 'frontend' / 'build' / 'web'
    ThreadingHTTPServer(('0.0.0.0', 3000), partial(Handler, directory=str(root))).serve_forever()
