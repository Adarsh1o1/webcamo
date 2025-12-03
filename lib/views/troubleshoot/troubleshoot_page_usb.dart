import 'package:flutter/material.dart';
import 'package:webcamo/utils/colors.dart';

class TroubleshootUsbPage extends StatelessWidget {
  const TroubleshootUsbPage({super.key});

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
                    title: "Phone is not detected when connecting via USB.",
                    steps: [
                      "If your phone is not detected by the desktop app, it usually means USB Debugging is not enabled. USB Debugging allows your PC to communicate with your phone over ADB. To fix this, open Settings → About Phone → Tap “Build Number” 7 times to enable Developer Options. Then go to Settings → System → Developer Options and enable USB Debugging. After enabling it, reconnect your phone and make sure you allow the “Trust this computer?” permission when prompted.",
                    ],
                  ),
                  _buildIssue(
                    title: "“ADB not found” or “USB mode cannot start”.",
                    steps: [
                      "If you see an error saying ADB is missing, the desktop application is unable to locate the ADB tool required for USB communication. This can happen if ADB is not installed on your system or has been removed. The easiest solution is to install Android Platform Tools from Google’s official website or ensure that the application’s bundled ADB folder is intact. Restart the app after installation and try again."
                    ],
                  ),
                  _buildIssue(
                    title: "USB connection not working on Windows 10/11.",
                    steps: [
                      "Windows sometimes fails to install necessary USB drivers automatically. If your device keeps disconnecting, install the OEM USB drivers for your phone brand (Samsung, Xiaomi, OnePlus, Vivo, etc.). After installing the drivers, restart your PC and reconnect your phone. This helps ADB communicate with your device without interruptions.",
                    ],
                  ),
                  _buildIssue(
                    title: "The desktop app freezes when switching between wireless and USB mode.",
                    steps: [
                      "Switching between modes too quickly can interrupt the active ADB connection. If you experience freezing, close and reopen the desktop app, then reconnect the phone. Ensure that USB Debugging is enabled and that the cable is working correctly. Future updates will improve automatic handling of these transitions.",
                    ],
                  ),
                  _buildIssue(
                    title: "USB connection works once but stops after a few seconds.",
                    steps: [
                      "This usually indicates a faulty or low-quality USB cable. Many USB cables are designed only for charging and do not support data transfer. Replace the cable with a high-quality USB data cable, preferably the one provided with your phone. Also try plugging it into a different USB port on your computer, preferably a USB 3.0 port for better stability.",
                    ],
                  ),
                  _buildIssue(
                    title: "Slow or choppy video in USB mode.",
                    steps: [
                      "If the video appears slow, laggy, or freezes, it may be due to slow USB data transfer or background processes on the phone. Try closing apps that use the camera, rebooting your phone, or switching to a different USB port. Ensuring that no heavy apps are running in the background helps the stream remain smooth.",
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
