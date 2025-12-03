import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:webcamo/providers/usb_provider.dart';
import 'package:webcamo/utils/colors.dart';
import 'package:webcamo/utils/sizes.dart';

class UsbStreamingPage extends ConsumerStatefulWidget {
  // 1. Add callback to handle closing the widget
  final VoidCallback onStop;

  const UsbStreamingPage({super.key, required this.onStop});

  @override
  ConsumerState<UsbStreamingPage> createState() => _UsbStreamingPageState();
}

class _UsbStreamingPageState extends ConsumerState<UsbStreamingPage>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  CameraDescription? _selectedCamera;
  bool _isStreaming = false;
  ServerSocket? _serverSocket;
  final List<Socket> _clients = [];
  bool _isConnected = false; // <-- NEW: Track connection status
  bool _isFlashOn = false;

  bool _isPaused = false;

  static const int _packetTypeVideo = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    // _isPaused = true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Ensure clean up - we can't call async _stopStreaming here directly and expect it to finish
    // but we can trigger the cleanup logic.
    // Ideally _stopStreaming should be called before dispose.
    if (_isStreaming) {
      _stopStreaming();
    }
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _stopStreaming();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        _selectedCamera = _cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras.first,
        );
        await _initController(_selectedCamera!);

        // 2. AUTO START: Start server immediately after camera init
        _startServer();
      }
    } catch (e) {
      debugPrint("Error initializing camera: $e");
    }
  }

  Future<void> _initController(CameraDescription cameraDescription) async {
    final controller = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );

    try {
      await controller.initialize();
      if (mounted) {
        setState(() {
          _cameraController = controller;
        });
      }
    } catch (e) {
      debugPrint("Error initializing camera controller: $e");
    }
  }

  Future<void> _startServer() async {
    // Prevent double start
    if (_isStreaming) return;

    try {
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 23233);
      if (mounted) {
        setState(() {
          _isStreaming = true;
        });
        // Update provider
        ref.read(usbProvider.notifier).setStreaming(true);
      }

      _serverSocket!.listen((socket) {
        debugPrint("Client connected: ${socket.remoteAddress.address}");
        _clients.add(socket);
        if (mounted) {
          setState(() {
            _isConnected = true; // <-- NEW: Client connected
          });
        }

        socket.done.then((_) {
          debugPrint("Client disconnected");
          _clients.remove(socket);
          if (mounted && _clients.isEmpty) {
            setState(() {
              _isConnected = false; // <-- NEW: Client disconnected
            });
          }
        });

        socket.handleError((error) {
          debugPrint("Socket error: $error");
          _clients.remove(socket);
          if (mounted && _clients.isEmpty) {
            setState(() {
              _isConnected = false; // <-- NEW: Client disconnected
            });
          }
        });
      });

      _startImageStream();
    } catch (e) {
      debugPrint("Error starting server: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to start server: $e")));
      }
    }
  }

  void _startImageStream() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (_cameraController!.value.isStreamingImages) return;

    int frameCount = 0;
    _cameraController!.startImageStream((CameraImage image) async {
      frameCount++;
      if (frameCount % 2 != 0) return;
      if (_clients.isEmpty) return;

      try {
        if (Platform.isAndroid &&
            image.format.group == ImageFormatGroup.yuv420) {
          final bool isFront =
              _cameraController!.description.lensDirection ==
              CameraLensDirection.front;

          final int width = image.width;
          final int height = image.height;

          final Plane planeY = image.planes[0];
          final Plane planeU = image.planes[1];
          final Plane planeV = image.planes[2];

          final Uint8List yBytes = planeY.bytes;
          final Uint8List uBytes = planeU.bytes;
          final Uint8List vBytes = planeV.bytes;

          final int metadataSize = 41;
          final int payloadSize =
              metadataSize + yBytes.length + uBytes.length + vBytes.length;

          final List<int> header = [];
          header.add(_packetTypeVideo);
          header.addAll(_int32ToBytes(payloadSize));

          header.addAll(_int32ToBytes(width));
          header.addAll(_int32ToBytes(height));
          header.addAll(_int32ToBytes(yBytes.length));
          header.addAll(_int32ToBytes(uBytes.length));
          header.addAll(_int32ToBytes(vBytes.length));
          header.addAll(_int32ToBytes(planeY.bytesPerRow));
          header.addAll(_int32ToBytes(planeU.bytesPerRow));
          header.addAll(_int32ToBytes(planeV.bytesPerRow));
          header.addAll(_int32ToBytes(planeU.bytesPerPixel ?? 1));
          header.addAll(_int32ToBytes(planeV.bytesPerPixel ?? 1));
          header.add(isFront ? 1 : 0);

          for (final client in _clients) {
            client.add(header);
            client.add(yBytes);
            client.add(uBytes);
            client.add(vBytes);
            await client.flush();
          }
        }
      } catch (e) {
        debugPrint("Error streaming video frame: $e");
        _stopStreaming();
        _initializeCamera();
      }
    });
  }

  List<int> _int32ToBytes(int value) {
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }

  // 3. Logic to Stop and trigger callback
  Future<void> _handleStopAndExit() async {
    await _stopStreaming();
    widget.onStop();
  }

  Future<void> _stopStreaming() async {
    if (_cameraController != null &&
        _cameraController!.value.isStreamingImages) {
      await _cameraController!.stopImageStream();
    }

    for (final client in _clients) {
      client.destroy();
    }
    _clients.clear();

    await _serverSocket?.close();
    _serverSocket = null;

    if (mounted) {
      setState(() {
        _isStreaming = false;
        _isConnected = false; // <-- NEW: Reset connection status
      });
      // Update provider
      ref.read(usbProvider.notifier).setStreaming(false);
    } else {
      // Even if unmounted, try to update provider if ref is still valid (though arguably less critical if unmounted)
      // But usually we want to ensure global state reflects reality.
      // However, accessing ref in dispose/unmounted state can be tricky.
      // Since we call this from dispose, we should be careful.
      // For now, let's assume _handleStopAndExit is the main exit point where we are mounted.
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null) return;
    if (_isPaused) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Start stream first.',
            style: TextStyle(
              color: MyColors.lightColorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: MyColors.grey,
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      return;
    }
    try {
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
      bool isFront =
          _selectedCamera!.lensDirection == CameraLensDirection.front;
      if (isFront && _isFlashOn) {
        print(_selectedCamera!.lensDirection == CameraLensDirection.front);
        print(_isFlashOn);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Flash may not be supported on front camera.',
              style: TextStyle(
                color: MyColors.lightColorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: MyColors.grey,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        _isFlashOn = !_isFlashOn;
      }

      await _cameraController!.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );
    } catch (e) {
      debugPrint("Error toggling flash: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Flash not avialable.',
            style: TextStyle(
              color: MyColors.lightColorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: MyColors.grey,
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      setState(() {
        _isFlashOn = false;
      });
    }
  }

  Future<void> _pauseStream() async {
    print('is flash on $_isFlashOn');
    print('is paused on $_isPaused');
    if (!_isPaused) {
      _cameraController?.stopImageStream();
      await _cameraController?.dispose();
      final newPauseState = !_isPaused;
      setState(() {
        _isFlashOn = false;
        _isPaused = newPauseState;
      });
    } else {
      final newPauseState = !_isPaused;
      setState(() {
        _isFlashOn = false;
        _isPaused = newPauseState;
      });
      _restartCameraPreview();
    }
    print('is flash on $_isFlashOn');
    print('is paused on $_isPaused');
  }

  Future<void> _restartCameraPreview() async {
    if (_selectedCamera != null) {
      await _initController(_selectedCamera!);
      if (_isStreaming) {
        _startImageStream();
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_isPaused) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Start stream first.',
            style: TextStyle(
              color: MyColors.lightColorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: MyColors.grey,
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    if (_cameras.length < 2) return;

    final lensDirection = _cameraController!.description.lensDirection;
    CameraDescription newCamera;
    if (lensDirection == CameraLensDirection.front) {
      newCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
    } else {
      newCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
    }
    _selectedCamera = newCamera;
    _isFlashOn = false;
    if (_isStreaming) {
      await _cameraController!.stopImageStream();
    }
    await _cameraController!.dispose();
    await _initController(newCamera);

    if (_isStreaming) {
      _startImageStream();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color successColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.greenAccent[400]!
        : Colors.green.shade600;
    final Color errorColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.orangeAccent[200]!
        : Colors.orange.shade800;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSizes.p16,
          vertical: AppSizes.p24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: Colors.white12),
              ),
              child: Padding(
                padding: EdgeInsets.all(20.sp),
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: successColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(30.r),
                        border: Border.all(color: successColor, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.link, size: 16.sp, color: successColor),
                          SizedBox(width: 8.w),
                          Text(
                            "Server running...",
                            style: TextStyle(
                              color: successColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.sp,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20.h),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        // Call exit function
                        onPressed: _startServer,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text("Refresh"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MyColors.green.withOpacity(0.8),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                      ),
                    ),
                    // Text(
                    //   "Server has started on port 23233",
                    //   style: TextStyle(
                    //     color: Colors.white54,
                    //     fontSize: 12.sp,
                    //     fontWeight: FontWeight.w600,
                    //   ),
                    // ),

                    // SizedBox(height: 4.h),
                    // SelectableText(
                    //   "23233",
                    //   style: TextStyle(
                    //     fontSize: 36.sp,
                    //     fontWeight: FontWeight.bold,
                    //     color: Colors.white,
                    //     letterSpacing: 1.5,
                    //   ),
                    // ),

                    // SizedBox(height: 10.h),
                    // Container(
                    //   padding: EdgeInsets.symmetric(
                    //     horizontal: 12.w,
                    //     vertical: 8.h,
                    //   ),
                    //   decoration: BoxDecoration(
                    //     color: Colors.black26,
                    //     borderRadius: BorderRadius.circular(8.r),
                    //   ),
                    //   child: Row(
                    //     mainAxisSize: MainAxisSize.min,
                    //     children: [
                    //       Icon(
                    //         Icons.terminal,
                    //         size: 16.sp,
                    //         color: Colors.white54,
                    //       ),
                    //       SizedBox(width: 8.w),
                    //       Flexible(
                    //         child: Text(
                    //           "adb reverse tcp:23233 tcp:23233",
                    //           style: TextStyle(
                    //             color: Colors.white70,
                    //             fontSize: 14.sp,
                    //             fontFamily: 'Courier',
                    //           ),
                    //         ),
                    //       ),
                    //     ],
                    //   ),
                    // ),
                    SizedBox(height: 15.h),

                    // 4. STOP Button only
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        // Call exit function
                        onPressed: _handleStopAndExit,
                        icon: const Icon(Icons.power_off_rounded),
                        label: const Text("Stop & Exit"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade900.withOpacity(0.8),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24.h),
            Text(
              "LIVE PREVIEW",
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 10.h),

            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(24.r),
                      border: Border.all(color: Colors.white12, width: 1),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(23.r),
                      child: !_isPaused
                          ? _cameraController != null &&
                                    _cameraController!.value.isInitialized
                                ? FittedBox(
                                    fit: BoxFit.cover,
                                    child: SizedBox(
                                      width: _cameraController!
                                          .value
                                          .previewSize!
                                          .height,
                                      height: _cameraController!
                                          .value
                                          .previewSize!
                                          .width,
                                      child: CameraPreview(_cameraController!),
                                    ),
                                  )
                                : const Center(
                                    child: CircularProgressIndicator(),
                                  )
                          : Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.pause_circle_filled,
                                    size: 48.sp,
                                    color: Colors.white70,
                                  ),
                                  SizedBox(height: 8.h),
                                  Text(
                                    "PREVIEW PAUSED",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16.sp,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16.h,
                  left: 16.w,
                  right: 16.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 12.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(30.r),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ControlIcon(
                          icon: Icons.cameraswitch_rounded,
                          onTap: _cameras.length < 2 ? null : _switchCamera,
                        ),
                        _ControlIcon(
                          icon: _isFlashOn
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          onTap: _toggleFlash,
                          isActive: _isFlashOn,
                          activeColor: Colors.yellow,
                        ),
                        _ControlIcon(
                          icon: _isPaused
                              ? Icons.play_arrow_rounded
                              : Icons.stop_rounded,
                          onTap: _pauseStream,
                          isActive:
                              _isPaused, // Highlights when paused (technically "play" mode)
                          activeColor: MyColors.green,
                          isDestructive:
                              !_isPaused, // Red when it's a "Stop" button
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }
}

class _ControlIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isActive;
  final Color? activeColor;
  final bool isDestructive;

  const _ControlIcon({
    required this.icon,
    this.onTap,
    this.isActive = false,
    this.activeColor,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    Color iconColor = Colors.white;
    Color bgColor = Colors.white10;

    if (isActive && activeColor != null) {
      iconColor = Colors.black;
      bgColor = activeColor!;
    } else if (isDestructive) {
      iconColor = Colors.white;
      bgColor = Colors.red.withOpacity(0.8);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50.sp,
        height: 50.sp,
        decoration: BoxDecoration(
          color: onTap == null ? Colors.white10 : bgColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: onTap == null ? Colors.white24 : iconColor,
          size: 24.sp,
        ),
      ),
    );
  }
}
