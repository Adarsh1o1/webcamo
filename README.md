# Webcamo: Low-Latency P2P Mobile Webcam

<p align="center">
  <img src="android/assets/icon/icon.png" alt="Webcamo Logo" width="150">
</p>

<p align="center">
  <strong>Transforms your smartphone into a high-quality, low-latency PC webcam using WebRTC.</strong>
</p>


---

**Webcamo** is a high-performance solution that leverages the power of WebRTC to provide a real-time (sub-second latency) video feed from your phone's camera to your PC. It is designed to work entirely **offline** over your local Wi-Fi requiring no internet connection.

This project consists of two main components:
1.  **The Mobile App (Flutter):** A cross-platform app that runs a local signaling server and streams your camera/mic feed.
2.  **The OBS Project :** The **OBS Browser Source** decodes the stream and feeds them into a virtual camera driver and pipes it to a virtual camera for use in any PC application (OBS, Zoom, Teams, etc.).

## 📸 Core Features

* **Real-Time Low Latency:** Sub-second latency perfect for meetings, powered by a direct WebRTC peer-to-peer connection.
* **100% Offline:** No internet connection required. The app works entirely over your local Wi-Fi or mobile hotspot by running its own signaling server.
* **High-Quality Stream:** Captures and streams video at 1080p @ 30fps (or 720p for better performance), utilizing hardware-accelerated H.264 encoding.
* **Local Camera Preview:** See exactly what you're streaming with a real-time, in-app preview on your phone.
* **Modern UI:** Built with Material 3, including dynamic light/dark theme support, custom color schemes, and a clean, card-based layout.
* **Full Camera Control:**
    * Switch between front and back cameras at any time.
    * Toggle the flash (for both front and back cameras, if supported).
* **Server Controls:** Stop, and refresh the local server directly from the app to save battery.

## 🚀 How it Works: The Architecture

The system avoids internet-based STUN/TURN servers by running its own signaling server on the phone, making it ideal for offline-first local networks.

1.  **Phone App (Sender & Signaling Server)**
    * A Flutter app using `flutter_webrtc` captures the camera and microphone.
    * A local `shelf` server is started on the phone's IP (e.g., `192.168.43.1:8080`), bound to `0.0.0.0` to accept connections from any interface.
    * This server listens for WebSocket connections on `/ws` to perform the WebRTC signaling (exchanging offer/answer/candidates).

2.  **Desktop Client**
    * The **OBS Browser Source** decodes the stream and feeds them into a virtual camera driver (e.g., the OBS Virtual Camera driver).
    * Any app on the PC (Zoom, Teams, Chrome) can now select "OBS Virtual Camera" as its video source.

## 🛠️ Tech Stack

| Component | Technology | Key Libraries |
| :--- | :--- | :--- |
| **Mobile App** | Flutter / Dart | `flutter_webrtc`, `shelf_web_socket`, `permission_handler`, `wakelock_plus` |
| **Protocol** | WebRTC | `SDP` for handshake, `ICE` for connection, `SRTP` for media |

## 🐛 Known Issues & Bugs

* **Hotspot Firewall Block:** This is the biggest issue. The app may work on a "Private" home Wi-Fi but fails on a "Public" mobile hotspot. This is because the Windows Firewall blocks the P2P video stream.
* **AP Isolation:** The app will not work on Wi-Fi networks (like many public or guest networks) that have "AP Isolation" or "Client Isolation" enabled, as this blocks all P2P communication between devices.
* **Audio Not Piped:** The current Python script receives the audio track from the phone but does not have a driver to pipe it to a "Virtual Microphone." Video is fully functional.

## 🔮 Future Work

* **Packaged Desktop Client:** The top priority. Package the Python script, all dependencies, and a virtual camera driver into a single `.exe` installer (using PyInstaller and Inno Setup). The installer would also run the firewall command automatically, providing a one-click setup for any user.
* **USB Streaming:** Implement streaming over a USB cable (`adb forward`) for a zero-latency, high-reliability connection that doesn't depend on Wi-Fi.
* **Data Channel:** Utilize the WebRTC data channel to send metadata from the phone (battery level, notifications) or send commands from the PC (remote-control camera switching/flash).
* **Virtual Audio:** Investigate a virtual audio driver (like VAC or VB-Audio) to pair with the Python script, enabling the phone's mic to be used on the PC.

---

## 📜 License

This project is licensed under the MIT License.
