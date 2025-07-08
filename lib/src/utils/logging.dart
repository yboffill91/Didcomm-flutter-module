/// Niveles de log disponibles en el sistema
enum LogLevel {
  debug,
  info,
  warning,
  error;

  /// Convierte un string a un nivel de log
  static LogLevel fromString(String level) {
    switch (level.toLowerCase()) {
      case 'debug':
        return LogLevel.debug;
      case 'info':
        return LogLevel.info;
      case 'warning':
        return LogLevel.warning;
      case 'error':
        return LogLevel.error;
      default:
        return LogLevel.info;
    }
  }
}

/// Sistema de logging simple para la aplicación DIDComm
class Logger {
  final LogLevel level;
  
  /// Constructor del logger
  /// 
  /// [level] - Nivel mínimo de logs a mostrar
  Logger(this.level);
  
  /// Log de nivel debug
  /// 
  /// [message] - Mensaje a loggear
  /// [context] - Contexto opcional del mensaje
  void debug(String message, [Map<String, dynamic>? context]) {
    if (level.index <= LogLevel.debug.index) {
      _log('DEBUG', message, context);
    }
  }
  
  /// Log de nivel info
  /// 
  /// [message] - Mensaje a loggear
  /// [context] - Contexto opcional del mensaje
  void info(String message, [Map<String, dynamic>? context]) {
    if (level.index <= LogLevel.info.index) {
      _log('INFO', message, context);
    }
  }
  
  /// Log de nivel warning
  /// 
  /// [message] - Mensaje a loggear
  /// [context] - Contexto opcional del mensaje
  void warning(String message, [Map<String, dynamic>? context]) {
    if (level.index <= LogLevel.warning.index) {
      _log('WARNING', message, context);
    }
  }
  
  /// Log de nivel error
  /// 
  /// [message] - Mensaje a loggear
  /// [context] - Contexto opcional del mensaje
  void error(String message, [Map<String, dynamic>? context]) {
    if (level.index <= LogLevel.error.index) {
      _log('ERROR', message, context);
    }
  }
  
  /// Método interno para formatear y mostrar logs
  void _log(String level, String message, [Map<String, dynamic>? context]) {
    final timestamp = DateTime.now().toIso8601String();
    final contextStr = context != null ? ' | context: $context' : '';
    print('[$timestamp] $level: $message$contextStr');
  }
}
