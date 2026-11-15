# Talqui Flutter SDK: instructions for AI coding agents

Quick install guide for AI agents adding Talqui live chat to a Flutter app (iOS and Android). Follow the steps in order. Every step ends with something to check before moving on.

Package: `talqui_sdk_flutter`. Human docs: [README](./README.md).

**Full documentation:** [docs.talqui.chat/guides/chat-sdks/flutter](https://docs.talqui.chat/guides/chat-sdks/flutter). Open it whenever you need more than this guide: identifying users, metadata, every event, permissions per platform and troubleshooting. The rest of the Talqui platform (REST API, webhooks, chatbots, AI agents) is documented at [docs.talqui.chat](https://docs.talqui.chat).

## 0. What you need from the user

Two IDs from their Talqui workspace. They are public (the same values go in a website snippet), so they can live in the app code, in `--dart-define` values or in the project's config.

| Value | Where it is |
| --- | --- |
| `tenantId` | The workspace UUID. In the app URL: `https://app.talqui.chat/tenant/<tenantId>/...` |
| `connectionId` | The WebChat connection UUID. app.talqui.chat → Plugins → WebChat → Installation, or in the URL of that connection: `.../connections/<connectionId>` |

How to get them:

1. **Ask the user** for both IDs.
2. **No Talqui account yet?** Open `https://app.talqui.chat/initiate/signup/` in their browser and ask them to create the account. If you can see the browser, wait until they are logged in, then read `tenantId` from the address bar (`/tenant/<tenantId>/`).
3. **No WebChat connection yet?** Ask them to add one in Plugins → WebChat, then read `connectionId` from the Installation screen or the connection URL.

Never ask for, type or read the user's password or any secret. You only need the two IDs. Both are UUIDs (`xxxxxxxx-xxxx-4xxx-xxxx-xxxxxxxxxxxx`); if a value does not look like one, ask again.

## 1. Check the project

| Requirement | How to check |
| --- | --- |
| Flutter 3.24+ / Dart 3.5+ | `flutter --version`, `environment:` in `pubspec.yaml` |
| iOS 13+ | `platform :ios` in `ios/Podfile` |
| Android 7+ (API 24) | `minSdk` in `android/app/build.gradle(.kts)`; raise it to 24 if lower |

Also note where the app builds `MaterialApp` / `CupertinoApp`, its navigation (`Navigator`, `go_router`, `auto_route`) and its state management (Provider, Riverpod, Bloc, GetIt). Use what is there.

## 2. Install

```bash
flutter pub add talqui_sdk_flutter
```

**Check:** `talqui_sdk_flutter` is in `pubspec.yaml` and `flutter pub get` succeeds.

## 3. Create one controller and keep it

```dart
import 'package:talqui_sdk_flutter/talqui_sdk_flutter.dart';

final talqui = TalquiController(
  tenantId: 'TENANT_ID',
  connectionId: 'CONNECTION_ID',
);
```

- One controller for the whole app. Create it once: a top-level `final`, a Provider/Riverpod provider, a GetIt singleton or the root `State`.
- If it lives in a `State`, call `talqui.dispose()` in that `State`'s `dispose()`.
- Do not create a controller inside `build()`: every rebuild would load a new chat.
- During integration pass `debug: true` to log every message exchanged with the chat. Remove it before shipping.
- For per-environment IDs: `const String.fromEnvironment('TALQUI_TENANT_ID')` with `--dart-define`.

## 4. Open the chat

Full screen, from any button (support screen, settings, help menu):

```dart
FilledButton(
  onPressed: () => talqui.open(context),
  child: const Text('Talk to us'),
)
```

`context` must be under a `Navigator` (any `MaterialApp`, `CupertinoApp` or `go_router` app). `open` pushes a full-screen route; do not wrap it in a bottom sheet or dialog.

Or inline, as a tab or screen of its own:

```dart
TalquiChat(controller: talqui, hideCloseButton: true)
```

- Give it the space it should fill (a tab body, `Expanded`, `Scaffold.body`).
- `hideCloseButton` removes the header's close button, which has nothing to close in a tab.
- Show one `TalquiChat` at a time: they share the controller's chat page.

Unread badge:

```dart
ValueListenableBuilder<int>(
  valueListenable: talqui.unreadCount,
  builder: (context, unread, child) => Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: child),
  child: const Icon(Icons.chat_bubble_outline),
)
```

## 5. Permissions (attachments, camera, voice messages)

`ios/Runner/Info.plist`, inside the main `<dict>`:

```xml
<key>NSCameraUsageDescription</key>
<string>Take photos to send in the support chat.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Record voice messages for the support chat.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Choose photos to send in the support chat.</string>
```

`android/app/src/main/AndroidManifest.xml`, above `<application>`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

Keep `android:windowSoftInputMode="adjustResize"` on the activity (the Flutter template default). Merge with existing entries; never replace the files. Rebuild the app after editing them (a hot reload is not enough).

## 6. Connect it to the app's login (when the app has users)

```dart
// after login
await talqui.identify(TalquiUser(name: user.name, email: user.email, phone: user.phone));

// on logout, always
await talqui.logout();
```

- Find the app's existing login and logout code (auth service, Bloc event, Riverpod notifier) and call these there. Do not create a new auth flow.
- `phone` in international format (`+5511999990000`). Invalid values are ignored, the rest still applies.
- `userHash` keeps a user's history across devices. It must be computed **on the backend**: `HMAC_SHA256(secret, "<tenantId>:<userId>")`, lowercase hex. Never put the secret in the app. If the project has no backend endpoint for it, skip `userHash` and tell the user.

Optional context the support team sees next to the conversation:

```dart
talqui.setContactMeta({'plan': 'pro'});                         // about the person
talqui.setSessionMeta({'screen': 'checkout', 'order_id': '4821'}); // about this conversation
```

Keys: `a-z 0-9 _ -`, up to 60 chars, 20 per call. Values: `String`, `num`, `bool` (stored as text, 255 chars) or `null` to remove. Never send passwords, tokens or card data.

## 7. Validate

Run these and report the result to the user:

1. `flutter analyze` has no new issues.
2. `flutter run` on a simulator or device and trigger `open(context)`.
3. With `debug: true`, the console shows `[talqui] ← ready {...}` within a few seconds.
4. The chat shows the workspace name and a message box. Send "Test from the app".
5. Ask the user to confirm the message arrived in their inbox at app.talqui.chat.
6. If the app identifies users: after login the pre-chat form does not appear (when name, email and phone cover the fields the workspace requires); after logout and opening again, the chat starts as a new visitor.

## 8. Troubleshooting

| Symptom | Fix |
| --- | --- |
| "Invalid link" screen | `tenantId` or `connectionId` is wrong or not a UUID. |
| `Navigator operation requested with a context that does not include a Navigator` | Call `open` with a `context` below `MaterialApp` / the router. |
| Attach / camera / mic does nothing | Permissions from step 5 are missing; rebuild after editing them. |
| Keyboard covers the message box | The chat is inside a bottom sheet or dialog; use `open(context)` or a full screen. |
| Chat reloads all the time | The controller is created in `build()`; create it once (step 3). |
| Android build fails on minSdk | Raise `minSdk` to 24. |

## Rules

- Do not fork the SDK, copy its source or call the chat page directly. Use the package API.
- Do not edit files in the pub cache.
- Keep the change small: controller, one entry point, permissions, login hooks. Ask before adding screens the user did not request.
