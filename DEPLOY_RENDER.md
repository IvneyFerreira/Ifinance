# 🚀 Deploy do Servidor de IA do IFinance (Render) — em 1 clique

Este guia coloca o **Assessor IA** na internet, de graça, em ~15 minutos.
Depois disso, o app instalado (APK) conversa com a IA de qualquer lugar — **sem
recompilar nada**.

> Por que preciso disso? A IA precisa de um servidor que guarde a **chave da
> API em segredo**. O APK é só um cliente: ele conversa com esse servidor.

---

## 📋 O que você vai precisar

| Item | Onde conseguir |
|---|---|
| Conta no GitHub (já tem: `IvneyFerreira/Ifinance`) | https://github.com |
| Conta no Render (grátis) | https://render.com |
| Uma **chave de IA** compatível com OpenAI | ver seção abaixo |

### 🔑 Chave de IA — opções

Escolha **uma**:

1. **OpenAI** (paga, qualidade alta)
   - https://platform.openai.com/api-keys → *Create new secret key*
   - `OPENAI_BASE_URL = https://api.openai.com/v1`
   - `OPENAI_API_KEY = sk-...`
   - `IFINANCE_LLM_MODEL = gpt-4o-mini`

2. **OpenRouter** (tem modelos grátis)
   - https://openrouter.ai/keys → *Create Key*
   - `OPENAI_BASE_URL = https://openrouter.ai/api/v1`
   - `OPENAI_API_KEY = sk-or-...`
   - `IFINANCE_LLM_MODEL = meta-llama/llama-3.1-8b-instruct:free`

3. **Groq** (grátis e muito rápido)
   - https://console.groq.com/keys
   - `OPENAI_BASE_URL = https://api.groq.com/openai/v1`
   - `OPENAI_API_KEY = gsk_...`
   - `IFINANCE_LLM_MODEL = llama-3.1-8b-instant`

4. **Qualquer provedor compatível com OpenAI** — basta a URL base, a chave e o
   nome do modelo.

---

## ✅ Caminho 1 — Render com Blueprint (recomendado, 1 clique)

O arquivo `render.yaml` já está no repositório. O Render lê tudo sozinho.

### Passo 1. Abra o Blueprints
👉 https://dashboard.render.com/blueprints

### Passo 2. Clique em **New Blueprint Instance**

### Passo 3. Conecte o GitHub
- Clique em **Connect account** (se ainda não conectou)
- Autorize o Render a ver seus repositórios
- Escolha **`IvneyFerreira/Ifinance`**
- Clique em **Connect**

### Passo 4. Confirme o serviço
O Render mostra o serviço **`ifinance-assessor`** já configurado. Clique em **Apply**.

### Passo 5. Preencha as variáveis da IA
Na tela que aparece (ou depois em *Environment*), preencha:

| Variável | Valor |
|---|---|
| `OPENAI_BASE_URL` | a URL do seu provedor (ex.: `https://api.openai.com/v1`) |
| `OPENAI_API_KEY` | sua chave secreta |
| `IFINANCE_LLM_MODEL` | o modelo (ex.: `gpt-4o-mini`) |
| `IFINANCE_API_TOKEN` | *(opcional)* um segredo seu, ex.: `meu-token-secreto-123` |

> 💡 **Recomendo preencher `IFINANCE_API_TOKEN`**: evita que estranhos usem sua chave de IA.

### Passo 6. Aguarde o deploy
Leva ~3 minutos. Quando aparecer **"Live"** ✅ verde, está no ar.

Sua URL será algo como:
```
https://ifinance-assessor.onrender.com
```

### Passo 7. Copie a URL
No topo do painel do Render, copie a URL do serviço (`https://ifinance-assessor-xxxx.onrender.com`).

---

## ✅ Caminho 2 — Render manual (se preferir do zero)

1. https://dashboard.render.com → **New** → **Web Service**
2. Conecte `IvneyFerreira/Ifinance`
3. Preencha:
   - **Name**: `ifinance-assessor`
   - **Language/Runtime**: **Docker**
   - **Dockerfile Path**: `./Dockerfile`
   - **Instance Type**: **Free**
   - **Health Check Path**: `/api/health`
4. Em **Environment Variables**, adicione as 4 variáveis da IA (Passo 5 acima).
5. Clique em **Create Web Service**.

---

## 📱 Passo final — Conectar o app ao servidor

Agora configure o app (não precisa recompilar!):

1. Abra o **IFinance**
2. Vá em **Configurações** (menu ☰ ou aba inferior)
3. Toque em **Assistente IA**
4. Preencha:
   - **Endereço do servidor**: `https://ifinance-assessor-xxxx.onrender.com`
   - **Token**: o mesmo valor de `IFINANCE_API_TOKEN` (se você definiu)
5. Toque em **Testar** → deve aparecer ✅ **"Conectado"**
6. Toque em **Salvar**

Pronto! Abra a aba **Assessor IA** e converse. 🎉

---

## 🧪 Como testar pelo navegador

Abra a URL do seu servidor + `/api/health`:

```
https://ifinance-assessor-xxxx.onrender.com/api/health
```

Resposta esperada:
```json
{
  "status": "ok",
  "version": "1.1.0",
  "ai_enabled": true,
  "model": "gpt-4o-mini",
  "auth_required": true
}
```

- `"ai_enabled": true` → a chave está correta ✅
- `"auth_required": true` → você definiu um token ✅

Se `"ai_enabled": false`, revise `OPENAI_BASE_URL` e `OPENAI_API_KEY`.

---

## 💰 Custos

| Serviço | Plano | Observação |
|---|---|---|
| Render | **Free** | Dorme após 15 min de inatividade; acorda em ~30 s no primeiro uso |
| IA | varia | OpenAI cobra por uso; OpenRouter/Groq têm camadas grátis |

> No plano Free do Render, a primeira mensagem do dia pode demorar ~30 s
> (o servidor está "acordando"). As seguintes são instantâneas.

---

## 🛠️ Problemas comuns

### "Build failed" no Render
- Confirme que **Dockerfile Path** = `./Dockerfile`
- Confirme que **Runtime** = `Docker`

### Health check falhando
- O caminho deve ser exatamente `/api/health`
- Veja os logs no Render (*Logs*)

### App diz "Servidor da IA não configurado"
- Você ainda não preencheu o endereço em **Configurações → Assistente IA**

### App diz "Não autorizado" (401)
- O servidor exige token, mas o app não tem (ou está diferente)
- Copie o valor de `IFINANCE_API_TOKEN` para o campo **Token** no app

### App diz "IA indisponível" (502)
- A chave está errada, sem créditos, ou o modelo não existe no provedor
- Teste o `/api/health` e confira `ai_enabled`

### CORS / erro de origem
- O `render.yaml` já define `IFINANCE_ALLOWED_ORIGINS=*` (libera tudo)
- Se você restringir, inclua a origem do app (`https://...`)

---

## 🔒 Segurança

- ✅ A chave da IA fica **apenas no Render** — nunca no APK
- ✅ Use `IFINANCE_API_TOKEN` em servidores públicos
- ✅ `IFINANCE_RATE_LIMIT=30` limita abuso (30 req/min por IP)
- ✅ O repositório **não** contém segredos (`.env` e keystore estão no `.gitignore`)
- ⚠️ Nunca faça commit de `.env`, `key.properties` ou `release-key.jks`

---

## 🖥️ Alternativa: VPS própria (avançado)

Se preferir sua própria máquina (Ubuntu + Docker):

```bash
# 1. Clone o repositório
git clone https://github.com/IvneyFerreira/Ifinance.git
cd Ifinance

# 2. Crie o .env
cp .env.example .env
nano .env      # preencha OPENAI_BASE_URL, OPENAI_API_KEY, IFINANCE_API_TOKEN

# 3. Suba o container
docker build -t ifinance .
docker run -d --name ifinance --restart unless-stopped \
  -p 80:5060 --env-file .env ifinance

# 4. Teste
curl http://SEU_IP/api/health
```

> Para HTTPS, coloque um Nginx/Caddy na frente, ou use Cloudflare Tunnel.

---

## 📞 Resumo em uma frase

**Faça o Passo 1–7 no Render, copie a URL, cole em Configurações → Assistente IA. Pronto.**
