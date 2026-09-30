import 'package:http/http.dart' as http;
import 'ai_config.dart';
import 'http_client_stub.dart' if (dart.library.io) 'http_client_io.dart' as impl;

/// Cria o cliente HTTP padrão do app.
///
/// - No **Android/iOS** usa um cliente que respeita [AiConfig.verifySsl]
///   (permite servidores de teste com certificado self-signed).
/// - No **Web** devolve o cliente padrão (o navegador cuida do TLS).
http.Client createDefaultClient() => impl.createDefaultClient();
