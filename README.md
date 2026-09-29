# IFinance

**Personal Financial Command Center** — Sua vida financeira em movimento. Sob controle.

O IFinance responde às perguntas que realmente importam:

- Quanto eu tenho?
- Quanto está comprometido?
- Quanto está realmente livre?
- Como eu vou terminar o mês?

## Descrição

Aplicativo Flutter (Android + Web/PWA) de gestão financeira pessoal, com tema escuro premium (grafite/esmeralda) e uma camada central de cálculo financeiro (`FinanceEngine`) que separa a lógica das telas.

## Principais recursos

- **Dashboard** inteligente (saldo seguro, comprometido, projeção de fim de mês)
- **Contas, Cartões e Faturas** (com parcelamento sem perder centavos)
- **Transações** (receitas, despesas e transferências entre contas)
- **Calendário financeiro** e recorrentes
- **Planejamento, Orçamentos e Metas**
- **Patrimônio, Dívidas e Assinaturas**
- **Simulador** de cenários e **Radar** de alertas
- **IFinance Assessor** (assistente financeiro)
- **Relatórios** e **Notificações**

## Arquitetura

- `lib/core/finance` — `FinanceEngine` (toda a lógica financeira)
- `lib/core/models` — modelos de domínio (dinheiro sempre em centavos `int`)
- `lib/core/db` — persistência local com Hive (isolamento multi-usuário)
- `lib/core/services` — autenticação, seed demo
- `lib/state` — `AppController` (Provider / ChangeNotifier)
- `lib/ui` — telas organizadas por módulo

## Como executar

```bash
flutter pub get
flutter run            # Android
flutter build web --release
```

## Documentação

- Flutter: https://docs.flutter.dev/
