"""Local static frontend server; deployment should use the supplied reverse-proxy policy."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from functools import partial
from pathlib import Path
import json
import os
import http.client

BACKEND_PROXY_PORT = int(os.environ.get('BACKEND_PROXY_PORT', '8000'))

CSP = ("default-src 'self'; script-src 'self' 'wasm-unsafe-eval' https://*.razorpay.com https://*.razorpay.in; "
       "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; "
       "font-src 'self' data: https://fonts.gstatic.com; "
       "img-src 'self' data: blob: https://*.razorpay.com https://*.razorpay.in; "
       "connect-src 'self' http://127.0.0.1:8000 http://127.0.0.1:5000 http://127.0.0.1:5001 https://*.razorpay.com https://*.razorpay.in https://*.trycloudflare.com https: http:; "
       "frame-src https://*.razorpay.com https://*.razorpay.in; "
       "worker-src 'self' blob:; object-src 'none'; base-uri 'self'; frame-ancestors 'none'")

class Handler(SimpleHTTPRequestHandler):
    def proxy_api(self):
        if not self.path.split('?')[0].startswith(('/api/', '/health')):
            return False
        size = int(self.headers.get('Content-Length', '0'))
        if size > 60 * 1024 * 1024:
            self.send_error(413)
            return True
        headers = {k: v for k, v in self.headers.items() if k.lower() not in ('host', 'connection', 'transfer-encoding')}
        connection = http.client.HTTPConnection('127.0.0.1', BACKEND_PROXY_PORT, timeout=120)
        try:
            connection.request(self.command, self.path, body=self.rfile.read(size) if size else None, headers=headers)
            response = connection.getresponse()
            self.send_response(response.status)
            for key, value in response.getheaders():
                if key.lower() not in ('connection', 'transfer-encoding'):
                    self.send_header(key, value)
            self.end_headers()
            while chunk := response.read(64 * 1024):
                self.wfile.write(chunk)
        except OSError:
            self.send_error(502, 'Backend unavailable')
        finally:
            connection.close()
        return True

    def do_POST(self):
        if not self.proxy_api():
            self.send_error(404)

    do_PUT = do_POST
    do_PATCH = do_POST
    do_DELETE = do_POST
    do_OPTIONS = do_POST

    def end_headers(self):
        self.send_header('Content-Security-Policy', CSP)
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Referrer-Policy', 'no-referrer')
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def do_GET(self):
        if self.proxy_api():
            return
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
            # An empty URL selects the current web origin. /api is proxied above,
            # so mobile LAN browsers never receive an unreachable localhost URL.
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
