import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:record/record.dart';
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

  // MJPEG Header
  final _boundary = "boundary";

  StreamSubscription<List<int>>? _audioSubscription;
  AudioRecorder? _audioRecorder;

  // Protocol Constants
  static const int _packetTypeVideo = 0;
  static const int _packetTypeAudio = 1;

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
    _audioRecorder?.dispose();
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
        _selectedCamera = _cameras.first;
        await _initController(_selectedCamera!);
      }
    } catch (e) {
      debugPrint("Error initializing camera: $e");
    }
  }

  Future<void> _initController(CameraDescription cameraDescription) async {
    final controller = CameraController(
      cameraDescription,
      ResolutionPreset.medium,
      enableAudio: false, // We handle audio separately
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
      _startAudioStream();
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
      if (frameCount % 2 != 0) return;
      if (_clients.isEmpty) return;

      try {
        Uint8List bytes;

        if (Platform.isAndroid &&
            image.format.group == ImageFormatGroup.yuv420) {
          bytes = _yuv420ToI420(image);
        } else if (Platform.isIOS &&
            image.format.group == ImageFormatGroup.bgra8888) {
          // Optional: handle iOS later. For now you can skip or add BGRA path.
          return;
        } else {
          // Unsupported format
          return;
        }

        final sizeBytes = _int32ToBytes(bytes.length);
        final widthBytes = _int32ToBytes(image.width);
        final heightBytes = _int32ToBytes(image.height);

        for (final client in _clients) {
          client.add([_packetTypeVideo]);
          client.add(sizeBytes);
          client.add(widthBytes);
          client.add(heightBytes);
          client.add(bytes);
          await client.flush();
        }
      } catch (e) {
        debugPrint("Error streaming video frame: $e");
      }
    });
  }

  Future<void> _startAudioStream() async {
    try {
      _audioRecorder = AudioRecorder();

      // Check permissions
      if (await _audioRecorder!.hasPermission()) {
        final stream = await _audioRecorder!.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 16000,
            numChannels: 1,
          ),
        );

        _audioSubscription = stream.listen((data) {
          if (_clients.isEmpty) return;

          // Protocol: [TYPE:1][SIZE:4][DATA]
          // Type 1 = Audio

          final sizeBytes = _int32ToBytes(data.length);

          for (final client in _clients) {
            try {
              client.add([_packetTypeAudio]);
              client.add(sizeBytes);
              client.add(data);
              client.flush();
            } catch (e) {
              debugPrint("Error sending audio: $e");
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Error starting audio stream: $e");
    }
  }

  // ... (_concatenatePlanes, _int32ToBytes)

  Uint8List _yuv420ToI420(CameraImage image) {
    assert(image.format.group == ImageFormatGroup.yuv420);

    final int width = image.width;
    final int height = image.height;

    final Plane planeY = image.planes[0];
    final Plane planeU = image.planes[1];
    final Plane planeV = image.planes[2];

    final int ySize = width * height;
    final int uvSize = width * height ~/ 4; // because of 4:2:0

    final Uint8List out = Uint8List(ySize + uvSize * 2);

    int offset = 0;

    // --- Copy Y plane (no subsampling) ---
    for (int row = 0; row < height; row++) {
      final int rowStart = row * planeY.bytesPerRow;
      out.setRange(
        offset,
        offset + width,
        planeY.bytes.sublist(rowStart, rowStart + width),
      );
      offset += width;
    }

    // --- Copy U plane (subsampled) ---
    final int uvWidth = width ~/ 2;
    final int uvHeight = height ~/ 2;

    final int uBytesPerRow = planeU.bytesPerRow;
    final int uPixelStride = planeU.bytesPerPixel ?? 1;

    for (int row = 0; row < uvHeight; row++) {
      final int rowStart = row * uBytesPerRow;
      for (int col = 0; col < uvWidth; col++) {
        out[offset + row * uvWidth + col] =
            planeU.bytes[rowStart + col * uPixelStride];
      }
    }
    offset += uvSize;

    // --- Copy V plane (subsampled) ---
    final int vBytesPerRow = planeV.bytesPerRow;
    final int vPixelStride = planeV.bytesPerPixel ?? 1;

    for (int row = 0; row < uvHeight; row++) {
      final int rowStart = row * vBytesPerRow;
      for (int col = 0; col < uvWidth; col++) {
        out[offset + row * uvWidth + col] =
            planeV.bytes[rowStart + col * vPixelStride];
      }
    }

    return out;
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

    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _audioRecorder?.stop();
    _audioRecorder = null;

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
          padding: EdgeInsets.all(16.sp),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: Colors.white12),
                ),
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
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),

                    // Instructions
                    Text(
                      "ADB Command Required:",
                      style: TextStyle(color: Colors.white54, fontSize: 12.sp),
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      padding: EdgeInsets.all(12.sp),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: SelectableText(
                        "adb reverse tcp:23233 tcp:23233",
                        style: TextStyle(
                          fontFamily: 'Courier',
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 24.h),

                    // Start/Stop Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isStreaming ? _stopStreaming : _startServer,
                        icon: Icon(
                          _isStreaming ? Icons.stop : Icons.play_arrow,
                        ),
                        label: Text(
                          _isStreaming ? "Stop Streaming" : "Start Streaming",
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isStreaming
                              ? Colors.red.shade900
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

              SizedBox(height: 24.h),

              // Preview
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

              AspectRatio(
                aspectRatio: 1, // Square preview
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(24.r),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(23.r),
                    child:
                        _cameraController != null &&
                            _cameraController!.value.isInitialized
                        ? CameraPreview(_cameraController!)
                        : const Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),

              SizedBox(height: 16.h),

              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _switchCamera,
                    icon: const Icon(Icons.cameraswitch, color: Colors.white),
                    iconSize: 32.sp,
                  ),
                  SizedBox(width: 32.w),
                  IconButton(
                    onPressed: _toggleFlash,
                    icon: Icon(
                      _isFlashOn ? Icons.flash_on : Icons.flash_off,
                      color: _isFlashOn ? Colors.yellow : Colors.white,
                    ),
                    iconSize: 32.sp,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
