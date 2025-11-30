package com.smarttutor;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

public class WhisperPlugin implements FlutterPlugin, MethodCallHandler {
    private static final String CHANNEL_NAME = "smart_tutor_lite/whisper";

    static {
        System.loadLibrary("whisper");
    }

    private MethodChannel channel;
    private long nativeContext = 0L;

    private native long nativeInitModel(String modelPath);
    private native String nativeTranscribe(long contextPtr, String audioPath);
    private native void nativeFree(long contextPtr);

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL_NAME);
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        if (channel != null) {
            channel.setMethodCallHandler(null);
            channel = null;
        }
        releaseNativeContext();
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        switch (call.method) {
            case "initModel":
                handleInit(call, result);
                break;
            case "transcribe":
                handleTranscribe(call, result);
                break;
            case "free":
                releaseNativeContext();
                result.success(null);
                break;
            default:
                result.notImplemented();
        }
    }

    private void handleInit(MethodCall call, Result result) {
        String modelPath = call.argument("modelPath");
        if (modelPath == null || modelPath.isEmpty()) {
            result.error("invalid_args", "modelPath is required", null);
            return;
        }
        releaseNativeContext();
        nativeContext = nativeInitModel(modelPath);
        result.success(nativeContext != 0L);
    }

    private void handleTranscribe(MethodCall call, Result result) {
        if (nativeContext == 0L) {
            result.error("not_initialized", "Call initModel before transcribe", null);
            return;
        }
        String audioPath = call.argument("audioPath");
        if (audioPath == null || audioPath.isEmpty()) {
            result.error("invalid_args", "audioPath is required", null);
            return;
        }
        try {
            String transcription = nativeTranscribe(nativeContext, audioPath);
            result.success(transcription);
        } catch (RuntimeException ex) {
            result.error("native_error", ex.getMessage(), null);
        }
    }

    private void releaseNativeContext() {
        if (nativeContext != 0L) {
            nativeFree(nativeContext);
            nativeContext = 0L;
        }
    }
}

