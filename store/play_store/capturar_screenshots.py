#!/usr/bin/env python3
"""
IFinance — Captura de screenshots para a Play Store (1080x1920).

Usa o Chrome em modo headless via Chrome DevTools Protocol (CDP) para
controlar de verdade o app Flutter (cliques na barra inferior e no menu).
O viewport é 432x768 CSS com deviceScaleFactor=2.5 → exatamente 1080x1920.

Requer o app servido localmente. Ex.:
    python3 server.py 8099            # ou: python3 -m http.server 8099 --directory build/web
    python3 store/play_store/capturar_screenshots.py http://localhost:8099

Observação: use a porta 8099 (a 5060 está na lista de "unresolved ports" do
Chrome e é bloqueada com ERR_UNSAFE_PORT).
"""

from __future__ import annotations

import base64
import json
import os
import subprocess
import sys
import time
import urllib.request

import websocket  # pacote websocket-client

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "screenshots")
BASE = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8099"

# Viewport CSS + escala → 1080x1920 px (formato de telefone da Play Store).
W, H, DSF = 432, 768, 2.5

CHROME = "/usr/bin/google-chrome"


def _http(url, timeout=2):
    return urllib.request.urlopen(url, timeout=timeout)


def start_chrome():
    """Reaproveita uma instância já aberta ou inicia uma nova."""
    for port in (9222, 9223, 9224):
        try:
            _http(f"http://localhost:{port}/json/version", 1)
            return port
        except Exception:
            pass
    port = 9222
    subprocess.Popen([
        CHROME, "--headless=new", "--no-sandbox", "--disable-gpu",
        "--hide-scrollbars", "--mute-audio", "--force-device-scale-factor=1",
        "--remote-allow-origins=*",
        f"--remote-debugging-port={port}",
        f"--window-size={W},{H}",
        "about:blank",
    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    for _ in range(40):
        try:
            _http(f"http://localhost:{port}/json/version", 1)
            return port
        except Exception:
            time.sleep(0.5)
    return None


class CDP:
    def __init__(self, port):
        tabs = json.loads(_http(f"http://localhost:{port}/json").read())
        page = next(t for t in tabs if t["type"] == "page")
        self.ws = websocket.create_connection(
            page["webSocketDebuggerUrl"], max_size=None)
        self._i = 0

    def cmd(self, method, **params):
        self._i += 1
        self.ws.send(json.dumps(
            {"id": self._i, "method": method, "params": params}))
        while True:
            msg = json.loads(self.ws.recv())
            if msg.get("id") == self._i:
                return msg.get("result", {})

    def shot(self, name):
        os.makedirs(OUT, exist_ok=True)
        r = self.cmd("Page.captureScreenshot", format="png")
        path = os.path.join(OUT, f"{name}.png")
        with open(path, "wb") as f:
            f.write(base64.b64decode(r["data"]))
        print(f"  ✓ {path}")
        return path

    def click(self, x, y):
        for t in ("mousePressed", "mouseReleased"):
            self.cmd("Input.dispatchMouseEvent", type=t, x=x, y=y,
                     button="left", clickCount=1)
            time.sleep(0.06)


# Centros dos itens da barra inferior (6 áreas + vão central de 64px).
_NAV_Y = H - 34
_STEP = (W - 64) / 6
_NAV_X = [
    _STEP * 0.5,
    _STEP * 1.5,
    _STEP * 2.5,
    _STEP * 3.5 + 64,
    _STEP * 4.5 + 64,
    _STEP * 5.5 + 64,
]


def main():
    port = start_chrome()
    if not port:
        print("✗ Chrome não iniciou")
        return 1

    print(f"IFinance — screenshots Play Store | base={BASE}")
    c = CDP(port)
    c.cmd("Page.enable")
    c.cmd("Runtime.enable")
    c.cmd("Network.enable")
    c.cmd("Network.clearBrowserCache")
    c.cmd("Emulation.setDeviceMetricsOverride", width=W, height=H,
          deviceScaleFactor=DSF, mobile=True)

    c.cmd("Page.navigate", url=f"{BASE}/?v={int(time.time())}")
    time.sleep(10)

    plan = [
        ("01_inicio", None),
        ("02_movimentacoes", 1),
        ("03_assessor_ia", 2),
        ("04_planejar", 3),
        ("05_metas", 4),
        ("06_perfil", 5),
    ]
    for name, nav in plan:
        if nav is not None:
            c.click(_NAV_X[nav], _NAV_Y)
            time.sleep(2.2)
        c.shot(name)

    # Menu lateral: volta ao Início e abre a gaveta pelo hambúrguer.
    c.click(_NAV_X[0], _NAV_Y)
    time.sleep(1.6)
    c.click(26, 26)
    time.sleep(1.8)
    c.shot("07_menu")

    c.ws.close()
    print(f"\n✓ Screenshots em {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
