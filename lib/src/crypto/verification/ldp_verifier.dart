import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import '../../utils/logging.dart';
import '../../service/did_resolver.dart';

/// Verificador de Linked Data Proofs (LDP)
/// 
/// Esta clase implementa la verificación de firmas en mensajes
/// que siguen el formato de Linked Data Proofs
class LdpVerifier {
  final DIDResolver didResolver;
  final Logger _logger;
  
  /// Constructor del verificador LDP
  /// 
  /// [didResolver] - Resolutor de DIDs para obtener las claves públicas
  /// [logger] - Logger para registro de operaciones (opcional)
  LdpVerifier(this.didResolver, {Logger? logger}) :
    _logger = logger ?? Logger(LogLevel.info);
  
  /// Verifica la firma de un mensaje
  /// 
  /// [signedMessage] - Mensaje firmado a verificar
  /// 
  /// Retorna true si la firma es válida, false en caso contrario
  Future<bool> verify(Map<String, dynamic> signedMessage) async {
    try {
      _logger.debug('Iniciando verificación de firma');
      
      // Verificamos que el mensaje tenga una prueba de firma
      if (!signedMessage.containsKey('proof')) {
        _logger.warning('El mensaje no contiene una prueba de firma');
        return false;
      }
      
      final proof = signedMessage['proof'] as Map<String, dynamic>;
      final signatureBase64 = proof['proofValue'] as String?;
      final verificationMethod = proof['verificationMethod'] as String?;
      
      if (signatureBase64 == null || verificationMethod == null) {
        _logger.warning('La prueba de firma está incompleta');
        return false;
      }
      
      // Extraemos el DID del método de verificación
      final didParts = verificationMethod.split('#');
      if (didParts.isEmpty) {
        _logger.warning('Método de verificación inválido');
        return false;
      }
      
      final did = didParts[0];
      
      // Obtenemos la clave pública asociada al DID
      final publicKeyBytes = await didResolver.resolvePublicKey(did);
      if (publicKeyBytes == null) {
        _logger.warning('No se pudo resolver la clave pública para el DID', {'did': did});
        return false;
      }
      
      // Reconstruimos la clave pública
      final algorithm = Ed25519();
      final publicKey = SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519);
      
      // Canonicalizamos el mensaje para la verificación
      final canonicalizedMessage = await sirt(signedMessage);
      
      // Decodificamos la firma
      final signature = base64Url.decode(signatureBase64);
      
      // Verificamos la firma
      final isValid = await algorithm.verify(
        utf8.encode(canonicalizedMessage),
        signature: Signature(signature, publicKey: publicKey),
      );
      
      _logger.debug('Verificación de firma completada', {'isValid': isValid});
      return isValid;
    } catch (e) {
      _logger.error('Error al verificar firma', {'error': e.toString()});
      return false;
    }
  }
  
  /// Canonicaliza un mensaje para la verificación (Similar Input Reduction Transform)
  /// 
  /// [message] - Mensaje a canonicalizar
  /// 
  /// Retorna una representación canónica del mensaje para verificación
  Future<String> sirt(Map<String, dynamic> message) async {
    // Removemos el campo proof para la verificación
    final messageWithoutProof = Map<String, dynamic>.from(message);
    messageWithoutProof.remove('proof');
    
    // Ordenamos las claves alfabéticamente para asegurar consistencia
    final orderedMap = _sortMapRecursively(messageWithoutProof);
    
    // Serializamos el mensaje a JSON con espacios compactos
    return jsonEncode(orderedMap);
  }
  
  /// Ordena un mapa recursivamente para la canonicalización
  dynamic _sortMapRecursively(dynamic input) {
    if (input is Map) {
      final sortedMap = <String, dynamic>{};
      final sortedKeys = input.keys.toList()..sort();
      
      for (final key in sortedKeys) {
        sortedMap[key] = _sortMapRecursively(input[key]);
      }
      return sortedMap;
    } else if (input is List) {
      return input.map(_sortMapRecursively).toList();
    } else {
      return input;
    }
  }
}
