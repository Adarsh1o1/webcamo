package com.example.webcamo

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register our plugin manually
        CamstreamPlugin.registerWith(
            flutterEngine.dartExecutor.binaryMessenger,
            this
        )
    }
}
