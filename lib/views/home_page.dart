import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
import 'package:webcamo/providers/server_provider.dart';
import 'package:webcamo/utils/colors.dart';
import 'package:webcamo/utils/sizes.dart';
import 'package:webcamo/views/troubleshoot/troubleshoot_page.dart';

const String clientHtml = """
<!DOCTYPE html>
<html>
<head>
    <title>Flutter Webcam Client</title>
    <style>
        body {
          background-color: #111;
          color: white;
          margin: 0;
          padding: 0;
          display: flex;
          justify-content: center;
          align-items: center;
          height: 100vh;
        }

        /* Square container (1:1 aspect ratio) */
        #videoContainer {
          width: 100vmin;
          height: 100vmin;
          position: relative;
          overflow: hidden;
          display: flex;
          justify-content: center;
          align-items: center;
        }

        /* Video fills the container fully */
        video {
          width: 100%;
          height: 100%;
          object-fit: cover; /* crop to fill */
        }

        #status {
          position: fixed;
          top: 20px;
          left: 20px;
          background-color: rgba(0,0,0,0.55);
          padding: 10px 14px;
          border-radius: 6px;
          font-size: 14px;
        }
    </style>
</head>
<body>
    <div id="videoContainer">
        <video id="webcamVideo" autoplay playsinline muted></video>
    </div>
    <div id="status">Connecting to WebSocket...</div>
    <script>
        const videoElement = document.getElementById('webcamVideo');
        const statusElement = document.getElementById('status');
        let peerConnection;
        const ws = new WebSocket(`ws://\${window.location.host}/ws`);

        function log(msg) { console.log(msg); statusElement.textContent = msg; }
        function error(msg) { console.error(msg); statusElement.textContent = `Error: \${msg}`; }

        ws.onopen = () => {
            log('WebSocket connected. Creating PeerConnection...');
            createPeerConnection();
        };

        ws.onmessage = async (event) => {
            const data = JSON.parse(event.data);
            log(`Received message: \${data.type}`);
            try {
                if (data.type === 'answer') {
                    await peerConnection.setRemoteDescription(new RTCSessionDescription(data));
                } else if (data.type === 'candidate') {
                    if (data.candidate) {
                        await peerConnection.addIceCandidate(new RTCIceCandidate(data.candidate));
                    }
                }
            } catch (e) { error(e.toString()); }
        };
        ws.onerror = (err) => { error('WebSocket failed.'); };
        ws.onclose = () => { log('WebSocket disconnected.'); };

        async function createPeerConnection() {
            peerConnection = new RTCPeerConnection({ iceServers: [] });

            peerConnection.onicecandidate = (event) => {
                if (event.candidate) {
                    log('Sending candidate...');
                    ws.send(JSON.stringify({ type: 'candidate', candidate: event.candidate }));
                }
            };

            peerConnection.ontrack = (event) => {
                log('✅ Received remote video track!');
                statusElement.style.display = 'none';
                if (videoElement.srcObject !== event.streams[0]) {
                    videoElement.srcObject = event.streams[0];
                }
            };

            peerConnection.onconnectionstatechange = (event) => {
                log(`Connection State: \${peerConnection.connectionState}`);
                if(peerConnection.connectionState === 'failed'){
                    error('Peer connection failed. Check PC firewall.');
                }
            };

            try {
                const offer = await peerConnection.createOffer({
                    offerToReceiveAudio: 1,
                    offerToReceiveVideo: 1
                });
                await peerConnection.setLocalDescription(offer);
                log('Sending offer...');
                ws.send(JSON.stringify(offer));
            } catch (e) { error(e.toString()); }
        }
    </script>
</body>
</html>
""";

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  HttpServer? _httpServer;
  String? _serverUrl;
  bool _isConnected = false;
  bool _hasPermissions = false;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final int _port = 8080;
  WebSocketChannel? _webSocket;
  bool _isFlashOn = false;

  bool _isPaused = false;

  bool _isInitialized = false;
  bool _isServerStarting = false;

  String _ipAddress = '';

  bool _canToggleFlash = false;

  PermissionStatus _permissionStatus = PermissionStatus.denied;

  SharedPreferences? _sharedPreferences;
  // Timer? _reconnectTimer;
  // bool _shouldReconnect = true;

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();

  List<MediaDeviceInfo> _cameras = [];
  MediaDeviceInfo? _selectedCamera;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
    // NOW safe to start camera
    _localRenderer.initialize();
    _isPaused = true;
  }

  @override
  void dispose() {
    // ✅ NEW: Ensure full cleanup when leaving the page
    if (_serverUrl != null) {
      _fullCleanup();
    } else {
      // At minimum, stop camera
      _localStream?.getTracks().forEach((track) {
        track.stop();
      });
      _localStream?.dispose();
    }

    WidgetsBinding.instance.removeObserver(this);
    _localRenderer.dispose();
    _httpServer?.close(force: true);
    _ipController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    // if (state == AppLifecycleState.paused ||
    //     state == AppLifecycleState.inactive) {
    //   // ✅ App went background → stop streaming but keep preview stream alive
    //   await _peerConnection?.close();
    //   _peerConnection = null;
    //   _isConnected = false;
    // }
    // if (state == AppLifecycleState.paused ||
    //     state == AppLifecycleState.detached) {
    //   _stopStream(); // or _fullCleanup() if you want to stop server too
    // } else
    if (state == AppLifecycleState.resumed && !_isPaused) {
      print('app paused and restarted camera');
      // ✅ Recreate camera pipeline on resume
      await _restartCameraPreview();
    }
  }

  Future<void> _restartCameraPreview() async {
    try {
      // Recreate camera (fresh pipeline)
      await _initializeLocalPreview();
      if (_peerConnection != null) {
        // 4. Get the new tracks from the stream that is powering our preview
        final newVideoTrack = _localStream!.getVideoTracks()[0];
        // final newAudioTrack = _localStream!.getAudioTracks()[0];

        // 5. Find the "senders" in the P2P connection
        final senders = await _peerConnection!.getSenders();
        final videoSender = senders.firstWhere((s) => s.track?.kind == 'video');
        // final audioSender = senders.firstWhere((s) => s.track?.kind == 'audio');

        // 6. Replace the tracks in the connection
        // print('Replacing tracks on active P2P stream...');
        await videoSender.replaceTrack(newVideoTrack);
        // await audioSender.replaceTrack(newAudioTrack);
      }

      // Restore WebRTC if server was running and previously connected
      // if (_serverUrl != null) {
      //   _scheduleReconnect(); // From your auto-reconnect setup
      // }

      setState(() {});
    } catch (e) {
      print("Camera restart error: $e");
    }
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      _showErrorDialog('Could not launch $urlString');
    }
  }

  Future<void> _initializeLocalPreview() async {
    if (_selectedCamera == null) return;

    // Clean up old stream if it exists
    _localStream?.getTracks().forEach((track) {
      track.stop();
    });
    await _localStream?.dispose();
    _localRenderer.srcObject = null;

    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': false,
        'video': {
          'deviceId': _selectedCamera!.deviceId,
          'mandatory': {
            'minWidth': '1080',
            'minHeight': '1080',
            'minFrameRate': '30',
            'maxFrameRate': '30',
          },
          // 'width': {'ideal': 720},
          // 'height': {'ideal': 720},
          // 'aspectRatio': 16 / 9,            // ✅ forces landscape view
          // 'resizeMode': 'crop-and-scale'    // ✅ important for correct framing
        },
      });

      _localRenderer.srcObject = _localStream;

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      // print("Error initializing local preview: $e");
      _showErrorDialog("Failed to start camera: ${e.toString()}");
    }
  }

  Future<void> _checkPermissions() async {
    var cameraStatus = await Permission.camera.request();
    var micStatus = await Permission.microphone.request();
    _sharedPreferences = await SharedPreferences.getInstance();
    if (cameraStatus.isGranted && micStatus.isGranted) {
      if (mounted) {
        setState(() {
          _hasPermissions = true;
          _sharedPreferences?.setBool('hasPermissions', true);
        });
      }

      final devices = await navigator.mediaDevices.enumerateDevices();
      _cameras = devices.where((d) => d.kind == 'videoinput').toList();

      if (_cameras.isNotEmpty) {
        // print("--- AVAILABLE CAMERAS ---");
        // for (var camera in _cameras) {
        //   print("Label: ${camera.label}, ID: ${camera.deviceId}");
        // }
        // print("-------------------------");

        _selectedCamera = _cameras.firstWhere(
          (d) => d.label.toLowerCase().contains('front'),
          orElse: () => _cameras.first,
        );

        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
        // print("Selected camera: ${_selectedCamera!.label}");
      } else {
        _showErrorDialog("No cameras found on this device.");
      }

      // await _startServer();
    } else {
      _hasPermissions = false;
      _sharedPreferences?.setBool('hasPermissions', false);
      _showErrorDialog("Camera and Microphone permissions are required.");
    }
  }

  Future<void> _toggleFlash() async {
    if (_localStream == null || _localStream!.getVideoTracks().isEmpty) return;
    if (_isPaused) {

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Start stream first.',
          style: TextStyle(color: MyColors.lightColorScheme.primary, fontWeight: FontWeight.bold),
        ),
        backgroundColor: MyColors.grey,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
      

      return;
    }

    try {
      final bool isFrontCamera =
          _selectedCamera?.label.toLowerCase().contains('front') ?? false;
      final videoTrack = _localStream!.getVideoTracks()[0];
      final newFlashState = !_isFlashOn;
      await videoTrack.setTorch(newFlashState);
      setState(() {
        _isFlashOn = newFlashState;
      });

      if (isFrontCamera && _isFlashOn) {
            ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Flash may not be supported on front camera.',
          style: TextStyle(color: MyColors.lightColorScheme.primary, fontWeight: FontWeight.bold),
        ),
        backgroundColor: MyColors.grey,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
      }
    } catch (e) {
      // print("Error toggling flash: $e");
          ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Flash not avialable.',
          style: TextStyle(color: MyColors.lightColorScheme.primary, fontWeight: FontWeight.bold),
        ),
        backgroundColor: MyColors.grey,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      _localStream?.getTracks().forEach((track) {
        track.stop();
      });
      await _localStream?.dispose();
      final newPauseState = !_isPaused;
      _localRenderer.srcObject = null;
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

  Future<void> _requestPermission() async {
    var cameraStatus = await Permission.camera.isPermanentlyDenied;
    var micStatus = await Permission.microphone.isPermanentlyDenied;
    setState(() {
      _permissionStatus = (cameraStatus || micStatus)
          ? PermissionStatus.permanentlyDenied
          : PermissionStatus.granted;
    });
    print(cameraStatus);
    print(micStatus);
    print(_permissionStatus);

    if (_permissionStatus == PermissionStatus.permanentlyDenied) {
      print("Status is permanently denied. Opening settings.");
      await openAppSettings();
      _checkPermissions();
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _selectedCamera == null) return;
    if (_isPaused) {
      ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Start stream first.',
          style: TextStyle(color: MyColors.lightColorScheme.primary, fontWeight: FontWeight.bold),
        ),
        backgroundColor: MyColors.grey,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

      return;
    }

    // 1. Select the next camera
    int currentIndex = _cameras.indexWhere(
      (c) => c.deviceId == _selectedCamera!.deviceId,
    );
    int nextIndex = (currentIndex + 1) % _cameras.length;
    _selectedCamera = _cameras[nextIndex];

    // print('Switching camera to: ${_selectedCamera!.label}');
    await _initializeLocalPreview();

    if (_peerConnection != null) {
      // 4. Get the new tracks from the stream that is powering our preview
      final newVideoTrack = _localStream!.getVideoTracks()[0];
      // final newAudioTrack = _localStream!.getAudioTracks()[0];

      // 5. Find the "senders" in the P2P connection
      final senders = await _peerConnection!.getSenders();
      final videoSender = senders.firstWhere((s) => s.track?.kind == 'video');
      // final audioSender = senders.firstWhere((s) => s.track?.kind == 'audio');

      // 6. Replace the tracks in the connection
      // print('Replacing tracks on active P2P stream...');
      await videoSender.replaceTrack(newVideoTrack);
      // await audioSender.replaceTrack(newAudioTrack);
    }

    setState(() {
      _isFlashOn = false;
    });
  }

  Future<void> _startServer() async {
    // _shouldReconnect = true;
    if (mounted) {
      setState(() {
        _isPaused = false;
        _isServerStarting = true;
      });
    }
    await _initializeLocalPreview();

    final ip = await NetworkInfo().getWifiIP();
    String? displayIp = ip;

    if (ip == null) {
      displayIp = '192.168.43.1'; // Default for hotspot
    }

    final router = shelf_router.Router();

    router.get('/', (shelf.Request request) {
      return shelf.Response.ok(
        clientHtml,
        headers: {'Content-Type': 'text/html'},
      );
    });

    router.get('/ws', (shelf.Request request) {
      final handler = webSocketHandler((WebSocketChannel webSocket, dynamic _) {
        // print('WebSocket connection established!');
        _webSocket = webSocket; // Save the socket
        if (mounted) {
          setState(() {
            _isConnected = true;
          });
        }

        webSocket.stream.listen(
          (message) {
            _handleSignalingMessage(message);
          },
          onDone: () {
            // print('WebSocket connection closed.');

            if (mounted) {
              setState(() {
                _isConnected = false;
              });
            }

            _stopStream(); // <-- Use our new "Stop" function
          },

          onError: (error) {
            if (mounted) {
              setState(() {
                _isConnected = false;
              });
            }

            _stopStream(); // <-- Use our new "Stop" function
          },
        );
      });

      return handler(request);
    });

    try {
      _httpServer = await shelf_io.serve(
        router.call,
        InternetAddress.anyIPv4,
        _port,
      );
      // --------------------------------------------------------

      if (mounted) {
        setState(() {
          // We still show the user the *actual* Wi-Fi/Hotspot IP
          _serverUrl = 'http://$displayIp:$_port';
          _isServerStarting = false;
          _ipAddress = displayIp!;
        });
        ref
            .read(serverProvider.notifier)
            .setServerRunning(true, serverUrl: _serverUrl);
      }
      // print('✅ Server running at http://0.0.0.0:$_port (displaying $_serverUrl)');
    } catch (e) {
      // print('❌ Failed to start server: $e');
    }
  }

  Future<void> _handleSignalingMessage(String message) async {
    final Map<String, dynamic> data = jsonDecode(message);

    if (data['type'] == 'offer') {
      // print('Received offer...');
      await _createPeerConnection();

      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(data['sdp'], data['type']),
      );

      final answer = await _peerConnection!.createAnswer();

      await _peerConnection!.setLocalDescription(answer);

      _sendToPC({
        "type": "answer",
        "sdp": answer.sdp, // ✅ send correct SDP field
      });
    } else if (data['type'] == 'candidate') {
      if (_peerConnection == null) return;
      // print('Received ICE candidate...');
      await _peerConnection!.addCandidate(
        RTCIceCandidate(
          data['candidate']['candidate'],
          data['candidate']['sdpMid'],
          data['candidate']['sdpMLineIndex'],
        ),
      );
    }
  }

  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection({
      'iceServers': [], // An empty list
    });

    if (_localStream == null) {
      // print("Error: Local stream is null. Cannot create peer connection.");
      return;
    }

    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      _sendToPC({'type': 'candidate', 'candidate': candidate.toMap()});
    };

    WakelockPlus.enable();
  }

  // --- NEW: This function stops EVERYTHING (server, stream, camera) ---
  Future<void> _fullCleanup() async {
    await _stopStream(); // Stop the P2P connection
    // await _pauseStream();

    // Stop the local camera stream
    _localStream?.getTracks().forEach((track) {
      track.stop();
    });
    await _localStream?.dispose();
    _localStream = null;
    _localRenderer.srcObject = null;

    // Stop the server
    await _httpServer?.close(force: true);
    _httpServer = null;

    ref.read(serverProvider.notifier).stopServer();

    if (mounted) {
      setState(() {
        _isInitialized = false;
        _serverUrl = null;
        _isConnected = false;
        _isFlashOn = false;
        _isPaused = true;
      });
    }
  }

  // This function STOPS THE P2P STREAM but LEAVES THE CAMERA ON
  Future<void> _stopStream() async {
    await _peerConnection?.close();
    _peerConnection = null;
    WakelockPlus.disable();

    if (mounted) {
      setState(() {
        _isConnected = false; // Go back to "Awaiting Connection"
        _isFlashOn = false;
      });
    }
    // print("P2P Stream stopped. Local preview remains active.");
  }

  // Future<void> _stopServerOnly() async {
  //   // ✅ Remove tracks from PeerConnection cleanly
  //   if (_peerConnection != null) {
  //     final senders = await _peerConnection!.getSenders();
  //     for (var sender in senders) {
  //       await _peerConnection!.removeTrack(sender);
  //     }
  //     await _peerConnection!.close();
  //   }
  //   _peerConnection = null;

  //   // ✅ Close signaling
  //   _webSocket?.sink.close();
  //   _webSocket = null;

  //   // ✅ Stop only the server (NOT the camera)
  //   await _httpServer?.close(force: true);
  //   _httpServer = null;

  //   if (mounted) {
  //     setState(() {
  //       _serverUrl = null;
  //       _isConnected = false;
  //       _isFlashOn = false;
  //     });
  //   }

  //   // ✅ KEEP PREVIEW RUNNING — DO NOT STOP camera tracks here
  // }

  void _sendToPC(Map<String, dynamic> data) {
    if (_webSocket != null) {
      _webSocket!.sink.add(jsonEncode(data));
    }
  }

  // Add the missing _ipController
  final TextEditingController _ipController = TextEditingController();

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    // We get the colors from the theme
    final ColorScheme colors = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'How to Use Webcamo',
          style: TextStyle(
            fontSize: AppSizes.font_lg,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: 60.w,
          height: 300.h,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '1. Start the Server',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Tap on Start Server to start the server. Wait until the app shows the WiFi IP.\n',
                  style: TextStyle(color: MyColors.grey),
                ),
                const Text(
                  '2. Connect on PC',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  'On your PC, open the Webcamo Desktop Application. Enter the WiFi IP displayed on your phone and click connect.\n',
                  style: TextStyle(color: MyColors.grey),
                ),
                const Text(
                  'Note: Phone and PC must be on the same Local Wi-Fi network only.\n',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                // const Text(
                //   'On your PC, open the Webcamo Desktop Application. Enter the WiFi IP displayed on your phone and click connect.\n',
                // ),
                const Text(
                  '3. Voila! ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

                // --- THIS IS THE NEW PART ---
                RichText(
                  text: TextSpan(
                    // Use the default text style from the dialog
                    style: Theme.of(context).dialogTheme.contentTextStyle,
                    children: [
                      TextSpan(
                        text:
                            'Open any app (Zoom, OBS, Discord, Google, Meet, etc.). Thank you for using Webcamo! If you find it useful, consider supporting me by ',
                        style: TextStyle(
                          color: colors
                              .onSurface, // This will be black in light mode and white in dark mode
                        ),
                      ),
                      TextSpan(
                        text: 'Buying me a Coffee.',
                        style: TextStyle(
                          color: colors.primary, // Make it look like a link
                          decoration: TextDecoration.underline,
                        ),
                        // This makes the text tappable
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            // Open the link when tapped
                            _launchURL(
                              'https://www.buymeacoffee.com/adarsh1o1',
                            );
                          },
                      ),
                    ],
                  ),
                ),
                // --- END OF NEW PART ---
              ],
            ),
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Text(
              'Got it!',
              style: TextStyle(
                fontSize: AppSizes.font_md,
                fontWeight: FontWeight.bold,
                color: MyColors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isFrontCamera =
        _selectedCamera?.label.toLowerCase().contains('front') ?? false;

    final ColorScheme colors = Theme.of(context).colorScheme;

    final Color successColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.greenAccent[400]!
        : Colors.green.shade600;

    final Color errorColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.orangeAccent[200]!
        : Colors.orange.shade800;

    return Scaffold(
      backgroundColor: MyColors.lightColorScheme.primary,
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- IMPROVED PERMISSIONS CARD ---
            if (_sharedPreferences?.getBool('hasPermissions') == false)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.p16,
                  vertical: 8.h,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _requestPermission(),
                    borderRadius: BorderRadius.circular(12.r),
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors.errorContainer.withOpacity(0.1),
                        border: Border.all(
                          color: colors.error.withOpacity(0.5),
                        ),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      padding: EdgeInsets.all(16.sp),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: colors.error,
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Permissions Required',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: colors.error,
                                    fontSize: 14.sp,
                                  ),
                                ),
                                Text(
                                  'Tap to grant Camera & Mic access',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    fontSize: 12.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14.sp,
                            color: colors.error,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            if (_isServerStarting)
              SizedBox(
                height: 600.h,
                child: const Center(child: CircularProgressIndicator()),
              )
            else if (_serverUrl == null)
              // --- STATE 1: SERVER STOPPED ---
              Stack(
                children: [
                  Positioned(
                    top: -100,
                    left: -100,
                    right: -100,
                    child: Container(
                      height: 500.h,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            MyColors.grey.withOpacity(0.2),
                            Colors.transparent,
                          ],
                          radius: 0.8.r,
                        ),
                      ),
                    ),
                  ),
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: 60.h),
              
                        // Animation
                        const _RippleUSBIcon(),
              
                        SizedBox(height: 20.h),
              
                        // --- NEW: Heading Text ---
                        Text(
                          "Wireless Webcam",
                          style: TextStyle(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors
                                .white, // Assuming dark background based on your code
                          ),
                        ),
                        // SizedBox(height: 8.h),
                        // Text(
                        //   "Turn your phone into a high-quality\nPC webcam in seconds.",
                        //   textAlign: TextAlign.center,
                        //   style: TextStyle(
                        //     fontSize: 14.sp,
                        //     color: Colors.white70,
                        //     height: 1.5,
                        //   ),
                        // ),
              
                        SizedBox(height: 30.h),
              
                        // Start Button
                        Center(
                          child: SizedBox(
                            width: 200.w,
                            height: 50.h,
                            child: ElevatedButton.icon(
                              onPressed: _serverUrl == null
                                  ? _startServer
                                  : _fullCleanup,
                              icon: Icon(
                                _serverUrl == null
                                    ? Icons.power_settings_new
                                    : Icons.power_off,
                              ),
                              label: Text(
                                _serverUrl == null
                                    ? 'Start Server'
                                    : 'Stop Server',
                              ),
                              style: ElevatedButton.styleFrom(
                                textStyle: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                                backgroundColor: _serverUrl == null
                                    ? MyColors.green
                                    : Colors.red.shade700,
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shadowColor: _serverUrl == null
                                    ? MyColors.green.withOpacity(0.5)
                                    : Colors.red.withOpacity(0.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30.r),
                                ),
                              ),
                            ),
                          ),
                        ),
              
                        SizedBox(height: 30.h),
              
                        // --- NEW: Instruction Points ---
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 60.w),
                          child: Align(
                            alignment:Alignment.center,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _InstructionRow(
                                  text: "Connect Mobile & PC to same Wi-Fi",
                                ),
                                SizedBox(height: 12.h),
                                _InstructionRow(
                                  text: "Start Server above and note the IP",
                                ),
                                SizedBox(height: 12.h),
                                _InstructionRow(
                                  text: "Enter IP in the Desktop client app",
                                ),
                              ],
                            ),
                          ),
                        ),
              
                        SizedBox(height: 15.h),
              
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const TroubleshootPage(),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white54,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.help_outline, size: 16.sp),
                              SizedBox(width: 8.w),
                              const Text("Having trouble?"),
                            ],
                          ),
                        ),
                        // SizedBox(height: 50.sp),
                      ],
                    ),
                  ),
                ],
              )
            else
              // --- STATE 2: SERVER RUNNING (IMPROVED UI) ---
              Padding(
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
                                color: _isConnected
                                    ? successColor.withOpacity(0.2)
                                    : errorColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(30.r),
                                border: Border.all(
                                  color: _isConnected
                                      ? successColor
                                      : errorColor,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isConnected ? Icons.link : Icons.link_off,
                                    size: 16.sp,
                                    color: _isConnected
                                        ? successColor
                                        : errorColor,
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    _isConnected
                                        ? "CONNECTED"
                                        : "WAITING FOR PC...",
                                    style: TextStyle(
                                      color: _isConnected
                                          ? successColor
                                          : errorColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.sp,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 20.h),

                            // The IP Address (Hero Text)
                            Text(
                              "WiFi IP Address",
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            SelectableText(
                              _ipAddress,
                              style: TextStyle(
                                fontSize: 36.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.5,
                              ),
                            ),

                            SizedBox(height: 10.h),

                            // Browser URL
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
                                    Icons.language,
                                    size: 16.sp,
                                    color: Colors.white54,
                                  ),
                                  SizedBox(width: 8.w),
                                  Flexible(
                                    child: Text(
                                      "Enter in PC Browser: $_serverUrl",
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

                            // Stop Server Button (Danger Action)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _fullCleanup,
                                icon: const Icon(Icons.power_off_rounded),
                                label: const Text("Stop Server"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade900
                                      .withOpacity(0.8),
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
                              child: _isInitialized
                                  ? RTCVideoView(
                                      _localRenderer,
                                      objectFit: RTCVideoViewObjectFit
                                          .RTCVideoViewObjectFitCover,
                                      mirror: isFrontCamera,
                                    )
                                  : const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                            ),
                          ),
                        ),

                        // Pause Overlay
                        if (_isPaused)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(24.r),
                              ),
                              child: Center(
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Switch Camera
                                _ControlIcon(
                                  icon: Icons.cameraswitch_rounded,
                                  onTap: _cameras.length < 2
                                      ? null
                                      : _switchCamera,
                                  isActive:
                                      false, // Always neutral unless specific logic
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

                                // Pause Toggle
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
          ],
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

class BulletListItem extends StatelessWidget {
  final String text;

  const BulletListItem({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            "• ",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: AppSizes.font_md,
              color: MyColors.grey,
            ),
          ),
          SizedBox(width: 10.sp),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: AppSizes.font_sm,
                color: MyColors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RippleUSBIcon extends StatefulWidget {
  const _RippleUSBIcon();

  @override
  State<_RippleUSBIcon> createState() => _RippleUSBIconState();
}

class _RippleUSBIconState extends State<_RippleUSBIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200.w,
      height: 200.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildRipple(0),
          _buildRipple(1),
          _buildRipple(2),
          Container(
            width: 100.w,
            height: 100.w,
            decoration: BoxDecoration(
              color: MyColors.lightColorScheme.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: MyColors.lightColorScheme.primary.withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(Icons.wifi, size: 50.sp, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildRipple(int index) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double progress = (_controller.value + (index * 0.33)) % 1.0;
        final double size = 100.w + (progress * 100.w);
        final double opacity = (1.0 - progress).clamp(0.0, 1.0);

        return Opacity(
          opacity: opacity,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: MyColors.lightColorScheme.primary.withOpacity(0.5),
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }
}


class _InstructionRow extends StatelessWidget {
  final String text;
  const _InstructionRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(AppSizes.p4 - 1.sp),
          decoration: BoxDecoration(
            color: Colors.white10,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, size: 12, color: MyColors.green),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.white60, fontSize: 13.sp),
          ),
        ),
      ],
    );
  }
}
