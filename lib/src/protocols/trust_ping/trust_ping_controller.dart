import 'dart:async';
import 'dart:convert';
import '../../crypto/signing/ldp_signer.dart';
import '../../crypto/encryption/jwe_encryptor.dart';
import '../../transport/service_didcomm.dart';
import '../../utils/logging.dart';
import '../../utils/error_handling.dart';
import 'trust_ping_message.dart';

/// Controlador para el protocolo Trust Ping
/// 
/// Implementa la lógica para enviar y recibir mensajes de Trust Ping
/// según la especificación DIDComm v2
class TrustPingController {
  final LdpSigner signer;
  final JweEncryptor encryptor;
  final DIDCommService commService;
  final Logger _logger;
  final ErrorHandler _errorHandler;
  
  // Mapa para almacenar los temporizadores de espera de respuestas
  final Map<String, Timer> _pendingPings = {};
  
  // Streams para las respuestas de ping y para los eventos de timeout
  final _pingResponseController = StreamController<TrustPingMessage>.broadcast();
  final _pingTimeoutController = StreamController<String>.broadcast();
  
  /// Constructor del controlador
  /// 
  /// Requiere un [signer] para firmar mensajes, un [encryptor] para cifrarlos
  /// y un [commService] para enviar/recibir mensajes
  /// [logger] - Logger para registro de operaciones (opcional)
  TrustPingController(this.signer, this.encryptor, this.commService, {Logger? logger}) : 
      _logger = logger ?? Logger(LogLevel.info),
      _errorHandler = ErrorHandler(logger ?? Logger(LogLevel.info)) {
    // Configuramos el listener para manejar respuestas de ping
    commService.listenToIncoming(_handleIncomingMessage);
  }
  
  /// Stream de respuestas a los pings enviados
  Stream<TrustPingMessage> get onPingResponse => _pingResponseController.stream;
  
  /// Stream de eventos de timeout cuando no hay respuesta
  Stream<String> get onPingTimeout => _pingTimeoutController.stream;
  
  /// Envía un mensaje de ping a un DID específico
  /// 
  /// [toDid] - DID del destinatario
  /// [responseRequested] - Si se espera una respuesta
  /// [comment] - Comentario opcional en el mensaje
  /// [timeoutSeconds] - Tiempo de espera en segundos para la respuesta
  /// 
  /// Retorna el ID del mensaje de ping enviado
  Future<String> sendPing(
    String toDid, {
    bool responseRequested = true,
    String? comment,
    int timeoutSeconds = 30,
  }) async {
    return _errorHandler.handleErrors<String>(
      function: () async {
        // Validación de entrada
        if (toDid.isEmpty) {
          throw DIDCommException(
            DIDCommErrorType.protocol,
            'El DID del destinatario no puede estar vacío'
          );
        }
        
        _logger.info('Enviando mensaje de ping', {
          'to': toDid,
          'responseRequested': responseRequested,
          'timeoutSeconds': timeoutSeconds,
        });
      
      // Crear mensaje de ping
      final pingMessage = TrustPingMessage.createPing(
        from: signer.didGen.myDid,
        to: toDid,
        responseRequested: responseRequested,
        comment: comment,
      );
      
      // Firmar mensaje
      final signed = await signer.sign(pingMessage.toJson());
      
      // Cifrar mensaje
      final encrypted = await encryptor.encrypt(signed, toDid);
      
      // Enviar mensaje
      await commService.send(jsonEncode(encrypted));
      
      // Si se requiere respuesta, configurar temporizador
      if (responseRequested) {
        _pendingPings[pingMessage.id] = Timer(
          Duration(seconds: timeoutSeconds),
          () => _handlePingTimeout(pingMessage.id),
        );
      }
      
      _logger.debug('Ping enviado exitosamente', {'id': pingMessage.id});
      return pingMessage.id;
      },
      errorType: DIDCommErrorType.communication,
      context: {
        'operation': 'sendPing', 
        'toDid': toDid,
        'responseRequested': responseRequested,
      },
      defaultErrorMessage: 'Error al enviar mensaje de ping'
    );
  }
  
  /// Maneja los mensajes entrantes
  /// 
  /// Procesa los mensajes recibidos y los clasifica según su tipo
  void _handleIncomingMessage(Map<String, dynamic> message) async {
    try {
      _logger.debug('Procesando mensaje entrante', {'type': message['@type']});
      if (message['@type'] == TrustPingTypes.ping) {
        // Si es un ping, respondemos automáticamente
        _respondToPing(TrustPingMessage.fromJson(message));
      } else if (message['@type'] == TrustPingTypes.pingResponse) {
        // Si es una respuesta a un ping, notificamos a los listeners
        final responseMsg = TrustPingMessage.fromJson(message);
        final pingId = responseMsg.thid;
        
        if (pingId != null && _pendingPings.containsKey(pingId)) {
          // Cancelamos el temporizador
          _pendingPings[pingId]?.cancel();
          _pendingPings.remove(pingId);
          
          // Notificamos la respuesta
          _pingResponseController.add(responseMsg);
        }
      }
    } catch (e) {
      _logger.error('Error procesando mensaje entrante', {'error': e.toString()});
    }
  }
  
  /// Responde automáticamente a un ping recibido
  /// 
  /// [pingMessage] - El mensaje de ping recibido
  Future<void> _respondToPing(TrustPingMessage pingMessage) async {
    return _errorHandler.handleErrors<void>(
      function: () async {
        _logger.info('Respondiendo a ping recibido', {'from': pingMessage.from});
      // Verificamos si el ping solicita respuesta
      final responseRequested = pingMessage.body['response_requested'] as bool? ?? true;
      
      if (responseRequested) {
        // Creamos mensaje de respuesta
        final responseMessage = TrustPingMessage.createPingResponse(
          pingMessage: pingMessage,
          comment: 'Respuesta automática de ping',
        );
        
        // Firmamos mensaje
        _logger.debug('Firmando respuesta de ping');
        final signed = await signer.sign(responseMessage.toJson());
        
        // Ciframos mensaje
        _logger.debug('Cifrando respuesta de ping para: ${pingMessage.from}');
        final encrypted = await encryptor.encrypt(signed, pingMessage.from);
        
        // Enviamos respuesta
        _logger.debug('Enviando respuesta de ping');
        await commService.send(jsonEncode(encrypted));
        _logger.info('Respuesta de ping enviada exitosamente');
      } else {
        _logger.info('No se requiere respuesta para el ping recibido');
      }
      },
      errorType: DIDCommErrorType.protocol,
      context: {'pingId': pingMessage.id, 'from': pingMessage.from},
      defaultErrorMessage: 'Error al responder al ping'
    );
  }
  
  /// Maneja el timeout de un ping
  /// 
  /// [pingId] - ID del mensaje de ping que expiró
  void _handlePingTimeout(String pingId) {
    _pendingPings.remove(pingId);
    _pingTimeoutController.add(pingId);
    _logger.warning('Timeout en ping', {'pingId': pingId});
  }
  
  /// Cierra los recursos utilizados por el controlador
  void dispose() {
    // Cancelar todos los temporizadores pendientes
    for (final timer in _pendingPings.values) {
      timer.cancel();
    }
    _pendingPings.clear();
    
    // Cerrar los streams controllers
    _pingResponseController.close();
    _pingTimeoutController.close();
    
    _logger.info('TrustPingController liberado');
  }
}
