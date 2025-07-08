import 'package:uuid/uuid.dart';

/// Constantes para los tipos de mensajes de Trust Ping
class TrustPingTypes {
  static const String ping = 'https://didcomm.org/trust-ping/2.0/ping';
  static const String pingResponse =
      'https://didcomm.org/trust-ping/2.0/ping-response';
}

/// Modelo para representar un mensaje Trust Ping según la especificación DIDComm v2
class TrustPingMessage {
  final String id;
  final String type;
  final String from;
  final String to;
  final Map<String, dynamic> body;
  final String? thid;
  final DateTime created;
  final DateTime expires;

  /// Constructor para un mensaje Trust Ping
  ///
  /// [id] - Identificador único del mensaje (generado automáticamente si no se proporciona)
  /// [type] - Tipo de mensaje (ping o ping-response)
  /// [from] - DID del remitente
  /// [to] - DID del destinatario
  /// [body] - Cuerpo del mensaje, contiene los datos específicos del tipo de mensaje
  /// [thid] - Thread ID para correlacionar respuestas (opcional)
  /// [created] - Fecha de creación (por defecto ahora)
  /// [expires] - Fecha de expiración (por defecto 5 minutos desde created)
  TrustPingMessage({
    String? id,
    required this.type,
    required this.from,
    required this.to,
    required this.body,
    this.thid,
    DateTime? created,
    DateTime? expires,
  })  : id = id ?? const Uuid().v4(),
        created = created ?? DateTime.now().toUtc(),
        expires =
            expires ?? DateTime.now().toUtc().add(const Duration(minutes: 5));

  /// Convierte el mensaje a un Map<String, dynamic> para serialización
  Map<String, dynamic> toJson() => {
        '@id': id,
        '@type': type,
        'from': from,
        'to': to,
        'body': body,
        'created_time': created.toIso8601String(),
        'expires_time': expires.toIso8601String(),
        if (thid != null) 'thid': thid,
      };

  /// Crea un mensaje de ping para verificar conexión
  ///
  /// [from] - DID del remitente
  /// [to] - DID del destinatario
  /// [responseRequested] - Si se requiere respuesta
  /// [comment] - Comentario opcional para el ping
  static TrustPingMessage createPing({
    required String from,
    required String to,
    bool responseRequested = true,
    String? comment,
  }) {
    return TrustPingMessage(
      type: TrustPingTypes.ping,
      from: from,
      to: to,
      body: {
        'response_requested': responseRequested,
        if (comment != null) 'comment': comment,
      },
    );
  }

  /// Crea una respuesta a un mensaje de ping
  ///
  /// [pingMessage] - El mensaje de ping original
  /// [comment] - Comentario opcional para la respuesta
  static TrustPingMessage createPingResponse({
    required TrustPingMessage pingMessage,
    String? comment,
  }) {
    return TrustPingMessage(
      type: TrustPingTypes.pingResponse,
      from: pingMessage.to, // Invertimos remitente/destinatario
      to: pingMessage.from,
      thid: pingMessage.id, // Referenciamos el ID del ping original
      body: comment != null ? {'comment': comment} : {},
    );
  }

  /// Crea un TrustPingMessage desde un Map<String, dynamic>
  static TrustPingMessage fromJson(Map<String, dynamic> json) {
    return TrustPingMessage(
      id: json['@id'],
      type: json['@type'],
      from: json['from'],
      to: json['to'],
      body: json['body'],
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
