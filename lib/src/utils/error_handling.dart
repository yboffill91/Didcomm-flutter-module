import 'logging.dart';

/// Tipos de errores en el sistema DIDComm
enum DIDCommErrorType {
  /// Errores de comunicación (red, WebSocket, etc.)
  communication,
  
  /// Errores de cifrado o descifrado
  encryption,
  
  /// Errores de firma o verificación
  signature,
  
  /// Errores de resolución de DIDs
  resolution,
  
  /// Errores de protocolo DIDComm
  protocol,
  
  /// Errores de configuración
  configuration,
  
  /// Errores generales no categorizados
  general
}

/// Clase de excepción personalizada para DIDComm
class DIDCommException implements Exception {
  /// Tipo de error
  final DIDCommErrorType type;
  
  /// Mensaje descriptivo del error
  final String message;
  
  /// Excepción original que causó este error (opcional)
  final dynamic cause;
  
  /// Datos contextuales adicionales sobre el error (opcional)
  final Map<String, dynamic>? context;
  
  /// Constructor de la excepción
  DIDCommException(
    this.type,
    this.message, {
    this.cause,
    this.context,
  });
  
  @override
  String toString() {
    String result = 'DIDCommException(${type.name}): $message';
    if (cause != null) {
      result += '\nCaused by: $cause';
    }
    if (context != null && context!.isNotEmpty) {
      result += '\nContext: $context';
    }
    return result;
  }
  
  /// Registra esta excepción en el logger proporcionado
  void log(Logger logger) {
    final Map<String, dynamic> logContext = {
      'error_type': type.name,
    };
    
    if (context != null) {
      logContext.addAll(context!);
    }
    
    if (cause != null) {
      logContext['cause'] = cause.toString();
    }
    
    logger.error(message, logContext);
  }
}

/// Utilidad para manejar excepciones de forma uniforme
class ErrorHandler {
  final Logger _logger;
  
  /// Constructor del manejador de errores
  ErrorHandler(this._logger);
  
  /// Ejecuta una función y maneja cualquier excepción que pueda ocurrir
  /// 
  /// [function] - Función asincrónica a ejecutar
  /// [errorType] - Tipo de error a asignar si ocurre una excepción
  /// [context] - Contexto adicional para incluir en el error
  /// [defaultErrorMessage] - Mensaje de error por defecto si no se proporciona uno específico
  /// 
  /// Retorna el resultado de la función o rethrows una DIDCommException
  Future<T> handleErrors<T>({
    required Future<T> Function() function,
    required DIDCommErrorType errorType,
    Map<String, dynamic>? context,
    String defaultErrorMessage = 'Error inesperado en la operación',
  }) async {
    try {
      return await function();
    } catch (e) {
      // Si ya es una DIDCommException, la propagamos añadiendo contexto
      if (e is DIDCommException) {
        final updatedContext = {...(e.context ?? {}), ...(context ?? {})};
        final updatedException = DIDCommException(
          e.type,
          e.message,
          cause: e.cause,
          context: updatedContext,
        );
        updatedException.log(_logger);
        throw updatedException;
      }
      
      // Si es otra excepción, la convertimos a DIDCommException
      final exception = DIDCommException(
        errorType,
        e.toString().isNotEmpty ? e.toString() : defaultErrorMessage,
        cause: e,
        context: context,
      );
      exception.log(_logger);
      throw exception;
    }
  }
  
  /// Versión sincrónica del manejador de errores
  T handleErrorsSync<T>({
    required T Function() function,
    required DIDCommErrorType errorType,
    Map<String, dynamic>? context,
    String defaultErrorMessage = 'Error inesperado en la operación',
  }) {
    try {
      return function();
    } catch (e) {
      // Si ya es una DIDCommException, la propagamos añadiendo contexto
      if (e is DIDCommException) {
        final updatedContext = {...(e.context ?? {}), ...(context ?? {})};
        final updatedException = DIDCommException(
          e.type,
          e.message,
          cause: e.cause,
          context: updatedContext,
        );
        updatedException.log(_logger);
        throw updatedException;
      }
      
      // Si es otra excepción, la convertimos a DIDCommException
      final exception = DIDCommException(
        errorType,
        e.toString().isNotEmpty ? e.toString() : defaultErrorMessage,
        cause: e,
        context: context,
      );
      exception.log(_logger);
      throw exception;
    }
  }
}
