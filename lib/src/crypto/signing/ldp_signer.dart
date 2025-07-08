import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import '../../utils/logging.dart';
import '../did/did_generator.dart';

/// Firmante de Linked Data Proofs (LDP)
/// 
/// Esta clase implementa la firma de mensajes utilizando
/// el algoritmo Ed25519 siguiendo el formato de Linked Data Proofs
class LdpSigner {
  final DidGenerator didGen;
  final Logger _logger;
  
  /// Constructor del firmante LDP
  /// 
  /// [didGen] - Generador de DID que contiene las claves criptográficas
  /// [logger] - Logger para registro de operaciones (opcional)
  LdpSigner(this.didGen, {Logger? logger}) : 
    _logger = logger ?? Logger(LogLevel.info);
  
  /// Firma un mensaje utilizando la clave privada del DID
  /// 
  /// [message] - Mensaje a firmar como Map<String, dynamic>
  /// 
  /// Retorna un Map<String, dynamic> con el mensaje firmado
  /// incluyendo la prueba de firma (proof)
  Future<Map<String, dynamic>> sign(Map<String, dynamic> message) async {
    try {
      _logger.debug('Iniciando proceso de firma LDP');
      
      // Creamos una copia del mensaje para no modificar el original
      final messageToSign = Map<String, dynamic>.from(message);
      
      // Generamos un mensaje canonicalizado para firmar
      final canonicalizedMessage = await _canonicalizeMessage(messageToSign);
      _logger.debug('Mensaje canonicalizado para firma');
      
      // Firmamos el mensaje utilizando el algoritmo Ed25519
      final algorithm = Ed25519();
      final signature = await algorithm.sign(
        utf8.encode(canonicalizedMessage),
        keyPair: didGen.keyPair,
      );
      
      // Codificamos la firma en base64
      final signatureBase64 = base64Url.encode(signature.bytes);
      
      // Añadimos la prueba de firma al mensaje original
      messageToSign['proof'] = {
        'type': 'Ed25519Signature2018',
        'created': DateTime.now().toIso8601String(),
        'verificationMethod': '${didGen.myDid}#keys-1',
        'proofPurpose': 'authentication',
        'proofValue': signatureBase64,
      };
      
      _logger.debug('Firma completada exitosamente');
      return messageToSign;
    } catch (e) {
      _logger.error('Error al firmar mensaje', {'error': e.toString()});
      throw Exception('Error al firmar mensaje: ${e.toString()}');
    }
  }
  
  /// Canonicaliza un mensaje para la firma
  /// 
  /// La canonicalización asegura que el mensaje tenga siempre
  /// el mismo formato de serialización para garantizar firmas consistentes
  Future<String> _canonicalizeMessage(Map<String, dynamic> message) async {
    // Removemos el campo proof si existe
    final Map<String, dynamic> messageWithoutProof = Map<String, dynamic>.from(message);
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
