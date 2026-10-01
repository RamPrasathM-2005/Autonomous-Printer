"""Local static frontend server; deployment should use the supplied reverse-proxy policy."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from functools import partial
from pathlib import Path

CSP = ("default-src 'self'; script-src 'self' 'wasm-unsafe-eval' https://*.razorpay.com https://*.razorpay.in; "
       "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; "
       "font-src 'self' data: https://fonts.gstatic.com; "
       "img-src 'self' data: blob: https://*.razorpay.com https://*.razorpay.in; "
       "connect-src 'self' http://127.0.0.1:8000 http://127.0.0.1:5000 http://127.0.0.1:5001 https://*.razorpay.com https://*.razorpay.in; "
       "frame-src https://*.razorpay.com https://*.razorpay.in; "
       "worker-src 'self' blob:; object-src 'none'; base-uri 'self'; frame-ancestors 'none'")

class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Content-Security-Policy', CSP)
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Referrer-Policy', 'no-referrer')
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

if __name__ == '__main__':
    root = Path(__file__).resolve().parents[1] / 'frontend' / 'build' / 'web'
    ThreadingHTTPServer(('127.0.0.1', 3000), partial(Handler, directory=str(root))).serve_forever()
