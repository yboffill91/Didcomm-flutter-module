import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:bs58/bs58.dart' as bs58;
import 'package:thirds/blake3.dart';
import '../../utils/logging.dart';
import '../../config/didcomm_config.dart';

class DidGenerator {
  final SimpleKeyPair keyPair;
  final PublicKey publicKey;
  final String myDid;
  final Logger _logger;

  /// Constructor privado para uso en la factory
  DidGenerator._internal(
      this.keyPair, this.publicKey, this.myDid, this._logger);

  /// Crea una instancia del generador con nuevas claves
  ///
  /// [config] - Configuración de DIDComm
  /// [logger] - Logger para registro de operaciones (opcional)
  static Future<DidGenerator> create({
    DIDCommConfig? config,
    Logger? logger,
  }) async {
    final log = logger ?? Logger(LogLevel.info);
    log.info('Generando nuevo par de claves Ed25519');

    try {
      // Generamos un nuevo par de claves Ed25519
      final algorithm = Ed25519();
      final keyPair = await algorithm.newKeyPair();
      final publicKey = await keyPair.extractPublicKey();

      // Extraemos los bytes de la clave pública
      // Para Ed25519, la clave pública es una SimplePublicKey que tiene bytes directamente
      final List<int> publicKeyBytes = publicKey.bytes;

      // Construimos el DID usando blake3 como en la versión original
      // Utilizamos blake3Hex para generar el hash de la clave pública
      final hash = blake3Hex(publicKeyBytes).substring(0, 24);
      // Formato del DID: did:mydsc:key:{hash}
      final did = 'did:mydsc:key:$hash';

      log.info('Generación de DID completada', {'did': did});

      return DidGenerator._internal(keyPair, publicKey, did, log);
    } catch (e) {
      log.error('Error al generar DID', {'error': e.toString()});
      rethrow;
    }
  }

  /// Crea una instancia del generador desde un par de claves existente
  ///
  /// [serializedKeyPair] - Par de claves serializado en formato JSON
  /// [logger] - Logger para registro de operaciones (opcional)
  static Future<DidGenerator> fromSerialized(
    String serializedKeyPair, {
    Logger? logger,
  }) async {
    final log = logger ?? Logger(LogLevel.info);
    log.info('Cargando par de claves existente');

    try {
      // Deserializamos el par de claves
      final keyMap = jsonDecode(serializedKeyPair);
      final privateKeyBytes = base64Url.decode(keyMap['privateKey']);

      // Reconstruimos el par de claves
      final algorithm = Ed25519();
      final secretKey = SecretKey(privateKeyBytes);
      final seed = await secretKey.extractBytes();
      final keyPair = await algorithm.newKeyPairFromSeed(seed);
      final publicKey = await keyPair.extractPublicKey();

      // Reconstruimos el DID usando blake3 como en la versión original
      final List<int> publicKeyBytes = (publicKey as SimplePublicKey).bytes;
      // Utilizamos blake3Hex para generar el hash de la clave pública
      final hash = blake3Hex(publicKeyBytes).substring(0, 24);
      // Formato del DID: did:mydsc:key:{hash}
      final did = 'did:mydsc:key:$hash';

      log.info('Carga de DID existente completada', {'did': did});

      return DidGenerator._internal(keyPair, publicKey, did, log);
    } catch (e) {
      log.error('Error al cargar par de claves', {'error': e.toString()});
      throw Exception(
          'Error al deserializar el par de claves: ${e.toString()}');
    }
  }

  /// Serializa el par de claves para almacenamiento
  ///
  /// Retorna una representación JSON del par de claves privadas
  Future<String> serialize() async {
    try {
      final privateKeyData = await keyPair.extractPrivateKeyBytes();
      final Map<String, dynamic> keyData = {
        'privateKey': base64Url.encode(privateKeyData),
        'algorithm': 'Ed25519',
        'created': DateTime.now().toIso8601String(),
      };
      return jsonEncode(keyData);
    } catch (e) {
      _logger
          .error('Error al serializar par de claves', {'error': e.toString()});
      throw Exception('Error al serializar par de claves: ${e.toString()}');
    }
  }

  /// Obtiene la clave pública en formato Base58
  Future<String> getPublicKeyBase58() async {
    final List<int> publicKeyBytes = (publicKey as SimplePublicKey).bytes;
    return bs58.base58.encode(Uint8List.fromList(publicKeyBytes));
  }

  /// Obtiene el hash blake3 de la clave pública
  ///
  /// Retorna un hash hexadecimal truncado a 24 caracteres
  String getBlake3Hash() {
    final List<int> publicKeyBytes = (publicKey as SimplePublicKey).bytes;
    return blake3Hex(publicKeyBytes).substring(0, 24);
  }

  /// Obtiene el DID Document asociado a este DID
  ///
  /// Retorna un Map con el DID Document según la especificación
  Future<Map<String, dynamic>> getDidDocument() async {
    final publicKeyBase58 = await getPublicKeyBase58();
    final verificationMethod = '${myDid}#keys-1';

    return {
      '@context': [
        'https://www.w3.org/ns/did/v1',
        'https://w3id.org/security/suites/ed25519-2020/v1'
      ],
      'id': myDid,
      'verificationMethod': [
        {
          'id': verificationMethod,
          'type': 'Ed25519VerificationKey2020',
          'controller': myDid,
          'publicKeyBase58': publicKeyBase58,
          'blake3Hash': getBlake3Hash(),
        }
      ],
      'authentication': [verificationMethod],
      'assertionMethod': [verificationMethod],
      'keyAgreement': [verificationMethod],
      'capabilityInvocation': [verificationMethod],
      'capabilityDelegation': [verificationMethod],
    };
  }
}
