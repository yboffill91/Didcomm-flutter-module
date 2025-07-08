import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import '../../utils/logging.dart';
import '../did/did_generator.dart';
import '../../service/did_resolver.dart';

/// Clase para encriptar mensajes según la especificación JWE (JSON Web Encryption)
///
/// Implementa la encriptación de mensajes utilizando ECDH con X25519 para
/// el intercambio de claves y AES-GCM para la encriptación simétrica del contenido
class JweEncryptor {
  final DidGenerator didGen;
  final DIDResolver didResolver;
  final Logger _logger;

  /// Constructor del encriptador JWE
  ///
  /// [didGen] - Generador de DID que contiene las claves criptográficas
  /// [didResolver] - Resolutor de DIDs para obtener las claves públicas
  /// [logger] - Logger para registro de operaciones (opcional)
  JweEncryptor(this.didGen, this.didResolver, {Logger? logger})
      : _logger = logger ?? Logger(LogLevel.info);

  /// Encripta un mensaje para un destinatario específico
  ///
  /// [message] - Mensaje a encriptar como Map<String, dynamic>
  /// [recipientDid] - DID del destinatario
  ///
  /// Retorna el mensaje encriptado en formato JWE
  Future<Map<String, dynamic>> encrypt(
      Map<String, dynamic> message, String recipientDid) async {
    try {
      _logger.debug('Iniciando encriptación JWE para: $recipientDid');

      // Obtenemos la clave pública del destinatario
      final recipientPublicKey =
          await didResolver.resolvePublicKey(recipientDid);
      if (recipientPublicKey == null) {
        throw Exception(
            'No se pudo resolver la clave pública para el DID: $recipientDid');
      }

      // Generamos una clave AES-GCM aleatoria para la encriptación simétrica
      final aesKeyAlgorithm = AesGcm.with256bits();
      final contentEncryptionKey = await aesKeyAlgorithm.newSecretKey();
      final contentEncryptionKeyBytes =
          await contentEncryptionKey.extractBytes();

      // Generamos un nonce aleatorio para la encriptación AES-GCM
      final nonce = _generateRandomBytes(
          12); // AES-GCM usa 96 bits (12 bytes) para el nonce

      // Serializamos el mensaje a JSON y lo encriptamos con AES-GCM
      final plaintext = utf8.encode(jsonEncode(message));
      final contentEncryption = await aesKeyAlgorithm.encrypt(
        plaintext,
        secretKey: contentEncryptionKey,
        nonce: nonce,
      );

      // Ahora encriptamos la clave AES con la clave pública del destinatario usando ECDH X25519
      final x25519 = X25519();
      final ephemeralKeyPair = await x25519.newKeyPair();
      final ephemeralPublicKey = await ephemeralKeyPair.extractPublicKey();
      final ephemeralPublicKeyBytes = ephemeralPublicKey.bytes;

      // Realizamos el acuerdo de claves ECDH
      final sharedSecret = await x25519.sharedSecretKey(
        keyPair: ephemeralKeyPair,
        remotePublicKey:
            SimplePublicKey(recipientPublicKey, type: KeyPairType.x25519),
      );
      final sharedSecretBytes = await sharedSecret.extractBytes();

      // Derivamos la clave de encriptación de la clave compartida usando HKDF
      final hkdf = Hkdf(hmac: Hmac(Sha256()), outputLength: 32);
      final kek = await hkdf.deriveKey(
        secretKey: SecretKey(sharedSecretBytes),
        nonce: _generateRandomBytes(16),
        info: utf8.encode('JWE CEK encryption'),
      );

      // Encriptamos la clave de contenido con la clave derivada
      final kekBytes = await kek.extractBytes();
      final encryptedKey = _xorBytes(
          Uint8List.fromList(contentEncryptionKeyBytes),
          Uint8List.fromList(kekBytes));

      // Construimos el objeto JWE
      final jwe = {
        'protected': base64Url.encode(utf8.encode(jsonEncode({
          'alg': 'ECDH-ES+A256KW',
          'enc': 'A256GCM',
          'epk': {
            'kty': 'OKP',
            'crv': 'X25519',
            'x': base64Url.encode(ephemeralPublicKeyBytes),
          },
          'typ': 'application/didcomm-encrypted+json',
        }))),
        'recipients': [
          {
            'header': {
              'kid': recipientDid,
            },
            'encrypted_key': base64Url.encode(encryptedKey),
          }
        ],
        'iv': base64Url.encode(nonce),
        'ciphertext': base64Url.encode(contentEncryption.cipherText),
        'tag': base64Url.encode(contentEncryption.mac.bytes),
      };

      _logger.debug('Encriptación JWE completada exitosamente');
      return jwe;
    } catch (e) {
      _logger.error('Error al encriptar mensaje', {'error': e.toString()});
      throw Exception('Error al encriptar mensaje: ${e.toString()}');
    }
  }

  /// Genera una secuencia de bytes aleatorios
  Uint8List _generateRandomBytes(int length) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }

  /// Operación XOR entre dos arrays de bytes
  Uint8List _xorBytes(Uint8List a, Uint8List b) {
    final length = min(a.length, b.length);
    final result = Uint8List(length);
    for (var i = 0; i < length; i++) {
      result[i] = a[i] ^ b[i];
    }
    return result;
  }
}
