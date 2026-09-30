# IFinance — imagem do backend (Assessor IA + Passkeys).
#
# ⚠️  Este container roda em MODO API: expõe /api/health e /api/assessor.
#     É o que o APK Android precisa (o app é o cliente da API).
#
# O build web do Flutter (build/web) NÃO é copiado de propósito: ele é um
# artefato de build (está no .gitignore) e sua ausência quebraria o build do
# Docker. Para servir também o site estático, use o passo opcional no final.
#
# Build:
#   docker build -t ifinance .
#
# Run:
#   docker run -p 5060:5060 \
#     -e OPENAI_BASE_URL="https://api.openai.com/v1" \
#     -e OPENAI_API_KEY="sk-sua-chave" \
#     -e IFINANCE_LLM_MODEL="gpt-4o-mini" \
#     -e IFINANCE_ALLOWED_ORIGINS="*" \
#     ifinance
FROM python:3.12-slim

WORKDIR /app

# Servidor + Passkeys + dependências (arquivos versionados).
COPY server.py ./
COPY webauthn.py ./
COPY requirements.txt ./

# Passkeys (WebAuthn) são opcionais: se a instalação falhar, o servidor
# ainda sobe servindo o Assessor IA.
RUN pip install --no-cache-dir -r requirements.txt || true

# Diretório web vazio (o servidor tolera): mantém o modo somente-API.
RUN mkdir -p /app/build/web

ENV PORT=5060 \
    WEB_DIR=/app/build/web \
    IFINANCE_LLM_MODEL=gpt-4o-mini

EXPOSE 5060

CMD ["python3", "server.py"]

# ---------------------------------------------------------------------------
# OPCIONAL: servir também o app web (site estático) no mesmo container.
# Descomente as 2 linhas abaixo SOMENTE se você versionar build/web no repo
# (ou usar um estágio de build do Flutter). Caso contrário, deixe comentado.
# ---------------------------------------------------------------------------
# COPY build/web/ /app/build/web/
# RUN test -f /app/build/web/index.html || echo "web ausente: modo API"
