import 'package:flutter_test/flutter_test.dart';
import 'package:android_wallet_mydsc/src/utils/logging.dart';
import 'dart:async';

void main() {
  group('Logger Tests', () {
    late Logger logger;
    late StreamController<LogEntry> logStreamController;
    List<LogEntry> capturedLogs = [];

    setUp(() {
      logStreamController = StreamController<LogEntry>.broadcast();
      logger = Logger(
        LogLevel.debug, 
        customLogHandler: (entry) => logStreamController.add(entry)
      );
      
      capturedLogs = [];
      logStreamController.stream.listen((entry) {
        capturedLogs.add(entry);
      });
    });

    tearDown(() {
      logStreamController.close();
    });

    test('Logger should respect log level threshold', () {
      // Arrange - logger con nivel info
      final infoLogger = Logger(
        LogLevel.info, 
        customLogHandler: (entry) => logStreamController.add(entry)
      );
      
      // Act - enviar mensajes de diferentes niveles
      infoLogger.debug('Debug message');
      infoLogger.info('Info message');
      infoLogger.warning('Warning message');
      infoLogger.error('Error message');
      
      // Assert
      expect(capturedLogs.length, equals(3)); // No debe capturar el mensaje de debug
      expect(capturedLogs.any((log) => log.level == LogLevel.debug), isFalse);
      expect(capturedLogs.any((log) => log.level == LogLevel.info), isTrue);
      expect(capturedLogs.any((log) => log.level == LogLevel.warning), isTrue);
      expect(capturedLogs.any((log) => log.level == LogLevel.error), isTrue);
    });
    
    test('LogEntry should include context data', () {
      // Act
      logger.info('Test message with context', {'key': 'value', 'number': 42});
      
      // Assert
      expect(capturedLogs.length, equals(1));
      final entry = capturedLogs.first;
      expect(entry.message, equals('Test message with context'));
      expect(entry.context?['key'], equals('value'));
      expect(entry.context?['number'], equals(42));
      expect(entry.timestamp, isNotNull);
    });
    
    test('LogLevel fromString should parse correctly', () {
      // Act & Assert
      expect(LogLevel.fromString('debug'), equals(LogLevel.debug));
      expect(LogLevel.fromString('info'), equals(LogLevel.info));
      expect(LogLevel.fromString('warning'), equals(LogLevel.warning));
      expect(LogLevel.fromString('error'), equals(LogLevel.error));
      expect(LogLevel.fromString('unknown'), equals(LogLevel.info)); // valor por defecto
    });
    
    test('LogEntry toString should format message properly', () {
      // Arrange
      final entry = LogEntry(
        level: LogLevel.warning,
        message: 'Test warning',
        context: {'source': 'unit-test'},
        timestamp: DateTime(2023, 1, 1, 12, 0, 0),
      );
      
      // Act
      final stringRepresentation = entry.toString();
      
      // Assert
      expect(stringRepresentation, contains('[WARNING]'));
      expect(stringRepresentation, contains('Test warning'));
      expect(stringRepresentation, contains('source: unit-test'));
      expect(stringRepresentation, contains('2023-01-01'));
    });
    
    test('Logger should handle null context', () {
      // Act
      logger.info('Message without context');
      
      // Assert
      expect(capturedLogs.length, equals(1));
      final entry = capturedLogs.first;
      expect(entry.message, equals('Message without context'));
      expect(entry.context, isNull);
    });
  });
}
