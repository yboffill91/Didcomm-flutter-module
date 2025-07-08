import 'dart:async';
import '../../utils/logging.dart';
import '../../utils/error_handling.dart';
import 'trust_ping_controller.dart';

/// Estrategia para realizar un ping antes de una operación DIDComm
/// 
/// Esta clase implementa un patrón de estrategia que permite
/// verificar la conectividad con un DID antes de realizar
/// una operación de comunicación más compleja
class PingFirstStrategy {
  final TrustPingController _pingController;
  final Logger _logger;
  final ErrorHandler _errorHandler;
  
  /// Constructor de la estrategia
  /// 
  /// Requiere un controlador de Trust Ping
  /// [logger] - Logger para registro de operaciones (opcional)
  PingFirstStrategy(this._pingController, {Logger? logger}) :
    _logger = logger ?? Logger(LogLevel.info),
    _errorHandler = ErrorHandler(logger ?? Logger(LogLevel.info));
  
  /// Ejecuta una operación sólo si el ping previo es exitoso
  /// 
  /// [toDid] - DID del destinatario
  /// [operation] - Función a ejecutar si el ping tiene éxito
  /// [timeoutSeconds] - Tiempo de espera para el ping
  /// [comment] - Comentario opcional para el mensaje de ping
  /// [onTimeout] - Función a ejecutar en caso de timeout
  /// 
  /// Retorna un Future con el resultado de la operación
  /// o null si falló el ping
  /// Ejecuta una operación sólo si el ping previo es exitoso
  /// 
  /// [toDid] - DID del destinatario
  /// [operation] - Función a ejecutar si el ping tiene éxito
  /// [timeoutSeconds] - Tiempo de espera para el ping
  /// [comment] - Comentario opcional para el mensaje de ping
  /// [onTimeout] - Función a ejecutar en caso de timeout
  /// 
  /// Retorna un Future con el resultado de la operación
  /// o null si falló el ping
  Future<T?> executeWithPingCheck<T>({
    required String toDid,
    required Future<T> Function() operation,
    int timeoutSeconds = 30,
    String? comment,
    void Function()? onTimeout,
  }) async {
    return _errorHandler.handleErrors<T?>(
      function: () async {
        _logger.info('Ejecutando operación con verificación de ping', {'toDid': toDid});
        
        // Crear completer para esperar la respuesta del ping
        final completer = Completer<bool>();
        
        // Suscribirse a las respuestas y timeouts
        late StreamSubscription<dynamic> responseSubscription;
        late StreamSubscription<dynamic> timeoutSubscription;
    
        // Enviar ping y obtener su ID
        _logger.debug('Enviando ping de verificación');
        final pingId = await _pingController.sendPing(
      toDid,
      responseRequested: true,
      comment: comment ?? 'Verificación de conectividad',
      timeoutSeconds: timeoutSeconds,
    );
    
        // Suscribirse para recibir respuestas de ping
        responseSubscription = _pingController.onPingResponse.listen((response) {
          _logger.debug('Recibida respuesta de ping', {'responseId': response.id});
          if (response.thid == pingId) {
            _logger.info('Verificación de ping exitosa', {'pingId': pingId});
            completer.complete(true);
            responseSubscription.cancel();
            timeoutSubscription.cancel();
          }
    });
    
        // Suscribirse para recibir timeouts de ping
        timeoutSubscription = _pingController.onPingTimeout.listen((id) {
          if (id == pingId) {
            _logger.warning('Timeout en verificación de ping', {'pingId': pingId});
            completer.complete(false);
            responseSubscription.cancel();
            timeoutSubscription.cancel();
            onTimeout?.call();
          }
        });
    
        // Esperar el resultado del ping
        final pingSuccess = await completer.future;
        
        // Cancelar suscripciones si aún están activas
        responseSubscription.cancel();
        timeoutSubscription.cancel();
    
        // Ejecutar la operación sólo si el ping fue exitoso
        if (pingSuccess) {
          _logger.info('Ejecutando operación tras ping exitoso');
          return await operation();
        } else {
          _logger.warning('Operación cancelada debido a fallo en ping');
          return null;
        }
      },
      errorType: DIDCommErrorType.communication,
      context: {'operation': 'executeWithPingCheck', 'toDid': toDid},
      defaultErrorMessage: 'Error al ejecutar operación con verificación de ping'
    );
  }
}
