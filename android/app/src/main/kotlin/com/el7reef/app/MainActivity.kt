package com.el7reef.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var prideVideoExportChannel: PrideVideoExportChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        prideVideoExportChannel =
            PrideVideoExportChannel(
                applicationContext,
                flutterEngine.dartExecutor.binaryMessenger,
            )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        prideVideoExportChannel?.dispose()
        prideVideoExportChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
