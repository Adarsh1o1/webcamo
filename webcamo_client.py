YOUR_PHONE_IP = "192.168.31.183"
import asyncio
import json
import websockets
import numpy as np
import pyvirtualcam

from aiortc import RTCPeerConnection, RTCSessionDescription


async def main():
    pc = RTCPeerConnection()

    async with websockets.connect(f"ws://{YOUR_PHONE_IP}:8080/ws") as ws:

        @pc.on("track")
        def on_track(track):
            print("✅ Receiving video stream...")
            cam = None

            async def process():
                nonlocal cam
                while True:
                    frame = await track.recv()
                    img = frame.to_ndarray(format="bgr24")

                    if cam is None:
                        cam = pyvirtualcam.Camera(
                            width=img.shape[1],
                            height=img.shape[0],
                            fps=30,
                            print_fps=True
                        )

                    cam.send(img)
                    cam.sleep_until_next_frame()

            asyncio.ensure_future(process())

        # Receive OFFER (from phone)
        offer_json = await ws.recv()
        offer = json.loads(offer_json)
        await pc.setRemoteDescription(
            RTCSessionDescription(offer["sdp"], offer["type"])
        )

        # Create and send ANSWER
        answer = await pc.createAnswer()
        await pc.setLocalDescription(answer)
        await ws.send(json.dumps({
            "type": answer.type,
            "sdp": answer.sdp
        }))

        # Handle ICE candidates
        while True:
            message = await ws.recv()
            data = json.loads(message)

            if data.get("type") == "candidate" and data.get("candidate"):
                await pc.addIceCandidate(data["candidate"])


asyncio.run(main())
