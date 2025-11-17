import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

class ServerState {
  final bool isServerRunning;
  final String? serverUrl;

  const ServerState({this.isServerRunning = false, this.serverUrl});

  ServerState copyWith({bool? isServerRunning, String? serverUrl}) {
    return ServerState(
      isServerRunning: isServerRunning ?? this.isServerRunning,
      serverUrl: serverUrl ?? this.serverUrl,
    );
  }
}

class ServerNotifier extends StateNotifier<ServerState> {
  ServerNotifier() : super(const ServerState());

  void setServerRunning(bool running, {String? serverUrl}) {
    state = state.copyWith(
      isServerRunning: running,
      serverUrl: running ? serverUrl : null,
    );
  }

  void stopServer() {
    state = const ServerState(isServerRunning: false, serverUrl: null);
  }
}

final serverProvider = StateNotifierProvider<ServerNotifier, ServerState>((
  ref,
) {
  return ServerNotifier();
});

final isServerRunningProvider = Provider((ref) {
  return ref.watch(serverProvider).isServerRunning;
});

final serverUrlProvider = Provider((ref) {
  return ref.watch(serverProvider).serverUrl;
});
