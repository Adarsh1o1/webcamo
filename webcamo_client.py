PHONE_URL = "ws://192.168.31.183:8080/ws"   # <---- Replace this
import sys
import asyncio
import json
import time
import numpy as np
import cv2
import websockets
import pyvirtualcam
from pyvirtualcam import PixelFormat

from aiortc import RTCPeerConnection, RTCSessionDescription
from aiortc.sdp import candidate_from_sdp

from PyQt6.QtCore import Qt, QTimer, pyqtSignal, QObject
from PyQt6.QtGui import QImage, QPixmap
from PyQt6.QtWidgets import (
    QApplication, QWidget, QLabel, QLineEdit, QPushButton, QVBoxLayout,
    QHBoxLayout, QSlider, QCheckBox, QGroupBox, QFormLayout, QMessageBox, QComboBox, QSpinBox
)

from qasync import QEventLoop, asyncSlot


TARGET_WIDTH = 720
TARGET_HEIGHT = 1280  # Portrait orientation


def bgr_to_qimage(img_bgr):
    img_rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
    h, w, ch = img_rgb.shape
    bytes_per_line = ch * w
    return QImage(img_rgb.data, w, h, bytes_per_line, QImage.Format.Format_RGB888)


def center_crop_square(img):
    h, w, _ = img.shape
    m = min(h, w)
    y0 = (h - m) // 2
    x0 = (w - m) // 2
    return img[y0:y0+m, x0:x0+m]

def rotate_frame(img, rotation):
    if rotation == 90:
        return cv2.rotate(img, cv2.ROTATE_90_CLOCKWISE)
    elif rotation == 180:
        return cv2.rotate(img, cv2.ROTATE_180)
    elif rotation == 270:
        return cv2.rotate(img, cv2.ROTATE_90_COUNTERCLOCKWISE)
    return img

# def apply_filters(
#     img,
#     smooth=60,          # 0..100
#     sharpen=30,         # 0..300 (%)
#     brightness=0,       # -100..100
#     contrast=100,       # 50..150 (%)
#     warmth=0            # -100..100
# ):
#     # 1) Beauty smoothing (bilateral)
#     if smooth > 0:
#         # Map slider to bilateral parameters
#         d = 9
#         sigma_color = 30 + int(smooth * 2.0)     # 30..230
#         sigma_space = 30 + int(smooth * 1.5)     # 30..180
#         img = cv2.bilateralFilter(img, d=d, sigmaColor=sigma_color, sigmaSpace=sigma_space)

#     # 2) Basic brightness/contrast
#     alpha = contrast / 100.0   # 0.5..1.5
#     beta = brightness          # -100..100
#     img = cv2.convertScaleAbs(img, alpha=alpha, beta=beta)

#     # 3) Warm/Cool tint (very subtle)
#     if warmth != 0:
#         # split channels (B,G,R)
#         b, g, r = cv2.split(img)
#         if warmth > 0:
#             # warmer: slightly reduce B, boost R
#             amt = np.clip(warmth, 0, 100)
#             r = cv2.add(r, np.uint8(amt * 0.3))
#             b = cv2.subtract(b, np.uint8(amt * 0.3))
#         else:
#             # cooler: do the opposite
#             amt = np.clip(-warmth, 0, 100)
#             b = cv2.add(b, np.uint8(amt * 0.3))
#             r = cv2.subtract(r, np.uint8(amt * 0.3))
#         img = cv2.merge([b, g, r])

#     # 4) Sharpen (unsharp mask)
#     if sharpen > 0:
#         amount = sharpen / 100.0  # 0..3.0 typically
#         blur = cv2.GaussianBlur(img, (0, 0), sigmaX=1.0)
#         img = cv2.addWeighted(img, 1 + amount, blur, -amount, 0)

#     return img


class Signals(QObject):
    frame_ready = pyqtSignal(np.ndarray)
    status = pyqtSignal(str)
    connected = pyqtSignal(bool)





class WebcamoClient(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Webcamo Desktop")
        self.setMinimumSize(960, 720)

        # UI elements
        self.preview_label = QLabel("Preview")
        self.preview_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.preview_label.setStyleSheet("background:#111; color:#aaa; border:1px solid #333;")


        self.url_edit = QLineEdit("192.168.31.183")
        self.connect_btn = QPushButton("Connect")
        self.disconnect_btn = QPushButton("Disconnect")
        self.disconnect_btn.setEnabled(False)

        # Toggles
        self.virtual_cam_chk = QCheckBox("Virtual Camera ON")
        self.virtual_cam_chk.setChecked(True)
        

        

        self.status_label = QLabel("Status: Idle")
        self.status_label.setStyleSheet("""
            background: #111;
            color: #0f0;
            padding: 6px;
            border: 1px solid #333;
            font-family: Consolas, monospace;
        """)



        top_bar = QHBoxLayout()
        top_bar.addWidget(QLabel("Enter IP:"))
        top_bar.addWidget(self.url_edit)
        top_bar.addWidget(self.connect_btn)
        top_bar.addWidget(self.disconnect_btn)
        top_bar.addWidget(self.virtual_cam_chk)


        self.flip_chk = QCheckBox("Flip Video (Mirror)")
        self.flip_chk.setChecked(True)
        top_bar.addWidget(self.flip_chk)


        layout = QVBoxLayout(self)
        layout.addLayout(top_bar)
        layout.addWidget(self.preview_label, stretch=1)
        layout.addWidget(self.status_label, stretch=0)



        # State
        self.signals = Signals()
        self.signals.frame_ready.connect(self.update_preview)
        self.signals.status.connect(self.log)
        self.signals.connected.connect(self.on_connected)

        self.pc: RTCPeerConnection | None = None
        self.ws = None
        self.cam = None  # pyvirtualcam.Camera
        self.running_receiver = False
        self._closing = False

        # FPS watchdog (optional)
        self._last_fps_time = time.time()
        self._frames_count = 0
        self._fps_timer = QTimer(self)
        self._fps_timer.setInterval(1000)
        self._fps_timer.timeout.connect(self._show_fps)
        self._fps_timer.start()

        # Wire buttons
        self.connect_btn.clicked.connect(self.on_connect_clicked)
        self.disconnect_btn.clicked.connect(self.on_disconnect_clicked)

    def _slider(self, mn, mx, val):
        s = QSlider(Qt.Orientation.Horizontal)
        s.setMinimum(mn); s.setMaximum(mx); s.setValue(val)
        return s

    def log(self, msg: str):
        print(msg)
        self.status_label.setText(msg)

    def on_connected(self, ok: bool):
        self.connect_btn.setEnabled(not ok)
        self.disconnect_btn.setEnabled(ok)

    @asyncSlot()
    async def on_connect_clicked(self):
        ip = self.url_edit.text().strip()
        print(ip)
        url = f"ws://{ip}:8080/ws"
        if not url:
            QMessageBox.warning(self, "Missing URL", "Enter WebSocket URL (e.g., ws://PHONE_IP:8080/ws)")
            return
        await self.connect(url)

    @asyncSlot()
    async def on_disconnect_clicked(self):
        await self.disconnect()

    async def connect(self, url: str):
        try:
            self.signals.status.emit("🔧 Creating PeerConnection")
            self.pc = RTCPeerConnection()

            # Log ICE state changes
            @self.pc.on("iceconnectionstatechange")
            def _on_ice_state():
                self.signals.status.emit(f"🌐 ICE: {self.pc.iceConnectionState}")

            # Prepare to receive video
            self.pc.addTransceiver("video", direction="recvonly")

            self.signals.status.emit(f"🔗 Connecting WebSocket: {url}")
            self.ws = await websockets.connect(url)
            self.signals.status.emit("✅ WebSocket connected")

            # Track handler
            @self.pc.on("track")
            def on_track(track):
                self.signals.status.emit(f"🎥 Track: {track.kind}")
                if track.kind != "video":
                    return
                if self.running_receiver:
                    return
                self.running_receiver = True
                asyncio.ensure_future(self._receiver_task(track))

            # Create & send OFFER
            self.signals.status.emit("📤 Creating Offer…")
            offer = await self.pc.createOffer()
            await self.pc.setLocalDescription(offer)

            await self.ws.send(json.dumps({
                "type": "offer",
                "sdp": self.pc.localDescription.sdp
            }))
            self.signals.status.emit("✅ Offer sent. ⏳ Waiting for Answer…")

            # Receive ANSWER
            answer_json = await self.ws.recv()
            data = json.loads(answer_json)
            if data.get("type") != "answer" or not data.get("sdp"):
                raise RuntimeError(f"Bad answer: {data}")
            await self.pc.setRemoteDescription(RTCSessionDescription(data["sdp"], "answer"))
            self.signals.status.emit("✅ Answer applied")
            self.signals.connected.emit(True)

            # Handle incoming ICE
            asyncio.ensure_future(self._ice_listener())

        except Exception as e:
            self.signals.status.emit(f"❌ Connect error: {e}")
            await self.disconnect()

    async def _ice_listener(self):
        try:
            while self.ws:
                msg = await self.ws.recv()
                data = json.loads(msg)
                if data.get("type") == "candidate" and data.get("candidate"):
                    cand = data["candidate"]
                    self.signals.status.emit("🧊 ICE Candidate → parsing SDP")
                    ice = candidate_from_sdp(cand["candidate"])
                    ice.sdpMid = cand.get("sdpMid")
                    ice.sdpMLineIndex = cand.get("sdpMLineIndex")
                    await self.pc.addIceCandidate(ice)
                    self.signals.status.emit("✅ ICE added")
        except Exception as e:
            if not self._closing:
                self.signals.status.emit(f"⚠️ ICE listener ended: {e}")

    async def _receiver_task(self, track):
        self.signals.status.emit("📥 Starting frame receiver")
        try:
            while True:
                        frame = await track.recv()
                        img = frame.to_ndarray(format="bgr24")
                        # print(img.shape)
                        h, w, _ = img.shape
                        if h > w:
                            img = cv2.rotate(img, cv2.ROTATE_90_CLOCKWISE)

                        if self.flip_chk.isChecked():
                            img = cv2.flip(img, 1) 

                        # img = center_crop_square(img)
                        img = cv2.resize(img, (1280, 720), interpolation=cv2.INTER_AREA)

                        self._frames_count += 1
                        self.signals.frame_ready.emit(img)

                        
                        if self.cam is None:
                            self.signals.status.emit(f"🎬 Starting Virtual Cam at 1280x720")


                            self.cam = pyvirtualcam.Camera(
                                1280,
                                720,
                                30,
                                fmt=PixelFormat.RGB
                            )

                            self.signals.status.emit("✅ Virtual cam active")

                        # ✅ Convert BGR → I420 exactly
                        img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
                        self.cam.send(img_rgb)
                        self.cam.sleep_until_next_frame()


        except Exception as e:
            if not self._closing:
                self.signals.status.emit(f"⚠️ Receiver ended: {e}")
        finally:
            self.running_receiver = False

    def update_preview(self, img):
        qimg = bgr_to_qimage(img)
        pix = QPixmap.fromImage(qimg).scaled(
            self.preview_label.width(),
            self.preview_label.height(),
            Qt.AspectRatioMode.KeepAspectRatio,
            Qt.TransformationMode.SmoothTransformation
        )
        self.preview_label.setPixmap(pix)

    



    def _show_fps(self):
        now = time.time()
        dt = now - self._last_fps_time
        if dt >= 1.0:
            fps = self._frames_count / dt
            self._frames_count = 0
            self._last_fps_time = now
            self.setWindowTitle(f"Webcamo Desktop")

    async def disconnect(self):
        self._closing = True
        self.signals.connected.emit(False)
        try:
            if self.ws:
                await self.ws.close()
        except Exception:
            pass
        self.ws = None

        try:
            if self.pc:
                await self.pc.close()
        except Exception:
            pass
        self.pc = None

        if self.cam:
            try:
                self.cam.close()
            except Exception:
                pass
        self.cam = None

        self._closing = False
        self.signals.status.emit("🔌 Disconnected.")

    def closeEvent(self, event):
        reply = QMessageBox.question(
            self,
            "Exit Webcamo",
            "Are you sure you want to exit?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No,
        )

        if reply == QMessageBox.StandardButton.Yes:
            # Proceed with asynchronous clean shutdown
            asyncio.ensure_future(self._graceful_close(event))
        else:
            event.ignore()


    async def _graceful_close(self, event):
        await self.disconnect()          # Clean shutdown WebSocket, RTC, and virtual cam
        event.accept()                   # Allow window to close
        QApplication.instance().quit()   # End application




def main():
    app = QApplication(sys.argv)
    loop = QEventLoop(app)
    asyncio.set_event_loop(loop)

    w = WebcamoClient()
    w.show()

    with loop:
        loop.run_forever()


if __name__ == "__main__":
    main()
