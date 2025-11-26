import socket
import struct
import cv2
import numpy as np
import sys
import time
import subprocess
import os

# Try importing optional dependencies
try:
    import pyvirtualcam
    from pyvirtualcam import PixelFormat
except ImportError:
    print("Error: pyvirtualcam not found. Please run: pip install pyvirtualcam")
    sys.exit(1)

# Configuration
HOST = '127.0.0.1'
PORT = 23233

def start_adb_reverse():
    """
    Automatically runs 'adb reverse tcp:23233 tcp:23233'.
    Checks for 'adb.exe' in the same directory (for bundled apps) or uses system PATH.
    """
    adb_cmd = 'adb'
    
    # Check if we are running in a bundled environment (PyInstaller)
    if getattr(sys, 'frozen', False):
        # Look for adb in the same folder as the executable
        base_path = os.path.dirname(sys.executable)
        bundled_adb = os.path.join(base_path, 'adb.exe')
        if os.path.exists(bundled_adb):
            adb_cmd = bundled_adb
    else:
        # Look in current script directory
        local_adb = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'adb.exe')
        if os.path.exists(local_adb):
            adb_cmd = local_adb

    print(f"Using ADB: {adb_cmd}")
    
    try:
        subprocess.run([adb_cmd, 'forward', 'tcp:23233', 'tcp:23233'], check=True, capture_output=True)
        print("ADB forward successful.")
    except subprocess.CalledProcessError as e:
        print(f"Error running ADB forward: {e}")
        print("Make sure your phone is connected and USB debugging is enabled.")
    except FileNotFoundError:
        print("ADB not found. Please install Android Platform Tools or place adb.exe in this folder.")

def recv_exact(sock, size):
    buf = b''
    while len(buf) < size:
        chunk = sock.recv(size - len(buf))
        if not chunk:
            return None
        buf += chunk
    return buf

def main():
    print("Starting Webcamo Receiver...")
    start_adb_reverse()
    
    print(f"Connecting to {HOST}:{PORT}...")

    # Connect Socket
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.connect((HOST, PORT))
        print("Connected to phone!")
    except ConnectionRefusedError:
        print("Connection failed. Check if the app is streaming.")
        sys.exit(1)

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

                    # 1. Y Plane
                    # Reshape to (height, stride) then crop to (height, width)
                    y_data = pad_to_stride(y_data, height, y_stride)
                    y_plane = np.frombuffer(y_data, dtype=np.uint8).reshape((height, y_stride))
                    if y_stride > width:
                        y_plane = y_plane[:, :width]
                    
                    # 2. U Plane
                    # Subsampled height/2, width/2
                    uv_width = width // 2
                    uv_height = height // 2
                    
                    u_data = pad_to_stride(u_data, uv_height, u_stride)
                    u_plane = np.frombuffer(u_data, dtype=np.uint8).reshape((uv_height, u_stride))
                    # De-interleave if pixel stride > 1
                    if u_pixel_stride > 1:
                        u_plane = u_plane[:, ::u_pixel_stride]
                    # Crop width
                    if u_plane.shape[1] > uv_width:
                        u_plane = u_plane[:, :uv_width]

                    # 3. V Plane
                    v_data = pad_to_stride(v_data, uv_height, v_stride)
                    v_plane = np.frombuffer(v_data, dtype=np.uint8).reshape((uv_height, v_stride))
                    if v_pixel_stride > 1:
                        v_plane = v_plane[:, ::v_pixel_stride]
                    if v_plane.shape[1] > uv_width:
                        v_plane = v_plane[:, :uv_width]

                    # 4. Merge to I420 (Planar YUV)
                    # I420 expects: Y (full), U (1/4), V (1/4) contiguously
                    # Note: OpenCV's COLOR_YUV2BGR_I420 expects Y, then U, then V
                    
                    # Flatten and concatenate
                    y_flat = y_plane.flatten()
                    u_flat = u_plane.flatten()
                    v_flat = v_plane.flatten()
                    
                    i420 = np.concatenate([y_flat, u_flat, v_flat])
                    
                    # Reshape for OpenCV (height * 1.5, width)
                    i420_reshaped = i420.reshape((height + height // 2, width))
                    
                    # Convert to BGR
                    bgr = cv2.cvtColor(i420_reshaped, cv2.COLOR_YUV2BGR_I420)

                    # --- OPTIMIZATION: Crop & Rotate ---
                    h, w = bgr.shape[:2]
                    
                    if w > h:
                        # Landscape -> Crop center square
                        min_dim = h
                        center_x = w // 2
                        half_dim = min_dim // 2
                        start_x = center_x - half_dim
                        end_x = center_x + half_dim
                        bgr = bgr[:, start_x:end_x]
                        
                    # Rotate 90 degrees
                    bgr = cv2.rotate(bgr, cv2.ROTATE_90_CLOCKWISE)

                except Exception as e:
                    print(f"Error processing frame: {e}")
                    continue

                if cam is None:
                    h, w = bgr.shape[:2]
                    print(f"Initializing Virtual Camera: {w}x{h} @ 30fps")
                    cam = pyvirtualcam.Camera(width=w, height=h, fps=30, fmt=PixelFormat.BGR)
                    print(f"Virtual Camera started: {cam.device}")
                    

                cam.send(bgr)
                cam.sleep_until_next_frame()
                            
                # Optional: Show preview
                cv2.imshow('Preview', bgr)
                if cv2.waitKey(1) & 0xFF == 27: break
            
            else:
                print(f"Unknown packet type: {packet_type}")
                break

    except Exception as e:
        print(f"Error: {e}")
    finally:
        print("Cleaning up...")
        if cam: cam.close()
        s.close()
        cv2.destroyAllWindows()

if __name__ == '__main__':
    main()
