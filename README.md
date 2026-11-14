# Talqui for Flutter

Add Talqui live chat to your Flutter app. Your users talk to your team, your bots and your AI agents from inside the app, with their history, attachments and voice messages.

- **Full screen or inline.** `open(context)` from any button, or `TalquiChat` in a tab.
- **Knows who is talking.** Pass the logged-in user and data about the conversation (an order, a plan, the screen they are on), at any moment.
- **Events.** Unread badge, new messages, chat closed.
- **Safe logout.** One call and the next user of the phone starts from nothing.
- **Attachments work on Android** out of the box (file picker wired for you).

## Requirements

Flutter 3.24+, iOS 13+, Android 7+ (API 24).

## Install

```bash
flutter pub add talqui_flutter
```

## Get your IDs

You need your **Tenant ID** and your WebChat **Connection ID**: app.talqui.chat → Plugins → WebChat → Installation. [Step by step with screenshots →](https://docs.talqui.chat/guides/chat-sdks/get-your-ids)

## Quick start

```dart
import 'package:talqui_flutter/talqui_flutter.dart';

final talqui = TalquiController(tenantId: 'YOUR_TENANT_ID', connectionId: 'YOUR_CONNECTION_ID');

FilledButton(
  onPressed: () => talqui.open(context),
  child: const Text('Talk to us'),
);
```

Create the controller once (a `State`, Provider, Riverpod, GetIt…) and reuse it. Want the chat in a tab instead? Put `TalquiChat(controller: talqui)` in that screen.

## Permissions

Attachments, photos and voice messages need these entries.

`ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Take photos to send in the support chat.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Record voice messages for the support chat.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Choose photos to send in the support chat.</string>
```

`android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

Keep `android:windowSoftInputMode="adjustResize"` on your activity (the Flutter default) so the keyboard never covers the message box.

## Identify users

```dart
await talqui.identify(const TalquiUser(name: 'Ana Souza', email: 'ana@example.com', phone: '+5511999990000'));
```

To keep a user's history across devices, also pass a `userHash` computed **on your backend**: `HMAC_SHA256(secret, "<tenantId>:<userId>")`. Never compute it in the app. [Read more →](https://docs.talqui.chat/guides/chat-sdks/identify-users)

## Metadata

```dart
talqui.setContactMeta({'plan': 'pro'});                    // about the person
talqui.setSessionMeta({'order_id': '4821', 'step': 'cart'}); // about this conversation, can change any time
```

Your team sees it next to the conversation. Keys: lowercase letters, digits, `_` and `-`. [Read more →](https://docs.talqui.chat/guides/chat-sdks/metadata)

## Events

```dart
talqui.events.where((e) => e.name == 'messageReceived').listen((e) => print(e.payload['preview']));

ValueListenableBuilder<int>(
  valueListenable: talqui.unreadCount, // for a badge
  builder: (context, unread, _) => Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.chat)),
);
```

[All events →](https://docs.talqui.chat/guides/chat-sdks/events)

## Logout

```dart
await talqui.logout(); // call it when your user logs out
```

## Example app

```bash
cd example && flutter run
```

It has an "Open chat" button and a "Chat" tab, connected to the Talqui demo workspace.

## Troubleshooting

- **The attach or camera button does nothing**: the permissions above are missing.
- **The keyboard covers the message box**: do not open the chat in a bottom sheet; `open(context)` uses a full-screen route.
- **"Invalid link" screen**: `tenantId` or `connectionId` is wrong.

[More →](https://docs.talqui.chat/guides/chat-sdks/troubleshooting)

## Documentation

[docs.talqui.chat/guides/chat-sdks/flutter](https://docs.talqui.chat/guides/chat-sdks/flutter)

## License

MIT

Built by [Talqui](https://talqui.chat).
