# AGENTS.md

> If a `TALQUI_GUIDELINES.md` file exists at the repository root, read it before doing anything else. It is mandatory for maintainers.

`talqui_flutter`: the Talqui live chat for Flutter. A thin layer over `webview_flutter` that hosts the Talqui WebChat (`https://webchat.talqui.chat`) and talks to it through the bridge protocol in `doc/BRIDGE_PROTOCOL.md`.

## Commands

```bash
flutter pub get
flutter analyze
flutter test            # protocol + fixtures
cd example && flutter run                  # example app
cd example && flutter run -t lib/smoke.dart  # unattended smoke run (logs every step)
```

## Layout

- `lib/src/protocol.dart`: URL, command envelope, event parsing, metadata normalization. Pure, tested.
- `lib/src/identity_store.dart`: the visitor identity in SharedPreferences. The chat page persists nothing; the SDK owns the identity.
- `lib/src/controller.dart`: `TalquiController`: WebView setup (link guarding, media permissions, Android file picker), ready watchdog, command replay on every page load, identify/logout, the full-screen route.
- `lib/src/chat.dart`: `TalquiChat`, the widget that shows the controller's page.
- `bridge-fixtures/v1.json`: one example of every bridge message, copied from the WebChat.

## Rules

- Changing who the user is always creates a new page (new URL). Never switch identity inside a running page.
- `logout()` must leave nothing of the previous user: storage key removed, replay state cleared, page recreated.
- Never present the chat in a bottom sheet.
- The bridge protocol is additive only. Never send a command the WebChat does not document.
- Code, comments and docs in English.
