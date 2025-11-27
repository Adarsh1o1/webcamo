import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:webcamo/utils/colors.dart';
import 'package:webcamo/utils/sizes.dart';

class UsbStreamingPage extends StatefulWidget {
  const UsbStreamingPage({super.key});

  @override
  State<UsbStreamingPage> createState() => _UsbStreamingPageState();
}

class _UsbStreamingPageState extends State<UsbStreamingPage>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  CameraDescription? _selectedCamera;
  bool _isStreaming = false;
  ServerSocket? _serverSocket;
  final List<Socket> _clients = [];
  bool _isFlashOn = false;

  // Protocol Constants
  static const int _packetTypeVideo = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopStreaming();
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
    try {
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 23233);
      setState(() {
        _isStreaming = true;
      });

      _serverSocket!.listen((socket) {
        debugPrint("Client connected: ${socket.remoteAddress.address}");
        _clients.add(socket);

        socket.done.then((_) {
          debugPrint("Client disconnected");
          _clients.remove(socket);
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

    if (_cameraController!.value.isStreamingImages)
      return; // avoid double stream

    int frameCount = 0;
    _cameraController!.startImageStream((CameraImage image) async {
      frameCount++;
      if (frameCount % 2 != 0) return; // Limit FPS if needed
      if (_clients.isEmpty) return;

      try {
        if (Platform.isAndroid &&
            image.format.group == ImageFormatGroup.yuv420) {
          
          // --- OPTIMIZED STREAMING: Send Raw Planes ---
          // Instead of converting to I420 in Dart (slow), we send the raw planes
          // and metadata to Python, which can handle it much faster.

          final int width = image.width;
          final int height = image.height;
          
          final Plane planeY = image.planes[0];
          final Plane planeU = image.planes[1];
          final Plane planeV = image.planes[2];

          final Uint8List yBytes = planeY.bytes;
          final Uint8List uBytes = planeU.bytes;
          final Uint8List vBytes = planeV.bytes;

          // Calculate total packet size
          // Header (1) + TotalSize (4) + Metadata (40) + Data (Variable)
          // Metadata: Width(4), Height(4), YLen(4), ULen(4), VLen(4), 
          //           YStride(4), UStride(4), VStride(4), UPixelStride(4), VPixelStride(4)
          
          final int metadataSize = 40;
          final int payloadSize = metadataSize + yBytes.length + uBytes.length + vBytes.length;

          final List<int> header = [];
          header.add(_packetTypeVideo); // Type: 0
          header.addAll(_int32ToBytes(payloadSize)); // Total Size

          // Metadata
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

          for (final client in _clients) {
            client.add(header);
            client.add(yBytes);
            client.add(uBytes);
            client.add(vBytes);
            await client.flush();
          }

        } else {
          // Unsupported format (e.g. iOS BGRA for now)
          return;
        }
      } catch (e) {
        debugPrint("Error streaming video frame: $e");
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
      });
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null) return;
    try {
      _isFlashOn = !_isFlashOn;
      await _cameraController!.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );
      setState(() {});
    } catch (e) {
      debugPrint("Error toggling flash: $e");
    }
  }

  Future<void> _switchCamera() async {
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

    return Scaffold(
      backgroundColor: MyColors.lightColorScheme.primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "USB Streaming",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes.p16,
            vertical: AppSizes.p24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Connection Info Card (Dashboard Style)
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
                      // Status Badge
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: _isStreaming
                              ? successColor.withOpacity(0.2)
                              : errorColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(30.r),
                          border: Border.all(
                            color: _isStreaming ? successColor : errorColor,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isStreaming ? Icons.link : Icons.link_off,
                              size: 16.sp,
                              color: _isStreaming ? successColor : errorColor,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              _isStreaming
                                  ? "STREAMING ACTIVE"
                                  : "READY TO STREAM",
                              style: TextStyle(
                                color: _isStreaming ? successColor : errorColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.sp,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 20.h),

                      // Connection Info (Hero Text)
                      Text(
                        "USB Port",
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      SelectableText(
                        "23233",
                        style: TextStyle(
                          fontSize: 36.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),

                      SizedBox(height: 10.h),

                      // ADB Command Hint
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 8.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.terminal,
                              size: 16.sp,
                              color: Colors.white54,
                            ),
                            SizedBox(width: 8.w),
                            Flexible(
                              child: Text(
                                "adb reverse tcp:23233 tcp:23233",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14.sp,
                                  fontFamily: 'Courier',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 24.h),

                      // Start/Stop Server Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isStreaming ? _stopStreaming : _startServer,
                          icon: Icon(
                            _isStreaming ? Icons.power_off_rounded : Icons.power_settings_new,
                          ),
                          label: Text(_isStreaming ? "Stop Streaming" : "Start Streaming"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isStreaming
                                ? Colors.red.shade900.withOpacity(0.8)
                                : MyColors.green,
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

              // 2. Camera Preview & Controls Section
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

              // Camera Viewport
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1, // Square aspect for preview
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(24.r),
                        border: Border.all(
                          color: Colors.white12,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(23.r),
                        child: _cameraController != null &&
                                _cameraController!.value.isInitialized
                            ? FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: _cameraController!
                                      .value.previewSize!.height,
                                  height: _cameraController!
                                      .value.previewSize!.width,
                                  child: CameraPreview(_cameraController!),
                                ),
                              )
                            : const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  ),

                  // Camera Control Bar (Floating)
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
                          // Switch Camera
                          _ControlIcon(
                            icon: Icons.cameraswitch_rounded,
                            onTap: _cameras.length < 2 ? null : _switchCamera,
                          ),

                          // Flash Toggle
                          _ControlIcon(
                            icon: _isFlashOn
                                ? Icons.flash_on_rounded
                                : Icons.flash_off_rounded,
                            onTap: _toggleFlash,
                            isActive: _isFlashOn,
                            activeColor: Colors.yellow,
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
      ),
    );
  }
}

// --- Custom Widget for Camera Controls ---
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
