import 'dart:convert';

/// talqui.bridge.v1: the messages exchanged with the chat page running in the
/// WebView. Commands go in through `window.TalquiBridge.receive(json)`, events
/// come out through the `TalquiNative` JavaScript channel.
const int talquiProtocol = 1;
const String talquiDefaultBaseUrl = 'https://webchat.talqui.chat';
const String talquiSdkLabel = 'flutter@0.2.0';

final RegExp _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$', caseSensitive: false);
final RegExp identityPattern = RegExp(r'^[A-Za-z0-9_-]{8,128}$');
final RegExp userHashPattern = RegExp(r'^[A-Za-z0-9_-]{32,128}$');
final RegExp _metaKey = RegExp(r'^[a-z0-9_-]{1,60}$');
const List<String> _unsafeKeys = ['__proto__', 'constructor', 'prototype'];

bool isUuid(String value) => _uuid.hasMatch(value);

/// Who the chat page is booted as.
class TalquiIdentity {
  const TalquiIdentity({required this.identified, required this.id});

  /// `true` for a user named by your backend (`userHash`), `false` for this device's anonymous visitor.
  final bool identified;
  final String id;

  Map<String, Object> toJson() => {'kind': identified ? 'identified' : 'anonymous', 'id': id};

  static TalquiIdentity? fromJson(Object? json) {
    if (json is! Map) return null;
    final kind = json['kind'];
    final id = json['id'];
    if ((kind != 'anonymous' && kind != 'identified') || id is! String || !identityPattern.hasMatch(id)) return null;
    return TalquiIdentity(identified: kind == 'identified', id: id);
  }
}

/// The page to load. Everything lives in the URL fragment (after `#`), which
/// is never sent to a server, so the identity never reaches access logs.
String buildChatUrl({
  required String baseUrl,
  required String tenantId,
  required String connectionId,
  TalquiIdentity? identity,
}) {
  final query = <String, String>{
    'T_ID': tenantId,
    'PC_ID': connectionId,
    'EMBED': '1',
    'SDK': talquiSdkLabel,
    if (identity != null) (identity.identified ? 'S_ID' : 'A_ID'): identity.id,
  };
  final base = baseUrl.replaceAll(RegExp(r'/+$'), '');
  return '$base/#/chat?${Uri(queryParameters: query).query}';
}

/// The JavaScript run in the WebView to deliver one command. The JSON is
/// passed as a string literal, so nothing in the payload is evaluated as code.
String commandScript(String name, Map<String, Object?> payload, String id) {
  final json = jsonEncode({'talqui': talquiProtocol, 'kind': 'command', 'name': name, 'id': id, 'payload': payload});
  return 'window.TalquiBridge&&window.TalquiBridge.receive(${jsonEncode(json)});';
}

/// An event from the chat page.
class TalquiEvent {
  const TalquiEvent(this.name, this.payload);

  /// `ready`, `sessionStarted`, `messageSent`, `messageReceived`, `unreadChanged`,
  /// `closeRequested`, `openUrl`, `resetDone` or `error`.
  final String name;
  final Map<String, dynamic> payload;

  @override
  String toString() => 'TalquiEvent($name, $payload)';
}

/// Reads an event posted by the page; `null` for anything that is not a v1 event.
TalquiEvent? parseEvent(String raw) {
  Object? message;
  try {
    message = jsonDecode(raw);
  } catch (_) {
    return null;
  }
  if (message is! Map) return null;
  if (message['talqui'] != talquiProtocol || message['kind'] != 'event' || message['name'] is! String) return null;
  final payload = message['payload'];
  return TalquiEvent(message['name'] as String, payload is Map ? Map<String, dynamic>.from(payload) : <String, dynamic>{});
}

/// Turns what the app passed into what the chat accepts: keys lowercased,
/// numbers and booleans as text, long values cut. Anything that cannot be
/// fixed is dropped with a warning — never an exception in the host app.
Map<String, String?> normalizeMeta(Map<String, Object?> meta, void Function(String) warn) {
  final out = <String, String?>{};
  meta.forEach((rawKey, value) {
    final key = rawKey.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    if (key != rawKey) warn('metadata key "$rawKey" was sent as "$key".');
    if (!_metaKey.hasMatch(key) || _unsafeKeys.contains(key)) {
      warn('metadata key "$rawKey" ignored: use lowercase letters, digits, "_" and "-" (max 60 chars).');
      return;
    }
    if (value == null) {
      out[key] = null;
    } else if (value is String) {
      final trimmed = value.trim();
      out[key] = trimmed.length > 255 ? trimmed.substring(0, 255) : trimmed;
    } else if ((value is num && value.isFinite) || value is bool) {
      out[key] = value.toString();
    } else {
      warn('metadata "$rawKey" ignored: values are strings, numbers, booleans or null.');
    }
  });
  return out;
}
