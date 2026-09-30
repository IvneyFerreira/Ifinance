# Deploy da IA (Opção B) — Assessor IFinance na nuvem

Este guia coloca o **Assessor IA** funcionando de verdade no app instalado
(Android). A arquitetura é simples:

```
[Celular: IFinance]  --HTTPS-->  [Seu servidor: server.py]  --HTTPS-->  [IA (OpenAI/Groq/...)]
                                        ↑ guarda a chave secreta
```

- A **chave da IA nunca vai para o celular** — fica só no servidor.
- O **endereço do servidor** pode ser definido **dentro do app**
  (Configurações → Assistente IA), então você **não precisa recompilar** o APK
  para trocar de servidor.
- Todo o resto do app (finanças, backup, cálculos) continua **100% offline**.

---

## 1. Conseguir uma chave de IA (compatível com OpenAI)

Escolha um provedor e pegue uma **API key**:

| Provedor   | `OPENAI_BASE_URL`                 | `IFINANCE_LLM_MODEL`              |
| ---------- | --------------------------------- | --------------------------------- |
| OpenAI     | `https://api.openai.com/v1`       | `gpt-4o-mini` (barato) / `gpt-4o` |
| Groq       | `https://api.groq.com/openai/v1`  | `llama-3.3-70b-versatile`         |
| OpenRouter | `https://openrouter.ai/api/v1`    | ex.: `openai/gpt-4o-mini`         |
| DeepSeek   | `https://api.deepseek.com/v1`     | `deepseek-chat`                   |

> O `server.py` é compatível com **qualquer** endpoint no padrão OpenAI
> (`POST {BASE}/chat/completions`).

---

## 2. Publicar o servidor

O projeto já inclui `server.py`, `Dockerfile` e `Procfile` prontos.

### Opção A — Render.com (mais fácil, tem plano grátis)

1. Suba este repositório no **GitHub**.
2. No Render: **New → Web Service** → conecte o repositório.
3. O Render detecta o **`Dockerfile`** automaticamente (ou use:
   Build Command vazio / Start Command `python3 server.py`).
4. Em **Environment → Environment Variables**, adicione:

   ```env
   OPENAI_BASE_URL=https://api.openai.com/v1
   OPENAI_API_KEY=sk-sua-chave-secreta
   IFINANCE_LLM_MODEL=gpt-4o-mini
   IFINANCE_ALLOWED_ORIGINS=*
   IFINANCE_RATE_LIMIT=30
   ```

5. Deploy. Você recebe uma URL, ex.: `https://ifinance-ia.onrender.com`.

### Opção B — Railway / Fly.io

Mesmo esquema: conecte o repositório e configure as variáveis acima.
`Procfile` (`web: python3 server.py`) já está pronto para plataformas
baseadas em buildpacks.

### Opção C — VPS com Docker

```bash
flutter build web --release         # gera build/web
docker build -t ifinance .
docker run -d -p 80:5060 --restart always \
  -e OPENAI_BASE_URL="https://api.openai.com/v1" \
  -e OPENAI_API_KEY="sk-sua-chave" \
  -e IFINANCE_LLM_MODEL="gpt-4o-mini" \
  -e IFINANCE_ALLOWED_ORIGINS="*" \
  ifinance
```

---

## 3. Testar o servidor

Abra no navegador:

```
https://SEU-ENDEREÇO/api/health
```

Deve responder algo como:

```json
{ "status": "ok", "ai_enabled": true, "model": "gpt-4o-mini", ... }
```

- `"ai_enabled": true` → IA pronta ✅
- `"ai_enabled": false` → confira `OPENAI_BASE_URL` e `OPENAI_API_KEY`.

Teste a conversa (opcional):

```bash
curl -X POST https://SEU-ENDEREÇO/api/assessor \
  -H 'Content-Type: application/json' \
  -d '{"question":"Quanto entrou este mês?","context":{}}'
```

---

## 4. Apontar o app para o servidor

Você tem **duas** formas — a primeira **não exige recompilar**:

### 4.1 No próprio app (recomendado)

No app: **Menu → Configurações → Assistente IA**:

- Cole o endereço: `https://SEU-ENDEREÇO`
- Toque em **Testar** → deve mostrar *"Conectado! A IA está ativa no servidor."*
- Toque em **Salvar**.

Pronto — o chat do Assessor IA passa a funcionar. Para trocar de servidor,
basta repetir com outro endereço (sem reinstalar).

### 4.2 Embutido no APK (para já vir pronto)

```bash
flutter build apk --release \
  --dart-define=ASSESSOR_API_BASE=https://SEU-ENDEREÇO
```

Isso deixa o endereço como padrão de fábrica. O usuário ainda pode
sobrescrever na tela de Configurações.

> 🔐 Se você protegeu o servidor com token (`IFINANCE_API_TOKEN`), informe o
> mesmo valor no campo **"Token de acesso"** em Configurações → Assistente IA.

---

## 5. Segurança / custos

- **Rate limit** por IP: `IFINANCE_RATE_LIMIT` (padrão 30 req/min).
- **Token de acesso** (opcional, recomendado em servidor público):
  ```env
  IFINANCE_API_TOKEN=um-segredo-grande-e-aleatorio
  ```
  O app envia no cabeçalho `X-IFinance-Token`.
- **CORS**: use `IFINANCE_ALLOWED_ORIGINS=*` para apps nativos; se servir o
  app web de um domínio, restrinja a esse domínio.
- A **chave da IA** fica apenas no servidor — nunca no app.
- Para reduzir custo, use um modelo econômico (`gpt-4o-mini`,
  `llama-3.3-70b-versatile`) e um `IFINANCE_RATE_LIMIT` baixo.

---

## 6. Resumo

| Item                              | Onde fica                         |
| --------------------------------- | --------------------------------- |
| Chave da IA                       | Variável de ambiente do servidor   |
| Endereço do servidor              | Configurações do app (ou dart-define) |
| Dados financeiros do usuário      | Só no aparelho (offline)          |
| Chat da IA                        | Precisa de internet               |
| Todo o resto do app              | Funciona offline                  |

## 7. Solução de problemas

| Sintoma                                  | Causa provável / solução                              |
| ---------------------------------------- | ----------------------------------------------------- |
| "Servidor da IA não configurado"         | Defina o endereço em Configurações → Assistente IA     |
| "Não foi possível conectar"              | URL errada, servidor fora do ar, ou sem HTTPS          |
| `ai_enabled: false` no `/api/health`     | `OPENAI_BASE_URL`/`OPENAI_API_KEY` ausentes ou errados |
| Erro 401 no chat                         | Servidor com `IFINANCE_API_TOKEN`; informe o token no app |
| Erro 429                                 | Limite de requisições; aumente `IFINANCE_RATE_LIMIT`   |
| Erro 502                                 | A IA (provedor) recusou; confira a chave/saldo da conta |
