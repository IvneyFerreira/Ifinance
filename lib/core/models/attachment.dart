/// Anexo (comprovante) vinculado a uma movimentação (cap. 42).
///
/// O conteúdo é guardado em base64 dentro do próprio banco local (Hive),
/// mantendo a filosofia "seus dados são seus": nada é enviado para fora.
class Attachment {
  final String id;
  final String userId;
  final String transactionId;
  final String name;
  final String mimeType;
  final int sizeBytes;
  /// Conteúdo bruto em base64.
  final String dataBase64;
  final DateTime createdAt;

  const Attachment({
    required this.id,
    required this.userId,
    required this.transactionId,
    required this.name,
    this.mimeType = 'application/octet-stream',
    this.sizeBytes = 0,
    required this.dataBase64,
    required this.createdAt,
  });

  bool get isImage => mimeType.startsWith('image/');
  bool get isPdf => mimeType == 'application/pdf';

  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Attachment copyWith({
    String? name,
    String? mimeType,
    int? sizeBytes,
    String? dataBase64,
  }) {
    return Attachment(
      id: id,
      userId: userId,
      transactionId: transactionId,
      name: name ?? this.name,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      dataBase64: dataBase64 ?? this.dataBase64,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'transactionId': transactionId,
        'name': name,
        'mimeType': mimeType,
        'sizeBytes': sizeBytes,
        'dataBase64': dataBase64,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Attachment.fromMap(Map<String, dynamic> m) => Attachment(
        id: m['id'] as String,
        userId: m['userId'] as String,
        transactionId: (m['transactionId'] as String?) ?? '',
        name: (m['name'] as String?) ?? 'documento',
        mimeType: (m['mimeType'] as String?) ?? 'application/octet-stream',
        sizeBytes: (m['sizeBytes'] as num?)?.toInt() ?? 0,
        dataBase64: (m['dataBase64'] as String?) ?? '',
        createdAt: DateTime.tryParse((m['createdAt'] as String?) ?? '') ??
            DateTime.now(),
      );
}
