# DIDComm Modular Implementation

[![Dart Version](https://img.shields.io/badge/Dart-2.19+-blue.svg)](https://dart.dev)
[![DIDComm v2](https://img.shields.io/badge/DIDComm-v2-green.svg)](https://identity.foundation/didcomm-messaging/spec/)
[![Blake3](https://img.shields.io/badge/Blake3-Hash-purple.svg)](https://github.com/BLAKE3-team/BLAKE3)

Una implementación modular y extensible y robusta del protocolo DIDComm v2 en
Dart, con soporte para Trust Ping 2.0 y mediación de mensajes. Esta biblioteca
utiliza Blake3 para la generación de identificadores DID, manejo estructurado de
errores y un sistema de logging configurable.

## Índice

- [Características](#características)
- [Librerías Utilizadas](#librerías-utilizadas)
- [Configuración](#configuración)
- [Estructura del Proyecto](#estructura-del-proyecto)
- [Flujo de Implementación](#flujo-de-implementación)
- [Casos de Uso](#casos-de-uso)
- [API Pública](#api-pública)
- [Manejo de Errores](#manejo-de-errores)

## Características

- **Arquitectura modular** - Componentes desacoplados organizados en capas
  lógicas
- **Manejo de errores estructurado** - Sistema unificado con categorías de error
  y logging por niveles
- **Trust Ping 2.0** - Verificación de conectividad como paso previo a
  operaciones críticas
- **Mediación de mensajes** - Capacidad para registrarse con mediadores y
  gestionar claves mediadas
- **Criptografía robusta**:
  - Ed25519 para firmas digitales
  - X25519 para intercambio de claves ECDH
  - AES-GCM para cifrado simétrico autenticado
  - Blake3 para generación de identificadores DID
- **Configuración centralizada** - Parametrización vía archivos .env

## Librerías Utilizadas

| Librería           | Versión | Propósito                                             |
| ------------------ | ------- | ----------------------------------------------------- |
| cryptography       | ^2.5.0  | Operaciones criptográficas (Ed25519, X25519, AES-GCM) |
| thirds             | ^0.2.0  | Implementación de Blake3 para hashing                 |
| bs58               | ^1.0.0  | Codificación Base58 para claves                       |
| flutter_dotenv     | ^5.1.0  | Manejo de variables de entorno                        |
| http               | ^1.1.0  | Comunicaciones HTTP                                   |
| web_socket_channel | ^2.4.0  | Transporte WebSocket                                  |
| logging            | ^1.2.0  | Sistema de logging avanzado                           |
| json_annotation    | ^4.8.1  | Serialización/deserialización JSON                    |

### Dev Dependencies

| Librería     | Versión | Propósito                       |
| ------------ | ------- | ------------------------------- |
| flutter_test | -       | Testing de componentes          |
| mockito      | ^5.4.2  | Creación de mocks para testing  |
| build_runner | ^2.4.6  | Generación de código para tests |

## Configuración

### Archivo .env

```env
USE_WS
DIDCOMM_ENDPOINT
DIDCOMM_WS

```

#### Mensajes básicos

```dart
// Enviar un mensaje genérico
final message = DIDCommMessage(
  type: 'https://didcomm.org/mi-protocolo/1.0/mi-mensaje',
  to: ['did:key:z...recipiente'],
  from: client.myDid,
  body: {'key': 'value'},
);
final success = await client.sendMessage(message);

// Verificar un mensaje firmado
final isValid = await client.verifyMessage(signedMessage);
```

#### Trust Ping

```dart
// Enviar un ping y esperar respuesta
final pingId = await client.sendPing(
  'did:key:z...recipiente',
  responseRequested: true,
  comment: 'Verificando conexión',
  timeoutSeconds: 30,
);

// Escuchar respuestas a pings
client.onPingResponse.listen((response) {
  print('Respuesta recibida para ping: ${response['thid']}');
});

// Escuchar timeouts de ping
client.onPingTimeout.listen((pingId) {
  print('Timeout para ping: $pingId');
});
```

#### Mediación

```dart
// Solicitar mediación
final success = await client.requestMediation(
  'did:key:z...mediador',
  verifyConnectivity: true, // Envía ping primero
);

// Actualizar claves mediadas
await client.updateMediatedKeys(
  'did:key:z...mediador',
  addDids: ['did:key:z...nuevoDid'],
  removeDids: ['did:key:z...didAntiguo'],
);
```

## Casos de Uso

### 1. Verificación de conectividad antes de operaciones críticas

El protocolo Trust Ping 2.0 se utiliza para verificar la conectividad con un
agente antes de realizar operaciones críticas como solicitar mediación.

```dart
try {
  // Estrategia que verifica conectividad primero
  final pingStrategy = PingFirstStrategy(
    trustPingController,
    logger: Logger(LogLevel.debug),
  );

  // Ejecutar la estrategia antes de operación crítica
  final isConnected = await pingStrategy.execute(targetDid);

  if (isConnected) {
    // Proceder con la operación crítica
    await performCriticalOperation(targetDid);
  } else {
    // Manejar fallo de conectividad
    logger.warning('No se pudo establecer conexión con $targetDid');
  }
} catch (e) {
  // Manejo estructurado de errores
  logger.error('Error durante verificación', {'error': e.toString()});
}
```

### 2. Generación y manejo de DIDs

Para crear un nuevo DID compatible con DIDComm:

```dart
try {
  // Crear un nuevo generador de DID con claves Ed25519
  final didGenerator = await DidGenerator.create(
    logger: Logger(LogLevel.info),
  );

  // Obtener el DID generado
  final myDid = didGenerator.myDid;
  print('DID generado: $myDid');

  // Serializar las claves para almacenamiento seguro
  final serializedKeys = await didGenerator.serialize();
  await secureStorage.write(key: 'my_keys', value: serializedKeys);
} catch (e) {
  final exception = e is DIDCommException
      ? e
      : DIDCommException(
          errorCode: 'DID_GENERATION_ERROR',
          message: e.toString(),
          severity: ErrorSeverity.error,
        );

  logger.error('Error generando DID', {
    'code': exception.errorCode,
    'details': exception.details,
  });
}
```

### 3. Cifrado y envío de mensajes seguros

Para enviar mensajes cifrados a través de DIDComm:

```dart
try {
  // Crear mensaje
  final message = {
    'id': uuid.v4(),
    'type': 'https://didcomm.org/mi-protocolo/1.0/mensaje-seguro',
    'from': myDid,
    'to': [recipientDid],
    'created_time': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    'body': {
      'content': 'Mensaje secreto',
      'additional_data': {'key': 'value'}
    }
  };

  // Firmar el mensaje
  final signedMessage = await signer.sign(message);

  // Cifrar el mensaje firmado
  final encryptedMessage = await encryptor.encrypt(signedMessage, recipientDid);

  // Enviar el mensaje cifrado
  await commService.send(encryptedMessage);

  logger.info('Mensaje enviado exitosamente', {'recipient': recipientDid});
} catch (e) {
  ErrorHandler.handleException(
    () => throw e,
    logger: logger,
    context: 'Envío de mensaje seguro',
  );
}
```

## Manejo de Errores y Logging

El sistema implementa un manejo estructurado de errores con niveles de severidad
y capacidades de logging extensivas:

```dart
try {
  // Código que podría fallar
} catch (e) {
  ErrorHandler.handleException(
    () => throw e,
    logger: logger,
    context: 'Operación específica',
  );
}

// Logging con diferentes niveles
logger.debug('Información detallada para debugging');
logger.info('Información general del proceso');
logger.warning('Advertencia: algo inesperado pero no crítico');
logger.error('Error importante', {'details': errorDetails});
```

## Pruebas

Para ejecutar las pruebas unitarias:

```bash
flutter test
```

## Contribución

Se agradecen las contribuciones. Por favor, asegúrate de seguir las directrices
de código y añadir pruebas unitarias para cualquier nueva funcionalidad.

## Licencia

[Especificar licencia]
