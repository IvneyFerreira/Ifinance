package com.ifinance.app

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity é OBRIGATÓRIA para o plugin local_auth (biometria):
// a API de autenticação por digital/rosto exige uma FragmentActivity para
// exibir o prompt do sistema. Com FlutterActivity o fluxo falha silenciosamente.
class MainActivity : FlutterFragmentActivity()
