import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../crypto/signing/ldp_signer.dart';
import '../crypto/encryption/jwe_encryptor.dart';
import '../messaging/message_model.dart';
import '../utils/logging.dart';
import '../config/didcomm_config.dart';

/// Servicio principal para comunicación DIDComm
/// 
/// Esta clase proporciona la funcionalidad básica para enviar y recibir
/// mensajes DIDComm, con soporte para HTTP/HTTPS y WebSockets
class DIDCommService {
  final LdpSigner signer;
  final JweEncryptor encryptor;
  final DIDCommConfig config;
  final Logger _logger;
  WebSocketChannel? _wsChannel;

  /// Constructor del servicio DIDComm
  /// 
  /// [signer] - Firmante para mensajes
  /// [encryptor] - Encriptador para mensajes
  /// [config] - Configuración del servicio
  DIDCommService(this.signer, this.encryptor, this.config) : 
    _logger = Logger(LogLevel.fromString(config.logLevel));

  /// Envía un mensaje DIDComm
  /// 
  /// [message] - Mensaje a enviar (puede ser un objeto DIDCommMessage o directamente un Map)
  /// [skipEncryption] - Si se debe omitir la encriptación (para mensajes ya cifrados)
  /// 
  /// Retorna true si el envío fue exitoso
  Future<bool> send(dynamic message) async {
    try {
      // Convertir a formato JSON si es un objeto DIDCommMessage
      Map<String, dynamic> jsonMessage;
      String recipientDid;
      
      if (message is DIDCommMessage) {
        jsonMessage = message.toJson();
        recipientDid = message.to;
      } else if (message is Map<String, dynamic>) {
        jsonMessage = message;
        recipientDid = message['to'];
      } else if (message is String) {
        // Si ya es una cadena JSON, asumimos que está completamente procesado
        final jsonBody = message;
        return await _sendPreparedMessage(jsonBody);
      } else {
        throw ArgumentError('El mensaje debe ser un DIDCommMessage, un Map o una cadena JSON');
      }
      
      // Firmar el mensaje
      _logger.debug('Firmando mensaje');
      final signed = await signer.sign(jsonMessage);
      
      // Cifrar el mensaje
      _logger.debug('Cifrando mensaje para $recipientDid');
      final encrypted = await encryptor.encrypt(signed, recipientDid);
      
      // Serializar a JSON
      final jsonBody = jsonEncode(encrypted);
      
      return await _sendPreparedMessage(jsonBody);
    } catch (e) {
      _logger.error('Error al enviar mensaje', {'error': e.toString()});
      return false;
    }
  }

  /// Envía un mensaje ya preparado (firmado y cifrado)
  Future<bool> _sendPreparedMessage(String jsonBody) async {
    try {
      if (config.useWebSockets) {
        // Enviar por WebSocket
        _logger.debug('Enviando mensaje por WebSocket');
        _getOrCreateWebSocket().sink.add(jsonBody);
      } else {
        // Enviar por HTTP/HTTPS
        _logger.debug('Enviando mensaje por HTTP');
        final response = await http.post(
          Uri.parse(config.transportEndpoint),
          headers: {'Content-Type': 'application/didcomm-encrypted+json'},
          body: jsonBody,
        );
        
        if (response.statusCode != 200) {
          _logger.warning('Respuesta HTTP no exitosa', {
            'statusCode': response.statusCode,
            'body': response.body
          });
          return false;
        }
      }
      return true;
    } catch (e) {
      _logger.error('Error al enviar mensaje preparado', {'error': e.toString()});
      return false;
    }
  }

  /// Obtiene o crea un canal WebSocket
  WebSocketChannel _getOrCreateWebSocket() {
    if (_wsChannel == null) {
      _logger.debug('Creando nueva conexión WebSocket');
      _wsChannel = WebSocketChannel.connect(Uri.parse(config.wsEndpoint));
    }
    return _wsChannel!;
  }

  /// Escucha mensajes entrantes
  /// 
  /// [onMessage] - Función a llamar cuando se recibe un mensaje
  void listenToIncoming(void Function(Map<String, dynamic>) onMessage) {
    if (config.useWebSockets) {
      // Escuchar en WebSocket
      final ws = _getOrCreateWebSocket();
      ws.stream.listen(
        (event) {
          try {
            final msg = jsonDecode(event);
            _logger.debug('Mensaje recibido por WebSocket');
            onMessage(msg);
          } catch (e) {
            _logger.error('Error al procesar mensaje WebSocket', {'error': e.toString()});
          }
        },
        onError: (error) {
          _logger.error('Error en WebSocket', {'error': error.toString()});
        },
        onDone: () {
          _logger.info('Conexión WebSocket cerrada');
          // Reiniciar WebSocket para futuros intentos
          _wsChannel = null;
        }
      );
    } else {
      _logger.warning('La escucha de mensajes entrantes sólo está disponible en modo WebSocket');
    }
  }

  /// Cierra los recursos utilizados por el servicio
  void dispose() {
    _wsChannel?.sink.close();
    _wsChannel = null;
    _logger.info('Servicio DIDComm cerrado');
  }
}
