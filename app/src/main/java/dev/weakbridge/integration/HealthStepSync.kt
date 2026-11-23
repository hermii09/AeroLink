package dev.weakbridge.integration

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.SystemClock
import androidx.core.content.ContextCompat
import dev.weakbridge.ble.GattTransport
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.UUID
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import org.json.JSONObject

/** Sends step-count intervals to the paired iPhone only when its HealthKit GATT endpoint exists. */
class HealthStepSync(
    context: Context,
    private val scope: CoroutineScope,
    private val transport: GattTransport,
) : SensorEventListener {
    private val appContext = context.applicationContext
    private val sensorManager = appContext.getSystemService(SensorManager::class.java)
    private val preferences = appContext.getSharedPreferences("health-sync", Context.MODE_PRIVATE)
    private val sensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
    private var latestTotal: Long? = null
    private var sampler: Job? = null
    private var sendJob: Job? = null

    fun start() {
        if (ContextCompat.checkSelfPermission(appContext, Manifest.permission.ACTIVITY_RECOGNITION)
            != PackageManager.PERMISSION_GRANTED || sensor == null
        ) return
        sendPending()
        sensorManager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL)
        sampler?.cancel()
        sampler = scope.launch {
            while (isActive) {
                delay(SYNC_INTERVAL_MS)
                flush()
            }
        }
    }

    fun stop() {
        sampler?.cancel()
        sampler = null
        sensorManager.unregisterListener(this)
        // A pending sample is intentionally kept on disk and retried after reconnect.
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type != Sensor.TYPE_STEP_COUNTER || event.values.isEmpty()) return
        latestTotal = event.values[0].toLong().coerceAtLeast(0)
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    private fun flush() {
        val current = latestTotal ?: return
        val last = preferences.getLong(KEY_TOTAL, -1L)
        val end = System.currentTimeMillis()
        if (last < 0L) {
            // Establish a clean baseline at opt-in; do not import an unknown lifetime count.
            preferences.edit().putLong(KEY_TOTAL, current).putLong(KEY_TIME, end).apply()
            return
        }
        if (current < last) {
            // Step counter resets after reboot. Start a new baseline instead of creating a huge delta.
            preferences.edit().putLong(KEY_TOTAL, current).putLong(KEY_TIME, end).apply()
            return
        }
        if (current == last || preferences.contains(KEY_PENDING)) {
            if (preferences.contains(KEY_PENDING)) sendPending()
            return
        }
        val count = current - last
        val start = preferences.getLong(KEY_TIME, end)
        val eventId = UUID.randomUUID().toString()
        val reading = JSONObject()
            .put("eventID", eventId)
            .put("metric", "steps")
            .put("value", count)
            .put("unit", "count")
            .put("start", start)
            .put("end", end)
            .put("targetTotal", current)
        preferences.edit().putString(KEY_PENDING, reading.toString()).apply()
        sendPending()
    }

    private fun sendPending() {
        if (sendJob?.isActive == true) return
        val pending = preferences.getString(KEY_PENDING, null) ?: return
        val reading = runCatching { JSONObject(pending) }.getOrNull() ?: return
        val payload = JSONObject(pending).apply { remove("targetTotal") }.toString().toByteArray(Charsets.UTF_8)
        if (payload.isEmpty() || payload.size > MAX_MESSAGE_BYTES) return
        sendJob = scope.launch {
            try {
                val chunks = (payload.size + CHUNK_DATA_BYTES - 1) / CHUNK_DATA_BYTES
                val messageId = (SystemClock.elapsedRealtime().toInt() and 0xffff)
                for (index in 0 until chunks) {
                    val from = index * CHUNK_DATA_BYTES
                    val to = minOf(from + CHUNK_DATA_BYTES, payload.size)
                    val packet = ByteBuffer.allocate(HEADER_BYTES + (to - from))
                        .order(ByteOrder.BIG_ENDIAN)
                        .put(PROTOCOL_VERSION)
                        .putShort(messageId.toShort())
                        .put(index.toByte())
                        .put(chunks.toByte())
                        .put(payload, from, to - from)
                        .array()
                    transport.write(SERVICE, READING, packet)
                }
                preferences.edit()
                    .putLong(KEY_TOTAL, reading.getLong("targetTotal"))
                    .putLong(KEY_TIME, reading.getLong("end"))
                    .remove(KEY_PENDING)
                    .apply()
            } catch (_: Exception) {
                // Keep the exact event and identifier for safe retry after the next interval/reconnect.
            }
        }
    }

    companion object {
        val SERVICE: UUID = UUID.fromString("A3C5E000-4C8A-4D1E-9B3A-2E7C0D91A610")
        val READING: UUID = UUID.fromString("A3C5E001-4C8A-4D1E-9B3A-2E7C0D91A610")
        private const val PROTOCOL_VERSION: Byte = 1
        private const val HEADER_BYTES = 5
        private const val CHUNK_DATA_BYTES = 15 // 20-byte ATT value for the default MTU.
        private const val MAX_MESSAGE_BYTES = 512
        private const val SYNC_INTERVAL_MS = 5 * 60 * 1000L
        private const val KEY_TOTAL = "last_step_total"
        private const val KEY_TIME = "last_step_time"
        private const val KEY_PENDING = "pending_step_reading"
    }
}
