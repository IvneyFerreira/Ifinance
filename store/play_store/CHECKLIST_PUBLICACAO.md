# IFinance — Kit de Publicação na Google Play Store

Tudo que você precisa para publicar o IFinance. Versão do app: **1.0.0**
Pacote: `com.ifinance.app`

---

## 1. Estrutura deste kit

```
store/play_store/
├── graphics/
│   ├── feature_graphic_1024x500.png   ✅ pronto (Banner da loja — obrigatório)
│   └── app_icon_512x512.png           ✅ pronto (Ícone da loja — obrigatório)
├── screenshots/
│   ├── 01_inicio.png          ✅ 1080×1920
│   ├── 02_movimentacoes.png   ✅ 1080×1920
│   ├── 03_assessor_ia.png     ✅ 1080×1920
│   ├── 04_planejar.png        ✅ 1080×1920
│   ├── 05_metas.png           ✅ 1080×1920
│   ├── 06_perfil.png          ✅ 1080×1920
│   └── 07_menu.png            ✅ 1080×1920
├── listing/
│   ├── descricao_curta.txt            ✅ até 80 caracteres
│   ├── descricao_completa.txt         ✅ até 4000 caracteres
│   ├── notas_versao.txt               ✅ "O que há de novo"
│   └── metadados.txt                  ✅ categoria, tags, contato
├── capturar_screenshots.py            ✅ script pronto (Chrome headless)
└── CHECKLIST_PUBLICACAO.md            ← este arquivo
```

---

## 2. Especificações da loja (já atendidas)

| Recurso | Exigência do Google | Status |
|---|---|---|
| Ícone da loja | 512×512 PNG (32 bits) | ✅ `app_icon_512x512.png` |
| Gráfico de destaque | 1024×500 PNG/JPG | ✅ `feature_graphic_1024x500.png` |
| Screenshots (telefone) | 2–8 imagens, 16:9 ou 9:16, mín. 320px | ✅ 7 imagens 1080×1920 |
| Descrição curta | ≤ 80 caracteres | ✅ |
| Descrição completa | ≤ 4000 caracteres | ✅ |
| Política de privacidade | URL pública obrigatória | ⚠️ publique uma URL |

---

## 3. Screenshots (captura)

O IFinance é um app de finanças: capture as telas **Início, Movimentações,
Assessor IA, Planejar, Metas, Perfil e o menu lateral (gaveta)**.
Formato recomendado: **1080×1920 (9:16)**.

### Opção A — captura automática (Chrome headless — recomendado)

O script controla o app de verdade via Chrome DevTools Protocol (cliques na
barra inferior + abertura do menu) e salva as imagens já em **1080×1920**:

```bash
# 1) Sirva o build web localmente (use a porta 8099; a 5060 é bloqueada pelo Chrome)
cd /home/user/flutter_app
python3 server.py 8099 &   # ou: python3 -m http.server 8099 --directory build/web &

# 2) Rode o script de captura (usa google-chrome headless via CDP)
python3 store/play_store/capturar_screenshots.py http://localhost:8099
```

### Opção B — captura manual (melhor qualidade)

1. Abra o app no Chrome (modo dispositivo móvel, 1080×1920).
2. Registre algumas despesas e entradas para o app ficar com dados reais.
3. Use a ferramenta de screenshot do navegador em cada tela.
4. Salve em `store/play_store/screenshots/` como `01_painel.png`,
   `02_transacoes.png`, etc.

> Dica: evite telas vazias. Dados reais (valores, categorias) aumentam
> bastante a taxa de conversão na loja.

---

## 4. Checklist de publicação

### Antes de enviar
- [ ] App compila em release (APK/AAB) sem erros — ✅ feito
- [ ] `flutter analyze` limpo (0 issues) — ✅ feito
- [ ] Ícone e feature graphic gerados — ✅ feito
- [ ] Descrições (curta + completa) prontas — ✅ feito
- [x] Screenshots capturados (7 imagens 1080×1920)
- [ ] **Keystore oficial gerado e guardado em local seguro** (ver seção 5)
- [ ] Política de privacidade publicada em URL pública
- [ ] `google-services.json` (se usar Firebase) com o package correto

### No Play Console (https://play.google.com/console)
- [ ] Criar o aplicativo (nome: **IFinance**, idioma padrão: Português (BR))
- [ ] Preencher "Presença na loja": nome, descrição curta, descrição completa
- [ ] Enviar ícone 512×512 e gráfico de destaque 1024×500
- [ ] Enviar 2–8 screenshots de telefone
- [ ] **Classificação de conteúdo**: preencher questionário (Finanças → Livre)
- [ ] **Segurança dos dados**: declarar coleta/uso de dados
- [ ] **Público-alvo**: 18+ (app financeiro)
- [ ] **Apps de finanças**: anexar declaração/isenção se solicitado
- [ ] Configurar **Play App Signing** (recomendado)
- [ ] Enviar AAB (`app-release.aab`) para a **faixa de teste interno** primeiro
- [ ] Testar, depois promover para **produção**

---

## 5. Keystore oficial (importante!)

O build atual usa uma chave **de teste** (`android/release-key.jks`). Para
publicar de verdade, gere uma chave oficial e **guarde-a com segurança** —
se perdê-la, não conseguirá atualizar o app na loja.

```bash
keytool -genkey -v -keystore ifinance-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias ifinance
```

Depois aponte o `android/key.properties` para essa chave e atualize
`IFINANCE_ANDROID_SHA256` (no backend) com o fingerprint SHA-256:

```bash
keytool -list -v -keystore ifinance-upload.jks -alias ifinance | grep SHA256
```

---

## 6. Passkeys (WebAuthn) na loja

O login por passkey exige **Digital Asset Links**. Depois de publicar:

1. Obtenha o fingerprint SHA-256 do certificado (**do upload key E do Play
   App Signing**).
2. Configure no backend:
   ```bash
   IFINANCE_RP_ID=seu-dominio.com
   IFINANCE_ANDROID_PACKAGE=com.ifinance.app
   IFINANCE_ANDROID_SHA256=AA:BB:...,CC:DD:...
   ```
3. Confirme que `https://seu-dominio.com/.well-known/assetlinks.json` está
   acessível (o `server.py` já o serve) e retorna `application/json`.

---

## 7. Build do pacote final

```bash
# App Bundle para a Play Store (recomendado)
cd /home/user/flutter_app
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab
```

Pronto! Com este kit, basta subir os arquivos no Play Console.
