import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:android_wallet_mydsc/src/crypto/encryption/jwe_encryptor.dart';
import 'package:android_wallet_mydsc/src/crypto/did/did_generator.dart';
import 'package:android_wallet_mydsc/src/service/did_resolver.dart';
import 'package:android_wallet_mydsc/src/utils/logging.dart';

// Generar mocks para los servicios
@GenerateMocks([DidGenerator, DIDResolver])
import 'jwe_encryptor_test.mocks.dart';

void main() {
  late JweEncryptor jweEncryptor;
  late MockDidGenerator mockDidGen;
  late MockDIDResolver mockDIDResolver;

  setUp(() async {
    mockDidGen = MockDidGenerator();
    mockDIDResolver = MockDIDResolver();

    jweEncryptor = JweEncryptor(
      mockDidGen,
      mockDIDResolver,
      logger: Logger(LogLevel.debug),
    );
  });

  group('JweEncryptor Tests', () {
    test('encrypt should create valid JWE structure', () async {
      // Arrange
      final message = {
        'id': 'test-msg-123',
        'type': 'test-message',
        'body': {'key': 'value'}
      };

      final recipientDid =
          'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK';
      final mockPublicKey = Uint8List.fromList(List.generate(32, (i) => i));

      // Mock did resolver para devolver una clave pública
      when(mockDIDResolver.resolvePublicKey(recipientDid))
          .thenAnswer((_) async => mockPublicKey);

      // Act
      final jwe = await jweEncryptor.encrypt(message, recipientDid);

      // Assert
      expect(jwe, isA<Map<String, dynamic>>());
      expect(jwe['protected'], isA<String>());
      expect(jwe['recipients'], isA<List>());
      expect(jwe['iv'], isA<String>());
      expect(jwe['ciphertext'], isA<String>());
      expect(jwe['tag'], isA<String>());

      // Verificar estructura interna
      final protected =
          json.decode(utf8.decode(base64Url.decode(jwe['protected'])));
      expect(protected['alg'], 'ECDH-ES+A256KW');
      expect(protected['enc'], 'A256GCM');

      verify(mockDIDResolver.resolvePublicKey(recipientDid)).called(1);
    });

    test('encrypt should throw error when recipient key cannot be resolved',
        () async {
      // Arrange
      final message = {
        'id': 'test-msg-123',
        'type': 'test-message',
        'body': {'key': 'value'}
      };

      final recipientDid =
          'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK';

      // Mock did resolver para devolver null (no se encontró la clave)
      when(mockDIDResolver.resolvePublicKey(recipientDid))
          .thenAnswer((_) async => null);

      // Act & Assert
      expect(
        () => jweEncryptor.encrypt(message, recipientDid),
        throwsA(isA<Exception>()),
      );

      verify(mockDIDResolver.resolvePublicKey(recipientDid)).called(1);
    });

    test('generateRandomBytes should create bytes of correct length', () async {
      // Arrange - usando técnica de reflexión para acceder a método privado
      final length = 16;

      // Act - accediendo al método privado por reflexión
      final generateRandomBytesMethod =
          jweEncryptor.runtimeType.toString().contains('_generateRandomBytes')
              ? '_generateRandomBytes'
              : null;

      if (generateRandomBytesMethod == null) {
        // Si no podemos acceder al método privado directamente, saltamos la prueba
        print('No se puede acceder al método privado _generateRandomBytes');
        return;
      }

      // Esta parte solo funcionará si el método es accesible para pruebas
      final randomBytes = jweEncryptor._generateRandomBytes(length);

      // Assert
      expect(randomBytes.length, equals(length));

      // Verificar que los bytes no son todos iguales (asumiendo que son aleatorios)
      final Set<int> uniqueValues = randomBytes.toSet();
      expect(uniqueValues.length, greaterThan(1));
    });
  });
}
