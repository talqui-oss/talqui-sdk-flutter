# Example

A small app with an "Open chat" button and a "Chat" tab, connected to the Talqui demo workspace.

```bash
flutter run
```

Use your own workspace with `--dart-define=TALQUI_TENANT_ID=… --dart-define=TALQUI_CONNECTION_ID=…` (see `lib/talqui_config.dart`).

`lib/smoke.dart` runs the main flows unattended (open, identify, update, logout, open again) and prints each step; it is for developing the SDK.
