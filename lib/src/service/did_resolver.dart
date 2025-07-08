import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:bs58/bs58.dart';
import '../utils/logging.dart';
import '../config/didcomm_config.dart';

/// Servicio de resolución de DIDs
///
/// Esta clase es responsable de resolver DIDs a sus documentos asociados
/// y extraer las claves públicas necesarias para la verificación y encriptación
class DIDResolver {
  final DIDCommConfig config;
  final Logger _logger;
  final Map<String, Uint8List> _keyCache = {};

  /// Constructor del resolutor de DIDs
  ///
  /// [config] - Configuración DIDComm con endpoint del resolutor
  /// [logger] - Logger para registro de operaciones (opcional)
  DIDResolver(this.config, {Logger? logger}) 
      : _logger = logger ?? Logger(LogLevel.info);

  /// Resuelve la clave pública asociada a un DID
  ///
  /// [did] - DID a resolver
  /// 
  /// Retorna la clave pública como Uint8List o null si no se pudo resolver
  Future<Uint8List?> resolvePublicKey(String did) async {
    try {
      // Verificamos si ya tenemos la clave en caché
      if (_keyCache.containsKey(did)) {
        _logger.debug('Clave pública obtenida de caché para $did');
        return _keyCache[did];
      }
      
      // Verificamos si es un did:key que podemos resolver localmente
      if (did.startsWith('did:key:')) {
        final publicKey = _resolveDidKey(did);
        if (publicKey != null) {
          // Guardamos en caché para futuras consultas
          _keyCache[did] = publicKey;
          return publicKey;
        }
      }
      
      // Intentamos resolver usando el endpoint de resolución de DIDs
      _logger.debug('Resolviendo DID remotamente: $did');
      final url = '${config.didResolverEndpoint}?did=$did';
      
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        _logger.warning('Error al resolver DID remotamente', {
          'statusCode': response.statusCode,
          'body': response.body
        });
        return null;
      }
      
      // Parseamos el documento DID
      final didDocument = jsonDecode(response.body);
      final publicKey = await _extractPublicKeyFromDocument(didDocument, did);
      
      if (publicKey != null) {
        // Guardamos en caché para futuras consultas
        _keyCache[did] = publicKey;
      }
      
      return publicKey;
    } catch (e) {
      _logger.error('Error al resolver DID', {'did': did, 'error': e.toString()});
      return null;
    }
  }
  
  /// Resuelve la clave pública de un DID en formato did:key
  ///
  /// [did] - DID en formato did:key:z...
  ///
  /// Retorna la clave pública como Uint8List o null si el formato no es válido
  Uint8List? _resolveDidKey(String did) {
    try {
      // El formato did:key:z... contiene la clave codificada en base58
      if (!did.startsWith('did:key:z')) {
        return null;
      }
      
      // Extraemos la parte base58 después de "did:key:z"
      final base58Key = did.substring(10);
      
      // Decodificamos la clave
      final prefixedPublicKey = base58.decode(base58Key);
      
      // Los primeros 2 bytes son el multicodec prefix, los eliminamos
      // Ed25519: 0xed01, X25519: 0xec01
      if (prefixedPublicKey.length < 3) {
        return null;
      }
      
      return Uint8List.fromList(prefixedPublicKey.sublist(2));
    } catch (e) {
      _logger.error('Error al resolver did:key', {'did': did, 'error': e.toString()});
      return null;
    }
  }
  
  /// Extrae la clave pública de un documento DID
  ///
  /// [document] - Documento DID completo
  /// [did] - DID asociado al documento
  ///
  /// Retorna la clave pública como Uint8List o null si no se pudo extraer
  Future<Uint8List?> _extractPublicKeyFromDocument(Map<String, dynamic> document, String did) async {
    try {
      // Verificamos si el documento tiene métodos de verificación
      final verificationMethods = document['verificationMethod'];
      if (verificationMethods == null || verificationMethods is! List) {
        return null;
      }
      
      // Buscamos un método con publicKeyBase58 o publicKeyMultibase
      for (final method in verificationMethods) {
        if (method is! Map<String, dynamic>) continue;
        
        // Intentamos con publicKeyBase58
        if (method.containsKey('publicKeyBase58')) {
          final base58Key = method['publicKeyBase58'] as String;
          return Uint8List.fromList(base58.decode(base58Key));
        }
        
        // Intentamos con publicKeyMultibase
        if (method.containsKey('publicKeyMultibase')) {
          final multibaseKey = method['publicKeyMultibase'] as String;
          if (multibaseKey.startsWith('z')) {
            return Uint8List.fromList(base58.decode(multibaseKey.substring(1)));
          }
        }
        
        // Intentamos con publicKeyHex
        if (method.containsKey('publicKeyHex')) {
          final hexKey = method['publicKeyHex'] as String;
          return _hexToBytes(hexKey);
        }
      }
      
      _logger.warning('No se encontró clave pública en el documento DID', {'did': did});
      return null;
    } catch (e) {
      _logger.error('Error al extraer clave pública del documento', {'did': did, 'error': e.toString()});
      return null;
    }
  }
  
  /// Convierte una cadena hexadecimal a bytes
  Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      final value = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
      result[i] = value;
    }
    return result;
  }
  
  /// Limpia la caché de claves
  void clearCache() {
    _keyCache.clear();
  }
}
