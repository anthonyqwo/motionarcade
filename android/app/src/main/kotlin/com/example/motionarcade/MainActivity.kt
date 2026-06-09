package com.example.motionarcade

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "motionarcade/fused_motion"
        ).setStreamHandler(FusedMotionStreamHandler(this))

        io.flutter.plugin.common.MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "motionarcade/haptics"
        ).setMethodCallHandler { call, result ->
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as android.os.Vibrator
            if (call.method == "play") {
                val intensity = call.argument<Double>("intensity") ?: 0.5
                val sharpness = call.argument<Double>("sharpness") ?: 0.5
                val duration = call.argument<Double>("duration") ?: 0.1

                val durationMs = (duration * 1000).toLong().coerceAtLeast(10)
                val amplitude = (intensity * 255).toInt().coerceIn(1, 255)

                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    if (vibrator.hasAmplitudeControl()) {
                        vibrator.vibrate(android.os.VibrationEffect.createOneShot(durationMs, amplitude))
                    } else {
                        vibrator.vibrate(android.os.VibrationEffect.createOneShot(durationMs, android.os.VibrationEffect.DEFAULT_AMPLITUDE))
                    }
                } else {
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(durationMs)
                }
                result.success(null)
            } else if (call.method == "playPattern") {
                val pattern = call.argument<List<Map<String, Any>>>("pattern")
                if (pattern != null && pattern.isNotEmpty()) {
                    val handler = Handler(Looper.getMainLooper())
                    for (step in pattern) {
                        val typeStr = step["type"] as? String ?: "transient"
                        val time = step["time"] as? Double ?: 0.0
                        val stepDuration = step["duration"] as? Double ?: 0.1
                        val stepIntensity = step["intensity"] as? Double ?: 1.0

                        val timeMs = (time * 1000).toLong()
                        val stepDurationMs = (stepDuration * 1000).toLong().coerceAtLeast(10)
                        val stepAmp = (stepIntensity * 255).toInt().coerceIn(1, 255)

                        handler.postDelayed({
                            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                                if (vibrator.hasAmplitudeControl()) {
                                    vibrator.vibrate(android.os.VibrationEffect.createOneShot(stepDurationMs, stepAmp))
                                } else {
                                    vibrator.vibrate(android.os.VibrationEffect.createOneShot(stepDurationMs, android.os.VibrationEffect.DEFAULT_AMPLITUDE))
                                }
                            } else {
                                @Suppress("DEPRECATION")
                                vibrator.vibrate(stepDurationMs)
                            }
                        }, timeMs)
                    }
                } else {
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        vibrator.vibrate(android.os.VibrationEffect.createOneShot(80, android.os.VibrationEffect.DEFAULT_AMPLITUDE))
                    } else {
                        @Suppress("DEPRECATION")
                        vibrator.vibrate(80)
                    }
                }
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }
}

private class FusedMotionStreamHandler(
    context: Context
) : EventChannel.StreamHandler, SensorEventListener {
    private val sensorManager =
        context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null

    private var hasAttitude = false
    private var hasLinearAcceleration = false
    private val attitude = FloatArray(4) { index -> if (index == 0) 1f else 0f }
    private val gravity = FloatArray(3)
    private val linearAcceleration = FloatArray(3)
    private val rotationRate = FloatArray(3)

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        val rotationVector = sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
        val linear = sensorManager.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION)
        val gyroscope = sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE)
        val gravitySensor = sensorManager.getDefaultSensor(Sensor.TYPE_GRAVITY)

        if (rotationVector == null || linear == null) {
            events?.error(
                "fused_motion_unavailable",
                "Rotation vector or linear acceleration sensor is unavailable.",
                null
            )
            eventSink = null
            return
        }

        sensorManager.registerListener(this, rotationVector, SensorManager.SENSOR_DELAY_GAME)
        sensorManager.registerListener(this, linear, SensorManager.SENSOR_DELAY_GAME)
        if (gyroscope != null) {
            sensorManager.registerListener(this, gyroscope, SensorManager.SENSOR_DELAY_GAME)
        }
        if (gravitySensor != null) {
            sensorManager.registerListener(this, gravitySensor, SensorManager.SENSOR_DELAY_GAME)
        }
    }

    override fun onCancel(arguments: Any?) {
        sensorManager.unregisterListener(this)
        eventSink = null
        hasAttitude = false
        hasLinearAcceleration = false
    }

    override fun onSensorChanged(event: SensorEvent) {
        when (event.sensor.type) {
            Sensor.TYPE_ROTATION_VECTOR -> {
                SensorManager.getQuaternionFromVector(attitude, event.values)
                hasAttitude = true
            }
            Sensor.TYPE_LINEAR_ACCELERATION -> {
                copyVector(event.values, linearAcceleration)
                hasLinearAcceleration = true
            }
            Sensor.TYPE_GYROSCOPE -> copyVector(event.values, rotationRate)
            Sensor.TYPE_GRAVITY -> copyVector(event.values, gravity)
        }

        if (hasAttitude && hasLinearAcceleration) {
            emitSample()
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    private fun emitSample() {
        val payload = mapOf(
            "attitudeX" to attitude[1].toDouble(),
            "attitudeY" to attitude[2].toDouble(),
            "attitudeZ" to attitude[3].toDouble(),
            "attitudeW" to attitude[0].toDouble(),
            "gravityX" to gravity[0].toDouble(),
            "gravityY" to gravity[1].toDouble(),
            "gravityZ" to gravity[2].toDouble(),
            "userAccelerationX" to linearAcceleration[0].toDouble(),
            "userAccelerationY" to linearAcceleration[1].toDouble(),
            "userAccelerationZ" to linearAcceleration[2].toDouble(),
            "rotationRateX" to rotationRate[0].toDouble(),
            "rotationRateY" to rotationRate[1].toDouble(),
            "rotationRateZ" to rotationRate[2].toDouble(),
            "timestampMillis" to System.currentTimeMillis().toDouble(),
            "source" to "android_rotation_vector",
            "isAvailable" to true
        )
        mainHandler.post { eventSink?.success(payload) }
    }

    private fun copyVector(source: FloatArray, target: FloatArray) {
        target[0] = source.getOrElse(0) { 0f }
        target[1] = source.getOrElse(1) { 0f }
        target[2] = source.getOrElse(2) { 0f }
    }
}
