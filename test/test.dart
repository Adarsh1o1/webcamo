import 'package:flutter/material.dart';
import 'usb_stream.dart';
import 'package:permission_handler/permission_handler.dart';

void main() { runApp(const MyApp()); }

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String status = 'stopped';

  Future<void> _start() async {
    // Request camera permission
    final p = await Permission.camera.request();
    if (!p.isGranted) return;

    await CamstreamPlugin.start(port: 23233, width: 1280, height: 720, fps: 30, bitrate: 1500000);
    final s = await CamstreamPlugin.status();
    setState(() { status = s; });
  }

  Future<void> _stop() async {
    await CamstreamPlugin.stop();
    final s = await CamstreamPlugin.status();
    setState(() { status = s; });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('UsbStream Example')),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Service: $status'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _start, child: const Text('Start Streaming')),
            ElevatedButton(onPressed: _stop, child: const Text('Stop Streaming')),
            const SizedBox(height: 20),
            const Text('After start: run on PC:\nadb reverse tcp:5000 tcp:5000\npython pc_receiver.py')
          ]),
        ),
      ),
    );
  }
}