#!/usr/bin/env python3
"""
IFinance — Captura de screenshots para a Play Store (Chrome headless).

Requer o build web servido localmente (ex.: python3 -m http.server 8099
--directory build/web). Usa o google-chrome em modo headless para tirar
fotos em formato de telefone (1080x1920).

Uso:
    python3 store/play_store/capturar_screenshots.py [BASE_URL]

Dica: como o app é offline-first e começa vazio, o ideal é capturar a tela
"Painel" logo após registrar alguns lançamentos manualmente para a loja ficar
com dados reais. Este script faz a captura automática da tela inicial.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "screenshots")
BASE = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8099"

CHROME = shutil.which("google-chrome") or shutil.which("google-chrome-stable")

# (nome_do_arquivo, rota) — o app é SPA; ajuste as rotas conforme navegação.
SHOTS = [
    ("01_painel", "/"),
]


def wait_server(url, tries=30):
    for _ in range(tries):
        try:
            urllib.request.urlopen(url, timeout=3)
            return True
        except Exception:
            time.sleep(1)
    return False


def capture(route, out_path):
    if not CHROME:
        print("✗ Google Chrome não encontrado no PATH.")
        return False
    cmd = [
        CHROME,
        "--headless=new",
        "--disable-gpu",
        "--no-sandbox",
        "--hide-scrollbars",
        "--window-size=1080,1920",
        f"--screenshot={out_path}",
        f"--virtual-time-budget=8000",
        f"{BASE}{route}",
    ]
    try:
        subprocess.run(cmd, check=True, capture_output=True, timeout=90)
        return os.path.isfile(out_path)
    except Exception as e:
        print(f"✗ Falha ao capturar {route}: {e}")
        return False


def main():
    os.makedirs(OUT, exist_ok=True)
    print(f"IFinance — captura Play Store | base={BASE}")
    if not wait_server(BASE):
        print("✗ Servidor não respondeu. Inicie: "
              "python3 -m http.server 8099 --directory build/web")
        return 1
    ok = 0
    for name, route in SHOTS:
        path = os.path.join(OUT, f"{name}.png")
        if capture(route, path):
            print(f"✓ {path}")
            ok += 1
    print(f"\n{ok}/{len(SHOTS)} capturado(s) em {OUT}")
    print("Para mais telas, abra o app no Chrome (modo dispositivo 1080x1920)")
    print("e salve 02_transacoes.png, 03_cartoes.png, 04_metas.png, etc.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
