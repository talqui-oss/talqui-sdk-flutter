import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:talqui_flutter/src/protocol.dart';

const tenant = 'a0047199-8537-4f7d-bef8-2fae04a7ffd6';
const connection = 'a575c54c-4f0e-49e9-87c1-1b80df59e9df';

void main() {
  final fixtures = jsonDecode(File('bridge-fixtures/v1.json').readAsStringSync()) as Map<String, dynamic>;

  test('the URL carries everything in the fragment, never in the query string', () {
    final url = buildChatUrl(baseUrl: 'https://webchat.talqui.chat/', tenantId: tenant, connectionId: connection);
    final parts = url.split('#');
    expect(parts.first, 'https://webchat.talqui.chat/');
    final query = Uri.splitQueryString(parts.last.split('?').last);
    expect(query['T_ID'], tenant);
    expect(query['PC_ID'], connection);
    expect(query['EMBED'], '1');
    expect(query['SDK'], matches(RegExp(r'^flutter@\d+\.\d+\.\d+$')));
    expect(query.containsKey('A_ID') || query.containsKey('S_ID'), isFalse);
  });

  test('an anonymous identity goes as A_ID, an identified one as S_ID', () {
    final anon = buildChatUrl(baseUrl: 'https://x.test', tenantId: tenant, connectionId: connection, identity: const TalquiIdentity(identified: false, id: 'device-0001'));
    final user = buildChatUrl(baseUrl: 'https://x.test', tenantId: tenant, connectionId: connection, identity: TalquiIdentity(identified: true, id: 'a' * 64));
    expect(anon, contains('A_ID=device-0001'));
    expect(anon, isNot(contains('S_ID')));
    expect(user, contains('S_ID=${'a' * 64}'));
    expect(user, isNot(contains('A_ID')));
  });

  test('a command carries its envelope as a JSON string literal', () {
    for (final message in (fixtures['commands']['valid'] as List).cast<Map<String, dynamic>>()) {
      final script = commandScript(message['name'] as String, Map<String, Object?>.from(message['payload'] as Map), message['id'] as String);
      final literal = RegExp(r'receive\((".*")\);$').firstMatch(script)!.group(1)!;
      expect(jsonDecode(jsonDecode(literal) as String), message);
    }
    final tricky = commandScript('prefill', {'text': '"); alert(1); ("'}, 'c-1');
    final literal = RegExp(r'receive\((".*")\);$').firstMatch(tricky)!.group(1)!;
    expect((jsonDecode(jsonDecode(literal) as String) as Map)['payload'], {'text': '"); alert(1); ("'});
  });

  test('every fixture event is read back with its name and payload', () {
    for (final event in (fixtures['events'] as List).cast<Map<String, dynamic>>()) {
      final parsed = parseEvent(jsonEncode(event))!;
      expect(parsed.name, event['name']);
      expect(parsed.payload, event['payload']);
    }
  });

  test('anything that is not a v1 event is ignored', () {
    expect(parseEvent('not json'), isNull);
    expect(parseEvent('null'), isNull);
    expect(parseEvent(jsonEncode({'talqui': 2, 'kind': 'event', 'name': 'ready', 'payload': {}})), isNull);
    expect(parseEvent(jsonEncode({'talqui': 1, 'kind': 'command', 'name': 'ready', 'payload': {}})), isNull);
    expect(parseEvent(jsonEncode({'talqui': 1, 'kind': 'event', 'name': 'closeRequested'}))!.payload, isEmpty);
  });

  test('metadata is normalized, and what cannot be fixed is dropped with a warning', () {
    final warnings = <String>[];
    final out = normalizeMeta(
      {'Plan': 'pro', 'Order Id': 4821, 'vip': true, 'gone': null, 'long': 'x' * 300, 'nested': {'a': 1}, 'a.b': 'x', 'constructor': 'x', 'nan': double.nan},
      warnings.add,
    );
    expect(out, {'plan': 'pro', 'order_id': '4821', 'vip': 'true', 'gone': null, 'long': 'x' * 255});
    expect(warnings.any((w) => w.contains('"Plan" was sent as "plan"')), isTrue);
    expect(warnings.any((w) => w.contains('"nested" ignored')), isTrue);
    expect(warnings.any((w) => w.contains('"a.b" ignored')), isTrue);
    expect(warnings.any((w) => w.contains('"constructor" ignored')), isTrue);
    expect(warnings.any((w) => w.contains('"nan" ignored')), isTrue);
  });

  test('a stored identity is read back only when it is well formed', () {
    expect(TalquiIdentity.fromJson({'kind': 'anonymous', 'id': 'device-0001'})?.id, 'device-0001');
    expect(TalquiIdentity.fromJson({'kind': 'identified', 'id': 'short'}), isNull);
    expect(TalquiIdentity.fromJson({'kind': 'admin', 'id': 'device-0001'}), isNull);
    expect(TalquiIdentity.fromJson('garbage'), isNull);
  });

  test('userHash must look like a hash, not a raw id', () {
    expect(userHashPattern.hasMatch('f' * 64), isTrue);
    expect(userHashPattern.hasMatch('123'), isFalse);
  });
}
