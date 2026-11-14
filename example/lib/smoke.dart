// Unattended smoke run of the SDK on a device or simulator: opens the chat,
// identifies a user, updates the conversation, logs out and opens again,
// printing every step. For SDK development only:
//
//   flutter run -t lib/smoke.dart --dart-define=TALQUI_TENANT_ID=… --dart-define=TALQUI_CONNECTION_ID=…
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:talqui_flutter/talqui_flutter.dart';

import 'talqui_config.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(MaterialApp(navigatorKey: navigatorKey, home: const Scaffold(body: Center(child: Text('Talqui smoke run')))));
  WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_run()));
}

Future<void> _run() async {
  final talqui = TalquiController(
    tenantId: talquiTenantId,
    connectionId: talquiConnectionId,
    debugBaseUrl: talquiBaseUrl.isEmpty ? null : talquiBaseUrl,
  );
  talqui.events.listen((e) => debugPrint('SMOKE event ${e.name} ${e.payload}'));
  final context = navigatorKey.currentContext!;

  Future<void> ready() async {
    final end = DateTime.now().add(const Duration(seconds: 30));
    while (!talqui.isReady.value && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    debugPrint('SMOKE ready=${talqui.isReady.value}');
  }

  unawaited(talqui.open(context));
  await ready();
  await talqui.identify(const TalquiUser(name: 'Smoke iOS', email: 'smoke@example.com', phone: '+5511999990000'));
  talqui.setContactMeta({'plan': 'smoke'});
  talqui.setSessionMeta({'screen': 'smoke'});
  await Future<void>.delayed(const Duration(seconds: 3));
  talqui.close();
  debugPrint('SMOKE closed open=${talqui.isOpen}');
  await Future<void>.delayed(const Duration(seconds: 1));
  await talqui.logout();
  debugPrint('SMOKE logged out');
  unawaited(talqui.open(navigatorKey.currentContext!));
  await ready();
  debugPrint('SMOKE done');
}
