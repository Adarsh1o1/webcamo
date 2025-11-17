// lib/views/wifi/wifi_screen.dart
// (This is your refactored 'HomeScreen' widget)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webcamo/providers/connection_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late TextEditingController _ipController;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(text: '192.168.31.183');
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // We get all the providers here
    final isConnected = ref.watch(isConnectedProvider);
    final isLoading = ref.watch(isConnectionLoadingProvider);
    final error = ref.watch(connectionErrorProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    isConnected ? Icons.check_circle : Icons.link_off,
                    color: isConnected ? Colors.green : Colors.red,
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isConnected ? 'CONNECTED' : 'DISCONNECTED',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isConnected ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // IP Input
          TextField(
            controller: _ipController,
            decoration: const InputDecoration(
              labelText: 'Device IP Address',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Connect Button
          ElevatedButton(
            onPressed: isLoading
                ? null
                : () {
                    if (isConnected) {
                      ref.read(connectionProvider.notifier).disconnect();
                    } else {
                      ref
                          .read(connectionProvider.notifier)
                          .connectToDevice(_ipController.text);
                    }
                  },
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(isConnected ? 'Disconnect' : 'Connect'),
          ),

          // Error Message
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  error,
                  style: TextStyle(color: Colors.red.shade800),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
