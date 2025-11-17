package com.example.webcamo

import android.content.Context
import android.content.Intent
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.BinaryMessenger

class CamstreamPlugin private constructor(
    private val context: Context
) : MethodChannel.MethodCallHandler {

    companion object {
        @JvmStatic
        fun registerWith(messenger: BinaryMessenger, context: Context) {
            val channel = MethodChannel(messenger, "camstream_plugin")
            val instance = CamstreamPlugin(context.applicationContext)
            channel.setMethodCallHandler(instance)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {

            "start" -> {
                val args = call.arguments as Map<String, Any>

                val intent = Intent(context, CameraStreamService::class.java).apply {
                    action = "START"
                    putExtra("port", args["port"] as Int)
                    putExtra("width", args["width"] as Int)
                    putExtra("height", args["height"] as Int)
                    putExtra("fps", args["fps"] as Int)
                    putExtra("bitrate", args["bitrate"] as Int)
                }

                context.startForegroundService(intent)
                result.success(true)
            }

            "stop" -> {
                val intent = Intent(context, CameraStreamService::class.java).apply {
                    action = "STOP"
                }
                context.stopService(intent)
                result.success(true)
            }

            "status" -> {
                result.success(CameraStreamService.serviceRunningState)
            }

            else -> result.notImplemented()
        }
    }
}
