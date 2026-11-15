# Example

A small app with an "Open chat" button and a "Chat" tab, connected to the Talqui demo workspace.

```bash
flutter run
```

Use your own workspace with `--dart-define=TALQUI_TENANT_ID=… --dart-define=TALQUI_CONNECTION_ID=…` (see `lib/talqui_config.dart`).

`lib/smoke.dart` runs the main flows unattended (open, identify, update, logout, open again) and prints each step; it is for developing the SDK.

## Push notifications

Off by default, so the example runs without Firebase. The code is in `_setupPush` (`lib/main.dart`). To try it:

1. In app.talqui.chat → Plugins → WebChat → **Notificações**, choose **Via Talqui** and upload a service account of your Firebase project (the "Firebase Cloud Messaging API Admin" role is enough).
2. Add the app to that Firebase project: `android/app/google-services.json` for Android; `ios/Runner/GoogleService-Info.plist` plus the Push Notifications capability in Xcode and your APNs key uploaded in Firebase for iOS.
3. `flutter run --dart-define=TALQUI_PUSH=1`

Talqui only notifies when the chat is not on screen, at most once per conversation every 5 minutes. Tapping the notification opens the chat.
