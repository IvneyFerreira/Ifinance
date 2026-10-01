import base64
import json
import subprocess
import time

import requests
import websocket

CHROME = "/usr/bin/google-chrome"
URL = "http://localhost:8080/"
OUT = "/home/user/flutter_app/preview_check.png"
PORT = 9333

proc = subprocess.Popen(
    [
        CHROME,
        "--headless=new",
        f"--remote-debugging-port={PORT}",
        "--remote-allow-origins=*",
        "--user-data-dir=/tmp/chrome-preview-check",
        "--no-sandbox",
        "--disable-gpu",
        "--disable-dev-shm-usage",
        "--window-size=430,900",
        "about:blank",
    ],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
)

try:
    # Espera o DevTools.
    for _ in range(40):
        try:
            tabs = requests.get(f"http://localhost:{PORT}/json", timeout=2).json()
            if tabs:
                break
        except Exception:
            time.sleep(0.5)
    else:
        raise RuntimeError("DevTools não respondeu")

    page = None
    for t in tabs:
        if t.get("type") == "page":
            page = t
            break
    ws = websocket.create_connection(page["webSocketDebuggerUrl"], timeout=30)
    mid = 0

    def send(method, params=None):
        global mid
        mid += 1
        ws.send(json.dumps({"id": mid, "method": method, "params": params or {}}))
        while True:
            msg = json.loads(ws.recv())
            if msg.get("id") == mid:
                return msg.get("result", {})

    send("Page.enable")
    send("Page.navigate", {"url": URL})
    # Flutter + Hive (IndexedDB) precisam de tempo real para o boot.
    time.sleep(14)
    shot = send("Page.captureScreenshot", {"format": "png"})["data"]
    with open(OUT, "wb") as f:
        f.write(base64.b64decode(shot))
    print("screenshot salvo:", OUT)
finally:
    proc.terminate()
    try:
        proc.wait(timeout=10)
    except Exception:
        proc.kill()
