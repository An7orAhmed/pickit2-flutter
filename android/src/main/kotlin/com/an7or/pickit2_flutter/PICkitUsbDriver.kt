package com.an7or.pickit2_flutter

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.*
import android.os.Build
import android.util.Log
import java.io.IOException
import kotlin.math.max
import kotlin.math.min

class PICkitUsbDriver(private val context: Context) {
  private val TAG = "PICkitUsbDriver"
  private val ACTION_USB_PERMISSION = "com.an7or.pickit2_flutter.USB_PERMISSION"

  private val PICKIT2_VID = 0x04D8
  private val PICKIT2_PID = 0x0033

  private val usbManager: UsbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager
  private var pickitDevice: UsbDevice? = null
  private var connection: UsbDeviceConnection? = null
  private var endpointIn: UsbEndpoint? = null
  private var endpointOut: UsbEndpoint? = null
  private var usbInterface: UsbInterface? = null

  private val reqLen = 64
  private val usbTimeoutMs = 2000

  private val cmdSetVdd = 0xA0
  private val cmdSetVpp = 0xA1
  private val cmdExecuteScript = 0xA6
  private val cmdUploadData = 0xAA

  private val scmdVddOn = 0xFF
  private val scmdVddOff = 0xFE
  private val scmdMclrGndOn = 0xF7
  private val scmdMclrGndOff = 0xF6
  private val scmdSetIcspSpeed = 0xEA

  interface UsbCallback {
    fun onConnectionSuccess()
    fun onConnectionFailed(error: String)
  }

  private var currentCallback: UsbCallback? = null

  private val usbReceiver = object : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
      when (intent.action) {
        // 1. User plugged in a USB device
        UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
          val device: UsbDevice? = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
          device?.let {
            if (it.vendorId == PICKIT2_VID && it.productId == PICKIT2_PID) {
              Log.d(TAG, "PICkit 2 Attached! Auto-requesting permission...")
              pickitDevice = it
              requestPermission() // Automatically trigger the popup
            }
          }
        }

        // 2. User unplugged a USB device
        UsbManager.ACTION_USB_DEVICE_DETACHED -> {
          val device: UsbDevice? = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
          device?.let {
            if (it.vendorId == PICKIT2_VID && it.productId == PICKIT2_PID) {
              Log.d(TAG, "PICkit 2 Detached!")
              if (pickitDevice?.deviceId == it.deviceId) {
                pickitDevice = null
              }
              disconnect() // Clean up safely
            }
          }
        }

        // 3. User clicked Allow/Deny on the popup
        ACTION_USB_PERMISSION -> {
          synchronized(this) {
            val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
            if (granted) {
              Log.d(TAG, "Permission granted by user!")
              // We don't connect automatically, we wait for Flutter to call connect()
            } else {
              Log.e(TAG, "Permission denied by user.")
            }
          }
        }
      }
    }
  }

  init {
    // Register to listen for plug/unplug and permissions
    val filter = IntentFilter().apply {
      addAction(ACTION_USB_PERMISSION)
      addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
      addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
    }
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      context.registerReceiver(usbReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
    } else {
      context.registerReceiver(usbReceiver, filter)
    }

    // As soon as the app starts, check if it's ALREADY plugged in
    autoDetectIfAlreadyConnected()
  }

  private fun autoDetectIfAlreadyConnected() {
    for (device in usbManager.deviceList.values) {
      if (device.vendorId == PICKIT2_VID && device.productId == PICKIT2_PID) {
        pickitDevice = device
        Log.d(TAG, "PICkit 2 already plugged in on startup.")
        if (!usbManager.hasPermission(device)) {
          requestPermission()
        }
        return
      }
    }
  }

  private fun requestPermission() {
    if (pickitDevice == null) {
      pickitDevice = findPickitDevice()
    }
    pickitDevice?.let { device ->
      if (!usbManager.hasPermission(device)) {
        val pi = PendingIntent.getBroadcast(
          context, 0, Intent(ACTION_USB_PERMISSION), PendingIntent.FLAG_IMMUTABLE
        )
        usbManager.requestPermission(device, pi)
      }
    }
  }

  // Now called explicitly by Flutter, NOT automatically
  fun connect(callback: UsbCallback) {
    this.currentCallback = callback

    val device = findPickitDevice() ?: return replyError("PICkit 2 not found. Is it plugged in?")
    pickitDevice = device

    if (connection != null && endpointIn != null && endpointOut != null) {
      return replySuccess()
    }

    if (!usbManager.hasPermission(device)) {
      return replyError("USB Permission not granted yet. Please accept the popup.")
    }

    connection = usbManager.openDevice(device)
    if (connection == null) return replyError("Failed to open USB connection.")

    usbInterface = device.getInterface(0)
    if (connection?.claimInterface(usbInterface, true) != true) {
      return replyError("Failed to claim USB interface.")
    }

    usbInterface?.let { iface ->
      for (i in 0 until iface.endpointCount) {
        val ep = iface.getEndpoint(i)
        if (ep.type == UsbConstants.USB_ENDPOINT_XFER_INT) {
          if (ep.direction == UsbConstants.USB_DIR_IN) {
            endpointIn = ep
          } else if (ep.direction == UsbConstants.USB_DIR_OUT) {
            endpointOut = ep
          }
        }
      }
    }

    if (endpointIn != null && endpointOut != null) {
      Log.d(TAG, "Successfully connected and claimed endpoints.")
      replySuccess()
    } else {
      replyError("Endpoints not found.")
    }
  }

  fun disconnect() {
    connection?.let {
      usbInterface?.let { iface ->
        it.releaseInterface(iface)
      }
      it.close()
      Log.d(TAG, "USB connection closed.")
    }
    connection = null
    endpointIn = null
    endpointOut = null
    usbInterface = null
  }

  fun getSerialNumber(): String {
    val device = pickitDevice ?: findPickitDevice()
      ?: throw IllegalStateException("PICkit 2 not found. Is it plugged in?")

    if (connection == null) {
      throw IllegalStateException("PICkit 2 is not connected.")
    }

    if (!usbManager.hasPermission(device)) {
      throw SecurityException("USB permission not granted.")
    }

    val serialFromDevice = runCatching { device.serialNumber }.getOrNull()
    if (!serialFromDevice.isNullOrBlank()) {
      return serialFromDevice
    }

    val serialFromConnection = runCatching { connection?.serial }.getOrNull()
    if (!serialFromConnection.isNullOrBlank()) {
      return serialFromConnection
    }

    throw IllegalStateException("Device serial number is unavailable.")
  }

  fun autoDetectTarget(catalog: ChipCatalog): Map<String, Any> {
    if (connection == null || endpointIn == null || endpointOut == null) {
      throw IllegalStateException("PICkit 2 is not connected.")
    }
    if (!catalog.isLoaded()) {
      throw IllegalStateException("Chip catalog is not loaded.")
    }

    val detectFamilies = catalog.detectFamilyOrder()
    if (detectFamilies.isEmpty()) {
      throw IllegalStateException("No auto-detectable families found.")
    }

    val searchVdd = 3.3
    setProgrammingSpeed(1)

    for (family in detectFamilies) {
      try {
        val familyVdd = if (family.familyName.startsWith("EEPROMS/SPIFLASH 1v8")) 1.8 else searchVdd

        setVddVoltage(familyVdd, 0.85)
        setVppVoltage(if (family.vpp < 1f) familyVdd else family.vpp.toDouble(), 0.7)

        setMclr(true)
        vddOn()
        Thread.sleep(50)

        val entryScriptNumber = if (family.progEntryVppScript > 0) family.progEntryVppScript else family.progEntryScript
        executeScriptByNumber(catalog, entryScriptNumber)
        executeScriptByNumber(catalog, family.readDevIdScript)
        val raw = uploadData()
        executeScriptByNumber(catalog, family.progExitScript)

        vddOff()
        setMclr(false)

        var deviceId = 0
        if (raw.size >= 5) {
          deviceId = ((u8(raw[4]) shl 24) or (u8(raw[3]) shl 16) or (u8(raw[2]) shl 8) or u8(raw[1]))
        }

        repeat(max(0, family.progMemShift)) {
          deviceId = deviceId ushr 1
        }
        deviceId = deviceId and family.deviceIdMask

        if (family.familyName.startsWith("EEPROMS") && family.deviceIdMask == 0x00FFFFFF) {
          deviceId = ((deviceId shl 16) and 0x00FF0000) or (deviceId and 0x0000FF00) or ((deviceId ushr 16) and 0x000000FF)
        }

        if (family.familyName.startsWith("Midrange/1.8V Min MSB1st")) {
          deviceId = reverse16Bits(deviceId)
          deviceId = deviceId ushr 2
        }
        if (family.familyName.startsWith("PIC18/PIC18F MSB1st")) {
          deviceId = reverse16Bits(deviceId)
        }

        deviceId = deviceId and family.deviceIdMask
        if (deviceId == 0 || deviceId == 0xFFFF) {
          continue
        }

        val part = catalog.findPartByFamilyAndDeviceId(family.familyId, deviceId)
        if (part != null) {
          return mapOf(
            "found" to true,
            "familyId" to family.familyId,
            "family" to family.familyName,
            "model" to part.model,
            "deviceId" to formatHex(deviceId),
          )
        }
      } catch (e: Exception) {
        Log.w(TAG, "Auto-detect failed for family ${family.familyName}: ${e.message}")
        runCatching {
          vddOff()
          setMclr(false)
        }
      }
    }

    return mapOf("found" to false)
  }

  fun destroy() {
    disconnect()
    try {
      context.unregisterReceiver(usbReceiver)
    } catch (e: IllegalArgumentException) {
      // Ignored
    }
  }

  private fun replySuccess() {
    currentCallback?.onConnectionSuccess()
    currentCallback = null
  }

  private fun replyError(error: String) {
    currentCallback?.onConnectionFailed(error)
    currentCallback = null
  }

  private fun findPickitDevice(): UsbDevice? {
    return usbManager.deviceList.values.firstOrNull {
      it.vendorId == PICKIT2_VID && it.productId == PICKIT2_PID
    }
  }

  private fun setVddVoltage(voltage: Double, threshold: Double) {
    val safeVoltage = max(voltage, 1.7)
    var ccpValue = (safeVoltage * 32.0 + 10.5).toInt()
    ccpValue = ccpValue shl 6
    var vFault = (((threshold * safeVoltage) / 5.0) * 255.0).toInt()
    vFault = min(vFault, 210)

    write64(
      byteArrayOf(
        cmdSetVdd.toByte(),
        (ccpValue and 0xFF).toByte(),
        ((ccpValue ushr 8) and 0xFF).toByte(),
        (vFault and 0xFF).toByte(),
      ),
    )
  }

  private fun setVppVoltage(voltage: Double, threshold: Double) {
    val vppAdc = (voltage * 18.61).toInt()
    val vFault = (threshold * voltage * 18.61).toInt()
    write64(
      byteArrayOf(
        cmdSetVpp.toByte(),
        0x40,
        (vppAdc and 0xFF).toByte(),
        (vFault and 0xFF).toByte(),
      ),
    )
  }

  private fun setProgrammingSpeed(speed: Int) {
    val bounded = speed.coerceIn(1, 16)
    executeScriptBytes(byteArrayOf(scmdSetIcspSpeed.toByte(), bounded.toByte()))
  }

  private fun setMclr(asserted: Boolean) {
    executeScriptBytes(byteArrayOf(if (asserted) scmdMclrGndOn.toByte() else scmdMclrGndOff.toByte()))
  }

  private fun vddOn() {
    executeScriptBytes(byteArrayOf(scmdVddOn.toByte()))
  }

  private fun vddOff() {
    executeScriptBytes(byteArrayOf(scmdVddOff.toByte()))
  }

  private fun executeScriptByNumber(catalog: ChipCatalog, scriptNumber: Int) {
    if (scriptNumber <= 0) {
      return
    }
    val script = catalog.scriptByNumber(scriptNumber)
      ?: throw IllegalStateException("Script not found: $scriptNumber")
    executeScriptBytes(script.script)
  }

  private fun executeScriptBytes(scriptBytes: ByteArray) {
    if (scriptBytes.isEmpty()) {
      return
    }
    if (scriptBytes.size > reqLen - 2) {
      throw IllegalArgumentException("Script too long: ${scriptBytes.size}")
    }

    val command = ByteArray(scriptBytes.size + 2)
    command[0] = cmdExecuteScript.toByte()
    command[1] = scriptBytes.size.toByte()
    System.arraycopy(scriptBytes, 0, command, 2, scriptBytes.size)
    write64(command)
  }

  private fun uploadData(): ByteArray {
    write64(byteArrayOf(cmdUploadData.toByte()))
    return read64()
  }

  private fun write64(payload: ByteArray) {
    val out = endpointOut ?: throw IllegalStateException("USB OUT endpoint is unavailable")
    val conn = connection ?: throw IllegalStateException("USB connection is unavailable")

    val buffer = ByteArray(reqLen)
    val copyLen = min(payload.size, reqLen)
    System.arraycopy(payload, 0, buffer, 0, copyLen)

    val transferred = conn.bulkTransfer(out, buffer, reqLen, usbTimeoutMs)
    if (transferred != reqLen) {
      throw IOException("USB write failed, bytes=$transferred")
    }
  }

  private fun read64(): ByteArray {
    val input = endpointIn ?: throw IllegalStateException("USB IN endpoint is unavailable")
    val conn = connection ?: throw IllegalStateException("USB connection is unavailable")
    val buffer = ByteArray(reqLen)
    val transferred = conn.bulkTransfer(input, buffer, reqLen, usbTimeoutMs)
    if (transferred != reqLen) {
      throw IOException("USB read failed, bytes=$transferred")
    }
    return buffer
  }

  private fun u8(value: Byte): Int = value.toInt() and 0xFF

  private fun reverse16Bits(value: Int): Int {
    var result = 0
    var input = value and 0xFFFF
    for (i in 0 until 16) {
      result = (result shl 1) or (input and 1)
      input = input ushr 1
    }
    return result and 0xFFFF
  }

  private fun formatHex(value: Int): String {
    return "0x${value.toUInt().toString(16).uppercase()}"
  }
}