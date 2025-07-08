import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:android_wallet_mydsc/src/crypto/did/did_generator.dart';
import 'package:android_wallet_mydsc/src/utils/logging.dart';
import 'package:android_wallet_mydsc/src/config/didcomm_config.dart';
import 'package:android_wallet_mydsc/src/utils/error_handling.dart';

void main() {
  group('DidGenerator Tests', () {
    test('create should generate a valid DID', () async {
      // Act
      final didGenerator = await DidGenerator.create(
        logger: Logger(LogLevel.debug),
      );

      // Assert
      expect(didGenerator.myDid, startsWith('did:key:z'));
    });

    test('serialize and deserialize should work correctly', () async {
      // Arrange
      final didGenerator = await DidGenerator.create(
        logger: Logger(LogLevel.debug),
      );
      
      // Act
      final serialized = await didGenerator.serialize();
      final deserialized = await DidGenerator.fromSerialized(
        serialized,
        logger: Logger(LogLevel.debug),
      );
      
      // Assert
      expect(deserialized.myDid, equals(didGenerator.myDid));
    });

    test('getPublicKeyMultibase should return a valid multibase key', () async {
      // Arrange
      final didGenerator = await DidGenerator.create(
        logger: Logger(LogLevel.debug),
      );
      
      // Act
      final multibase = await didGenerator.getPublicKeyMultibase();
      
      // Assert
      expect(multibase, startsWith('z'));
    });

    test('getPublicKeyBase58 should return a valid base58 key', () async {
      // Arrange
      final didGenerator = await DidGenerator.create(
        logger: Logger(LogLevel.debug),
      );
      
      // Act
      final base58Key = await didGenerator.getPublicKeyBase58();
      
      // Assert
      expect(base58Key.length, greaterThan(16));
    });

    test('getDid should reconstruct the correct DID from keypair', () async {
      // Arrange
      final didGenerator = await DidGenerator.create(
        logger: Logger(LogLevel.debug),
      );
      final originalDid = didGenerator.myDid;
      
      // Act
      final reconstructedDid = await didGenerator.getDid();
      
      // Assert
      expect(reconstructedDid, equals(originalDid));
    });

    test('should handle errors during serialization and deserialization', () async {
      // Arrange - intentar deserializar un JSON inválido
      final invalidJson = '{"invalid": "json_format"}';
      
      // Act & Assert
      expect(
        () async => await DidGenerator.fromSerialized(
          invalidJson,
          logger: Logger(LogLevel.debug),
        ),
        throwsA(isA<DIDCommException>()),
      );
    });
  });
}
