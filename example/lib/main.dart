import 'package:flutter/material.dart';
import 'package:talqui_sdk_flutter/talqui_sdk_flutter.dart';

import 'talqui_config.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  // One controller for the whole app.
  final talqui = TalquiController(
    tenantId: talquiTenantId,
    connectionId: talquiConnectionId,
    debugBaseUrl: talquiBaseUrl.isEmpty ? null : talquiBaseUrl,
    debug: true,
  );
  int tab = 0;

  @override
  void initState() {
    super.initState();
    // Your analytics, a banner, a sound: every chat event is available.
    talqui.events.where((e) => e.name == 'messageReceived').listen((e) => debugPrint('New message: ${e.payload['preview']}'));
  }

  @override
  void dispose() {
    talqui.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Talqui example',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1A66FF), useMaterial3: true),
      home: Scaffold(
        body: SafeArea(
          child: IndexedStack(
            index: tab,
            children: [
              HomeScreen(talqui: talqui),
              // Mounted only while selected: one chat on screen at a time.
              if (tab == 1) TalquiChat(controller: talqui, hideCloseButton: true) else const SizedBox.shrink(),
            ],
          ),
        ),
        bottomNavigationBar: ValueListenableBuilder<int>(
          valueListenable: talqui.unreadCount,
          builder: (context, unread, _) => NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (index) => setState(() => tab = index),
            destinations: [
              const NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
              NavigationDestination(
                icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.chat_bubble_outline)),
                label: 'Chat',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.talqui});

  final TalquiController talqui;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Talqui chat example', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('The chat opens full screen. The "Chat" tab shows it inline.'),
        const SizedBox(height: 24),
        FilledButton(onPressed: () => talqui.open(context), child: const Text('Open chat')),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () {
            // In a real app: after login. The userHash comes from YOUR backend, never from the app.
            talqui.identify(const TalquiUser(name: 'Ana Souza', email: 'ana@example.com', phone: '+5511999990000'));
            talqui.setContactMeta({'plan': 'demo'});
            talqui.setSessionMeta({'screen': 'home'});
          },
          child: const Text('Identify demo user'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: () => talqui.setSessionMeta({'step': 'checkout', 'cart_items': 3}), child: const Text('Update conversation')),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: () => talqui.prefill('Hi! I need help with my order.'), child: const Text('Prefill a message')),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: talqui.logout, child: const Text('Log out')),
        const SizedBox(height: 24),
        ValueListenableBuilder<bool>(
          valueListenable: talqui.isReady,
          builder: (context, ready, _) => Text(ready ? 'Chat ready' : 'Chat not loaded yet', textAlign: TextAlign.center),
        ),
      ],
    );
  }
}
