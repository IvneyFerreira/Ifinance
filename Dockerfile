# IFinance — imagem do backend (sirva o build web + Assessor IA).
# Uso:
#   docker build -t ifinance .
#   docker run -p 5060:5060 \
#     -e OPENAI_BASE_URL=... -e OPENAI_API_KEY=... \
#     -e IFINANCE_ALLOWED_ORIGINS="https://seu-app.com" \
#     ifinance
FROM python:3.12-slim

WORKDIR /app

# Apenas o build web já compilado + servidor (leve e sem SDK do Flutter).
COPY build/web ./build/web
COPY server.py ./

ENV PORT=5060 \
    WEB_DIR=/app/build/web \
    IFINANCE_LLM_MODEL=gpt-5.4-mini

EXPOSE 5060

CMD ["python3", "server.py"]
