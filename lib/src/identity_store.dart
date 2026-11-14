import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'protocol.dart';

/// The visitor identity lives here, in the app's storage — never in the
/// WebView's. The chat page persists nothing about the visitor; it receives
/// the identity in its URL on every load. So `logout()` deleting this one key
/// is enough for the next user of the phone to start from nothing.
class IdentityStore {
  IdentityStore(this.tenantId);

  final String tenantId;
  String get _key => 'talqui:identity:$tenantId';

  Future<TalquiIdentity?> read() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      return raw == null ? null : TalquiIdentity.fromJson(jsonDecode(raw));
    } catch (_) {
      // Unreadable storage: start as a new anonymous visitor.
      return null;
    }
  }

  Future<void> write(TalquiIdentity identity) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_key, jsonEncode(identity.toJson()));
    } catch (_) {
      // The chat still works; the visitor just starts anew on the next launch.
    }
  }

  Future<void> clear() async {
    try {
      await (await SharedPreferences.getInstance()).remove(_key);
    } catch (_) {
      // Nothing more can be done; the page itself keeps nothing.
    }
  }
}
