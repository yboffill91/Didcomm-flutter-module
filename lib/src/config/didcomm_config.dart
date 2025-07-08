import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuración centralizada para el sistema DIDComm
/// 
/// Esta clase encapsula todas las opciones de configuración necesarias
/// para el funcionamiento del sistema DIDComm, permitiendo una
/// parametrización centralizada y flexible
class DIDCommConfig {
  final String didResolverEndpoint;
  final String transportEndpoint;
  final String wsEndpoint;
  final bool useWebSockets;
  final String storageLocation;
  final String logLevel;
  
  /// Constructor de la configuración
  /// 
  /// Todos los parámetros son opcionales y tienen valores por defecto
  /// razonables para desarrollo local
  DIDCommConfig({
    this.didResolverEndpoint = 'http://localhost:8000/resolve-did',
    this.transportEndpoint = 'http://localhost:8080/didcomm',
    this.wsEndpoint = 'ws://localhost:8081/ws',
    this.useWebSockets = false,
    this.storageLocation = 'didcomm_keys',
    this.logLevel = 'info',
  });
  
  /// Crea una instancia de configuración desde variables de entorno
  /// 
  /// Utiliza dotenv para leer las variables del archivo .env
  factory DIDCommConfig.fromEnv() {
    return DIDCommConfig(
      didResolverEndpoint: dotenv.env['DID_RESOLVER_ENDPOINT'] ?? 'http://10.0.2.2:8000/resolve-did',
      transportEndpoint: dotenv.env['DIDCOMM_ENDPOINT'] ?? 'http://10.0.2.2:8000/didcomm',
      wsEndpoint: dotenv.env['DIDCOMM_WS'] ?? 'ws://10.0.2.2:8081/ws',
      useWebSockets: dotenv.env['USE_WS']?.toLowerCase() == 'true',
      storageLocation: dotenv.env['STORAGE_LOCATION'] ?? 'didcomm_keys',
      logLevel: dotenv.env['LOG_LEVEL']?.toLowerCase() ?? 'info',
    );
  }
  
  /// Crea una instancia de configuración desde un mapa JSON
  factory DIDCommConfig.fromJson(Map<String, dynamic> json) {
    return DIDCommConfig(
      didResolverEndpoint: json['didResolverEndpoint'],
      transportEndpoint: json['transportEndpoint'],
      wsEndpoint: json['wsEndpoint'],
      useWebSockets: json['useWebSockets'] ?? false,
      storageLocation: json['storageLocation'],
      logLevel: json['logLevel'],
    );
  }
  
  /// Convierte la configuración a un mapa JSON
  Map<String, dynamic> toJson() {
    return {
      'didResolverEndpoint': didResolverEndpoint,
      'transportEndpoint': transportEndpoint,
      'wsEndpoint': wsEndpoint,
      'useWebSockets': useWebSockets,
      'storageLocation': storageLocation,
      'logLevel': logLevel,
    };
  }
  
  /// Crea una copia de esta configuración con valores actualizados
  DIDCommConfig copyWith({
    String? didResolverEndpoint,
    String? transportEndpoint,
    String? wsEndpoint,
    bool? useWebSockets,
    String? storageLocation,
    String? logLevel,
  }) {
    return DIDCommConfig(
      didResolverEndpoint: didResolverEndpoint ?? this.didResolverEndpoint,
      transportEndpoint: transportEndpoint ?? this.transportEndpoint,
      wsEndpoint: wsEndpoint ?? this.wsEndpoint,
      useWebSockets: useWebSockets ?? this.useWebSockets,
      storageLocation: storageLocation ?? this.storageLocation,
      logLevel: logLevel ?? this.logLevel,
    );
  }
}
