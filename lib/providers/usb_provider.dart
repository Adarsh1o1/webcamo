import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

class UsbState {
  final bool isStreaming;

  const UsbState({this.isStreaming = false});

  UsbState copyWith({bool? isStreaming}) {
    return UsbState(
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}

class UsbNotifier extends StateNotifier<UsbState> {
  UsbNotifier() : super(const UsbState());

  void setStreaming(bool streaming) {
    state = state.copyWith(isStreaming: streaming);
  }
}

final usbProvider = StateNotifierProvider<UsbNotifier, UsbState>((ref) {
  return UsbNotifier();
});

final isUsbStreamingProvider = Provider((ref) {
  return ref.watch(usbProvider).isStreaming;
});
