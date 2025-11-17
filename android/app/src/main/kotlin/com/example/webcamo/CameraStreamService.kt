package com.example.webcamo

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.graphics.SurfaceTexture
import android.hardware.camera2.*
import android.hardware.camera2.params.StreamConfigurationMap
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.os.*
import android.util.Log
import android.util.Range
import android.util.Size
import android.view.Surface
import androidx.core.app.NotificationCompat
import java.io.OutputStream
import java.net.ServerSocket
import java.net.Socket
import java.nio.ByteBuffer
import kotlin.concurrent.thread

class CameraStreamService : Service() {

    companion object {
        var serviceRunningState: String = "stopped"
        private const val TAG = "CamStream"
    }

    // Encoder related
    private var encoder: MediaCodec? = null
    private var encoderSurface: Surface? = null

    // Camera related
    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private lateinit var cameraManager: CameraManager

    // Server socket thread
    private var serverThread: Thread? = null
    private var serverSocket: ServerSocket? = null
    private var clientSocket: Socket? = null

    // Dummy preview surface (some HALs require a preview target)
    private var dummySurfaceTexture: SurfaceTexture? = null
    private var dummySurface: Surface? = null

    // Camera thread/handler to avoid UI thread usage
    private var cameraThread: HandlerThread? = null
    private var cameraHandler: Handler? = null

    override fun onBind(intent: Intent?) = null

    override fun onCreate() {
        super.onCreate()
        cameraManager = getSystemService(CAMERA_SERVICE) as CameraManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        if (action == "STOP") {
            stopSelf()
            return START_NOT_STICKY
        }

        val port = intent?.getIntExtra("port", 23233) ?: 23233
        val desiredWidth = intent?.getIntExtra("width", 1280) ?: 1280
        val desiredHeight = intent?.getIntExtra("height", 720) ?: 720
        val desiredFps = intent?.getIntExtra("fps", 30) ?: 30
        val bitrate = intent?.getIntExtra("bitrate", 2000000) ?: 2000000

        startForegroundNotification()
        startCameraStream(port, desiredWidth, desiredHeight, desiredFps, bitrate)

        return START_STICKY
    }

    private fun startForegroundNotification() {
        val channelId = "camstream_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val chan =
                NotificationChannel(
                    channelId,
                    "Camera Stream",
                    NotificationManager.IMPORTANCE_LOW
                )
            (getSystemService(NotificationManager::class.java)).createNotificationChannel(chan)
        }
        val notification: Notification =
            NotificationCompat.Builder(this, channelId)
                .setContentTitle("Camera Stream Running")
                .setContentText("Streaming camera to PC...")
                .setSmallIcon(android.R.drawable.ic_menu_camera)
                .build()
        startForeground(1, notification)
    }

    private fun startCameraStream(
        port: Int,
        desiredWidth: Int,
        desiredHeight: Int,
        desiredFps: Int,
        bitrate: Int
    ) {
        serviceRunningState = "running"

        val cameraId: String
        val actualSize: Size
        val actualFpsRange: Range<Int>

        try {
            cameraId = cameraManager.cameraIdList.firstOrNull { id ->
                val chars = cameraManager.getCameraCharacteristics(id)
                chars.get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_BACK
            } ?: cameraManager.cameraIdList[0]

            val characteristics = cameraManager.getCameraCharacteristics(cameraId)
            val map = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
            if (map == null) {
                Log.e(TAG, "Cannot get StreamConfigurationMap. Aborting.")
                stopSelf()
                return
            }

            actualSize = selectOptimalSize(map, desiredWidth, desiredHeight)
            actualFpsRange = selectOptimalFpsRange(characteristics, desiredFps)

        } catch (e: Exception) {
            Log.e(TAG, "Failed to query camera specs: ${e.message}", e)
            stopSelf()
            return
        }

        Log.d(TAG, "Configuring encoder: ${actualSize.width}x${actualSize.height} @${actualFpsRange}fps, bitrate=$bitrate")

        val format = MediaFormat.createVideoFormat("video/avc", actualSize.width, actualSize.height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, bitrate)
            setInteger(MediaFormat.KEY_FRAME_RATE, actualFpsRange.upper)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }
        // DO NOT force profile/level — many devices reject these.

        try {
            encoder = MediaCodec.createEncoderByType("video/avc")
            encoder!!.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            encoderSurface = encoder!!.createInputSurface()
            encoder!!.start()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to configure/start encoder: ${e.message}", e)
            stopSelf()
            return
        }

        startSocketServer(port)

        cameraThread = HandlerThread("CameraThread")
        cameraThread?.start()
        cameraHandler = Handler(cameraThread!!.looper)

        openCamera(cameraId, actualSize, actualFpsRange)
    }

    private fun selectOptimalSize(map: StreamConfigurationMap, desiredWidth: Int, desiredHeight: Int): Size {
        // Use SurfaceTexture sizes which better match encoder/Surface paths on many devices
        val supportedSizes = map.getOutputSizes(SurfaceTexture::class.java) ?: return Size(640, 480)

        Log.d(TAG, "Supported sizes for SurfaceTexture/encoder: ")
        supportedSizes.forEach { Log.d(TAG, "  ${it.width}x${it.height}") }

        for (size in supportedSizes) {
            if (size.width == desiredWidth && size.height == desiredHeight) {
                Log.i(TAG, "Found exact match: $size")
                return size
            }
        }

        val aspect16_9 = supportedSizes.filter {
            val a = it.width.toDouble() / it.height.toDouble()
            a in 1.75..1.79
        }.maxByOrNull { it.width * it.height }

        if (aspect16_9 != null) {
            Log.w(TAG, "No exact match for ${desiredWidth}x${desiredHeight}. Using largest 16:9: $aspect16_9")
            return aspect16_9
        }

        val largest = supportedSizes.maxByOrNull { it.width * it.height }
        if (largest != null) {
            Log.w(TAG, "No 16:9. Using largest available: $largest")
            return largest
        }

        Log.e(TAG, "No supported sizes! Using 640x480")
        return Size(640, 480)
    }

    private fun selectOptimalFpsRange(chars: CameraCharacteristics, desiredFps: Int): Range<Int> {
        val supportedRanges = chars.get(CameraCharacteristics.CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES)

        if (supportedRanges.isNullOrEmpty()) {
            Log.e(TAG, "No FPS ranges supported! Using 30-30")
            return Range(desiredFps, desiredFps)
        }

        val suitableRanges = supportedRanges.filter { it.upper == desiredFps }

        var bestRange: Range<Int>? = null

        if (suitableRanges.isNotEmpty()) {
            bestRange = suitableRanges.minByOrNull { it.lower }
        }

        if (bestRange != null) {
            Log.w(TAG, "Using best flexible FPS range: $bestRange")
            return bestRange
        }

        val bestOverall = supportedRanges.maxByOrNull { it.upper }
        if (bestOverall != null) {
            Log.w(TAG, "No range hits $desiredFps. Using highest available: $bestOverall")
            return bestOverall
        }

        Log.e(TAG, "Could not find any suitable FPS range. Using first available.")
        return supportedRanges[0]
    }

    private fun startSocketServer(port: Int) {
        serverThread = thread {
            try {
                Log.d(TAG, "Server thread started")
                val serverSocket = ServerSocket(port)
                Log.d(TAG, "ServerSocket created on port: $port")

                while (!Thread.interrupted()) {
                    Log.d(TAG, "Waiting for client...")
                    val client = serverSocket.accept()
                    Log.d(TAG, "Client connected!")
                    val out = client.getOutputStream()
                    Log.d(TAG, "Calling streamEncoderOutput()…")
                    streamEncoderOutput(out)
                    Log.d(TAG, "streamEncoderOutput() returned!")

                    try { client.close() } catch (_: Exception) {}
                }
            } catch (e: Exception) {
                if (!Thread.interrupted()) {
                    Log.e(TAG, "Server error: ${e.message}", e)
                }
            } finally {
                Log.d(TAG, "Closing sockets...")
                try { clientSocket?.close() } catch (_: Exception) {}
                try { serverSocket?.close() } catch (_: Exception) {}
                clientSocket = null
                serverSocket = null
            }
        }
    }

    private fun streamEncoderOutput(out: OutputStream) {
        Log.d(TAG, "streamEncoderOutput() started")
        val codec = encoder ?: run {
            Log.e(TAG, "streamEncoderOutput: encoder == null")
            return
        }
        val info = MediaCodec.BufferInfo()
        var spsPpsSent = false
        var noOutputCounter = 0

        try {
            while (!Thread.interrupted()) {
                val outIndex = codec.dequeueOutputBuffer(info, 100000)
                when {
                    outIndex >= 0 -> {
                        val encodedBuffer: ByteBuffer = codec.getOutputBuffer(outIndex)!!
                        encodedBuffer.position(info.offset)
                        encodedBuffer.limit(info.offset + info.size)

                        val bytes = ByteArray(info.size)
                        if (info.size > 0) {
                            encodedBuffer.get(bytes, 0, info.size)
                            out.write(bytes)
                            out.flush()
                        } else {
                            Log.d(TAG, "Got zero-size output buffer (flags=${info.flags})")
                        }

                        codec.releaseOutputBuffer(outIndex, false)
                        noOutputCounter = 0
                    }

                    outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        Log.d(TAG, "INFO_OUTPUT_FORMAT_CHANGED")
                        try {
                            val outFormat = codec.outputFormat
                            val csd0 = outFormat.getByteBuffer("csd-0")
                            val csd1 = outFormat.getByteBuffer("csd-1")
                            if (!spsPpsSent) {
                                csd0?.let {
                                    val h = ByteArray(it.remaining())
                                    it.get(h)
                                    out.write(h)
                                    Log.d(TAG, "Wrote csd-0 size=${h.size}")
                                }
                                csd1?.let {
                                    val h = ByteArray(it.remaining())
                                    it.get(h)
                                    out.write(h)
                                    Log.d(TAG, "Wrote csd-1 size=${h.size}")
                                }
                                out.flush()
                                spsPpsSent = true
                                Log.d(TAG, "SPS/PPS sent")
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to extract/send csd: ${e.message}", e)
                        }
                    }

                    outIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                        noOutputCounter++
                        if (noOutputCounter > 50) {
                            Log.d(TAG, "INFO_TRY_AGAIN_LATER (no output yet) count=$noOutputCounter")
                            noOutputCounter = 0
                        }
                    }

                    else -> {
                        Log.w(TAG, "Unknown dequeueOutputBuffer return: $outIndex")
                    }
                }
            }
        } catch (ie: InterruptedException) {
            Log.i(TAG, "streamEncoderOutput interrupted")
        } catch (e: Exception) {
            Log.e(TAG, "Encoder stream error (client likely disconnected): ${e.message}")
        } finally {
            Log.d(TAG, "Encoder stream loop exiting")
        }
    }

    private fun openCamera(cameraId: String, size: Size, fpsRange: Range<Int>) {
        try {
            if (checkSelfPermission(android.Manifest.permission.CAMERA) !=
                android.content.pm.PackageManager.PERMISSION_GRANTED
            ) {
                Log.e(TAG, "Camera permission NOT granted")
                stopSelf()
                return
            }

            cameraManager.openCamera(
                cameraId,
                object : CameraDevice.StateCallback() {
                    override fun onOpened(camera: CameraDevice) {
                        cameraDevice = camera
                        try {
                            Log.d(TAG, "openCamera using width=${size.width} height=${size.height}")

                            // Build request for RECORD (encoder) use-case
                            val request = camera.createCaptureRequest(CameraDevice.TEMPLATE_RECORD)
                            request.addTarget(encoderSurface!!)

                            // Controls — keep AE/AWB/AF automatic
                            request.set(CaptureRequest.CONTROL_MODE, CaptureRequest.CONTROL_MODE_AUTO)
                            request.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_VIDEO)
                            request.set(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, fpsRange)

                            // NOTE: Do NOT set CONTROL_VIDEO_STABILIZATION_MODE on some Samsung devices

                            // Create a small dummy preview surface to satisfy strict HALs
                            try {
                                dummySurfaceTexture = SurfaceTexture(11)
                                dummySurfaceTexture?.setDefaultBufferSize(size.width, size.height)
                                dummySurface = Surface(dummySurfaceTexture)
                            } catch (e: Exception) {
                                Log.w(TAG, "Failed to create dummy preview surface: ${e.message}")
                                dummySurface = null
                                dummySurfaceTexture = null
                            }

                            val targets = mutableListOf<Surface>()
                            encoderSurface?.let { targets.add(it) }
                            dummySurface?.let { targets.add(it) }

                            camera.createCaptureSession(
                                targets,
                                object : CameraCaptureSession.StateCallback() {
                                    override fun onConfigured(session: CameraCaptureSession) {
                                        val surf = encoderSurface
                                        Log.d(TAG, "Encoder surface = $surf")

                                        captureSession = session
                                        Log.d(TAG, "Capture session configured!")
                                        try {
                                            session.setRepeatingRequest(
                                                request.build(),
                                                object : CameraCaptureSession.CaptureCallback() {
                                                    override fun onCaptureFailed(
                                                        session: CameraCaptureSession,
                                                        request: CaptureRequest,
                                                        failure: CaptureFailure
                                                    ) {
                                                        Log.e(TAG, "Capture failed: ${failure.reason}, seq=${failure.sequenceId}")
                                                    }
                                                },
                                                cameraHandler
                                            )
                                        } catch (e: Exception) {
                                            Log.e(TAG, "Failed to setRepeatingRequest: ${e.message}", e)
                                        }
                                    }

                                    override fun onConfigureFailed(session: CameraCaptureSession) {
                                        Log.e(TAG, "Capture session configuration failed")
                                    }
                                },
                                cameraHandler
                            )
                        } catch (e: Exception) {
                            Log.e(TAG, "openCamera -> setup failed: ${e.message}", e)
                            camera.close()
                            cameraDevice = null
                        }
                    }

                    override fun onDisconnected(camera: CameraDevice) {
                        Log.d(TAG, "Camera disconnected")
                        camera.close()
                        cameraDevice = null
                    }

                    override fun onError(camera: CameraDevice, error: Int) {
                        Log.e(TAG, "Camera error: $error")
                        camera.close()
                        cameraDevice = null
                    }
                },
                cameraHandler
            )
        } catch (e: Exception) {
            Log.e(TAG, "openCamera exception: ${e.message}", e)
        }
    }

    override fun onDestroy() {
        serviceRunningState = "stopped"
        Log.d(TAG, "Service onDestroy - cleaning up")

        try { serverThread?.interrupt() } catch (_: Exception) {}
        serverThread = null
        try { captureSession?.close() } catch (_: Exception) {}
        try { cameraDevice?.close() } catch (_: Exception) {}
        try { encoder?.stop(); encoder?.release() } catch (_: Exception) {}
        try { dummySurface?.release() } catch (_: Exception) {}
        try { dummySurfaceTexture?.release() } catch (_: Exception) {}
        dummySurface = null
        dummySurfaceTexture = null
        try { cameraThread?.quitSafely() } catch (_: Exception) {}
        cameraHandler = null
        cameraThread = null
        super.onDestroy()
    }
}
