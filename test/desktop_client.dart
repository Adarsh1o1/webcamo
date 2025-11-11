import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/services.dart';

/// CHANGE THIS TO YOUR PHONE'S IP (same Wi‑Fi)
const wsUrl = 'ws://10.56.236.56:8080/ws';

class WindowsAppNew extends StatefulWidget {
  const WindowsAppNew({super.key});
  @override
  State<WindowsAppNew> createState() => _WindowsAppNewState();
}

class _WindowsAppNewState extends State<WindowsAppNew> {
  // WebRTC
  RTCPeerConnection? _pc;
  final _renderer = RTCVideoRenderer();
  WebSocketChannel? _ws;

  // Virtual cam
  bool _vcOn = false;
  MediaStreamTrack? _currentVideoTrack;
  Timer? _frameTimer;
  static const _platform = MethodChannel('webcamo/virtualcam');

  // UI state
  String _status = 'Connecting…';
  bool _isConnecting = true;

  @override
  void initState() {
    super.initState();
    _renderer.initialize().then((_) => _connectWebSocket());
  }

  // --------------------------------------------------------------
  // 1. WebSocket connection (wait for .ready)
  // --------------------------------------------------------------
  Future<void> _connectWebSocket() async {
    try {
      _ws = WebSocketChannel.connect(Uri.parse(wsUrl));
      await _ws!.ready;
      _updateStatus('WebSocket ready');
      await _createPeerConnection();
    } catch (e) {
      _updateStatus('WebSocket error: $e');
      _scheduleReconnect();
    }
  }

  // --------------------------------------------------------------
  // 2. PeerConnection + ICE + signalling
  // --------------------------------------------------------------
  Future<void> _createPeerConnection() async {
    _pc = await createPeerConnection({
      'iceServers': [
        
      ],
    });

    // ----- Remote track arrives → show preview -----
    _pc!.onTrack = (RTCTrackEvent e) async {
      if (e.track.kind == 'video') {
        _renderer.srcObject = e.streams.first;
        _currentVideoTrack = e.track;
        if (_vcOn) await _pumpFramesToVirtualCam(e.track);
        _updateStatus('Video track received');
      }
    };

    // ----- Send our ICE candidates (flat format) -----
    _pc!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null) {
        _ws!.sink.add(jsonEncode({
          'type': 'candidate',
          'candidate': candidate.candidate!,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        }));
      }
    };

    // ----- Debug ICE / connection state -----
    _pc!.onIceConnectionState = (state) {
      _updateStatus('ICE: $state');
    };
    _pc!.onConnectionState = (state) {
      _updateStatus('Conn: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _scheduleReconnect();
      }
    };

    // ----- Request a video track -----
    await _pc!.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
    );

    // ----- Create & send offer -----
    final offer = await _pc!.createOffer({'offerToReceiveVideo': true});
    await _pc!.setLocalDescription(offer);
    _ws!.sink.add(jsonEncode({'type': 'offer', 'sdp': offer.sdp}));

    // ----- Receive answer / candidates -----
    _ws!.stream.listen(
      (msg) async {
        final data = jsonDecode(msg);
        if (data['type'] == 'answer') {
          await _pc!.setRemoteDescription(
            RTCSessionDescription(data['sdp'], 'answer'),
          );
        } else if (data['type'] == 'candidate') {
          final c = data['candidate'];
          final mid = data['sdpMid'];
          final idx = data['sdpMLineIndex'];
          if (c != null && mid != null && idx != null) {
            await _pc!.addCandidate(RTCIceCandidate(c, mid, idx));
          }
        }
      },
      onError: (_) => _scheduleReconnect(),
      onDone: _scheduleReconnect,
    );
  }

  // --------------------------------------------------------------
  // 3. Reconnect logic
  // --------------------------------------------------------------
  int _reconnectAttempts = 0;
  void _scheduleReconnect() {
    if (!mounted) return;
    _reconnectAttempts++;
    final secs = _reconnectAttempts.clamp(1, 10);
    _updateStatus('Reconnect in $secs s');
    Future.delayed(Duration(seconds: secs), () {
      if (!mounted) return;
      _ws?.sink.close();
      _ws = null;
      _connectWebSocket();
    });
  }

  // --------------------------------------------------------------
  // 4. Virtual‑camera frame pump (captureFrame → native)
  // --------------------------------------------------------------
  Future<void> _pumpFramesToVirtualCam(MediaStreamTrack track) async {
    if (_vcOn) return;
    await _platform.invokeMethod('startVirtualCamera', {
      'width': 720,
      'height': 720,
      'fps': 30,
    });
    setState(() => _vcOn = true);
    track.enabled = true;

    _frameTimer = Timer.periodic(const Duration(milliseconds: 33), (_) async {
      if (!_vcOn || !mounted) return;
      try {
        final buf = await track.captureFrame();
        await _platform.invokeMethod('pushFrame', {
          'rgba': buf.asUint8List(),
          'width': 720,
          'height': 720,
        });
      } catch (e) {
        debugPrint('capture error: $e');
      }
    });
  }

  Future<void> _startVirtualCam() async {
    if (_currentVideoTrack != null && !_vcOn) {
      await _pumpFramesToVirtualCam(_currentVideoTrack!);
      _updateStatus('Virtual cam ON');
    }
  }

  Future<void> _stopVC() async {
    if (!_vcOn) return;
    _vcOn = false;
    _frameTimer?.cancel();
    try {
      await _platform.invokeMethod('stopVirtualCamera');
    } catch (_) {}
    setState(() {});
    _updateStatus('Virtual cam OFF');
  }

  // --------------------------------------------------------------
  // 5. Helper to update status text
  // --------------------------------------------------------------
  void _updateStatus(String text) {
    if (!mounted) return;
    setState(() {
      _status = text;
      _isConnecting = text.contains('Connecting') || text.contains('Reconnect');
    });
  }

  // --------------------------------------------------------------
  // 6. Cleanup
  // --------------------------------------------------------------
  @override
  void dispose() {
    _stopVC();
    _frameTimer?.cancel();
    _ws?.sink.close();
    _pc?.close();
    _renderer.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------
  // UI
  // --------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Webcamo Desktop – Virtual Camera'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ────── STATUS BAR ──────
          Container(
            width: double.infinity,
            color: _vcOn ? Colors.green : Colors.grey.shade800,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            child: Row(
              children: [
                Icon(
                  _isConnecting ? Icons.hourglass_bottom : Icons.check_circle,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _status,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_vcOn)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.videocam, color: Colors.white),
                  ),
              ],
            ),
          ),

          // ────── VIDEO PREVIEW ──────
          Expanded(
            child: Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: _renderer.srcObject != null
                  ? RTCVideoView(
                      _renderer,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                      mirror: false,
                    )
                  : _isConnecting
                      ? const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 16),
                            Text(
                              'Waiting for phone…',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        )
                      : const Text(
                          'No video stream',
                          style: TextStyle(color: Colors.white70),
                        ),
            ),
          ),

          // ────── CONTROLS ──────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _vcOn ? null : _startVirtualCam,
                  icon: const Icon(Icons.videocam),
                  label: const Text('Start Virtual Cam'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: _vcOn ? _stopVC : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop Virtual Cam'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                const Spacer(),
                const Text(
                  '720×720 @ 30 fps',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}