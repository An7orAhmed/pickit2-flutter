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
import java.nio.charset.Charset
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
  private val cmdClrUploadBuffer = 0xA9
  private val cmdRunScript = 0xA5
  private val cmdUploadDataNoLen = 0xAC
  private val cmdClrDownloadBuffer = 0xA7
  private val cmdDownloadData = 0xA8
  private val cmdEndOfBuffer = 0xAD

  private val scmdVddOn = 0xFF
  private val scmdVddOff = 0xFE
  private val scmdMclrGndOn = 0xF7
  private val scmdMclrGndOff = 0xF6
  private val scmdSetIcspSpeed = 0xEA

  private val SCR_PROG_ENTRY = 1
  private val SCR_PROG_EXIT = 2
  private val SCR_RD_DEVID = 3
  private val SCR_PROGMEM_RD = 4
  private val SCR_ERASE_CHIP_PREP = 5
  private val SCR_PROGMEM_ADDRSET = 6
  private val SCR_PROGMEM_WR_PREP = 7
  private val SCR_PROGMEM_WR = 8
  private val SCR_EE_RD = 9
  private val SCR_EE_WR_PREP = 10
  private val SCR_EE_WR = 11
  private val SCR_CONFIG_RD = 13
  private val SCR_CONFIG_WR_PREP = 14
  private val SCR_CONFIG_WR = 15
  private val SCR_ERASE_CHIP = 22

  interface UsbCallback {
    fun onConnectionSuccess()
    fun onConnectionFailed(error: String)
  }

  private var currentCallback: UsbCallback? = null

  private val usbReceiver = object : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
      when (intent.action) {
        UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
          val device: UsbDevice? = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
          device?.let {
            if (it.vendorId == PICKIT2_VID && it.productId == PICKIT2_PID) {
              Log.d(TAG, "PICkit 2 Attached! Auto-requesting permission...")
              pickitDevice = it
              requestPermission()
            }
          }
        }

        UsbManager.ACTION_USB_DEVICE_DETACHED -> {
          val device: UsbDevice? = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
          device?.let {
            if (it.vendorId == PICKIT2_VID && it.productId == PICKIT2_PID) {
              Log.d(TAG, "PICkit 2 Detached!")
              if (pickitDevice?.deviceId == it.deviceId) {
                pickitDevice = null
              }
              disconnect()
            }
          }
        }

        ACTION_USB_PERMISSION -> {
          synchronized(this) {
            val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
            if (granted) {
              Log.d(TAG, "Permission granted by user!")
            } else {
              Log.e(TAG, "Permission denied by user.")
            }
          }
        }
      }
    }
  }

  init {
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

  fun getFirmwareVersion(): String {
    if (connection == null || endpointIn == null || endpointOut == null) {
      throw IllegalStateException("PICkit 2 is not connected.")
    }

    val fwBytes = readFirmwareVersion()
    if (fwBytes[1].toInt() == 0x76 && fwBytes.size >= 9 && fwBytes[6].toInt() == 0x42) {
      val major = fwBytes[7].toInt() and 0xFF
      val minor = fwBytes[8].toInt() and 0xFF
      return "$major.$minor"
    }
    if (fwBytes.size >= 3) {
      return String.format("%d.%02d.%02d", fwBytes[0].toInt() and 0xFF, fwBytes[1].toInt() and 0xFF, fwBytes[2].toInt() and 0xFF)
    }
    return "Unknown"
  }

  private fun readFirmwareVersion(): ByteArray {
    val command = byteArrayOf(0x76.toByte())
    write64(command)
    return read64()
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

  fun eraseChip(catalog: ChipCatalog): Boolean {
    if (connection == null || endpointIn == null || endpointOut == null) {
      throw IllegalStateException("PICkit 2 is not connected.")
    }

    setProgrammingSpeed(1)
    setVddVoltage(3.3, 0.85)
    setVppVoltage(3.3, 0.7)

    setMclr(true)
    vddOn()
    Thread.sleep(50)

    try {
      executeScriptByNumber(catalog, SCR_PROG_ENTRY)

      val chipEraseScript = catalog.scriptByNumber(SCR_ERASE_CHIP)?.script
      if (chipEraseScript != null) {
        executeScriptBytes(chipEraseScript)
      }

      executeScriptByNumber(catalog, SCR_PROG_EXIT)
      return true
    } finally {
      vddOff()
      setMclr(false)
    }
  }

  fun readChip(catalog: ChipCatalog, partInfo: Map<String, Any>): Map<String, Any> {
    if (connection == null || endpointIn == null || endpointOut == null) {
      throw IllegalStateException("PICkit 2 is not connected.")
    }

    setProgrammingSpeed(1)
    setVddVoltage(3.3, 0.85)
    setVppVoltage(3.3, 0.7)

    setMclr(true)
    vddOn()
    Thread.sleep(50)

    try {
      executeScriptByNumber(catalog, SCR_PROG_ENTRY)

      val programMem = readProgramMemory(catalog, partInfo)
      val eepromMem = readEepromMemory(catalog, partInfo)
      val configMem = readConfigMemory(catalog, partInfo)

      executeScriptByNumber(catalog, SCR_PROG_EXIT)

      return mapOf(
        "success" to true,
        "programMemory" to programMem,
        "eepromMemory" to eepromMem,
        "configMemory" to configMem,
        "programMemSize" to programMem.size,
        "eepromMemSize" to eepromMem.size,
        "configMemSize" to configMem.size,
      )
    } finally {
      vddOff()
      setMclr(false)
    }
  }

  private fun readProgramMemory(catalog: ChipCatalog, partInfo: Map<String, Any>): List<Int> {
    val progMemSize = (partInfo["flashSize"] as? String)?.filter { it.isDigit() }?.toIntOrNull() ?: 0
    val bytesPerWord = partInfo["bytesPerLocation"] as? Int ?: 2
    val wordsPerRead = 16 / bytesPerWord
    val result = mutableListOf<Int>()

    if (progMemSize <= 0) return result

    downloadAddress3(0)
    executeScriptByNumber(catalog, SCR_PROGMEM_RD)

    val totalWords = progMemSize
    var wordsRead = 0

    while (wordsRead < totalWords && wordsRead < 8192) {
      val upload = uploadData()
      for (i in 0 until minOf(wordsPerRead, upload.size / bytesPerWord, totalWords - wordsRead)) {
        var word = 0
        for (b in 0 until bytesPerWord) {
          val idx = i * bytesPerWord + b
          if (idx < upload.size) {
            word = word or (u8(upload[idx]) shl (b * 8))
          }
        }
        result.add(word)
      }
      wordsRead += wordsPerRead
      if (wordsRead < totalWords) {
        downloadAddress3(wordsRead * bytesPerWord)
        executeScriptByNumber(catalog, SCR_PROGMEM_RD)
      }
    }

    return result
  }

  private fun readEepromMemory(catalog: ChipCatalog, partInfo: Map<String, Any>): List<Int> {
    val eeSize = (partInfo["eepromSize"] as? String)?.filter { it.isDigit() }?.toIntOrNull() ?: 0
    val result = mutableListOf<Int>()

    if (eeSize <= 0) return result

    val eeAddr = partInfo["eeAddr"] as? Int ?: 0
    downloadAddress3(eeAddr)
    executeScriptByNumber(catalog, SCR_EE_RD)

    for (i in 0 until minOf(eeSize, 2048)) {
      val upload = uploadData()
      if (upload.isNotEmpty()) {
        result.add(u8(upload[0]))
      }
    }

    return result
  }

  private fun readConfigMemory(catalog: ChipCatalog, partInfo: Map<String, Any>): List<Int> {
    val configWords = partInfo["configWords"] as? Int ?: 0
    val result = mutableListOf<Int>()

    if (configWords <= 0) return result

    executeScriptByNumber(catalog, SCR_CONFIG_RD)

    for (i in 0 until minOf(configWords, 16)) {
      val upload = uploadData()
      if (upload.size >= 2) {
        result.add((u8(upload[0]) shl 8) or u8(upload[1]))
      }
    }

    return result
  }

  private fun downloadAddress3(address: Int) {
    val cmd = byteArrayOf(
      0x00.toByte(),
      (address and 0xFF).toByte(),
      ((address shr 8) and 0xFF).toByte(),
      ((address shr 16) and 0xFF).toByte(),
    )
    write64(cmd)
  }

  // ── Firmware Write (Microchip Standard Flow) ─────────────────────────────

  fun writeFirmware(
    catalog: ChipCatalog,
    partInfo: Map<String, Any>,
    image: ProgramImage,
    skipBlankCheck: Boolean = false,
    progressCallback: ((phase: String, percent: Int, message: String) -> Unit)? = null,
  ): Boolean {
    if (connection == null || endpointIn == null || endpointOut == null) {
      throw IllegalStateException("PICkit 2 is not connected.")
    }
    if (image.isEmpty()) {
      throw IllegalStateException("No firmware image loaded.")
    }

    val family = catalog.detectFamilyOrder().firstOrNull { f ->
      catalog.findPartByFamilyAndDeviceId(f.familyId, 0) != null // approximate
    } ?: throw IllegalStateException("No auto-detectable family found.")

    val blankValue = family.blankValue.takeIf { it in 0..0xFFFF } ?: 0x3FFF
    val bytesPerWord = family.bytesPerLocation.takeIf { it in 1..4 } ?: 2
    val progMemSize = (partInfo["flashSize"] as? String)?.filter { it.isDigit() }?.toIntOrNull() ?: 0
    val eeSize = (partInfo["eepromSize"] as? String)?.filter { it.isDigit() }?.toIntOrNull() ?: 0
    val configWords = partInfo["configWords"] as? Int ?: 0
    val eeMemBytesPerWord = family.eeMemBytesPerWord.takeIf { it in 1..4 } ?: 1

    setProgrammingSpeed(1)
    setVddVoltage(3.3, 0.85)
    setVppVoltage(3.3, 0.7)
    setMclr(true)
    vddOn()
    Thread.sleep(50)

    try {
      // ── Step 0: Enter programming mode ──
      progressCallback?.invoke("setup", 2, "Entering programming mode…")
      executeScriptByNumber(catalog, SCR_PROG_ENTRY)

      // ── Step 1: Erase ──
      progressCallback?.invoke("erase", 5, "Erasing chip…")
      val erasePrepScript = catalog.scriptByNumber(SCR_ERASE_CHIP_PREP)?.script
      if (erasePrepScript != null) {
        executeScriptBytes(erasePrepScript)
      }
      val chipEraseScript = catalog.scriptByNumber(SCR_ERASE_CHIP)?.script
      if (chipEraseScript != null) {
        executeScriptBytes(chipEraseScript)
      }
      // Some devices need a pause after erase
      Thread.sleep(100)

      // ── Step 2: Blank Check (unless skipped) ──
      if (!skipBlankCheck) {
        progressCallback?.invoke("blankCheck", 10, "Blank checking…")
        val blankOk = blankCheckProgramMemory(catalog, partInfo, blankValue, bytesPerWord, progMemSize)
        if (!blankOk) {
          progressCallback?.invoke("error", 10, "Blank check failed – chip is not blank after erase")
          executeScriptByNumber(catalog, SCR_PROG_EXIT)
          return false
        }
        progressCallback?.invoke("blankCheck", 15, "Blank check passed")
      } else {
        progressCallback?.invoke("blankCheck", 15, "Blank check skipped")
      }

      // ── Step 3: Write Program Memory ──
      progressCallback?.invoke("writeProg", 20, "Writing program memory…")
      val progWriteBytes = writeProgramMemory(catalog, partInfo, image, bytesPerWord, blankValue) { addrPct ->
        val pct = 20 + (addrPct * 50 / 100)
        progressCallback?.invoke("writeProg", pct, "Writing program memory ${addrPct}%…")
      }

      // ── Step 4: Write EEPROM ──
      if (eeSize > 0 && image.minAddress() <= 0x2100) {
        progressCallback?.invoke("writeEE", 70, "Writing EEPROM…")
        writeEepromMemory(catalog, partInfo, image, eeMemBytesPerWord)
      }

      // ── Step 5: Write Config Words ──
      if (configWords > 0) {
        progressCallback?.invoke("writeConfig", 75, "Writing config words…")
        writeConfigMemory(catalog, image)
      }

      // ── Step 6: Verify ──
      progressCallback?.invoke("verify", 80, "Verifying…")
      val verifyOk = verifyProgramMemory(catalog, partInfo, image, bytesPerWord, blankValue) { addrPct ->
        val pct = 80 + (addrPct * 18 / 100)
        progressCallback?.invoke("verify", pct, "Verifying ${addrPct}%…")
      }

      if (!verifyOk) {
        progressCallback?.invoke("error", 98, "Verification failed – data mismatch")
        executeScriptByNumber(catalog, SCR_PROG_EXIT)
        return false
      }

      progressCallback?.invoke("done", 100, "Firmware written and verified successfully")
      executeScriptByNumber(catalog, SCR_PROG_EXIT)
      return true
    } catch (e: Exception) {
      progressCallback?.invoke("error", 0, "Write failed: ${e.message}")
      runCatching {
        executeScriptByNumber(catalog, SCR_PROG_EXIT)
      }
      throw e
    } finally {
      vddOff()
      setMclr(false)
    }
  }

  private fun blankCheckProgramMemory(
    catalog: ChipCatalog,
    partInfo: Map<String, Any>,
    blankValue: Int,
    bytesPerWord: Int,
    progMemSize: Int,
  ): Boolean {
    if (progMemSize <= 0) return true

    val bytesPerLoc = bytesPerWord.coerceIn(1, 4)
    val blankByte = blankValue and 0xFF
    val totalBytes = progMemSize * bytesPerLoc
    val readChunk = 64
    var offset = 0

    while (offset < totalBytes && offset < 8192) {
      downloadAddress3(offset)
      executeScriptByNumber(catalog, SCR_PROGMEM_RD)
      val upload = uploadData()

      for (i in upload.indices) {
        if (u8(upload[i]) != blankByte) {
          Log.w(TAG, "Blank check failed at offset ${offset + i}: expected $blankByte, got ${u8(upload[i])}")
          return false
        }
      }

      offset += readChunk
    }

    return true
  }

  private fun writeProgramMemory(
    catalog: ChipCatalog,
    partInfo: Map<String, Any>,
    image: ProgramImage,
    bytesPerWord: Int,
    blankValue: Int,
    progress: ((pct: Int) -> Unit)? = null,
  ): Int {
    val bytesPerLoc = bytesPerWord.coerceIn(1, 4)
    val progMemSize = (partInfo["flashSize"] as? String)?.filter { it.isDigit() }?.toIntOrNull() ?: 0
    if (progMemSize <= 0) return 0

    val maxAddr = image.maxAddress()
    val minAddr = image.minAddress()
    val maxWritable = maxAddr.coerceAtMost(progMemSize * bytesPerLoc - 1)
    val totalBytesToWrite = (maxWritable - minAddr + 1).coerceAtLeast(0)

    if (totalBytesToWrite <= 0) return 0

    var bytesWritten = 0
    val downloadChunk = 32 // must be multiple of bytesPerLoc for word alignment

    // Collect non-blank sections to write
    val sections = mutableListOf<Pair<Int, Int>>() // (startByte, length)
    var sectionStart = -1
    var currentLen = 0

    for (addr in minAddr..maxWritable) {
      val byteVal = image.getByte(addr) ?: (blankValue and 0xFF)
      if (byteVal != (blankValue and 0xFF)) {
        if (sectionStart < 0) sectionStart = addr
        currentLen++
      } else {
        if (sectionStart >= 0) {
          sections.add(sectionStart to currentLen)
        }
        sectionStart = -1
        currentLen = 0
      }
    }
    if (sectionStart >= 0) {
      sections.add(sectionStart to currentLen)
    }

    if (sections.isEmpty()) {
      progress?.invoke(100)
      return 0
    }

    for ((startAddr, length) in sections) {
      val alignedStart = (startAddr / bytesPerLoc) * bytesPerLoc
      val endAddr = startAddr + length
      val alignedEnd = ((endAddr + bytesPerLoc - 1) / bytesPerLoc) * bytesPerLoc
      val alignedLength = alignedEnd - alignedStart

      var pos = alignedStart
      while (pos < alignedEnd) {
        val chunkLen = minOf(alignedEnd - pos, downloadChunk)
        // Align to bytesPerLoc
        val writeLen = (chunkLen / bytesPerLoc) * bytesPerLoc
        if (writeLen <= 0) break

        // Build the data buffer for this chunk
        val dataBytes = ByteArray(writeLen)

        // Determine the word address
        val wordAddr = pos / bytesPerLoc

        // Set address
        executeScriptByNumber(catalog, SCR_PROGMEM_ADDRSET)
        downloadAddress3(wordAddr * bytesPerLoc)
        // For MSB1st families, we may need to use alternative address setting
        // downloadAddress3MSBFirst(wordAddr) if needed

        // Fill data bytes from image
        for (i in 0 until writeLen) {
          val byteAddr = pos + i
          val byteVal = image.getByte(byteAddr) ?: (blankValue and 0xFF)
          dataBytes[i] = byteVal.toByte()
        }

        // Download data to PICkit2 buffer
        clearDownloadBuffer()
        downloadData(dataBytes)

        // Execute write script
        executeScriptByNumber(catalog, SCR_PROGMEM_WR_PREP)
        executeScriptByNumber(catalog, SCR_PROGMEM_WR)

        bytesWritten += writeLen
        pos += writeLen

        val pct = if (totalBytesToWrite > 0) (bytesWritten * 100 / totalBytesToWrite).coerceIn(0, 100) else 0
        progress?.invoke(pct)
      }
    }

    progress?.invoke(100)
    return bytesWritten
  }

  private fun writeEepromMemory(
    catalog: ChipCatalog,
    partInfo: Map<String, Any>,
    image: ProgramImage,
    eeBytesPerWord: Int,
  ) {
    val eeSize = (partInfo["eepromSize"] as? String)?.filter { it.isDigit() }?.toIntOrNull() ?: 0
    if (eeSize <= 0) return

    val eeAddr = partInfo["eeAddr"] as? Int ?: 0
    // EEPROM typically starts at device-specific address; we write byte-by-byte for simplicity
    for (i in 0 until minOf(eeSize, 2048)) {
      val byteAddr = eeAddr + i
      val byteVal = image.getByte(byteAddr) ?: continue

      downloadAddress3(byteAddr)
      val data = byteArrayOf(byteVal.toByte())
      clearDownloadBuffer()
      downloadData(data)
      executeScriptByNumber(catalog, SCR_EE_WR_PREP)
      executeScriptByNumber(catalog, SCR_EE_WR)
    }
  }

  private fun writeConfigMemory(catalog: ChipCatalog, image: ProgramImage) {
    val configStartAddr = 0x300000 // Typical config address region
    for (offset in 0 until 16) {
      val addr = configStartAddr + offset * 2
      val hi = image.getByte(addr) ?: continue
      val lo = image.getByte(addr + 1) ?: continue

      val data = byteArrayOf(lo.toByte(), hi.toByte())
      clearDownloadBuffer()
      downloadData(data)
      executeScriptByNumber(catalog, SCR_CONFIG_WR_PREP)
      executeScriptByNumber(catalog, SCR_CONFIG_WR)
    }
  }

  private fun verifyProgramMemory(
    catalog: ChipCatalog,
    partInfo: Map<String, Any>,
    image: ProgramImage,
    bytesPerWord: Int,
    blankValue: Int,
    progress: ((pct: Int) -> Unit)? = null,
  ): Boolean {
    val bytesPerLoc = bytesPerWord.coerceIn(1, 4)
    val progMemSize = (partInfo["flashSize"] as? String)?.filter { it.isDigit() }?.toIntOrNull() ?: 0
    if (progMemSize <= 0) return true

    val maxAddr = image.maxAddress()
    val minAddr = image.minAddress()
    val maxVerifiable = maxAddr.coerceAtMost(progMemSize * bytesPerLoc - 1)
    val totalBytes = (maxVerifiable - minAddr + 1).coerceAtLeast(0)

    if (totalBytes <= 0) return true

    var bytesChecked = 0
    val readChunk = 64
    var offset = minAddr

    while (offset <= maxVerifiable) {
      downloadAddress3(offset)
      executeScriptByNumber(catalog, SCR_PROGMEM_RD)
      val upload = uploadData()

      for (i in upload.indices) {
        val byteAddr = offset + i
        if (byteAddr > maxVerifiable) break
        val expected = image.getByte(byteAddr) ?: (blankValue and 0xFF)
        val actual = u8(upload[i])
        if (expected != actual) {
          Log.w(TAG, "Verify failed at offset $byteAddr: expected $expected, got $actual")
          return false
        }
        bytesChecked++
      }

      offset += readChunk
      val pct = if (totalBytes > 0) (bytesChecked * 100 / totalBytes).coerceIn(0, 100) else 0
      progress?.invoke(pct)
    }

    progress?.invoke(100)
    return true
  }

  private fun clearDownloadBuffer() {
    write64(byteArrayOf(cmdClrDownloadBuffer.toByte()))
  }

  private fun downloadData(data: ByteArray) {
    val cmd = ByteArray(minOf(data.size, 62) + 2)
    cmd[0] = cmdDownloadData.toByte()
    cmd[1] = minOf(data.size, 62).toByte()
    System.arraycopy(data, 0, cmd, 2, minOf(data.size, 62))
    write64(cmd)

    // Signal end of buffer
    write64(byteArrayOf(cmdEndOfBuffer.toByte()))
  }
}