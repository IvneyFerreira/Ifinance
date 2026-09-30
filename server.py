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

try:
    import webauthn as wa
    _WEBAUTHN_IMPORT_ERROR = None
except Exception as _e:  # pragma: no cover - depende do ambiente
    wa = None
    _WEBAUTHN_IMPORT_ERROR = str(_e)

APP_VERSION = "1.1.0"

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
# Token de acesso opcional (se definido, o app precisa enviá-lo no cabeçalho
# X-IFinance-Token). Recomendado para servidores públicos.
API_TOKEN = os.environ.get("IFINANCE_API_TOKEN", "").strip()

# --- Passkeys (WebAuthn) ----------------------------------------------------
# Domínio do relying party (RP ID). Sem esquema. Ex.: app.ifinance.com.br
PASSKEY_RP_ID = os.environ.get("IFINANCE_RP_ID", "").strip()
PASSKEY_RP_NAME = os.environ.get("IFINANCE_RP_NAME", "IFinance").strip()
# Origens autorizadas (além do próprio RP ID), separadas por vírgula.
# Padrão: https://<RP_ID> e http://localhost:<PORT>
_extra_origins = os.environ.get("IFINANCE_PASSKEY_ORIGINS", "").strip()
PASSKEY_ORIGINS = [o.strip() for o in _extra_origins.split(",") if o.strip()]
if PASSKEY_RP_ID:
    PASSKEY_ORIGINS += [f"https://{PASSKEY_RP_ID}"]
PASSKEY_ORIGINS += [f"http://localhost:{PORT}", f"http://127.0.0.1:{PORT}"]
PASSKEY_ORIGINS = list(dict.fromkeys(PASSKEY_ORIGINS))
# Pacote Android e fingerprints para o assetlinks.json (Digital Asset Links).
PASSKEY_ANDROID_PACKAGE = os.environ.get(
    "IFINANCE_ANDROID_PACKAGE", "com.ifinance.app").strip()
_PKG = os.environ.get("IFINANCE_ANDROID_SHA256", "").strip()
PASSKEY_ANDROID_SHA256 = [f.strip() for f in _PKG.split(",") if f.strip()]

PASSKEY_STORE_PATH = os.environ.get(
    "IFINANCE_PASSKEY_STORE",
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "passkeys.json"),
)
PASSKEY_ENABLED = bool(wa and PASSKEY_RP_ID)
PASSKEY_STORE = wa.PasskeyStore(PASSKEY_STORE_PATH) if PASSKEY_ENABLED else None

# --- Backup automático na nuvem (cap. 73) -----------------------------------
# Guarda um "envelope" CIFRADO por conta (AES-GCM, chave derivada da senha do
# usuário). O servidor NUNCA consegue ler o conteúdo — apenas armazena o blob.
SYNC_ENABLED = os.environ.get("IFINANCE_SYNC_ENABLED", "1").lower() not in (
    "0", "false", "no", "")
SYNC_STORE_PATH = os.environ.get(
    "IFINANCE_SYNC_STORE",
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "sync_store.json"),
)
# Limite de tamanho por backup (bytes do JSON). Evita abuso de disco/memória.
SYNC_MAX_BYTES = int(os.environ.get("IFINANCE_SYNC_MAX_BYTES", str(8 * 1024 * 1024)))


class SyncStore:
    """Armazém simples (arquivo JSON) de backups cifrados por conta."""

    def __init__(self, path: str):
        self.path = path
        self._lock = threading.Lock()
        self._data = {}
        self._load()

    def _load(self):
        if os.path.isfile(self.path):
            try:
                with open(self.path, "r", encoding="utf-8") as fh:
                    self._data = json.load(fh)
            except Exception:
                self._data = {}
        if not isinstance(self._data, dict):
            self._data = {}

    def _save(self):
        tmp = self.path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump(self._data, fh, ensure_ascii=False)
        os.replace(tmp, self.path)

    @staticmethod
    def valid_account_id(account_id: str) -> bool:
        return bool(account_id) and account_id.isalnum() and 16 <= len(account_id) <= 128

    def info(self, account_id: str):
        with self._lock:
            entry = self._data.get(account_id)
        if not entry:
            return {"exists": False}
        blob = entry.get("envelope", {}).get("blob", "")
        return {
            "exists": True,
            "updatedAt": entry.get("updatedAt"),
            "size": len(blob),
        }

    def save(self, account_id: str, envelope: dict):
        with self._lock:
            self._data[account_id] = {
                "envelope": envelope,
                "updatedAt": datetime.utcnow().isoformat() + "Z",
                "savedAt": int(time.time()),
            }
            self._save()

    def load(self, account_id: str):
        with self._lock:
            entry = self._data.get(account_id)
        if not entry:
            return None
        return entry.get("envelope")

    def snapshot(self):
        return {"accounts": len(self._data), "path": os.path.basename(self.path)}


SYNC_STORE = SyncStore(SYNC_STORE_PATH) if SYNC_ENABLED else None

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


def _as_dict(value) -> dict:
    """Garante que o valor seja um dict (tolerante a payloads malformados)."""
    return value if isinstance(value, dict) else {}


def _as_list(value) -> list:
    """Garante que o valor seja uma lista de dicts."""
    if not isinstance(value, list):
        return []
    return [item for item in value if isinstance(item, dict)]


def _build_context_prompt(context: dict) -> str:
    """Transforma o contexto estruturado (vindo do FinanceEngine) em texto."""
    context = _as_dict(context)
    lines = []
    lines.append("### CONTEXTO FINANCEIRO (despesas, entradas e controle)")
    lines.append(f"Data de referência: {context.get('today', datetime.now().strftime('%d/%m/%Y'))}")
    lines.append(f"Mês de referência: {context.get('monthLabel', '')}")

    month = _as_dict(context.get("month"))
    lines.append("\n**Resumo do mês**")
    lines.append(f"- Entradas (receitas) do mês: {month.get('income', 'R$ 0,00')}")
    lines.append(f"- Despesas do mês: {month.get('expense', 'R$ 0,00')}")
    lines.append(f"- Resultado do mês (entradas - despesas): {month.get('result', 'R$ 0,00')}")
    lines.append(f"- Taxa de poupança: {month.get('savingsRate', '-')}")
    lines.append(f"- Comprometido até o fim do mês: {month.get('committed', 'R$ 0,00')}")
    lines.append(f"- Saldo disponível hoje: {context.get('available', 'R$ 0,00')}")
    lines.append(f"- Livre para gastar com segurança: {context.get('safeToSpend', 'R$ 0,00')}")
    lines.append(f"- Próximo recebimento: {context.get('nextIncome', 'sem previsão')}")

    cats = _as_list(context.get("topCategories"))
    lines.append("\n**Onde o usuário mais gastou neste mês**")
    if cats:
        for i, c in enumerate(cats, 1):
            lines.append(f"{i}. {c.get('name')}: {c.get('amount')} ({c.get('percent', '')} do total)")
    else:
        lines.append("- Nenhuma despesa registrada neste mês.")

    incomes = _as_list(context.get("incomes"))
    lines.append("\n**Entradas / receitas do mês**")
    if incomes:
        for inc in incomes[:8]:
            lines.append(f"- {inc.get('name')}: {inc.get('amount')} em {inc.get('date', '')}")
    else:
        lines.append("- Nenhuma receita registrada neste mês.")

    recent = _as_list(context.get("recentExpenses"))
    lines.append("\n**Últimas despesas registradas**")
    if recent:
        for r in recent[:10]:
            lines.append(f"- {r.get('date', '')} | {r.get('name')} | {r.get('category')} | {r.get('amount')}")
    else:
        lines.append("- Sem despesas recentes.")

    subs = _as_dict(context.get("subscriptions"))
    lines.append("\n**Assinaturas / recorrentes de despesa**")
    lines.append(f"- Custo mensal em assinaturas: {subs.get('monthly', 'R$ 0,00')}")
    lines.append(f"- Custo anual em assinaturas: {subs.get('annual', 'R$ 0,00')}")
    if subs.get("list"):
        for s in _as_list(subs["list"])[:8]:
            lines.append(f"   • {s.get('name')}: {s.get('amount')} ({s.get('freq', '')})")

    cards = _as_list(context.get("cards"))
    lines.append("\n**Faturas de cartão (gastos)**")
    if cards:
        for c in cards:
            lines.append(f"- {c.get('name')}: fatura atual {c.get('currentInvoice')}, disponível {c.get('available')}")
    else:
        lines.append("- Nenhum cartão cadastrado.")

    budgets = _as_list(context.get("budgets"))
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
                "auth_required": bool(API_TOKEN),
                "passkeys_enabled": PASSKEY_ENABLED,
                "cloud_backup_enabled": SYNC_ENABLED,
            })
            return
        if self.path.startswith("/api/passkey/health"):
            self._send_json(200, {
                "passkeys_enabled": PASSKEY_ENABLED,
                "rp_id": PASSKEY_RP_ID or None,
                "origins": PASSKEY_ORIGINS,
                "store": PASSKEY_STORE.snapshot() if PASSKEY_STORE else None,
            })
            return
        if self.path.startswith("/api/sync/"):
            self._handle_sync_get(self.path)
            return
        if self.path.startswith("/.well-known/assetlinks.json"):
            body = wa.assetlinks_json(
                PASSKEY_ANDROID_PACKAGE, PASSKEY_ANDROID_SHA256
            ) if wa else []
            body_bytes = json.dumps(body, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body_bytes)))
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(body_bytes)
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
        if self.path.startswith("/api/passkey/"):
            self._handle_passkey(self.path)
            return
        if self.path.startswith("/api/sync/"):
            self._handle_sync_post(self.path)
            return
        if not self.path.startswith("/api/assessor"):
            self._send_json(404, {"error": "not found"})
            return

        # Token opcional (se configurado no servidor).
        if API_TOKEN and self.headers.get("X-IFinance-Token", "") != API_TOKEN:
            self._send_json(401, {"error": "Não autorizado."})
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
        history = _as_list(payload.get("history"))

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

    # --- Backup na nuvem (sync) --------------------------------------------- #
    def _handle_sync_get(self, path):
        if not SYNC_ENABLED:
            self._send_json(503, {"enabled": False, "error": "Backup na nuvem desativado."})
            return
        from urllib.parse import urlparse, parse_qs
        query = parse_qs(urlparse(path).query)

        if path.startswith("/api/sync/health"):
            self._send_json(200, {"enabled": True, "store": SYNC_STORE.snapshot()})
            return
        if path.startswith("/api/sync/info"):
            account_id = (query.get("accountId") or [""])[0]
            if not SyncStore.valid_account_id(account_id):
                self._send_json(400, {"error": "accountId inválido."})
                return
            self._send_json(200, SYNC_STORE.info(account_id))
            return
        if path.startswith("/api/sync/load"):
            account_id = (query.get("accountId") or [""])[0]
            if not SyncStore.valid_account_id(account_id):
                self._send_json(400, {"error": "accountId inválido."})
                return
            envelope = SYNC_STORE.load(account_id)
            if envelope is None:
                self._send_json(404, {"error": "Nenhum backup encontrado."})
                return
            self._send_json(200, {"envelope": envelope})
            return
        self._send_json(404, {"error": "Endpoint de sync desconhecido."})

    def _handle_sync_post(self, path):
        if not SYNC_ENABLED:
            self._send_json(503, {"enabled": False, "error": "Backup na nuvem desativado."})
            return
        # Token opcional (o mesmo do app), quando configurado no servidor.
        if API_TOKEN and self.headers.get("X-IFinance-Token", "") != API_TOKEN:
            self._send_json(401, {"error": "Não autorizado."})
            return
        client_ip = self.client_address[0] if self.client_address else "?"
        if not _rate_ok(client_ip):
            self._send_json(429, {"error": "Muitas requisições. Tente mais tarde."})
            return

        payload = self._read_json()
        if payload is None:
            self._send_json(400, {"error": "JSON inválido."})
            return
        account_id = (payload.get("accountId") or "").strip()
        envelope = payload.get("envelope")
        if not SyncStore.valid_account_id(account_id):
            self._send_json(400, {"error": "accountId inválido."})
            return
        if not isinstance(envelope, dict) or not envelope.get("blob"):
            self._send_json(400, {"error": "Envelope inválido."})
            return
        if len(json.dumps(envelope)) > SYNC_MAX_BYTES:
            self._send_json(413, {"error": "Backup excede o tamanho máximo."})
            return

        if path.startswith("/api/sync/save"):
            SYNC_STORE.save(account_id, envelope)
            self._send_json(200, {"ok": True, "store": SYNC_STORE.snapshot()})
            return
        self._send_json(404, {"error": "Endpoint de sync desconhecido."})

    # --- Passkeys (WebAuthn) ------------------------------------------------ #
    def _read_json(self):
        try:
            length = int(self.headers.get("Content-Length", "0"))
            raw = self.rfile.read(length) if length else b"{}"
            return json.loads(raw or b"{}")
        except Exception:
            return None

    def _origin_allowed(self):
        origin = self.headers.get("Origin", "")
        return (origin in PASSKEY_ORIGINS) if PASSKEY_ORIGINS else True

    def _handle_passkey(self, path):
        if not PASSKEY_ENABLED:
            detail = "Passkeys desativadas."
            if _WEBAUTHN_IMPORT_ERROR:
                detail = f"Dependências ausentes: {_WEBAUTHN_IMPORT_ERROR}"
            elif not PASSKEY_RP_ID:
                detail = "IFINANCE_RP_ID não configurado no servidor."
            self._send_json(503, {"error": detail})
            return
        if not self._origin_allowed():
            self._send_json(403, {"error": "Origem não autorizada."})
            return

        payload = self._read_json()
        if payload is None:
            self._send_json(400, {"error": "JSON inválido"})
            return

        try:
            if path.startswith("/api/passkey/register/start"):
                username = (payload.get("username") or "").strip()
                display = (payload.get("displayName") or username).strip()
                if not username:
                    raise ValueError("username obrigatório.")
                cid, options = wa.create_registration_options(
                    PASSKEY_STORE, username, display,
                    PASSKEY_RP_ID, PASSKEY_RP_NAME,
                )
                self._send_json(200, {"challengeId": cid, "options": options})
                return

            if path.startswith("/api/passkey/register/finish"):
                cid = payload.get("challengeId") or ""
                credential = payload.get("credential") or {}
                username, origin = wa.verify_registration(
                    PASSKEY_STORE, cid, credential, PASSKEY_RP_ID
                )
                self._send_json(200, {
                    "verified": True, "username": username, "origin": origin,
                })
                return

            if path.startswith("/api/passkey/login/start"):
                username = (payload.get("username") or "").strip()
                if not username:
                    raise ValueError("username obrigatório.")
                cid, options = wa.create_authentication_options(
                    PASSKEY_STORE, username, PASSKEY_RP_ID
                )
                self._send_json(200, {"challengeId": cid, "options": options})
                return

            if path.startswith("/api/passkey/login/finish"):
                cid = payload.get("challengeId") or ""
                credential = payload.get("credential") or {}
                username, origin = wa.verify_authentication(
                    PASSKEY_STORE, cid, credential, PASSKEY_RP_ID
                )
                self._send_json(200, {
                    "verified": True, "username": username, "origin": origin,
                })
                return

            self._send_json(404, {"error": "Endpoint de passkey desconhecido."})
        except ValueError as e:
            self._send_json(400, {"error": str(e)[:300]})
        except Exception as e:  # pragma: no cover
            self._send_json(500, {"error": f"Falha na operação de passkey: {str(e)[:200]}"})


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
