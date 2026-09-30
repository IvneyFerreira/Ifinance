# IFinance — imagem do backend (serve o build web + Assessor IA + Passkeys).
#
# Build:
#   flutter build web --release          # gera build/web
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

# Build web já compilado + servidor (+ webauthn opcional para passkeys).
COPY build/web ./build/web
COPY server.py ./
COPY webauthn.py ./
COPY requirements.txt ./

# Passkeys (WebAuthn) são opcionais: se a instalação falhar, o servidor
# ainda sobe servindo o app e o Assessor IA.
RUN pip install --no-cache-dir -r requirements.txt || true

ENV PORT=5060 \
    WEB_DIR=/app/build/web \
    IFINANCE_LLM_MODEL=gpt-4o-mini

EXPOSE 5060

CMD ["python3", "server.py"]
