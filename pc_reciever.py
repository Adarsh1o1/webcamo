import socket
import av
import cv2
import sys

HOST = '127.0.0.1'  # This means you MUST use 'adb reverse'
PORT = 23233        # Make sure this matches the port in your Android app

print("Connecting to Android device...")

try:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.connect((HOST, PORT))
    print("Connected!")
except ConnectionRefusedError:
    print(f"Connection failed. Did you forget to run 'adb reverse tcp:{PORT} tcp:{PORT}'?")
    sys.exit(1)


# Turn the socket into a file-like object
# pyav will read from this just like a file
fileobj = s.makefile('rb')

try:
    # 'h264' is the format hint for the raw stream
    with av.open(fileobj, 'r', format='h264') as container:
        print("Opened video stream. Waiting for frames...")
        
        # We decode the first (and only) video stream
        for frame in container.decode(video=0):
            # Convert the frame to a NumPy array for OpenCV
            img = frame.to_ndarray(format='bgr24')
            
            # print(f"Displaying frame: {frame.pts} (Size: {frame.width}x{frame.height})")

            cv2.imshow('Phone Camera Stream', img)
            
            # Exit on 'ESC' key
            if cv2.waitKey(1) & 0xFF == 27:
                break

except av.error.EOFError:
    print("End of stream.")
except KeyboardInterrupt:
    print("Stream stopped by user.")
except Exception as e:
    print(f"An error occurred: {e}")
finally:
    print("Cleaning up...")
    fileobj.close()
    s.close()
    cv2.destroyAllWindows()