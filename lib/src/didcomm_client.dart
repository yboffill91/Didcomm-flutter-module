import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'crypto/signing/ldp_signer.dart';
import 'crypto/encryption/jwe_encryptor.dart';
import 'crypto/verification/ldp_verifier.dart';
import 'crypto/did/did_generator.dart';
import 'transport/service_didcomm.dart';
import 'service/did_resolver.dart';
import 'messaging/message_model.dart';
import 'protocols/trust_ping/trust_ping_controller.dart';
import 'protocols/mediation/mediator_controller.dart';
import 'config/didcomm_config.dart';
import 'utils/logging.dart';

/// Clase principal del cliente DIDComm
///
/// Esta clase sirve como punto de entrada para todas las funcionalidades
/// del sistema DIDComm y facilita la creación e inyección de dependencias
class DIDCommClient {
  // Componentes internos
  final DidGenerator didGenerator;
  final DIDCommConfig config;
  final Logger _logger;
  
  // Servicios principales
  late final LdpSigner _signer;
  late final JweEncryptor _encryptor;
  late final LdpVerifier _verifier;
  late final DIDCommService _commService;
  late final DIDResolver _didResolver;
  
  // Controladores de protocolos
  late final TrustPingController _pingController;
  late final MediatorController _mediatorController;
  
  // Stream controller para mensajes recibidos
  final StreamController<Map<String, dynamic>> _messageStreamController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  /// Devuelve un stream para escuchar mensajes recibidos
  Stream<Map<String, dynamic>> get onMessage => _messageStreamController.stream;
  
  /// Constructor privado usado por la factory
  DIDCommClient._({
    required this.didGenerator,
    required this.config,
    Logger? logger,
  }) : _logger = logger ?? Logger(LogLevel.fromString(config.logLevel)) {
    _initializeServices();
  }
  
  /// Inicializa todos los servicios y controladores internos
  void _initializeServices() {
    // Inicializar servicios base
    _didResolver = DIDResolver(config, logger: _logger);
    _signer = LdpSigner(didGenerator, logger: _logger);
    _verifier = LdpVerifier(_didResolver, logger: _logger);
    _encryptor = JweEncryptor(didGenerator, _didResolver, logger: _logger);
    _commService = DIDCommService(_signer, _encryptor, config);
    
    // Inicializar controladores de protocolos
    _pingController = TrustPingController(_signer, _encryptor, _commService);
    _mediatorController = MediatorController(
      _signer,
      _encryptor,
      _commService,
      config: config,
      pingController: _pingController,
    );
    
    // Configurar listener global para mensajes entrantes
    _commService.listenToIncoming((message) {
      _messageStreamController.add(message);
    });
    
    _logger.info('Cliente DIDComm inicializado correctamente', {
      'did': didGenerator.myDid,
      'transport': config.useWebSockets ? 'WebSocket' : 'HTTP',
    });
  }
  
  /// Crea un nuevo cliente DIDComm con una configuración específica
  ///
  /// [config] - Configuración para el cliente
  /// [existingDidJson] - JSON serializado de un DID existente (opcional)
  /// [logLevel] - Nivel de logging (opcional)
  ///
  /// Retorna un Future con el cliente DIDComm inicializado
  static Future<DIDCommClient> create({
    DIDCommConfig? config,
    String? existingDidJson,
    String logLevel = 'info',
  }) async {
    // Cargar variables de entorno si no se han cargado ya
    try {
      await dotenv.load(fileName: 'assets/.env');
    } catch (e) {
      // Ignorar errores si no se puede cargar el archivo .env
    }
    
    // Crear o usar la configuración proporcionada
    final clientConfig = config ?? DIDCommConfig.fromEnv();
    
    // Configurar logger
    final logger = Logger(LogLevel.fromString(logLevel));
    
    // Crear o cargar el generador de DID
    final didGenerator = existingDidJson != null
        ? await DidGenerator.fromSerialized(existingDidJson, logger: logger)
        : await DidGenerator.create(logger: logger);
    
    // Crear y devolver el cliente
    return DIDCommClient._(
      didGenerator: didGenerator,
      config: clientConfig,
      logger: logger,
    );
  }
  
  // === API pública para operaciones básicas ===
  
  /// Obtiene el DID actual del cliente
  String get myDid => didGenerator.myDid;
  
  /// Serializa las claves del cliente para almacenamiento
  Future<String> serializeKeys() => didGenerator.serialize();
  
  /// Envía un mensaje DIDComm genérico
  ///
  /// [message] - Mensaje a enviar
  Future<bool> sendMessage(DIDCommMessage message) async {
    try {
      return await _commService.send(message);
    } catch (e) {
      _logger.error('Error al enviar mensaje', {'error': e.toString()});
      return false;
    }
  }
  
  /// Verifica un mensaje firmado recibido
  ///
  /// [signedMessage] - Mensaje firmado a verificar
  Future<bool> verifyMessage(Map<String, dynamic> signedMessage) {
    return _verifier.verify(signedMessage);
  }
  
  // === API pública para protocolos específicos ===
  
  /// Envía un mensaje de ping para verificar conectividad
  ///
  /// [toDid] - DID del destinatario
  /// [responseRequested] - Si se espera una respuesta
  /// [comment] - Comentario opcional en el mensaje
  /// [timeoutSeconds] - Tiempo de espera en segundos
  Future<String> sendPing(
    String toDid, {
    bool responseRequested = true,
    String? comment,
    int timeoutSeconds = 30,
  }) {
    return _pingController.sendPing(
      toDid,
      responseRequested: responseRequested,
      comment: comment,
      timeoutSeconds: timeoutSeconds,
    );
  }
  
  /// Stream para recibir respuestas a pings enviados
  Stream get onPingResponse => _pingController.onPingResponse;
  
  /// Stream para recibir eventos de timeout de ping
  Stream<String> get onPingTimeout => _pingController.onPingTimeout;
  
  /// Envía una solicitud de mediación a un mediador
  ///
  /// [mediatorDid] - DID del mediador
  /// [verifyConnectivity] - Si se debe verificar conectividad con ping primero
  /// [timeoutSeconds] - Tiempo de espera para el ping
  Future<bool> requestMediation(
    String mediatorDid, {
    bool verifyConnectivity = true,
    int timeoutSeconds = 30,
  }) {
    return _mediatorController.sendMediateRequest(
      mediatorDid,
      verifyConnectivity: verifyConnectivity,
      timeoutSeconds: timeoutSeconds,
    );
  }
  
  /// Envía una actualización de claves mediadas
  ///
  /// [mediatorDid] - DID del mediador
  /// [addDids] - DIDs a añadir
  /// [removeDids] - DIDs a eliminar
  Future<bool> updateMediatedKeys(
    String mediatorDid, {
    List<String> addDids = const [],
    List<String> removeDids = const [],
  }) {
    return _mediatorController.sendMediationUpdate(
      mediatorDid,
      addDids: addDids,
      removeDids: removeDids,
    );
  }
  
  /// Libera los recursos utilizados por el cliente
  void dispose() {
    _messageStreamController.close();
    _pingController.dispose();
    _commService.dispose();
    _logger.info('Cliente DIDComm cerrado');
  }
}
