import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'dart:async';

import 'package:android_wallet_mydsc/src/protocols/trust_ping/ping_first_strategy.dart';
import 'package:android_wallet_mydsc/src/protocols/trust_ping/trust_ping_controller.dart';
import 'package:android_wallet_mydsc/src/utils/logging.dart';
import 'package:android_wallet_mydsc/src/utils/error_handling.dart';

// Generar mocks para el controlador de ping
@GenerateMocks([TrustPingController])
import 'ping_first_strategy_test.mocks.dart';

void main() {
  late PingFirstStrategy pingStrategy;
  late MockTrustPingController mockPingController;
  late StreamController<Map<String, dynamic>> pingResponseController;
  late StreamController<String> pingTimeoutController;

  setUp(() {
    mockPingController = MockTrustPingController();
    pingResponseController = StreamController<Map<String, dynamic>>.broadcast();
    pingTimeoutController = StreamController<String>.broadcast();
    
    // Configurar comportamiento del mock
    when(mockPingController.onPingResponse).thenAnswer(
      (_) => pingResponseController.stream
    );
    when(mockPingController.onPingTimeout).thenAnswer(
      (_) => pingTimeoutController.stream
    );
    
    pingStrategy = PingFirstStrategy(
      mockPingController,
      logger: Logger(LogLevel.debug),
    );
  });

  tearDown(() {
    pingStrategy.dispose();
    pingResponseController.close();
    pingTimeoutController.close();
  });

  group('PingFirstStrategy Tests', () {
    test('execute should succeed when ping gets response', () async {
      // Arrange
      final targetDid = 'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK';
      final pingId = 'test-ping-123';
      
      when(mockPingController.sendPing(
        targetDid, 
        responseRequested: true, 
        timeoutSeconds: anyNamed('timeoutSeconds')
      )).thenAnswer((_) async => pingId);

      // Act - inicie la estrategia en un future separado
      final executeCompleter = Completer<bool>();
      pingStrategy.execute(targetDid).then((result) {
        executeCompleter.complete(result);
      });
      
      // Simulate ping response after delay
      await Future.delayed(Duration(milliseconds: 100));
      pingResponseController.add({
        'id': 'response-123',
        'thid': pingId,
        'type': 'https://didcomm.org/trust-ping/2.0/ping-response',
      });
      
      // Assert
      final result = await executeCompleter.future;
      expect(result, isTrue);
      verify(mockPingController.sendPing(
        targetDid, 
        responseRequested: true, 
        timeoutSeconds: anyNamed('timeoutSeconds')
      )).called(1);
    });

    test('execute should fail when ping times out', () async {
      // Arrange
      final targetDid = 'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK';
      final pingId = 'test-ping-123';
      
      when(mockPingController.sendPing(
        targetDid, 
        responseRequested: true, 
        timeoutSeconds: anyNamed('timeoutSeconds')
      )).thenAnswer((_) async => pingId);

      // Act - inicie la estrategia en un future separado
      final executeCompleter = Completer<bool>();
      pingStrategy.execute(targetDid).then((result) {
        executeCompleter.complete(result);
      });
      
      // Simulate ping timeout after delay
      await Future.delayed(Duration(milliseconds: 100));
      pingTimeoutController.add(pingId);
      
      // Assert
      final result = await executeCompleter.future;
      expect(result, isFalse);
      verify(mockPingController.sendPing(
        targetDid, 
        responseRequested: true, 
        timeoutSeconds: anyNamed('timeoutSeconds')
      )).called(1);
    });

    test('execute should handle exceptions correctly', () async {
      // Arrange
      final targetDid = 'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK';
      
      when(mockPingController.sendPing(
        targetDid, 
        responseRequested: true, 
        timeoutSeconds: anyNamed('timeoutSeconds')
      )).thenThrow(DIDCommException(
        errorCode: 'PING_ERROR',
        message: 'Error sending ping',
        severity: ErrorSeverity.error
      ));

      // Act & Assert
      expect(
        () => pingStrategy.execute(targetDid),
        throwsA(isA<DIDCommException>()),
      );
    });

    test('dispose should cancel subscription', () async {
      // Arrange
      final targetDid = 'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK';
      final pingId = 'test-ping-123';
      
      when(mockPingController.sendPing(
        targetDid, 
        responseRequested: true, 
        timeoutSeconds: anyNamed('timeoutSeconds')
      )).thenAnswer((_) async => pingId);

      // Act - iniciar estrategia y luego disponer
      final executeCompleter = Completer<bool>();
      pingStrategy.execute(targetDid).then((result) {
        executeCompleter.complete(result);
      }).catchError((e) {
        executeCompleter.completeError(e);
      });
      
      // Dispose before any response
      await Future.delayed(Duration(milliseconds: 100));
      pingStrategy.dispose();
      
      // Send response after dispose - no debería afectar el resultado
      pingResponseController.add({
        'id': 'response-123',
        'thid': pingId,
        'type': 'https://didcomm.org/trust-ping/2.0/ping-response',
      });
      
      // Assert - la estrategia debería estar pendiente o fallar, pero no completarse con éxito
      expect(executeCompleter.isCompleted, isFalse);
    });
  });
}
