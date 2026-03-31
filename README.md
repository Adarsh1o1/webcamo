## Phone as Webcam — WebRTC + WebSockets

**The problem:** My desktop had no webcam. Cheap webcams have poor quality. My phone has a great camera. Why can't I just use it?

**What this does:** Streams your smartphone camera to your desktop as a webcam — over both WiFi and USB — using WebRTC for the media stream and WebSockets for signaling.

**Current state:** Stable at ~20fps. We targeted 30fps but hit a bottleneck in [signaling latency / encoding pipeline — explain the real reason here]. This is a known limitation and active area of improvement.

**Key decisions I made:**
- Chose WebRTC over simple MJPEG streaming because I wanted to understand peer-to-peer media — the complexity was the point
- Used WebSockets for the signaling layer rather than a managed service to keep the architecture transparent
- Flutter for the mobile client because it let us target both Android and iOS from one codebase

**What I'd do differently:**
- Investigate hardware-accelerated encoding on the mobile side earlier
- Better buffer management to reduce frame drops on congested networks

**What I learned:** More about how browsers negotiate media streams, ICE candidates, and STUN/TURN servers than any tutorial could have taught me.

[Play Store link](https://play.google.com/store/apps/details?id=com.eazycam.app)
