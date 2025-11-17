// lib/providers/camera_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

class CameraState {
  final bool isFlashOn;
  final bool isPaused;
  final int selectedCamera;

  const CameraState({
    this.isFlashOn = false,
    this.isPaused = false,
    this.selectedCamera = 0,
  });

  CameraState copyWith({bool? isFlashOn, bool? isPaused, int? selectedCamera}) {
    return CameraState(
      isFlashOn: isFlashOn ?? this.isFlashOn,
      isPaused: isPaused ?? this.isPaused,
      selectedCamera: selectedCamera ?? this.selectedCamera,
    );
  }
}

class CameraNotifier extends StateNotifier<CameraState> {
  CameraNotifier() : super(const CameraState());

  void toggleFlash() {
    state = state.copyWith(isFlashOn: !state.isFlashOn);
  }

  void pauseResume() {
    state = state.copyWith(isPaused: !state.isPaused);
  }

  void switchCamera() {
    state = state.copyWith(selectedCamera: state.selectedCamera == 0 ? 1 : 0);
  }
}

final cameraProvider = StateNotifierProvider<CameraNotifier, CameraState>((
  ref,
) {
  return CameraNotifier();
});

final isFlashOnProvider = Provider((ref) {
  return ref.watch(cameraProvider).isFlashOn;
});

final isCameraPausedProvider = Provider((ref) {
  return ref.watch(cameraProvider).isPaused;
});

final selectedCameraProvider = Provider((ref) {
  return ref.watch(cameraProvider).selectedCamera;
});
