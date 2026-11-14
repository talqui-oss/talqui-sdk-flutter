import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'chat.dart';
import 'identity_store.dart';
import 'protocol.dart';

/// How long the page may take to say it is ready before it is reloaded once, then shown as failed.
const Duration _readyTimeout = Duration(seconds: 15);

/// How long `logout()` waits for the page to confirm it dropped the conversation.
const Duration _resetTimeout = Duration(seconds: 2);

/// Who the user is, as far as your app knows. Every field is optional.
class TalquiUser {
  const TalquiUser({this.userId, this.userHash, this.name, this.email, this.phone});

  /// Your own id for the user. Only for your bookkeeping; never sent as the identity.
  final String? userId;

  /// Identifies the user across devices and keeps their history after they log
  /// in again. Computed on YOUR backend, never in the app:
  /// `HMAC_SHA256(secret, "<tenantId>:<userId>")` as lowercase hex. Anyone
  /// holding it can read that user's conversation, so treat it like a session
  /// token. 32 to 128 chars of `A-Z a-z 0-9 _ -`.
  final String? userHash;
  final String? name;
  final String? email;
  final String? phone;
}

/// The Talqui chat. Create one, keep it for the life of your app, and pass it
/// to `TalquiChat` or call `open(context)`.
///
/// ```dart
/// final talqui = TalquiController(tenantId: '…', connectionId: '…');
/// talqui.open(context);
/// ```
class TalquiController extends ChangeNotifier with WidgetsBindingObserver {
  TalquiController({
    required this.tenantId,
    required this.connectionId,
    this.onOpenUrl,
    this.debug = false,
    /// Points the SDK at another WebChat deployment. Only for developing the SDK itself.
    String? debugBaseUrl,
  })  : baseUrl = debugBaseUrl ?? talquiDefaultBaseUrl,
        _store = IdentityStore(tenantId) {
    if (!isUuid(tenantId) || !isUuid(connectionId)) {
      _warn('tenantId and connectionId must be the UUIDs shown on the WebChat installation screen.');
    }
    WidgetsBinding.instance.addObserver(this);
    _identityLoaded = _store.read().then((stored) => _identity = stored);
  }

  /// Your workspace id (app.talqui.chat → Plugins → WebChat → Installation).
  final String tenantId;

  /// The WebChat connection id, on the same screen.
  final String connectionId;

  /// Called for every link the user taps in the chat. Default: open it in the system browser.
  final void Function(Uri url)? onOpenUrl;

  /// Logs every message exchanged with the chat page.
  final bool debug;

  /// The WebChat deployment. Only changed when developing the SDK.
  final String baseUrl;

  final IdentityStore _store;
  late final Future<void> _identityLoaded;
  TalquiIdentity? _identity;

  WebViewController? _webView;
  bool _ready = false;
  bool _failed = false;
  int _attempt = 0;
  Timer? _watchdog;

  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
  final ValueNotifier<bool> isReady = ValueNotifier<bool>(false);
  final StreamController<TalquiEvent> _events = StreamController<TalquiEvent>.broadcast();

  /// Every event from the chat: `messageReceived`, `unreadChanged`, `closeRequested`…
  Stream<TalquiEvent> get events => _events.stream;

  // What the app told the chat, replayed every time a page (re)loads so nothing is lost.
  Map<String, String>? _contact;
  Map<String, String?> _contactMeta = {};
  Map<String, String?> _sessionMeta = {};
  String? _pendingPrefill;
  int _commandSeq = 0;

  int _hosts = 0;
  bool _routeOpen = false;
  bool _appActive = true;
  Route<void>? _route;

  /// Whether the full-screen chat route is on screen.
  bool get isOpen => _routeOpen;

  /// The page failed to load twice; `TalquiChat` shows a retry.
  bool get failed => _failed;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Shows the chat full screen.
  Future<void> open(BuildContext context) async {
    if (_routeOpen) return;
    _routeOpen = true;
    final route = MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        // Never a bottom sheet: text input inside one is unreliable on Android.
        body: SafeArea(child: TalquiChat(controller: this)),
      ),
    );
    _route = route;
    _syncVisibility();
    await Navigator.of(context).push(route);
    // Only if this is still the current route: a quick close-and-open already replaced it.
    if (identical(_route, route)) _markClosed();
  }

  /// Hides the full-screen chat.
  void close() {
    final route = _route;
    if (route == null) return;
    _markClosed();
    if (route.isActive) route.navigator?.removeRoute(route);
  }

  void _markClosed() {
    _routeOpen = false;
    _route = null;
    _syncVisibility();
  }

  /// Loads the chat ahead of time, so opening is instant and unread messages are counted.
  Future<void> preload() async {
    await _ensureWebView();
  }

  /// Sets who the user is. With a `userHash` the chat reloads as that user
  /// (their history follows them across devices); without one, the details
  /// are attached to this device's anonymous visitor.
  Future<void> identify(TalquiUser user) async {
    await _identityLoaded;
    final hash = user.userHash;
    if (hash != null) {
      if (!userHashPattern.hasMatch(hash)) {
        _warn('identify: userHash must be 32 to 128 chars of A-Z a-z 0-9 _ - (compute it on your backend). Ignored.');
      } else if (_identity?.identified != true || _identity?.id != hash) {
        _identity = TalquiIdentity(identified: true, id: hash);
        await _store.write(_identity!);
        // Another person: nothing from the previous one may carry over.
        _resetReplay();
        await _remount();
      }
    }
    setContact(name: user.name, email: user.email, phone: user.phone);
  }

  void setContact({String? name, String? email, String? phone}) {
    final next = {
      ...?_contact,
      if (name != null && name.isNotEmpty) 'name': name,
      if (email != null && email.isNotEmpty) 'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    };
    if (next.isEmpty) return;
    _contact = next;
    _send('setContact', next);
  }

  /// Data about the person, kept on their contact. Values: strings, numbers or booleans; `null` removes a key.
  void setContactMeta(Map<String, Object?> meta) {
    final normalized = normalizeMeta(meta, _warn);
    if (normalized.isEmpty) return;
    _contactMeta = {..._contactMeta, ...normalized};
    _send('setContactMeta', normalized);
  }

  /// Data about this conversation (an order, the screen they are on). Can change at any moment.
  void setSessionMeta(Map<String, Object?> meta) {
    final normalized = normalizeMeta(meta, _warn);
    if (normalized.isEmpty) return;
    _sessionMeta = {..._sessionMeta, ...normalized};
    _send('setSessionMeta', normalized);
  }

  /// Puts text in the message box. The user still decides to send it.
  void prefill(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final value = trimmed.length > 1000 ? trimmed.substring(0, 1000) : trimmed;
    if (_ready) {
      _send('prefill', {'text': value});
    } else {
      _pendingPrefill = value;
    }
  }

  /// Call it when your user logs out: forgets this user and starts a fresh anonymous visitor.
  Future<void> logout() async {
    if (_ready && _webView != null) {
      // Ask the page to drop the conversation now, but never hang on it.
      final done = events.firstWhere((e) => e.name == 'resetDone').timeout(_resetTimeout, onTimeout: () => const TalquiEvent('resetDone', {}));
      _send('reset', {});
      await done.catchError((_) => const TalquiEvent('resetDone', {}));
    }
    await _store.clear();
    _identity = null;
    // The previous user's details must not be replayed into the next page.
    _resetReplay();
    await _remount();
  }

  // ---------------------------------------------------------------------------
  // Used by TalquiChat
  // ---------------------------------------------------------------------------

  /// The WebView of the current page, created on first use.
  @internal
  WebViewController? get webView => _webView;

  @internal
  void attachHost() {
    _hosts++;
    unawaited(_ensureWebView());
    _syncVisibility();
  }

  @internal
  void detachHost() {
    _hosts = (_hosts - 1).clamp(0, 1 << 20);
    _syncVisibility();
  }

  @internal
  void retry() {
    _attempt = 0;
    _failed = false;
    notifyListeners();
    unawaited(_webView?.reload());
    _armWatchdog();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _syncVisibility();
    // iOS may kill a backgrounded WebView's page; a blank page never says ready again.
    if (_appActive && _webView != null && !_ready && !_failed) _armWatchdog();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watchdog?.cancel();
    unawaited(_events.close());
    unreadCount.dispose();
    isReady.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<void> _ensureWebView() async {
    if (_webView != null) return;
    await _identityLoaded;
    if (_webView != null) return;
    _webView = _createWebView();
    notifyListeners();
  }

  /// A new page for another person (identify with a new hash, logout). A
  /// running page is never switched to someone else in place.
  Future<void> _remount() async {
    _setReady(false);
    unreadCount.value = 0;
    _attempt = 0;
    _failed = false;
    final hadPage = _webView != null;
    _webView = null;
    if (hadPage) {
      _webView = _createWebView();
    }
    notifyListeners();
  }

  WebViewController _createWebView() {
    final params = WebViewPlatform.instance is WebKitWebViewPlatform
        ? WebKitWebViewControllerCreationParams(allowsInlineMediaPlayback: true, mediaTypesRequiringUserAction: const {})
        : const PlatformWebViewControllerCreationParams();

    final origin = Uri.parse(baseUrl).origin;
    final controller = WebViewController.fromPlatformCreationParams(
      params,
      // Camera and microphone for photos and voice messages, only for the chat page itself.
      onPermissionRequest: (request) => request.grant(),
    )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel('TalquiNative', onMessageReceived: (message) => _onMessage(message.message))
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => _setReady(false),
        onNavigationRequest: (request) {
          // Sub-frames (embedded media) load freely; only the page itself is guarded.
          if (!request.isMainFrame || request.url == 'about:blank' || request.url.startsWith(origin)) {
            return NavigationDecision.navigate;
          }
          _openOutside(request.url);
          return NavigationDecision.prevent;
        },
      ));

    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setMediaPlaybackRequiresUserGesture(false);
      // Without this, the attach button does nothing on Android.
      platform.setOnShowFileSelector(_pickFiles);
    }

    final url = buildChatUrl(baseUrl: baseUrl, tenantId: tenantId, connectionId: connectionId, identity: _identity);
    _log('load $url');
    controller.loadRequest(Uri.parse(url));
    _armWatchdog();
    return controller;
  }

  Future<List<String>> _pickFiles(FileSelectorParams params) async {
    final types = params.acceptTypes.where((t) => t.trim().isNotEmpty).toList();
    final group = XTypeGroup(label: 'files', mimeTypes: types.isEmpty ? null : types);
    final files = params.mode == FileSelectorMode.openMultiple
        ? await openFiles(acceptedTypeGroups: [group])
        : [if (await openFile(acceptedTypeGroups: [group]) case final file?) file];
    // The WebView expects file:// URIs.
    return files.map((file) => Uri.file(file.path).toString()).toList();
  }

  void _armWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(_readyTimeout, () {
      if (_ready || _webView == null) return;
      if (_attempt == 0) {
        _log('chat did not become ready, reloading once');
        _attempt = 1;
        unawaited(_webView!.reload());
        _armWatchdog();
      } else {
        _failed = true;
        notifyListeners();
      }
    });
  }

  void _onMessage(String raw) {
    final event = parseEvent(raw);
    if (event == null) return;
    _log('← ${event.name} ${event.payload}');

    switch (event.name) {
      case 'ready':
        _watchdog?.cancel();
        _setReady(true);
        final identity = event.payload['identity'];
        final minted = identity is Map ? identity['anonymousId'] : null;
        // The page minted an anonymous identity: keep it, so this device stays the same visitor.
        if (minted is String && _identity == null) {
          _identity = TalquiIdentity(identified: false, id: minted);
          unawaited(_store.write(_identity!));
        }
        _replay();
      case 'unreadChanged':
        final count = event.payload['count'];
        if (count is int) unreadCount.value = count;
      case 'openUrl':
        final url = event.payload['url'];
        if (url is String) _openOutside(url);
      case 'closeRequested':
        close();
      case 'error':
        _warn('${event.payload['code']}: ${event.payload['message']}');
    }

    if (!_events.isClosed) _events.add(event);
  }

  void _replay() {
    final contact = _contact;
    if (contact != null) _send('setContact', contact);
    if (_contactMeta.isNotEmpty) _send('setContactMeta', _contactMeta);
    if (_sessionMeta.isNotEmpty) _send('setSessionMeta', _sessionMeta);
    _send('setVisibility', {'visible': _visible});
    final prefill = _pendingPrefill;
    if (prefill != null) {
      _pendingPrefill = null;
      _send('prefill', {'text': prefill});
    }
  }

  void _resetReplay() {
    _contact = null;
    _contactMeta = {};
    _sessionMeta = {};
    _pendingPrefill = null;
  }

  bool get _visible => _appActive && (_routeOpen || _hosts > 0);

  void _syncVisibility() => _send('setVisibility', {'visible': _visible});

  void _send(String name, Map<String, Object?> payload) {
    // Before `ready` there is nothing to send to: the replay is delivered on `ready`.
    final webView = _webView;
    if (!_ready || webView == null) return;
    _log('→ $name $payload');
    unawaited(webView.runJavaScript(commandScript(name, payload, 'c-${++_commandSeq}')).catchError((Object error) {
      _log('command $name failed: $error');
    }));
  }

  void _setReady(bool ready) {
    _ready = ready;
    isReady.value = ready;
  }

  void _openOutside(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (onOpenUrl != null) {
      onOpenUrl!(uri);
    } else {
      unawaited(launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false));
    }
  }

  void _log(String message) {
    if (debug) debugPrint('[talqui] $message');
  }

  void _warn(String message) => debugPrint('[talqui] $message');
}
