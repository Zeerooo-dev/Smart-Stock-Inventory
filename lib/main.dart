import 'dart:async';

import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'platform/window_control.dart';
import 'state/smartstock_controller.dart';
import 'ui/smartstock_shell.dart';
import 'ui/pages/reports_page.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDesktopWindow();
  final controller = SmartStockController(sandbox: args.contains('--test'));
  runApp(SmartStockApplication(controller: controller));
  unawaited(controller.initialize());
}

class SmartStockApplication extends StatefulWidget {
  const SmartStockApplication({super.key, required this.controller});
  final SmartStockController controller;

  @override
  State<SmartStockApplication> createState() => _SmartStockApplicationState();
}

class _SmartStockApplicationState extends State<SmartStockApplication>
    with WidgetsBindingObserver {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _navigator = GlobalKey<NavigatorState>();

  void _showNotification(String title, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _messenger.currentState?.showSnackBar(
          SnackBar(
            content: Text('$title\n$message'),
            duration: const Duration(seconds: 5),
            action: title.toLowerCase().contains('stock')
                ? SnackBarAction(
                    label: 'Review stock',
                    onPressed: () {
                      final context = _navigator.currentContext;
                      if (context != null) {
                        showLowStockItems(context, widget.controller);
                      }
                    },
                  )
                : null,
          ),
        );
      } catch (_) {
        // Notification delivery must not interrupt inventory operations.
      }
    });
  }

  @override
  void initState() {
    super.initState();
    widget.controller.notifications.onNotification = _showNotification;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      unawaited(widget.controller.shutdown());
    }
  }

  @override
  void dispose() {
    widget.controller.notifications.onNotification = null;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.controller.shutdown());
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final theme = SmartStockThemes.build(
          widget.controller.theme,
          accent: widget.controller.customAccent,
        );
        return MaterialApp(
          navigatorKey: _navigator,
          scaffoldMessengerKey: _messenger,
          title: 'SmartStock Inventory System',
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: widget.controller.loading
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : widget.controller.startupError != null
              ? _StartupError(
                  message: widget.controller.startupError!,
                  controller: widget.controller,
                )
              : SmartStockShell(controller: widget.controller),
        );
      },
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.message, required this.controller});
  final SmartStockController controller;
  final String message;
  Future<void> _recoverLegacy(BuildContext context) async {
    var enteredPassphrase = '';
    final passphrase = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlock older database'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter the previous database passphrase. A recovery copy is retained before migration.',
              ),
              TextField(
                onChanged: (value) => enteredPassphrase = value,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Previous passphrase',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, enteredPassphrase),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
    if (passphrase != null && passphrase.isNotEmpty) {
      await controller.initialize(legacyPassphrase: passphrase);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 44,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'SmartStock could not open its database.',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(message, textAlign: TextAlign.center),
                    TextButton(
                      onPressed: () => controller.initialize(),
                      child: const Text('Retry'),
                    ),
                    if (controller.needsLegacyPassphrase) ...[
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => _recoverLegacy(context),
                        child: const Text('Unlock older Flutter database'),
                      ),
                    ],
                    const SizedBox(height: 10),
                    const Text(
                      'If this is a Python Fernet .db.enc file, open the old PyQt app first and create a plaintext .db backup, then use Legacy Database Import in Flutter.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
