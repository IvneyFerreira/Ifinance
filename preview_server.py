import http.server, socketserver, os, functools

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'build', 'web')

class NoCacheCORSHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.send_header('X-Frame-Options', 'ALLOWALL')
        self.send_header('Content-Security-Policy', 'frame-ancestors *')
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()
    def do_OPTIONS(self):
        self.send_response(200); self.end_headers()

Handler = functools.partial(NoCacheCORSHandler, directory=ROOT)
socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(('0.0.0.0', 5060), Handler) as httpd:
    print('Serving on 5060 (no-cache) from', ROOT, flush=True)
    httpd.serve_forever()
