"""Servidor de preview do IFinance (porta 5060).

Serve build/web com cabeçalhos que impedem cache do navegador/Service Worker,
garantindo que o preview SEMPRE mostre a última build (sem "tela travada" com
código antigo em cache).
"""
import functools
import http.server
import socketserver

DIRECTORY = "/home/user/flutter_app/build/web"
PORT = 5060


class NoCacheCORSHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("X-Frame-Options", "ALLOWALL")
        self.send_header("Content-Security-Policy", "frame-ancestors *")
        # Sem cache: preview sempre atualizado.
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def log_message(self, *args):  # silencioso
        pass


class ReusableTCPServer(socketserver.TCPServer):
    allow_reuse_address = True


if __name__ == "__main__":
    handler = functools.partial(NoCacheCORSHandler)
    with ReusableTCPServer(("0.0.0.0", PORT), NoCacheCORSHandler) as httpd:
        print(f"IFinance preview on :{PORT} -> {DIRECTORY}")
        httpd.serve_forever()
