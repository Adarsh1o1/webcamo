import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';

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

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  HttpServer? _httpServer;
  String? _serverUrl;
  bool _isConnected = false;
  bool _hasPermissions = false;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final int _port = 8080;
  WebSocketChannel? _webSocket;
  bool _isFlashOn = false;

  bool _isInitialized = false;
  bool _isServerStarting = false;

  // Timer? _reconnectTimer;
  // bool _shouldReconnect = true;

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();

  List<MediaDeviceInfo> _cameras = [];
  MediaDeviceInfo? _selectedCamera;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _localRenderer.initialize();
    _checkPermissions();
  }

  @override
  void dispose() {
    _fullCleanup();
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

    if (state == AppLifecycleState.resumed) {
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
    if (cameraStatus.isGranted && micStatus.isGranted) {
      if (mounted) {
        setState(() {
          _hasPermissions = true;
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

      await _startServer();
    } else {
      _hasPermissions = false;
      _showErrorDialog("Camera and Microphone permissions are required.");
    }
  }

  Future<void> _toggleFlash() async {
    if (_localStream == null || _localStream!.getVideoTracks().isEmpty) return;

    try {
      final videoTrack = _localStream!.getVideoTracks()[0];
      final newFlashState = !_isFlashOn;

      await videoTrack.setTorch(newFlashState);

      setState(() {
        _isFlashOn = newFlashState;
      });
    } catch (e) {
      // print("Error toggling flash: $e");

      _showErrorDialog("Failed to control flash");

      setState(() {
        _isFlashOn = false;
      });
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _selectedCamera == null) return;

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
        });
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

    if (mounted) {
      setState(() {
        _isInitialized = false;
        _serverUrl = null;
        _isConnected = false;
        _isFlashOn = false;
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

  Future<void> _stopServerOnly() async {
    // ✅ Remove tracks from PeerConnection cleanly
    if (_peerConnection != null) {
      final senders = await _peerConnection!.getSenders();
      for (var sender in senders) {
        await _peerConnection!.removeTrack(sender);
      }
      await _peerConnection!.close();
    }
    _peerConnection = null;

    // ✅ Close signaling
    _webSocket?.sink.close();
    _webSocket = null;

    // ✅ Stop only the server (NOT the camera)
    await _httpServer?.close(force: true);
    _httpServer = null;

    if (mounted) {
      setState(() {
        _serverUrl = null;
        _isConnected = false;
        _isFlashOn = false;
      });
    }

    // ✅ KEEP PREVIEW RUNNING — DO NOT STOP camera tracks here
  }

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
        title: const Text('How to Use Webcamo'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '1. Start the Server',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(
                'Make sure your phone and PC are on the same Wi-Fi. The Server will start automatically".\n',
              ),
              const Text(
                '2. Connect on PC (OBS/Chrome)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(
                'Copy the "STREAM URL" and paste it into a "Browser" source in OBS(For virtual Camera) or a new Chrome tab.\n',
              ),
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
                          'Thank you for using Webcamo! If you find it useful, consider supporting me by ',
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
                          _launchURL('https://www.buymeacoffee.com/adarsh1o1');
                        },
                    ),
                  ],
                ),
              ),
              // --- END OF NEW PART ---
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isFrontCamera =
        _selectedCamera?.label.toLowerCase().contains('front') ?? false;

    // --- Define our Color Palette & Text Styles ---
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;

    final Color successColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.greenAccent[400]! // Bright green for dark mode
        : Colors.green.shade800; // Dark green for light mode

    final Color errorColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.redAccent[200]! // Bright "warning" for dark mode
        : Colors.orange.shade800; // Dark "warning" for light mode
    // --- END DYNAMIC COLORS ---
    // ignore: deprecated_member_use
    final Color surfaceColor = colors.surfaceContainerHighest.withOpacity(0.7);

    return Scaffold(
      appBar: AppBar(
        // Use a subtle background color that's slightly
        // different from the scaffold's background
        // ignore: deprecated_member_use
        backgroundColor: colors.surfaceVariant.withOpacity(0.5),
        elevation: 1, // Add a very subtle shadow
        // 1. A nice title with an icon
        title: Row(
          mainAxisSize: MainAxisSize.min, // Keep the row compact
          children: [
            // Use RichText to combine different styles
            RichText(
              text: TextSpan(
                // This is the default style for all text in this widget
                // It takes the style from your theme
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                children: <TextSpan>[
                  // The "Web" part
                  TextSpan(
                    text: 'Web',
                    style: TextStyle(color: colors.primary), // Dark Teal/Grey
                  ),
                  // The "camo" part
                  TextSpan(
                    text: 'camo',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                    ), // Lighter Grey/Blue
                  ),
                ],
              ),
            ),
          ],
        ),

        // 2. An "action" button on the right
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Help & Instructions', // Good for accessibility
            onPressed: () {
              // Call the help dialog we just added
              _showHelpDialog(context);
            },
          ),
          const SizedBox(width: 8), // A bit of padding
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Logic for Permissions and Loading ---
              if (!_hasPermissions)
                Card(
                  color: colors.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Please grant Camera & Mic permissions and restart the app.',
                      style: text.bodyLarge?.copyWith(
                        color: colors.onErrorContainer,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              if (_isServerStarting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_serverUrl == null)
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _startServer,
                    icon: const Icon(Icons.power_settings_new),
                    label: const Text('Start Server'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),

              // --- FIX 4: Correct UI Layout ---
              // All buttons are now correctly nested inside the
              // `if (_serverUrl != null)` block and their respective cards.
              if (_serverUrl != null) ...[
                // --- Status Panel Card ---
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STREAM URL (Copy link & open in browser/OBS)',
                          style: text.labelMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          _serverUrl!,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                            decoration: TextDecoration.underline,
                            // --- AND THIS ---
                            decorationColor: colors.primary,
                          ),
                          textAlign: TextAlign.left,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'STATUS',
                          style: text.labelMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _isConnected
                                  ? Icons.check_circle_rounded
                                  : Icons.warning_amber_rounded,
                              color: _isConnected ? successColor : errorColor,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _isConnected
                                    ? 'DEVICE CONNECTED'
                                    : 'AWAITING CONNECTION',
                                style: text.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: _isConnected
                                      ? successColor
                                      : errorColor,
                                ),
                                softWrap: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // --- Controls Panel Card ---
                Card(
                  elevation: 0,
                  color: surfaceColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'CAMERA PREVIEW',
                          style: text.labelMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // --- NEW: Local Preview Window ---
                        if (_isInitialized)
                          // 1. Wrap the container in an AspectRatio widget
                          AspectRatio(
                            aspectRatio: 1,
                            child: Container(
                              // 3. Remove the fixed height
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                border: Border.all(color: Colors.grey.shade700),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: RTCVideoView(
                                  _localRenderer,
                                  // 4. Set objectFit back to Cover
                                  objectFit: RTCVideoViewObjectFit
                                      .RTCVideoViewObjectFitCover,
                                  mirror: isFrontCamera,
                                ),
                              ),
                            ),
                          ),
                        if (_isInitialized)
                          const SizedBox(height: 20), // Spacing after preview

                        Text(
                          'CONTROLS',
                          style: text.labelMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Switch Camera Button
                        ElevatedButton.icon(
                          onPressed: _cameras.length < 2 ? null : _switchCamera,
                          icon: const Icon(Icons.switch_camera_outlined),
                          label: Text(
                            _selectedCamera?.label.toLowerCase().contains(
                                      'back',
                                    ) ??
                                    false
                                ? 'Switch to Front Camera'
                                : 'Switch to Back Camera',
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          // Disable if streaming or if front camera is on
                          onPressed: _isConnected ? _toggleFlash : null,
                          icon: Icon(
                            _isFlashOn ? Icons.flash_on : Icons.flash_off,
                          ),
                          label: Text(_isFlashOn ? 'Flash ON' : 'Flash OFF'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            // Optional: Change color based on state
                            backgroundColor: _isFlashOn
                                ? Colors.yellow.shade800
                                : null,
                          ),
                        ),

                        const SizedBox(height: 16),

                        ElevatedButton.icon(
                          onPressed: _serverUrl == null
                              ? _startServer
                              : _stopServerOnly,
                          icon: Icon(
                            _serverUrl == null
                                ? Icons.power_settings_new
                                : Icons.power_off,
                          ),
                          label: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            child: Text(
                              _serverUrl == null
                                  ? 'Start Server'
                                  : 'Stop Server',
                            ),
                          ),

                          style: ElevatedButton.styleFrom(
                            // padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            // minimumSize: Size(150,50),
                            backgroundColor: _serverUrl == null
                                ? Colors.greenAccent
                                : Colors.red.shade700,
                            foregroundColor: Colors.white,
                          ),
                        ),

                        if (_cameras.length < 2)
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: Text(
                              'Only one camera found.',
                              textAlign: TextAlign.center,
                              style: text.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
