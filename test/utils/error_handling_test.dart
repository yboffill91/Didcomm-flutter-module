import 'package:flutter_test/flutter_test.dart';
import 'package:android_wallet_mydsc/src/utils/error_handling.dart';
import 'package:android_wallet_mydsc/src/utils/logging.dart';

void main() {
  group('Error Handling Tests', () {
    test('DIDCommException should correctly initialize with all properties', () {
      // Arrange & Act
      final exception = DIDCommException(
        errorCode: 'TEST_ERROR',
        message: 'Test error message',
        severity: ErrorSeverity.error,
        details: {'key': 'value'},
        innerException: Exception('Inner exception'),
      );
      
      // Assert
      expect(exception.errorCode, equals('TEST_ERROR'));
      expect(exception.message, equals('Test error message'));
      expect(exception.severity, equals(ErrorSeverity.error));
      expect(exception.details, equals({'key': 'value'}));
      expect(exception.innerException, isA<Exception>());
      expect(exception.timestamp, isNotNull);
    });
    
    test('DIDCommException toString should format properly', () {
      // Arrange
      final exception = DIDCommException(
        errorCode: 'TEST_ERROR',
        message: 'Test error message',
        severity: ErrorSeverity.error,
      );
      
      // Act
      final stringRepresentation = exception.toString();
      
      // Assert
      expect(stringRepresentation, contains('TEST_ERROR'));
      expect(stringRepresentation, contains('Test error message'));
      expect(stringRepresentation, contains('error'));
    });
    
    test('ErrorHandler should handle exceptions properly', () {
      // Arrange
      final logger = Logger(LogLevel.debug);
      
      // Act & Assert - probar manejo de excepciones conocidas
      try {
        ErrorHandler.handleException(
          () => throw DIDCommException(
            errorCode: 'KNOWN_ERROR',
            message: 'Known error',
            severity: ErrorSeverity.warning,
          ),
          logger: logger,
        );
        fail('Should have thrown an exception');
      } catch (e) {
        expect(e, isA<DIDCommException>());
        final didCommException = e as DIDCommException;
        expect(didCommException.errorCode, equals('KNOWN_ERROR'));
      }
    });
    
    test('ErrorHandler should wrap unknown exceptions', () {
      // Arrange
      final logger = Logger(LogLevel.debug);
      
      // Act & Assert - probar manejo de excepciones desconocidas
      try {
        ErrorHandler.handleException(
          () => throw Exception('Unknown error'),
          logger: logger,
          context: 'Test context',
        );
        fail('Should have thrown an exception');
      } catch (e) {
        expect(e, isA<DIDCommException>());
        final didCommException = e as DIDCommException;
        expect(didCommException.errorCode, equals('UNKNOWN_ERROR'));
        expect(didCommException.message, contains('Unknown error'));
        expect(didCommException.details?['context'], equals('Test context'));
        expect(didCommException.innerException, isA<Exception>());
      }
    });
    
    test('ErrorSeverity values should map correctly', () {
      // Assert
      expect(ErrorSeverity.debug.name, equals('debug'));
      expect(ErrorSeverity.info.name, equals('info'));
      expect(ErrorSeverity.warning.name, equals('warning'));
      expect(ErrorSeverity.error.name, equals('error'));
      expect(ErrorSeverity.critical.name, equals('critical'));
      
      // Verificar que los valores estén en orden creciente de gravedad
      expect(ErrorSeverity.debug.index < ErrorSeverity.info.index, isTrue);
      expect(ErrorSeverity.info.index < ErrorSeverity.warning.index, isTrue);
      expect(ErrorSeverity.warning.index < ErrorSeverity.error.index, isTrue);
      expect(ErrorSeverity.error.index < ErrorSeverity.critical.index, isTrue);
    });
  });
}
