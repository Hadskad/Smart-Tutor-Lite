package com.example.smart_tutor_lite

import com.smarttutor.PerformancePlugin
import com.smarttutor.WhisperPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(WhisperPlugin())
        flutterEngine.plugins.add(PerformancePlugin())
    }
}
