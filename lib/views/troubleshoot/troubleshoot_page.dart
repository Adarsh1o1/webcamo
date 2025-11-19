import 'package:flutter/material.dart';
import 'package:webcamo/utils/colors.dart';

class TroubleshootPage extends StatelessWidget {
  const TroubleshootPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (_) {}, // ← disables problematic hover tracking
      opaque: false,
      child: Scaffold(
        backgroundColor: MyColors.lightColorScheme.primary,
        appBar: AppBar(title: Text("Troubleshooting"), backgroundColor: Color(0xff1E1E1E)),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 30, 16, 22),
                children: [
                  const Text(
                    "Unable to connect? Here are some steps to help you troubleshoot your issues.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  SizedBox(height: 20),
                  _buildIssue(
                    title: "Client not connecting to server.",
                    steps: [
                      "Please make sure that both your PC and mobile device are connected to the same WiFi network and share the same configuration like port number (default is 8080). Also make sure that you entered the correct IP address of your mobile device in the client application on your PC.",
                    ],
                  ),
                  _buildIssue(
                    title: "Device connected but no Camera stream.",
                    steps: [
                      "The issue is likely caused by a firewall. WebSockets connect over TCP, and the video stream is sent after the WebSocket connection is established — usually over UDP and sometimes TCP on random discovery ports. These ports may be blocked by the firewall. Try disabling any VPNs or firewalls temporarily, or allow incoming connections in your firewall settings to fix the issue."
                    ],
                  ),
                  _buildIssue(
                    title: "Not connecting to the camera.",
                    steps: [
                      "Ensure you have granted camera and microphone permissions. if not granted, go to app settings and enable them.",
                    ],
                  ),
                  _buildIssue(
                    title: "Wifi IP is Null.",
                    steps: [
                      "Make sure that your device is connected to a Wi-Fi network only not mobile data. It should work even without internet access.",
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIssue({required String title, required List<String> steps}) {
    return Card(
      color: Color(0xff1E1E1E),
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...steps.map(
              (s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // const Text("• "),
                    Expanded(child: Text(s)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
