import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'ai_config.dart';

/// Implementação para **Android/iOS/Desktop**: permite desativar a validação
/// de TLS quando o usuário marcar "não verificar SSL" (servidores de teste).
http.Client createDefaultClient() {
  final client = HttpClient();
  client.badCertificateCallback = (cert, host, port) => !AiConfig.verifySsl;
  return IOClient(client);
}
