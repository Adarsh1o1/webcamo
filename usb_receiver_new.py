# pyinstaller --onefile --add-data "adb/adb.exe;adb" --add-data "adb/AdbWinApi.dll;adb" --add-data "adb/AdbWinUsbApi.dll;adb" webcamo_client.py

import shutil
import sys
import asyncio
import json
import numpy as np
import cv2
import websockets
import pyvirtualcam
from pyvirtualcam import PixelFormat
from aiortc import RTCPeerConnection, RTCSessionDescription
from aiortc.sdp import candidate_from_sdp
from PyQt6.QtCore import Qt, pyqtSignal, QObject, QThread, pyqtSlot, QTimer

from PyQt6.QtGui import QImage, QPixmap, QTextCursor, QIcon
from PyQt6.QtWidgets import (
    QApplication, QWidget, QLabel, QLineEdit, QPushButton, QVBoxLayout,
    QHBoxLayout, QCheckBox, QMessageBox, QTextEdit, QRadioButton, QStackedLayout
)
from qasync import QEventLoop, asyncSlot
import socket
import struct
import subprocess
import os

# def start_adb_reverse():
#         """
#         Automatically runs 'adb reverse tcp:23233 tcp:23233'.
#         Checks for 'adb.exe' in the same directory (for bundled apps) or uses system PATH.
#         """
#         adb_cmd = 'adb'
        
#         # Check if we are running in a bundled environment (PyInstaller)
#         if getattr(sys, 'frozen', False):
#             # Look for adb in the same folder as the executable
#             base_path = os.path.dirname(sys.executable)
#             bundled_adb = os.path.join(base_path, 'adb.exe')
#             if os.path.exists(bundled_adb):
#                 adb_cmd = bundled_adb
#         else:
#             # Look in current script directory
#             local_adb = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'adb.exe')
#             if os.path.exists(local_adb):
#                 adb_cmd = local_adb

#         # self.log(f"Using ADB: {adb_cmd}")
        
#         try:
#             subprocess.run([adb_cmd, 'forward', 'tcp:23233', 'tcp:23233'], check=True, capture_output=True)
#             self.log("ADB forward successful.")
#         except subprocess.CalledProcessError as e:
#             self.log(f"Error running ADB forward: {e}")
#             self.log("Make sure your phone is connected and USB debugging is enabled.")
#         except FileNotFoundError:
#             self.log("ADB not found. Please install Android Platform Tools or place adb.exe in this folder.")


class USBReceiverWorker(QObject):
    frame_ready = pyqtSignal(np.ndarray)
    log = pyqtSignal(str)
    finished = pyqtSignal()

    def __init__(self, flip=True):
        super().__init__()
        self.running = True
        self.flip = flip

    def stop(self):
        self.running = False
        try:
            if self.sock:
                self.sock.close()
        except:
            pass

        

    @pyqtSlot(bool)
    def set_flip(self, value):
        self.flip = value
        self.log.emit(f"USB: Flip set to {value}")


    def run(self):
        HOST = '127.0.0.1'
        PORT = 23233

        self.log.emit("Starting USB mode...")
        """
        Automatically runs 'adb reverse tcp:23233 tcp:23233'.
        Checks for 'adb.exe' in the same directory (for bundled apps) or uses system PATH.
        """
        adb_cmd = 'adb'
        
        if getattr(sys, 'frozen', False):
            base = sys._MEIPASS  # temp folder PyInstaller extracts to
            local_adb = os.path.join(base, "adb", "adb.exe")
            if os.path.exists(local_adb):
                adb_cmd = local_adb

    # 2) Local project folder
        local_adb = os.path.join(os.path.dirname(os.path.abspath(__file__)), "adb", "adb.exe")
        if os.path.exists(local_adb):
            adb_cmd =  local_adb

    # 3) System PATH
        system_adb = shutil.which("adb")
        if system_adb:
            adb_cmd = system_adb
        
        try:
            subprocess.run([adb_cmd, 'forward', 'tcp:23233', 'tcp:23233'], check=True, capture_output=True)
            self.log.emit("ADB forward successful.")
        except subprocess.CalledProcessError as e:
            self.log.emit(f"Error running ADB forward: {e}")
            self.log.emit("Make sure your phone is connected and USB debugging is enabled.")
        except FileNotFoundError:
            self.log.emit("ADB not found. Please install Android Platform Tools or place adb.exe in this folder.")

        
        self.log.emit(f"Connecting to adb device at {PORT}")

        # Connect Socket
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.connect((HOST, PORT))
            self.log.emit("Connected to phone!")
        except ConnectionRefusedError:
            self.log.emit("Connection failed. Check if the app is streaming.")

        cam = None
        try:
            while True:
                # Read Packet Type (1 byte)
                type_byte = s.recv(1)
                if not type_byte:
                    break
                
                packet_type = int.from_bytes(type_byte, byteorder='big')
                
                if packet_type == 0:  # Video
                    # Read Total Size (4 bytes)
                    total_size_data = recv_exact(s, 4)
                    if not total_size_data: break
                    total_size = struct.unpack('>I', total_size_data)[0]

                    # Read Metadata (40 bytes)
                    # Width(4), Height(4), YLen(4), ULen(4), VLen(4), 
                    # YStride(4), UStride(4), VStride(4), UPixelStride(4), VPixelStride(4)
                    metadata_data = recv_exact(s, 40)
                    is_front = s.recv(1)[0]
                    # print("Front Camera:", bool(is_front))
                    if not metadata_data: break
                    
                    (width, height, 
                    y_len, u_len, v_len, 
                    y_stride, u_stride, v_stride, 
                    u_pixel_stride, v_pixel_stride) = struct.unpack('>IIIIIIIIII', metadata_data)

                    # Read Plane Data
                    y_data = recv_exact(s, y_len)
                    u_data = recv_exact(s, u_len)
                    v_data = recv_exact(s, v_len)


                    if not y_data or not u_data or not v_data:
                        break

                    try:
    # --- RECONSTRUCT IMAGE FROM PLANES ---

                        def pad_to_stride(data, h, stride):
                            expected = h * stride
                            if len(data) < expected:
                                return data + b'\0' * (expected - len(data))
                            return data

                        # 1. Y plane
                        y_data = pad_to_stride(y_data, height, y_stride)
                        y_plane = np.frombuffer(y_data, dtype=np.uint8).reshape((height, y_stride))
                        y_plane = y_plane[:, :width]

                        # 2. U plane
                        uv_width = width // 2
                        uv_height = height // 2

                        u_data = pad_to_stride(u_data, uv_height, u_stride)
                        u_plane = np.frombuffer(u_data, dtype=np.uint8).reshape((uv_height, u_stride))
                        u_plane = u_plane[:, ::u_pixel_stride][:, :uv_width]

                        # 3. V plane
                        v_data = pad_to_stride(v_data, uv_height, v_stride)
                        v_plane = np.frombuffer(v_data, dtype=np.uint8).reshape((uv_height, v_stride))
                        v_plane = v_plane[:, ::v_pixel_stride][:, :uv_width]

                        # 4. Merge YUV → I420
                        y_flat = y_plane.flatten()
                        u_flat = u_plane.flatten()
                        v_flat = v_plane.flatten()

                        i420 = np.concatenate([y_flat, u_flat, v_flat])

                        i420_reshaped = i420.reshape((height + height // 2, width))

                        # 5. Convert to BGR (no rotation)
                        bgr = cv2.cvtColor(i420_reshaped, cv2.COLOR_YUV2BGR_I420)

                        h, w = bgr.shape[:2]
                        min_dim = min(h, w)
                        start_x = (w - min_dim) // 2
                        start_y = (h - min_dim) // 2
                        bgr = bgr[start_y:start_y + min_dim, start_x:start_x + min_dim]

                        # 6. Optional flip only if enabled
                        
                        if is_front:
                            bgr = np.rot90(bgr, k=1)
                            bgr = cv2.flip(bgr, 1)
                        else:
                            bgr = np.rot90(bgr, k=3)

                        # self.frame_ready.emit(bgr)

                            

                    except Exception as e:
                        self.log.emit(f"Error processing frame: {e}")
                        continue

                    if cam is None:
                        
                        try:
                            h, w = bgr.shape[:2]
                            cam = pyvirtualcam.Camera(width=w, height=h, fps=30, fmt=pyvirtualcam.PixelFormat.BGR, backend="unitycapture")
                            self.log.emit("USB worker: virtualcam started")
                        except Exception as e:
                            self.log.emit(f"USB worker: virtualcam error: {e}")
                            self.cam = None
                            continue
                    if cam:
                        cam.send(bgr)
                        # cam.sleep_until_next_frame()

                    # Output the image exactly as received
                    self.frame_ready.emit(bgr)

                
                else:
                    self.log.emit(f"Unknown packet type: {packet_type}")
                    break

        except Exception as e:
            self.log.emit(f"Error: {e}")
        finally:
            try:
                s.close()
            except:
                pass
            self.finished.emit()




def bgr_to_qimage(img_bgr):
    img_rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
    h, w, ch = img_rgb.shape
    bytes_per_line = ch * w
    return QImage(img_rgb.data, w, h, bytes_per_line, QImage.Format.Format_RGB888)

def recv_exact(sock, size):
    buf = b''
    while len(buf) < size:
        chunk = sock.recv(size - len(buf))
        if not chunk:
            return None
        buf += chunk
    return buf

class Signals(QObject):
    frame_ready = pyqtSignal(np.ndarray)
    status = pyqtSignal(str)
    connected = pyqtSignal(bool)

class WebcamoClient(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Webcamo Desktop")
        self.setWindowIcon(QIcon(r"C:\Users\adars\Desktop\webcamo\webcamo desktop\assets\logoo.ico"))
        self.setMinimumSize(600, 500)

        # UI elements
        self.preview_label = QLabel("Connect Device for Preview")
        self.preview_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.preview_label.setStyleSheet("background:#111; color:#aaa; border:1px solid #333;")


        self.url_edit = QLineEdit("192.168.31.183")
        self.connect_btn = QPushButton("Connect")
        self.disconnect_btn = QPushButton("Disconnect")
        self.disconnect_btn.setEnabled(False)
       



        self.mode_wireless = QRadioButton("Wireless")
        self.mode_usb = QRadioButton("USB")
        self.mode_wireless.setChecked(True)

        # Two independent checkboxes
        self.flip_chk = QCheckBox("Flip Video (Mirror)")
        self.flip_chk.setStyleSheet("""
    QCheckBox::indicator {
        width: 18px;
        height: 18px;
        border-radius: 4px;
    }

    QCheckBox::indicator:checked {
        background-color: #1ea73f;   /* ← GREEN YOU WANT */
        border: 1px solid #1ea73f;
        image: url(:/qt-project.org/styles/commonstyle/images/checkmark.png);
    }

    QCheckBox::indicator:unchecked {
        background-color: #2c2c2c;   /* matching dark theme */
        border: 1px solid #555;
    }
""")

        self.flip_chk_usb = QCheckBox("Flip Video (Mirror)")
        self.flip_chk.setChecked(True)
        self.flip_chk_usb.setChecked(True)

        self.refresh_usb_btn = QPushButton("Refresh USB Device")
        self.refresh_usb_btn.setStyleSheet("padding: 6px 12px;")
        self.refresh_usb_btn.clicked.connect(self.refresh_usb_mode)




        self.main_layout = QVBoxLayout(self)
        self.main_layout.setContentsMargins(10, 10, 10, 10)
        self.main_layout.setSpacing(8)

        # ----- Top mode selector -----
        mode_bar = QHBoxLayout()
        mode_bar.setSpacing(10)

        self.btn_wireless = QPushButton("Wireless Mode")
        self.btn_wireless.setStyleSheet("""
        QPushButton:checked {
            background-color: #1ea73f; 
            color: white;
          
        }
    """)

        self.btn_usb = QPushButton("USB Mode")
        self.btn_usb.setStyleSheet("""
        QPushButton:checked { 
            background-color: #1ea73f; 
            color: white;
          
        }
                                   """)
                                   
        self.btn_wireless.setCheckable(True)
        self.btn_usb.setCheckable(True)
        self.btn_wireless.setChecked(True)
        mode_bar.addWidget(self.btn_wireless)
        mode_bar.addWidget(self.btn_usb)
        self.main_layout.addLayout(mode_bar,stretch=0)


        # ----- Stacked Layout for Wireless / USB -----
        self.stack = QStackedLayout()

        # Wireless UI row
        self.wireless_widget = QWidget()
        wl = QHBoxLayout()
        wl.setSpacing(8)

        wl.addWidget(QLabel("Enter IP:"))
        wl.addWidget(self.url_edit)
        wl.addWidget(self.connect_btn)
        wl.addWidget(self.disconnect_btn)
        wl.addWidget(self.flip_chk)

        self.wireless_widget.setLayout(wl)
        self.stack.addWidget(self.wireless_widget)

        # USB UI row
        self.usb_widget = QWidget()
        ul = QHBoxLayout()
        ul.setSpacing(8)
        ul.addWidget(QLabel("USB Mode Active. Connect your phone via USB"))
        # ul.addWidget(self.flip_chk_usb)

        ul.addWidget(self.refresh_usb_btn)
        self.usb_widget.setLayout(ul)
        self.stack.addWidget(self.usb_widget)

        stack_container = QWidget()
        stack_container.setLayout(self.stack)
        self.main_layout.addWidget(stack_container, stretch=0)


        # ---- PREVIEW (this should stretch!) ----
        self.preview_label.setMinimumHeight(350)
        self.preview_label.setStyleSheet("background:#111; border:1px solid #333;")
        self.main_layout.addWidget(self.preview_label, stretch=1)


        # ---- CONTROL BAR (fixed height) ----
        controls = QHBoxLayout()
        controls.setSpacing(20)
        self.main_layout.addLayout(controls, stretch=0)



        self.btn_wireless.clicked.connect(self.activate_wireless_ui)
        self.btn_usb.clicked.connect(self.activate_usb_ui)

        self.usb_thread = None
        self.usb_worker = None

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


        self.connect_btn.clicked.connect(self.on_connect_clicked)
        self.disconnect_btn.clicked.connect(self.on_disconnect_clicked)


              
        self.log_box = QTextEdit()
        self.log_box.setReadOnly(True)
        self.log_box.setMaximumHeight(65)  
        self.log_box.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.log_box.setStyleSheet("""
            background: #0d0d0d;
            color: #1ea73f; 
            font-weight: bold;
            font-family: 'JetBrains Mono', Consolas, monospace;
            font-size: 14px;
            border: 1px solid #333;
            border-radius: 4px;
            padding: 4px;
        """)
        self.main_layout.addWidget(self.log_box)
        self.log_box.setPlainText(">> App initialized.\n>> Waiting for connection...")



    def log(self, msg: str):
        # print(msg)
        # self.status_label.setText(msg)
        self.log_box.append(f">> {msg}")
        max_lines = 20
        text = self.log_box.toPlainText().splitlines()
        if len(text) > max_lines:
            text = text[-max_lines:]  # keep only last few
            self.log_box.setPlainText("\n".join(text))

        self.log_box.moveCursor(QTextCursor.MoveOperation.End)

    




    def on_connected(self, ok: bool):
        self.connect_btn.setEnabled(not ok)
        self.disconnect_btn.setEnabled(ok)


    def activate_wireless_ui(self):
        if self.usb_thread:
            self.usb_worker.stop()
            print("Stopping USB worker...")
            self.usb_thread.quit()

        if self.stack.currentWidget() == self.wireless_widget:
            self.btn_wireless.setChecked(True)
            return
        self.stack.setCurrentWidget(self.wireless_widget)
        self.btn_usb.setChecked(False)

        self.log("Switched to Wireless Mode")

    def activate_usb_ui(self):
        if self.stack.currentWidget() == self.usb_widget:
            self.btn_usb.setChecked(True)
            return
        self.stack.setCurrentWidget(self.usb_widget)
        self.btn_wireless.setChecked(False)
        self.log("Switched to USB Mode")

        # Stop wireless receiver if active
        asyncio.ensure_future(self.disconnect())

        # Start USB receiver
        asyncio.ensure_future(self.start_usb_mode())

    @asyncSlot()
    async def start_usb_mode(self):
        if self.usb_thread:
            return  # already running

        self.usb_thread = QThread()
        flip = self.flip_chk_usb.isChecked()
        self.usb_worker = USBReceiverWorker(flip=flip)
        self.usb_worker.moveToThread(self.usb_thread)
        self.flip_chk_usb.toggled.connect(self.usb_worker.set_flip)

        # Connect thread start → worker.run
        self.usb_thread.started.connect(self.usb_worker.run)

        # Worker emits frames to UI
        self.usb_worker.frame_ready.connect(self.update_preview)
        self.usb_worker.log.connect(self.log)

        # When finished
        self.usb_worker.finished.connect(self.usb_thread.quit)
        self.usb_worker.finished.connect(self.usb_worker.deleteLater)
        self.usb_thread.finished.connect(self.thread_cleanup)

        self.usb_thread.start()  

    def thread_cleanup(self):
        self.log("Device Disconnected. USB thread cleaned up.")
        self.usb_thread = None
        self.usb_worker = None


    def refresh_usb_mode(self):
        self.log("Refreshing USB connection...")

        # 1) Stop USB worker safely
        if self.usb_worker:
            self.usb_worker.stop()

        # 2) Wait a tiny bit for socket to close
        # (prevents "address already in use" errors)
        QTimer.singleShot(300, self.start_usb_mode)


    # def stop_usb_receiver(self):
    #     if getattr(self, "usb_worker", None):
    #         self.log("Stopping USB worker...")
    #          # set running=False
    #     if getattr(self, "usb_thread", None):
    #         self.usb_thread.quit()
    #         self.usb_thread.wait()
    #         self.usb_thread = None
    #         self.usb_worker = None
    #         self.log("USB worker stopped.")


    @asyncSlot()
    async def on_connect_clicked(self):
        ip = self.url_edit.text().strip()
        url = f"ws://{ip}:8080/ws"
        if not url:
            QMessageBox.warning(self, "Missing URL", "Enter WebSocket IP (e.g., 192.168.0.1")
            return
        await self.connect(url)

    @asyncSlot()
    async def on_disconnect_clicked(self):
        await self.disconnect()

    async def connect(self, url: str):
        try:
            self.signals.status.emit("Creating PeerConnection")
            self.pc = RTCPeerConnection()

            # Log ICE state changes
            @self.pc.on("iceconnectionstatechange")
            def _on_ice_state():
                self.signals.status.emit(f"ICE: {self.pc.iceConnectionState}")

            # Prepare to receive video
            self.pc.addTransceiver("video", direction="recvonly")

            self.signals.status.emit(f"Connecting WebSocket: {url}")
            self.ws = await websockets.connect(url)
            self.signals.status.emit("WebSocket connected")

            # Track handler
            @self.pc.on("track")
            def on_track(track):
                self.signals.status.emit(f"Track: {track.kind}")
                if track.kind != "video":
                    return
                if self.running_receiver:
                    return
                self.running_receiver = True
                asyncio.ensure_future(self._receiver_task(track))

            # Create & send OFFER
            self.signals.status.emit("Creating Offer…")
            offer = await self.pc.createOffer()
            await self.pc.setLocalDescription(offer)

            await self.ws.send(json.dumps({
                "type": "offer",
                "sdp": self.pc.localDescription.sdp
            }))
            self.signals.status.emit("Offer sent. Waiting for Answer…")

            # Receive ANSWER
            answer_json = await self.ws.recv()
            data = json.loads(answer_json)
            if data.get("type") != "answer" or not data.get("sdp"):
                raise RuntimeError(f"Bad answer: {data}")
            await self.pc.setRemoteDescription(RTCSessionDescription(data["sdp"], "answer"))
            self.signals.status.emit("Answer applied")
            self.signals.connected.emit(True)

            # Handle incoming ICE
            asyncio.ensure_future(self._ice_listener())

        except Exception as e:
            self.signals.status.emit(f"⚠️  Connect error: {e}")
            await self.disconnect()

    async def _ice_listener(self):
        try:
            while self.ws:
                msg = await self.ws.recv()
                data = json.loads(msg)
                if data.get("type") == "candidate" and data.get("candidate"):
                    cand = data["candidate"]
                    self.signals.status.emit("ICE Candidate → parsing SDP")
                    ice = candidate_from_sdp(cand["candidate"])
                    ice.sdpMid = cand.get("sdpMid")
                    ice.sdpMLineIndex = cand.get("sdpMLineIndex")
                    await self.pc.addIceCandidate(ice)
                    self.signals.status.emit("ICE added")
        except Exception as e:
            if not self._closing:
                self.signals.status.emit(f"⚠️ ICE listener ended: {e}")

    async def _receiver_task(self, track):
        self.signals.status.emit("Starting frame receiver")
        try:

            W, H = 720, 720

            while True:
                frame = await track.recv()
                img = frame.to_ndarray(format="bgr24")

                # ✅ Fast rotation based on aspect (h > w means portrait)
                # if img.shape[0] > img.shape[1]:
                #     img = cv2.rotate(img, cv2.ROTATE_90_CLOCKWISE)

                if self.flip_chk.isChecked():
                    img = cv2.flip(img, 1)

                # Crop square first (cheap), then resize (one resize only)
                h, w, _ = img.shape
                m = min(h, w)
                y = (h - m) >> 1
                x = (w - m) >> 1
                img = img[y:y+m, x:x+m]

                img = cv2.resize(img, (W, H), cv2.INTER_AREA)

                # ✅ Preview (unchanged)
                self.signals.frame_ready.emit(img)

                # ✅ Initialize Virtual Cam ONCE
                # if self.virtual_cam_chk.isChecked():
            # If not already active, start it once
                if self.cam is None:
                    self.signals.status.emit(f"Starting UnityCapture Virtual Cam at {W}x{H}")
                    try:
                        self.cam = pyvirtualcam.Camera(
                            width=W,
                            height=H,
                            fps=30,
                            fmt=PixelFormat.I420,
                            backend="unitycapture"
                        )
                        self.signals.status.emit("Virtual cam active via UnityCapture")
                    except Exception as e:
                        self.signals.status.emit(f"[Error] Unable to start virtual cam: {e}")
                        self.cam = None
                        continue

                    # Send frame if virtual cam is running
                if self.cam:
                    img_i420 = cv2.cvtColor(img, cv2.COLOR_BGR2YUV_I420)
                    self.cam.send(img_i420)
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
        self.log_box.clear()
        self.signals.status.emit("Disconnected")

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
    app.setWindowIcon(QIcon(r"C:\Users\adars\Desktop\webcamo\webcamo desktop\assets\logoo.ico"))
    loop = QEventLoop(app)
    asyncio.set_event_loop(loop)

    w = WebcamoClient()
    w.setWindowIcon(QIcon(r"C:\Users\adars\Desktop\webcamo\webcamo desktop\assets\logoo.ico"))
    w.show()

    with loop:
        loop.run_forever()


if __name__ == "__main__":
    main()