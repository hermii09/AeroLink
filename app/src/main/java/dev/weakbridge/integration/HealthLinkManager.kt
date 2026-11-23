package dev.weakbridge.integration

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.pm.PackageManager
import android.os.ParcelUuid
import androidx.core.content.ContextCompat
import dev.weakbridge.BridgeSettings
import dev.weakbridge.ble.BleConnectionManager
import dev.weakbridge.ble.GattTransport
import dev.weakbridge.diagnostics.BridgeDiagnostics
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** Maintains the second, app-owned BLE link used only for Apple Health samples. */
@SuppressLint("MissingPermission")
class HealthLinkManager(
    context: Context,
    private val scope: CoroutineScope,
    settings: BridgeSettings,
) {
    private val appContext = context.applicationContext
    private val bluetooth = appContext.getSystemService(BluetoothManager::class.java)
    private val diagnostics = BridgeDiagnostics(settings)
    private var running = false
    private var scan: ScanCallback? = null
    private var scanTimeout: Job? = null
    private var retry: Job? = null
    private var connection: BleConnectionManager? = null
    private var sync: HealthStepSync? = null
    private var generation = 0L

    fun start() {
        if (running) return
        running = true
        scanForReceiver()
    }

    fun stop() {
        running = false
        generation++
        retry?.cancel()
        retry = null
        scanTimeout?.cancel()
        scanTimeout = null
        stopScan()
        sync?.stop()
        sync = null
        connection?.close()
        connection = null
    }

    private fun scanForReceiver() {
        if (!running || connection != null || scan != null) return
        if (ContextCompat.checkSelfPermission(appContext, Manifest.permission.BLUETOOTH_SCAN)
            != PackageManager.PERMISSION_GRANTED
        ) {
            retryScan()
            return
        }
        val scanner = bluetooth.adapter?.bluetoothLeScanner ?: run {
            retryScan()
            return
        }
        val scanGeneration = ++generation
        val callback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                if (!running || scan !== this || scanGeneration != generation) return
                stopScan()
                connect(result.device)
            }

            override fun onScanFailed(errorCode: Int) {
                if (scan === this) {
                    stopScan()
                    retryScan()
                }
            }
        }
        scan = callback
        try {
            scanner.startScan(
                listOf(ScanFilter.Builder().setServiceUuid(ParcelUuid(HealthStepSync.SERVICE)).build()),
                ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_POWER).build(),
                callback,
            )
            scanTimeout = scope.launch {
                delay(SCAN_WINDOW_MS)
                if (scan === callback) {
                    stopScan()
                    retryScan()
                }
            }
        } catch (_: SecurityException) {
            stopScan()
            retryScan()
        }
    }

    private fun connect(device: BluetoothDevice) {
        if (!running || connection != null) return
        lateinit var link: BleConnectionManager
        link = BleConnectionManager(
            appContext,
            scope,
            diagnostics,
            onLink = { transport -> initialize(link, transport) },
            onValue = { _, _ -> Unit },
            onLost = { lost(link) },
            onServiceChanged = { lost(link) },
        )
        connection = link
        try {
            link.connect(device, passive = false)
        } catch (_: SecurityException) {
            link.close()
            if (connection === link) connection = null
            retryScan()
        }
    }

    private suspend fun initialize(link: BleConnectionManager, transport: GattTransport) {
        if (!running || connection !== link) return
        transport.discover()
        if (!transport.has(HealthStepSync.SERVICE, HealthStepSync.READING)) {
            link.close()
            if (connection === link) connection = null
            retryScan()
            return
        }
        if (!running || connection !== link) return
        sync?.stop()
        sync = HealthStepSync(appContext, scope, transport).also { it.start() }
    }

    private fun lost(link: BleConnectionManager) {
        if (connection !== link) return
        sync?.stop()
        sync = null
        connection?.close()
        connection = null
        retryScan()
    }

    private fun retryScan() {
        if (!running || retry?.isActive == true) return
        retry = scope.launch {
            delay(RETRY_DELAY_MS)
            scanForReceiver()
        }
    }

    private fun stopScan() {
        scanTimeout?.cancel()
        scanTimeout = null
        val callback = scan ?: return
        scan = null
        runCatching { bluetooth.adapter?.bluetoothLeScanner?.stopScan(callback) }
    }

    companion object {
        private const val SCAN_WINDOW_MS = 15_000L
        private const val RETRY_DELAY_MS = 15_000L
    }
}
