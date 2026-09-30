#!/usr/bin/env python3
"""
IFinance — Servidor (preview + Assessor IA real) — pronto para produção.

Serve os arquivos estáticos do build web (build/web) e expõe:
  GET  /api/health    → status, versão e se a IA está ativa
  POST /api/assessor  → conversa com um LLM real (proxy compatível com OpenAI)

A chave da API nunca é exposta ao cliente: fica apenas aqui no servidor.

Configuração por variáveis de ambiente:
  PORT                    porta (default 5060)
  WEB_DIR                 diretório do build web (default ./build/web)
  OPENAI_BASE_URL         base do provedor compatível com OpenAI
  OPENAI_API_KEY          chave (somente servidor)
  IFINANCE_LLM_MODEL      modelo (default gpt-5.4-mini)
  IFINANCE_ALLOWED_ORIGINS  CORS: "*" ou lista separada por vírgula
  IFINANCE_RATE_LIMIT     requisições por minuto por IP (default 30; 0 = off)

Uso:
    python3 server.py 5060
    # ou: PORT=8080 WEB_DIR=./build/web python3 server.py
"""

import json
import os
import sys
import time
import threading
import http.server
import socketserver
import urllib.request
import urllib.error
from datetime import datetime

APP_VERSION = "1.0.0"

PORT = int(os.environ.get("PORT") or (sys.argv[1] if len(sys.argv) > 1 else 5060))
WEB_DIR = os.environ.get(
    "WEB_DIR",
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "build", "web"),
)

# --- Recursos de IA (somente servidor) -------------------------------------
LLM_BASE = os.environ.get("OPENAI_BASE_URL", "").rstrip("/")
LLM_KEY = os.environ.get("OPENAI_API_KEY", "")
LLM_MODEL = os.environ.get("IFINANCE_LLM_MODEL", "gpt-5.4-mini")
LLM_ENABLED = bool(LLM_BASE and LLM_KEY)

# CORS: "*" ou lista separada por vírgula de origens permitidas.
ALLOWED_ORIGINS = os.environ.get("IFINANCE_ALLOWED_ORIGINS", "*").strip()
# Rate limit simples por IP (requisições/minuto). 0 desativa.
RATE_LIMIT = int(os.environ.get("IFINANCE_RATE_LIMIT", "30") or "0")

_rate_lock = threading.Lock()
_rate_buckets = {}  # ip -> [window_start_ts, count]


def _rate_ok(ip: str) -> bool:
    if RATE_LIMIT <= 0:
        return True
    now = time.time()
    with _rate_lock:
        start, count = _rate_buckets.get(ip, [now, 0])
        if now - start >= 60:
            start, count = now, 0
        count += 1
        _rate_buckets[ip] = [start, count]
        return count <= RATE_LIMIT


def _cors_headers(origin: str):
    """Devolve (allow_origin, extra_headers) respeitando a configuração."""
    if ALLOWED_ORIGINS == "*":
        return "*", []
    allowed = [o.strip() for o in ALLOWED_ORIGINS.split(",") if o.strip()]
    if origin and origin in allowed:
        return origin, [("Vary", "Origin")]
    return (allowed[0] if allowed else "*"), []



SYSTEM_PROMPT = """Você é o Assessor Financeiro do IFinance, um assistente pessoal especializado EXCLUSIVAMENTE na vida financeira do usuário.

ESCOPO PERMITIDO (fale SOMENTE sobre isto):
- Despesas e gastos (por categoria, orçamento, maiores gastos, cortes).
- Entradas / receitas (quanto entrou, de onde vem a renda, próximo recebimento).
- Saldo, comprometido, livre para gastar, projeção de fim de mês, fluxo do mês.
- Cartões e faturas, assinaturas/recorrentes, dívidas e metas financeiras.

REGRAS OBRIGATÓRIAS:
- Você é um assistente FINANCEIRO. Você NUNCA fala sobre assuntos aleatórios ou fora de finanças pessoais (notícias, programação, piadas, saúde, receitas culinárias, conhecimentos gerais, opiniões, etc.).
- Se o pedido não for sobre finanças do usuário, recuse de forma educada e breve, e ofereça ajuda financeira.
- NUNCA invente números. Use SOMENTE os dados fornecidos no CONTEXTO FINANCEIRO. Se um dado não estiver no contexto, diga que ainda não há registro suficiente.
- Todos os valores estão em reais (R$) já formatados no padrão brasileiro (ex.: R$ 3.000,00). Nunca faça cálculos complexos por conta própria; prefira citar os valores do contexto.
- Seja direto, prático e empático. Responda em português do Brasil.
- Prefira respostas curtas (2 a 5 frases), com foco em ação financeira.
- Quando citar valores, use exatamente os valores do contexto.
"""


def _call_llm(messages, timeout=90):
    if not LLM_ENABLED:
        raise RuntimeError("LLM não configurado no servidor.")
    payload = {
        "model": LLM_MODEL,
        "messages": messages,
        "max_tokens": 700,
    }
    req = urllib.request.Request(
        LLM_BASE + "/chat/completions",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": "Bearer " + LLM_KEY,
            "Content-Type": "application/json",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        data = json.load(resp)
    return (data["choices"][0]["message"]["content"] or "").strip()


def _build_context_prompt(context: dict) -> str:
    """Transforma o contexto estruturado (vindo do FinanceEngine) em texto."""
    lines = []
    lines.append("### CONTEXTO FINANCEIRO (despesas, entradas e controle)")
    lines.append(f"Data de referência: {context.get('today', datetime.now().strftime('%d/%m/%Y'))}")
    lines.append(f"Mês de referência: {context.get('monthLabel', '')}")

    month = context.get("month", {}) or {}
    lines.append("\n**Resumo do mês**")
    lines.append(f"- Entradas (receitas) do mês: {month.get('income', 'R$ 0,00')}")
    lines.append(f"- Despesas do mês: {month.get('expense', 'R$ 0,00')}")
    lines.append(f"- Resultado do mês (entradas - despesas): {month.get('result', 'R$ 0,00')}")
    lines.append(f"- Taxa de poupança: {month.get('savingsRate', '-')}")
    lines.append(f"- Comprometido até o fim do mês: {month.get('committed', 'R$ 0,00')}")
    lines.append(f"- Saldo disponível hoje: {context.get('available', 'R$ 0,00')}")
    lines.append(f"- Livre para gastar com segurança: {context.get('safeToSpend', 'R$ 0,00')}")
    lines.append(f"- Próximo recebimento: {context.get('nextIncome', 'sem previsão')}")

    cats = context.get("topCategories", []) or []
    lines.append("\n**Onde o usuário mais gastou neste mês**")
    if cats:
        for i, c in enumerate(cats, 1):
            lines.append(f"{i}. {c.get('name')}: {c.get('amount')} ({c.get('percent', '')} do total)")
    else:
        lines.append("- Nenhuma despesa registrada neste mês.")

    incomes = context.get("incomes", []) or []
    lines.append("\n**Entradas / receitas do mês**")
    if incomes:
        for inc in incomes[:8]:
            lines.append(f"- {inc.get('name')}: {inc.get('amount')} em {inc.get('date', '')}")
    else:
        lines.append("- Nenhuma receita registrada neste mês.")

    recent = context.get("recentExpenses", []) or []
    lines.append("\n**Últimas despesas registradas**")
    if recent:
        for r in recent[:10]:
            lines.append(f"- {r.get('date', '')} | {r.get('name')} | {r.get('category')} | {r.get('amount')}")
    else:
        lines.append("- Sem despesas recentes.")

    subs = context.get("subscriptions", {}) or {}
    lines.append("\n**Assinaturas / recorrentes de despesa**")
    lines.append(f"- Custo mensal em assinaturas: {subs.get('monthly', 'R$ 0,00')}")
    lines.append(f"- Custo anual em assinaturas: {subs.get('annual', 'R$ 0,00')}")
    if subs.get("list"):
        for s in subs["list"][:8]:
            lines.append(f"   • {s.get('name')}: {s.get('amount')} ({s.get('freq', '')})")

    cards = context.get("cards", []) or []
    lines.append("\n**Faturas de cartão (gastos)**")
    if cards:
        for c in cards:
            lines.append(f"- {c.get('name')}: fatura atual {c.get('currentInvoice')}, disponível {c.get('available')}")
    else:
        lines.append("- Nenhum cartão cadastrado.")

    budgets = context.get("budgets", []) or []
    lines.append("\n**Orçamentos de despesa**")
    if budgets:
        for b in budgets[:10]:
            lines.append(f"- {b.get('name')}: gasto {b.get('spent')} de {b.get('limit')} ({b.get('percent')})")
    else:
        lines.append("- Nenhum orçamento definido.")

    return "\n".join(lines)


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    def _send_json(self, code, obj):
        body = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        allow, extra = _cors_headers(self.headers.get("Origin", ""))
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", allow)
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        for k, v in extra:
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        allow, extra = _cors_headers(self.headers.get("Origin", ""))
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", allow)
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        for k, v in extra:
            self.send_header(k, v)
        self.end_headers()

    def do_GET(self):
        if self.path.startswith("/api/health"):
            self._send_json(200, {
                "status": "ok",
                "version": APP_VERSION,
                "ai_enabled": LLM_ENABLED,
                "model": LLM_MODEL if LLM_ENABLED else None,
                "scope": "financas (despesas e entradas)",
                "rate_limit_per_min": RATE_LIMIT,
            })
            return
        # Flutter web (SPA): se o caminho não for um arquivo, serve index.html.
        return super().do_GET()

    def send_head(self):
        # Fallback SPA: rotas sem arquivo (ex.: /relatorios) caem em index.html.
        path = self.translate_path(self.path)
        if not os.path.exists(path) and not self.path.startswith("/api/"):
            self.path = "/index.html"
        return super().send_head()

    def do_POST(self):
        if not self.path.startswith("/api/assessor"):
            self._send_json(404, {"error": "not found"})
            return

        # Rate limit por IP (protege o custo da IA).
        client_ip = self.client_address[0] if self.client_address else "?"
        if not _rate_ok(client_ip):
            self._send_json(429, {
                "error": "Muitas requisições. Aguarde um instante e tente novamente."
            })
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
            raw = self.rfile.read(length) if length else b"{}"
            payload = json.loads(raw or b"{}")
        except Exception:
            self._send_json(400, {"error": "JSON inválido"})
            return

        question = (payload.get("question") or "").strip()
        context = payload.get("context") or {}
        history = payload.get("history") or []

        if not question:
            self._send_json(400, {"error": "Pergunta vazia"})
            return

        if not LLM_ENABLED:
            self._send_json(200, {
                "answer": "O Assessor está temporariamente indisponível (IA não configurada no servidor).",
                "offline": True,
            })
            return

        messages = [{"role": "system", "content": SYSTEM_PROMPT}]
        messages.append({"role": "system", "content": _build_context_prompt(context)})
        # Histórico recente (últimos 6 turnos), só texto.
        for h in history[-6:]:
            role = "user" if h.get("fromUser") else "assistant"
            txt = (h.get("text") or "").strip()
            if txt:
                messages.append({"role": role, "content": txt})
        messages.append({"role": "user", "content": question})

        try:
            answer = _call_llm(messages)
            self._send_json(200, {"answer": answer, "model": LLM_MODEL})
        except urllib.error.HTTPError as e:
            detail = e.read().decode("utf-8", "ignore")[:300]
            self._send_json(502, {"error": f"IA indisponível ({e.code}). {detail}"})
        except Exception as e:
            self._send_json(502, {"error": f"Falha ao consultar a IA: {str(e)[:200]}"})


class ThreadingServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


if __name__ == "__main__":
    WEB_DIR = os.path.abspath(WEB_DIR)
    if os.path.isdir(WEB_DIR):
        os.chdir(WEB_DIR)
    with ThreadingServer(("0.0.0.0", PORT), Handler) as httpd:
        print(f"IFinance {APP_VERSION} em http://0.0.0.0:{PORT} | WEB_DIR={WEB_DIR}")
        print(f"Assessor IA: {'ATIVO' if LLM_ENABLED else 'DESLIGADO'} (modelo={LLM_MODEL})")
        print(f"CORS: {ALLOWED_ORIGINS} | Rate limit: {RATE_LIMIT}/min")
        httpd.serve_forever()
