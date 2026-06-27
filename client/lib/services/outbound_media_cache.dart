import 'dart:typed_data';

/// In-memory media bytes for web retry (SharedPreferences cannot hold large blobs).
class OutboundMediaCache {
  OutboundMediaCache._();

  static final OutboundMediaCache instance = OutboundMediaCache._();

  final Map<String, Uint8List> _bytes = {};

  void put(String clientId, Uint8List bytes) => _bytes[clientId] = bytes;

  Uint8List? take(String clientId) => _bytes.remove(clientId);

  Uint8List? peek(String clientId) => _bytes[clientId];

  void remove(String clientId) => _bytes.remove(clientId);
}
