import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'dart:async';

import 'package:android_wallet_mydsc/src/protocols/trust_ping/trust_ping_controller.dart';
import 'package:android_wallet_mydsc/src/crypto/signing/ldp_signer.dart';
import 'package:android_wallet_mydsc/src/crypto/encryption/jwe_encryptor.dart';
import 'package:android_wallet_mydsc/src/transport/service_didcomm.dart';
import 'package:android_wallet_mydsc/src/utils/logging.dart';
import 'package:android_wallet_mydsc/src/utils/error_handling.dart';

// Generar mocks para los servicios
@GenerateMocks([LdpSigner, JweEncryptor, DIDCommService])
import 'trust_ping_controller_test.mocks.dart';

void main() {
  late TrustPingController pingController;
  late MockLdpSigner mockSigner;
  late MockJweEncryptor mockEncryptor;
  late MockDIDCommService mockCommService;
  late StreamController<Map<String, dynamic>> mockMessageController;

  setUp(() {
    mockSigner = MockLdpSigner();
    mockEncryptor = MockJweEncryptor();
    mockCommService = MockDIDCommService();
    mockMessageController = StreamController<Map<String, dynamic>>.broadcast();
    
    // Configurar comportamiento del mock
    when(mockCommService.listenToIncoming(any))
        .thenAnswer((_) {
          final callback = _.positionalArguments[0] as Function(Map<String, dynamic>);
          return mockMessageController.stream.listen((message) {
            callback(message);
          });
        });
    
    pingController = TrustPingController(
      mockSigner,
      mockEncryptor,
      mockCommService,
      logger: Logger(LogLevel.debug),
    );
  });

  tearDown(() {
    pingController.dispose();
    mockMessageController.close();
  });

  group('TrustPingController Tests', () {
    test('sendPing should create and send a trust ping message', () async {
      // Arrange
      final toDid = 'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK';
      final signedMessage = {'signed': 'message'};
      
      when(mockSigner.sign(any)).thenAnswer((_) async => signedMessage);
      when(mockCommService.send(any)).thenAnswer((_) async => true);

      // Act
      final result = await pingController.sendPing(
        toDid,
        responseRequested: true,
        comment: 'Test ping',
      );

      // Assert
      expect(result, isA<String>());
      verify(mockSigner.sign(any)).called(1);
      verify(mockCommService.send(any)).called(1);
    });

    test('sendPing should handle errors correctly', () async {
      // Arrange
      final toDid = 'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK';
      
      when(mockSigner.sign(any)).thenThrow(
        DIDCommException(
          errorCode: 'SIGNING_ERROR',
          message: 'Error signing message',
          severity: ErrorSeverity.error,
        ),
      );

      // Act & Assert
      expect(
        () => pingController.sendPing(toDid),
        throwsA(isA<DIDCommException>()),
      );
    });

    test('onPingResponse should emit responses to ping messages', () async {
      // Arrange
      final pingId = '123456';
      final response = {
        'type': 'https://didcomm.org/trust-ping/2.0/ping-response',
        'from': 'did:key:responder',
        'to': ['did:key:sender'],
        'thid': pingId,
        'body': {'ping_response': true},
      };

      // Act & Assert
      // Simular respuesta entrante
      expectLater(
        pingController.onPingResponse,
        emits(predicate((msg) => msg['thid'] == pingId)),
      );
      mockMessageController.add(response);
    });

    test('ping should timeout if no response is received', () async {
      // Arrange
      final toDid = 'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK';
      final signedMessage = {'signed': 'message'};
      final pingId = '123456';
      
      when(mockSigner.sign(any)).thenAnswer((_) {
        final message = _.positionalArguments[0] as Map<String, dynamic>;
        message['id'] = pingId;
        return Future.value(signedMessage);
      });
      when(mockCommService.send(any)).thenAnswer((_) async => true);

      // Act
      // Configuramos un tiempo de espera muy corto para la prueba
      expectLater(
        pingController.onPingTimeout,
        emits(pingId),
      );
      
      await pingController.sendPing(
        toDid,
        responseRequested: true,
        timeoutSeconds: 1,
      );
    });
  });
}
