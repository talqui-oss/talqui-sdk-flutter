import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'controller.dart';

/// The chat inline, filling its parent — for a "Chat" tab or a screen of your
/// own. `TalquiController.open` uses it too, inside a full-screen route.
///
/// Keep one on screen at a time: they share the controller's page.
class TalquiChat extends StatefulWidget {
  const TalquiChat({super.key, required this.controller, this.loading, this.error});

  final TalquiController controller;

  /// Replaces the spinner shown while the chat loads.
  final Widget? loading;

  /// Replaces the message shown when the chat cannot load. Call `controller` methods from it as needed.
  final Widget Function(VoidCallback retry)? error;

  @override
  State<TalquiChat> createState() => _TalquiChatState();
}

class _TalquiChatState extends State<TalquiChat> {
  @override
  void initState() {
    super.initState();
    widget.controller.attachHost();
  }

  @override
  void dispose() {
    widget.controller.detachHost();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final webView = controller.webView;
        return ColoredBox(
          color: Colors.white,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (webView != null) WebViewWidget(key: ObjectKey(webView), controller: webView),
              ValueListenableBuilder<bool>(
                valueListenable: controller.isReady,
                builder: (context, ready, _) {
                  if (controller.failed) {
                    return ColoredBox(
                      color: Colors.white,
                      child: widget.error?.call(controller.retry) ?? _DefaultError(onRetry: controller.retry),
                    );
                  }
                  if (ready) return const SizedBox.shrink();
                  return ColoredBox(
                    color: Colors.white,
                    child: Center(child: widget.loading ?? const CircularProgressIndicator()),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DefaultError extends StatelessWidget {
  const _DefaultError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Não foi possível carregar o chat.', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Tentar de novo')),
          ],
        ),
      ),
    );
  }
}
