import 'package:uuid/uuid.dart';
import '../../crypto/signing/ldp_signer.dart';
import '../../crypto/encryption/jwe_encryptor.dart';
import '../../transport/service_didcomm.dart';
import '../../messaging/message_model.dart';
import '../../utils/logging.dart';
import '../../config/didcomm_config.dart';
import '../trust_ping/ping_first_strategy.dart';
import '../trust_ping/trust_ping_controller.dart';

/// Controlador para el protocolo de mediación
/// 
/// Esta clase implementa la lógica para establecer y mantener
/// una relación de mediación con un mediador DID según la
/// especificación DIDComm v2
class MediatorController {
  final LdpSigner signer;
  final JweEncryptor encryptor;
  final DIDCommService commService;
  final Logger _logger;
  final PingFirstStrategy? _pingStrategy;
  
  /// Constructor del controlador
  /// 
  /// [signer] - Firmante para mensajes
  /// [encryptor] - Encriptador para mensajes
  /// [commService] - Servicio de comunicación DIDComm
  /// [config] - Configuración DIDComm
  /// [pingController] - Controlador de Trust Ping (opcional)
  MediatorController(
    this.signer, 
    this.encryptor, 
    this.commService, {
    required DIDCommConfig config,
    TrustPingController? pingController,
  }) : 
    _logger = Logger(LogLevel.fromString(config.logLevel)),
    _pingStrategy = pingController != null ? PingFirstStrategy(pingController) : null;

  /// Envía una solicitud de mediación a un DID mediador específico
  /// 
  /// [mediatorDid] - DID del mediador al que se enviará la solicitud
  /// [verifyConnectivity] - Si se debe verificar la conectividad con ping antes
  /// [timeoutSeconds] - Tiempo de espera para el ping (si aplica)
  /// 
  /// Retorna un [Future<bool>] que indica si la solicitud fue enviada correctamente
  Future<bool> sendMediateRequest(
    String mediatorDid, {
    bool verifyConnectivity = true,
    int timeoutSeconds = 30,
  }) async {
    try {
      // Validación de entrada
      if (mediatorDid.isEmpty) {
        throw Exception('El DID del mediador no puede estar vacío');
      }
      
      // Función que realiza el envío real de la solicitud
      Future<bool> performSendRequest() async {
        _logger.info('Enviando solicitud de mediación', {'mediatorDid': mediatorDid});
        
        final msg = DIDCommMessage(
          id: const Uuid().v4(),
          type: 'https://didcomm.org/coordinate-mediation/2.0/mediate-request',
          from: signer.didGen.myDid,
          to: mediatorDid,
          body: {},
        );
        
        return await commService.send(msg);
      }
      
      // Si tenemos estrategia de ping y queremos verificar conectividad
      if (_pingStrategy != null && verifyConnectivity) {
        _logger.debug('Verificando conectividad antes de enviar solicitud');
        
        final result = await _pingStrategy!.executeWithPingCheck<bool>(
          toDid: mediatorDid,
          operation: performSendRequest,
          timeoutSeconds: timeoutSeconds,
          comment: 'Verificación previa a solicitud de mediación',
          onTimeout: () {
            _logger.error('Timeout al intentar conectar con el mediador', {'mediatorDid': mediatorDid});
          },
        );
        
        return result ?? false;
      } else {
        // Enviar directamente sin ping previo
        return await performSendRequest();
      }
    } catch (e) {
      _logger.error('Error al enviar solicitud de mediación', {'error': e.toString()});
      throw Exception('Error al procesar la solicitud de mediación: ${e.toString()}');
    }
  }
  
  /// Envía una solicitud de concesión de mediación
  /// 
  /// Este mensaje se envía en respuesta a una grant-message desde el mediador
  /// [mediatorDid] - DID del mediador
  /// [recipientDids] - DIDs adicionales que queremos registrar con el mediador
  Future<bool> sendMediationGrant(String mediatorDid, {List<String> recipientDids = const []}) async {
    try {
      _logger.info('Enviando concesión de mediación', {
        'mediatorDid': mediatorDid,
        'recipientCount': recipientDids.length
      });
      
      final msg = DIDCommMessage(
        type: 'https://didcomm.org/coordinate-mediation/2.0/mediate-grant',
        from: signer.didGen.myDid,
        to: mediatorDid,
        body: {
          'recipient_dids': recipientDids,
        },
      );
      
      return await commService.send(msg);
    } catch (e) {
      _logger.error('Error al enviar concesión de mediación', {'error': e.toString()});
      return false;
    }
  }
  
  /// Envía una solicitud para actualizar las claves de mediación
  /// 
  /// [mediatorDid] - DID del mediador
  /// [addDids] - DIDs a añadir a la mediación
  /// [removeDids] - DIDs a eliminar de la mediación
  Future<bool> sendMediationUpdate(
    String mediatorDid, {
    List<String> addDids = const [],
    List<String> removeDids = const [],
  }) async {
    try {
      _logger.info('Enviando actualización de mediación', {
        'mediatorDid': mediatorDid,
        'addCount': addDids.length,
        'removeCount': removeDids.length,
      });
      
      final msg = DIDCommMessage(
        type: 'https://didcomm.org/coordinate-mediation/2.0/keylist-update',
        from: signer.didGen.myDid,
        to: mediatorDid,
        body: {
          'updates': [
            ...addDids.map((did) => {
              'action': 'add',
              'recipient_did': did,
            }),
            ...removeDids.map((did) => {
              'action': 'remove',
              'recipient_did': did,
            }),
          ],
        },
      );
      
      return await commService.send(msg);
    } catch (e) {
      _logger.error('Error al enviar actualización de mediación', {'error': e.toString()});
      return false;
    }
  }
  
  /// Consulta la lista de claves mediadas actualmente
  /// 
  /// [mediatorDid] - DID del mediador
  /// [limit] - Límite de resultados a devolver
  Future<bool> queryMediatorKeylist(String mediatorDid, {int? limit}) async {
    try {
      _logger.info('Consultando lista de claves mediadas', {'mediatorDid': mediatorDid});
      
      final msg = DIDCommMessage(
        type: 'https://didcomm.org/coordinate-mediation/2.0/keylist-query',
        from: signer.didGen.myDid,
        to: mediatorDid,
        body: limit != null ? {'paginate': {'limit': limit}} : {},
      );
      
      return await commService.send(msg);
    } catch (e) {
      _logger.error('Error al consultar lista de claves', {'error': e.toString()});
      return false;
    }
  }
}
