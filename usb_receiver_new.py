import socket
import struct
import cv2
import numpy as np
import sys
import time

# Try importing optional dependencies
try:
    import pyvirtualcam
    from pyvirtualcam import PixelFormat
except ImportError:
    print("Error: pyvirtualcam not found. Please run: pip install pyvirtualcam")
    sys.exit(1)

try:
    import pyaudio
except ImportError:
    print("Error: pyaudio not found. Please run: pip install pyaudio")
    sys.exit(1)

# Configuration
HOST = '127.0.0.1'
PORT = 23233

# Audio Configuration
CHUNK = 1024
FORMAT = pyaudio.paInt16
CHANNELS = 1
RATE = 16000

def list_audio_devices(p):
    info = p.get_host_api_info_by_index(0)
    numdevices = info.get('deviceCount')
    found_cable = None
    print("\nAvailable Audio Devices:")
    for i in range(0, numdevices):
        if (p.get_device_info_by_host_api_device_index(0, i).get('maxOutputChannels')) > 0:
            name = p.get_device_info_by_host_api_device_index(0, i).get('name')
            print(f"ID {i}: {name}")
            if "CABLE Input" in name:
                found_cable = i
    return found_cable

def recv_exact(sock, size):
    buf = b''
    while len(buf) < size:
        chunk = sock.recv(size - len(buf))
        if not chunk:
            return None
        buf += chunk
    return buf

def main():
    print(f"Connecting to {HOST}:{PORT}...")
    print("Ensure you have run: adb reverse tcp:23233 tcp:23233")

    # Initialize Audio
    p = pyaudio.PyAudio()
    output_device_index = list_audio_devices(p)
    
    if output_device_index is None:
        print("\nWARNING: 'CABLE Input' not found. Using default output device.")
        # output_device_index = p.get_default_output_device_info()['index']
        # Actually, default output is usually speakers. We want a virtual mic.
        # If no virtual cable, we just play to speakers for testing.
    else:
        print(f"\nUsing Audio Device ID {output_device_index} (CABLE Input)")

    audio_stream = p.open(format=FORMAT,
                          channels=CHANNELS,
                          rate=RATE,
                          output=True,
                          output_device_index=output_device_index)

    # Connect Socket
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.connect((HOST, PORT))
        print("Connected to phone!")
    except ConnectionRefusedError:
        print("Connection failed. Check ADB reverse and if the app is streaming.")
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
                size_data = recv_exact(s, 4)
                if not size_data:
                    break
                size = struct.unpack('>I', size_data)[0]

                width_data = recv_exact(s, 4)
                if not width_data:
                    break
                width = struct.unpack('>I', width_data)[0]

                height_data = recv_exact(s, 4)
                if not height_data:
                    break
                height = struct.unpack('>I', height_data)[0]

                data = recv_exact(s, size)
                if data is None:
                    break

                # We now *expect* proper I420
                expected = int(width * height * 1.5)
                if len(data) < expected:
                    print(f"Warning: got {len(data)} bytes, expected {expected}")
                    continue
                if len(data) > expected:
                    data = data[:expected]  # trim padding if any

                try:
                    yuv = np.frombuffer(data, dtype=np.uint8).reshape((height * 3 // 2, width))
                    bgr = cv2.cvtColor(yuv, cv2.COLOR_YUV2BGR_I420)

                    # yuv = np.frombuffer(data, dtype=np.uint8).reshape((height * 3 // 2, width))
                    # bgr = cv2.cvtColor(yuv, cv2.COLOR_YUV2BGR_I420)

                    # --- OPTIMIZATION START ---

                    # 2. CROP FIRST (Much Faster)
                    # We cut out the center square while it is still "sideways" (Landscape).
                    # This removes ~40% of the pixels we don't need before we do the heavy rotation.
                    h, w = bgr.shape[:2]
                    
                    if w > h:
                        # It's landscape (e.g., 1280x720), so we crop the center width
                        min_dim = h
                        center_x = w // 2
                        half_dim = min_dim // 2
                        
                        start_x = center_x - half_dim
                        end_x = center_x + half_dim
                        
                        # Crop the middle 720x720 chunk
                        bgr = bgr[:, start_x:end_x]
                        
                    # 3. ROTATE SECOND
                    # Now we only have to rotate a smaller square image.
                    bgr = cv2.rotate(bgr, cv2.ROTATE_90_CLOCKWISE)


                except Exception as e:
                    print(f"cv2 error on frame: {e}")
                    continue

                if cam is None:
                    print(f"Initializing Virtual Camera: {w}x{h} @ 30fps")
                    cam = pyvirtualcam.Camera(width=720, height=720, fps=30, fmt=PixelFormat.BGR)
                    print(f"Virtual Camera started: {cam.device}")
                    

                cam.send(bgr)
                cam.sleep_until_next_frame()
                            
                # Optional: Show preview
                cv2.imshow('Preview', bgr)
                if cv2.waitKey(1) & 0xFF == 27: break

            elif packet_type == 1: # Audio
                # Read Size (4 bytes)
                size_data = s.recv(4)
                if not size_data: break
                size = struct.unpack('>I', size_data)[0]
                
                # Read Data
                data = b''
                while len(data) < size:
                    packet = s.recv(size - len(data))
                    if not packet: break
                    data += packet
                
                if len(data) != size: break
                
                # Play Audio
                audio_stream.write(data)
            
            else:
                print(f"Unknown packet type: {packet_type}")
                # Try to recover?
                break

    except Exception as e:
        print(f"Error: {e}")
    finally:
        print("Cleaning up...")
        if cam: cam.close()
        audio_stream.stop_stream()
        audio_stream.close()
        p.terminate()
        s.close()
        cv2.destroyAllWindows()

if __name__ == '__main__':
    main()
