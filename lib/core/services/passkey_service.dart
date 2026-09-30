import 'package:flutter/foundation.dart';
import 'package:passkeys/authenticator.dart';
import 'package:passkeys/types.dart';

// Login sem senha por Passkey (WebAuthn / FIDO2) — cap. 71.
//
// O IFinance atua como *cliente*. O servidor (`server.py`) é o *relying party*:
// gera os desafios (challenges) e verifica a assinatura com a chave pública
// registrada. A chave privada nunca sai do dispositivo (fica no cofre do
// sistema: Google Play Services no Android, iCloud Keychain no iOS, ou o
// autenticador do navegador no Web).
//
// Requisitos por plataforma:
// - Android: Digital Asset Links (`/.well-known/assetlinks.json`) no domínio
//   do relying party, com o package name e o fingerprint SHA-256 do certificado.
// - Web: o domínio precisa ser HTTPS e o RP ID igual ao host.

/// Pedido cancelado pelo usuário (fecha o diálogo do sistema).
class PasskeyCancelled implements Exception {
  const PasskeyCancelled();
  @override
  String toString() => 'Operação de passkey cancelada.';
}

/// Falha de passkey com mensagem amigável para a UI.
class PasskeyFailure implements Exception {
  const PasskeyFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// `true` em plataformas capazes de usar passkeys (Android, iOS e Web).
bool get passkeysSupported {
  if (kIsWeb) return true;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

PasskeyAuthenticator _newAuthenticator() => PasskeyAuthenticator();

/// Registra uma nova passkey a partir das opções emitidas pelo servidor.
/// [challengeJson] é o JSON de `PublicKeyCredentialCreationOptions`.
/// Retorna o JSON da credencial (para enviar de volta ao servidor) ou `null`
/// se o usuário cancelar.
Future<String?> passkeyRegister(String challengeJson) async {
  try {
    final authenticator = _newAuthenticator();
    final request = RegisterRequestType.fromJsonString(challengeJson);
    final response = await authenticator.register(request);
    return response.toJsonString();
  } on PasskeyAuthCancelledException {
    return null;
  } on PasskeyUnsupportedException {
    throw const PasskeyFailure('Este dispositivo não suporta passkeys.');
  } on SyncAccountNotAvailableException {
    throw const PasskeyFailure(
        'Entre com sua Conta Google no dispositivo para usar passkeys.');
  } on MissingGoogleSignInException {
    throw const PasskeyFailure(
        'Faça login na sua Conta Google para continuar.');
  } on DomainNotAssociatedException {
    throw const PasskeyFailure(
        'Domínio (Digital Asset Links) não configurado para passkeys.');
  } on DeviceNotSupportedException {
    throw const PasskeyFailure('Este dispositivo não suporta passkeys.');
  } on AuthenticatorException catch (e) {
    throw PasskeyFailure(_friendly(e));
  } catch (e) {
    throw PasskeyFailure(_friendly(e));
  }
}

/// Autentica com uma passkey já registrada.
/// [challengeJson] é o JSON de `PublicKeyCredentialRequestOptions`.
/// Retorna o JSON da asserção (para o servidor verificar) ou `null` se cancelar.
Future<String?> passkeyAuthenticate(String challengeJson) async {
  try {
    final authenticator = _newAuthenticator();
    final request = AuthenticateRequestType.fromJsonString(
      challengeJson,
      mediation: MediationType.Optional,
      preferImmediatelyAvailableCredentials: true,
    );
    final response = await authenticator.authenticate(request);
    return response.toJsonString();
  } on PasskeyAuthCancelledException {
    return null;
  } on NoCredentialsAvailableException {
    throw const PasskeyFailure(
        'Nenhuma passkey encontrada para esta conta neste dispositivo.');
  } on NoCreateOptionException {
    throw const PasskeyFailure(
        'Nenhuma passkey encontrada para esta conta neste dispositivo.');
  } on PasskeyUnsupportedException {
    throw const PasskeyFailure('Este dispositivo não suporta passkeys.');
  } on DomainNotAssociatedException {
    throw const PasskeyFailure(
        'Domínio (Digital Asset Links) não configurado para passkeys.');
  } on AuthenticatorException catch (e) {
    throw PasskeyFailure(_friendly(e));
  } catch (e) {
    throw PasskeyFailure(_friendly(e));
  }
}

String _friendly(Object e) {
  final raw = e.toString();
  if (raw.contains('SyncAccountNotAvailable') || raw.contains('Google Account')) {
    return 'Entre com sua Conta Google no dispositivo para usar passkeys.';
  }
  if (raw.contains('NoCredentialsAvailable') ||
      raw.contains('NoCreateOption')) {
    return 'Nenhuma passkey encontrada para esta conta neste dispositivo.';
  }
  if (raw.contains('unsupported') || raw.contains('NotSupported')) {
    return 'Este dispositivo não suporta passkeys.';
  }
  return 'Não foi possível concluir a operação de passkey. Tente novamente.';
}
