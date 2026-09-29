#!/usr/bin/env python3
"""
IFinance — Servidor de preview + Assessor IA real.

Serve os arquivos estáticos do build web (build/web) e expõe um endpoint
/api/assessor que conversa com um LLM real (via proxy compatível com OpenAI
disponível no ambiente). A chave de API NUNCA é exposta ao cliente: fica
somente aqui, no servidor.

Uso:
    python3 server.py 5060
"""

import json
import os
import sys
import http.server
import socketserver
import urllib.request
import urllib.error
from datetime import datetime

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 5060
WEB_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "build", "web")

# --- Recursos de IA (somente servidor) -------------------------------------
LLM_BASE = os.environ.get("OPENAI_BASE_URL", "").rstrip("/")
LLM_KEY = os.environ.get("OPENAI_API_KEY", "")
LLM_MODEL = os.environ.get("IFINANCE_LLM_MODEL", "gpt-5.4-mini")
LLM_ENABLED = bool(LLM_BASE and LLM_KEY)

SYSTEM_PROMPT = """Você é o Assessor Financeiro do IFinance, um assistente pessoal especializado EXCLUSIVAMENTE em despesas e gastos do usuário.

REGRAS OBRIGATÓRIAS:
- Você só responde sobre despesas, gastos, orçamento, categorias de gasto, assinaturas, faturas de cartão e como reduzir/controlar despesas.
- Se o usuário perguntar sobre qualquer outro assunto (notícias, programação, piadas, saúde, etc.), recuse com educação e diga que você só ajuda com as despesas e o controle de gastos dele.
- NUNCA invente números. Use SOMENTE os dados fornecidos no CONTEXTO FINANCEIRO. Se um dado não estiver no contexto, diga que ainda não há registro suficiente.
- Todos os valores estão em reais (R$) e já formatados no padrão brasileiro (ex.: R$ 3.000,00). Nunca faça cálculos complexos por conta própria; prefira citar os valores do contexto.
- Seja direto, prático e empático. Responda em português do Brasil.
- Prefira respostas curtas (2 a 5 frases), com foco em ação: onde o usuário está gastando e o que pode fazer para reduzir.
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
    lines.append("### CONTEXTO FINANCEIRO (foco: DESPESAS)")
    lines.append(f"Data de referência: {context.get('today', datetime.now().strftime('%d/%m/%Y'))}")
    lines.append(f"Mês de referência: {context.get('monthLabel', '')}")

    month = context.get("month", {}) or {}
    lines.append("\n**Resumo do mês**")
    lines.append(f"- Despesas do mês: {month.get('expense', 'R$ 0,00')}")
    lines.append(f"- Receitas do mês: {month.get('income', 'R$ 0,00')}")
    lines.append(f"- Resultado do mês: {month.get('result', 'R$ 0,00')}")
    lines.append(f"- Comprometido até o fim do mês: {month.get('committed', 'R$ 0,00')}")
    lines.append(f"- Saldo disponível hoje: {context.get('available', 'R$ 0,00')}")
    lines.append(f"- Livre para gastar com segurança: {context.get('safeToSpend', 'R$ 0,00')}")

    cats = context.get("topCategories", []) or []
    lines.append("\n**Onde o usuário mais gastou neste mês**")
    if cats:
        for i, c in enumerate(cats, 1):
            lines.append(f"{i}. {c.get('name')}: {c.get('amount')} ({c.get('percent', '')} do total)")
    else:
        lines.append("- Nenhuma despesa registrada neste mês.")

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
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self):
        if self.path.startswith("/api/health"):
            self._send_json(200, {
                "status": "ok",
                "ai_enabled": LLM_ENABLED,
                "model": LLM_MODEL if LLM_ENABLED else None,
                "scope": "despesas",
            })
            return
        # Flutter web: web/ usa SPA. Fallback p/ index.html em rotas sem arquivo.
        return super().do_GET()

    def do_POST(self):
        if not self.path.startswith("/api/assessor"):
            self._send_json(404, {"error": "not found"})
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
    os.chdir(WEB_DIR)
    with ThreadingServer(("0.0.0.0", PORT), Handler) as httpd:
        print(f"IFinance server em http://0.0.0.0:{PORT} | WEB_DIR={WEB_DIR}")
        print(f"Assessor IA: {'ATIVO' if LLM_ENABLED else 'DESLIGADO'} (modelo={LLM_MODEL})")
        httpd.serve_forever()
