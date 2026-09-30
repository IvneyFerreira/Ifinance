import 'package:http/http.dart' as http;

/// Implementação para o **Web**: usa o cliente padrão (XHR/fetch).
/// O navegador é responsável pelo TLS/no CORS.
http.Client createDefaultClient() => http.Client();
