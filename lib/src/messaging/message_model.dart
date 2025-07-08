import 'package:uuid/uuid.dart';

/// Clase base para mensajes DIDComm
/// 
/// Esta clase implementa el formato básico de mensajes DIDComm v2
class DIDCommMessage {
  final String id;
  final String type;
  final String from;
  final String to;
  final Map<String, dynamic> body;
  final String? thid;
  final DateTime? created;
  final DateTime? expires;

  /// Constructor del mensaje DIDComm
  /// 
  /// [id] - Identificador único del mensaje (generado automáticamente si no se proporciona)
  /// [type] - URI que identifica el tipo de mensaje según el protocolo
  /// [from] - DID del remitente
  /// [to] - DID del destinatario
  /// [body] - Cuerpo del mensaje con contenido específico del tipo
  /// [thid] - Thread ID para correlacionar respuestas (opcional)
  /// [created] - Fecha de creación (opcional, por defecto ahora)
  /// [expires] - Fecha de expiración (opcional)
  DIDCommMessage({
    String? id,
    required this.type,
    required this.from,
    required this.to,
    required this.body,
    this.thid,
    this.created,
    this.expires,
  }) : id = id ?? const Uuid().v4();

  /// Convierte el mensaje a formato JSON para serialización
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      '@id': id,
      '@type': type,
      'from': from,
      'to': to,
      'body': body,
    };
    
    // Añadir campos opcionales si están presentes
    if (thid != null) json['thid'] = thid;
    if (created != null) json['created_time'] = created!.toIso8601String();
    if (expires != null) json['expires_time'] = expires!.toIso8601String();
    
    return json;
  }

  /// Crea un mensaje a partir de un mapa JSON
  static DIDCommMessage fromJson(Map<String, dynamic> json) {
    return DIDCommMessage(
      id: json['@id'],
      type: json['@type'],
      from: json['from'],
      to: json['to'],
      body: json['body'] ?? {},
      thid: json['thid'],
      created: json['created_time'] != null 
        ? DateTime.parse(json['created_time']) 
        : null,
      expires: json['expires_time'] != null 
        ? DateTime.parse(json['expires_time']) 
        : null,
    );
  }
}
