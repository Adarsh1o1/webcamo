// lib/providers/connection_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

class ConnectionState {
  final bool isConnected;
  final String? serverIP;
  final String? errorMessage;
  final bool isLoading;

  const ConnectionState({
    this.isConnected = false,
    this.serverIP,
    this.errorMessage,
    this.isLoading = false,
  });

  ConnectionState copyWith({
    bool? isConnected,
    String? serverIP,
    String? errorMessage,
    bool? isLoading,
  }) {
    return ConnectionState(
      isConnected: isConnected ?? this.isConnected,
      serverIP: serverIP ?? this.serverIP,
      errorMessage: errorMessage ?? this.errorMessage,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ConnectionNotifier extends StateNotifier<ConnectionState> {
  ConnectionNotifier() : super(const ConnectionState());

  Future<void> connectToDevice(String ip) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await Future.delayed(const Duration(seconds: 2));
      state = state.copyWith(isConnected: true, serverIP: ip, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isConnected: false,
        errorMessage: e.toString(),
        isLoading: false,
      );
    }
  }

  void disconnect() {
    state = const ConnectionState(isConnected: false);
  }
}

final connectionProvider =
    StateNotifierProvider<ConnectionNotifier, ConnectionState>((ref) {
      return ConnectionNotifier();
    });

final isConnectedProvider = Provider((ref) {
  return ref.watch(connectionProvider).isConnected;
});

final serverIPProvider = Provider((ref) {
  return ref.watch(connectionProvider).serverIP;
});

final connectionErrorProvider = Provider((ref) {
  return ref.watch(connectionProvider).errorMessage;
});

final isConnectionLoadingProvider = Provider((ref) {
  return ref.watch(connectionProvider).isLoading;
});
