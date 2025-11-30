package com.smarttutor

import android.app.ActivityManager
import android.content.Context
import android.os.BatteryManager
import android.os.Build
import android.os.Debug
import android.os.Process
import android.os.SystemClock
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.max
import kotlin.math.min

class PerformancePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val segments = ConcurrentHashMap<String, Segment>()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        segments.clear()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startSegment" -> handleStart(call, result)
            "endSegment" -> handleEnd(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleStart(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id")
        if (id.isNullOrEmpty()) {
            result.error("invalid_args", "Segment id is required", null)
            return
        }

        val segment = Segment(
            startTimeNs = SystemClock.elapsedRealtimeNanos(),
            startCpuTimeMs = Process.getElapsedCpuTime(),
            startBatteryLevel = currentBatteryLevel(),
            startCpuStat = readCpuStat()
        )
        segments[id] = segment
        result.success(null)
    }

    private fun handleEnd(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id")
        if (id.isNullOrEmpty()) {
            result.error("invalid_args", "Segment id is required", null)
            return
        }

        val segment = segments.remove(id)
        if (segment == null) {
            result.error("segment_missing", "Segment $id was not started", null)
            return
        }

        val durationMs =
            ((SystemClock.elapsedRealtimeNanos() - segment.startTimeNs) / 1_000_000).coerceAtLeast(0)
        val batteryLevel = currentBatteryLevel()
        val batteryDelta = if (segment.startBatteryLevel >= 0 && batteryLevel >= 0) {
            batteryLevel - segment.startBatteryLevel
        } else {
            null
        }

        val cpuUsage = calculateCpuUsage(
            segment.startCpuTimeMs,
            Process.getElapsedCpuTime(),
            durationMs
        )
        val systemCpu = calculateSystemCpuUsage(segment.startCpuStat, readCpuStat())
        val memoryUsage = memoryUsageMb()

        val response = mutableMapOf<String, Any>(
            "durationMs" to durationMs,
            "batteryLevel" to batteryLevel,
            "cpuUsage" to cpuUsage,
            "memoryUsageMb" to memoryUsage
        )

        val notes = mutableListOf<String>()
        if (batteryDelta != null && batteryDelta != 0) {
            notes.add("batteryDelta=$batteryDelta")
        }
        if (systemCpu != null) {
            notes.add("systemCpu=${"%.2f".format(systemCpu)}")
        }
        if (notes.isNotEmpty()) {
            response["notes"] = notes.joinToString("; ")
        }

        result.success(response)
    }

    private fun calculateCpuUsage(
        startCpuMs: Long,
        endCpuMs: Long,
        durationMs: Long
    ): Double {
        if (durationMs <= 0) return 0.0
        val delta = max(endCpuMs - startCpuMs, 0L).toDouble()
        val cores = max(Runtime.getRuntime().availableProcessors(), 1)
        val percentage = (delta / durationMs) * 100.0 / cores
        return percentage.coerceIn(0.0, 100.0)
    }

    private fun currentBatteryLevel(): Int {
        val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
            ?: return -1
        val level = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        return if (level == Int.MIN_VALUE) -1 else level
    }

    private fun memoryUsageMb(): Double {
        val activityManager =
            context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager ?: return 0.0
        val info: Debug.MemoryInfo = activityManager.getProcessMemoryInfo(intArrayOf(Process.myPid()))
            .firstOrNull() ?: return 0.0
        return info.totalPss.toDouble() / 1024.0
    }

    private fun readCpuStat(): CpuStat? {
        return try {
            val reader = java.io.RandomAccessFile("/proc/stat", "r")
            val load = reader.readLine()
            reader.close()
            val tokens = load.split(" ").filter { it.isNotEmpty() }
            if (tokens.size < 5) return null
            CpuStat(
                user = tokens[1].toLong(),
                nice = tokens[2].toLong(),
                system = tokens[3].toLong(),
                idle = tokens[4].toLong()
            )
        } catch (_: Exception) {
            null
        }
    }

    private fun calculateSystemCpuUsage(start: CpuStat?, end: CpuStat?): Double? {
        if (start == null || end == null) return null
        val startIdle = start.idle
        val endIdle = end.idle
        val startTotal = start.total
        val endTotal = end.total
        val totalDelta = endTotal - startTotal
        if (totalDelta <= 0) return null
        val idleDelta = endIdle - startIdle
        val usage = (totalDelta - idleDelta).toDouble() / totalDelta.toDouble() * 100.0
        return usage.coerceIn(0.0, 100.0)
    }

    private data class Segment(
        val startTimeNs: Long,
        val startCpuTimeMs: Long,
        val startBatteryLevel: Int,
        val startCpuStat: CpuStat?
    )

    private data class CpuStat(
        val user: Long,
        val nice: Long,
        val system: Long,
        val idle: Long
    ) {
        val total: Long
            get() = user + nice + system + idle
    }

    companion object {
        private const val CHANNEL_NAME = "smart_tutor_lite/performance"
    }
}


