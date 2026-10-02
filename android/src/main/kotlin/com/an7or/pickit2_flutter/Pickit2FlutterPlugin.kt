package com.an7or.pickit2_flutter

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.BufferedInputStream
import java.io.File
import java.io.FileReader
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class Pickit2FlutterPlugin : FlutterPlugin, MethodCallHandler {
  private lateinit var channel: MethodChannel
  private lateinit var context: Context
  private var usbDriver: PICkitUsbDriver? = null
  private var nativeEngine: NativePk2Engine? = null
  private var startupError: Exception? = null
  private val chipCatalog = ChipCatalog()
  private val backgroundExecutor: ExecutorService = Executors.newSingleThreadExecutor()
  private val mainHandler = Handler(Looper.getMainLooper())
  private val loadedImage = ProgramImage()
  private var selectedPartInfo: Map<String, Any?> = emptyMap()
  private var serialNumber = ""
  private var firmwareVersion = ""
  private var lastReadAvailable = false

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    channel = MethodChannel(binding.binaryMessenger, "pickit2_flutter")
    channel.setMethodCallHandler(this)
    usbDriver = PICkitUsbDriver(context, ::handleDeviceDetached)
    try {
      nativeEngine = NativePk2Engine(prepareDeviceFile().absolutePath) { phase, percent, message ->
        mainHandler.post {
          channel.invokeMethod(
            "onWriteProgress",
            mapOf("phase" to phase, "percent" to percent, "message" to message),
          )
        }
      }
    } catch (error: Exception) {
      startupError = error
    }
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "connect" -> connect(result)
      "disconnect" -> runAsync(result, "DISCONNECT_ERROR") {
        nativeEngine?.disconnect()
        usbDriver?.disconnect()
        serialNumber = ""
        firmwareVersion = ""
        selectedPartInfo = emptyMap()
        lastReadAvailable = false
        "Disconnected"
      }
      "getSerialNumber" -> result.success(serialNumber)
      "getFirmwareVersion" -> result.success(firmwareVersion)
      "loadHexFile" -> runCatchingResult(result, "HEX_LOAD_ERROR") {
        loadHexFile(call.argument("path"))
      }
      "loadBinFile" -> runCatchingResult(result, "BIN_LOAD_ERROR") {
        loadBinFile(call.argument("path"), call.argument<Int>("baseAddress") ?: 0)
      }
      "clearLoadedImage" -> {
        loadedImage.clear()
        result.success(true)
      }
      "getLoadedImageInfo" -> result.success(loadedImage.summary())
      "getLoadedImageData" -> result.success(loadedImageData())
      "loadChipData", "loadChipDataFromDat" -> loadChipData(call, result)
      "getChipCatalog" -> catalogResult(result) { chipCatalog.all() }
      "getChipFamilies" -> catalogResult(result) { chipCatalog.families() }
      "getChipModelsByFamily" -> catalogResult(result) {
        val family = call.argument<String>("family")?.takeIf(String::isNotBlank)
          ?: throw IllegalArgumentException("family is required")
        chipCatalog.modelsByFamily(family)
      }
      "selectChip" -> runAsync(result, "CHIP_SELECT_ERROR") {
        selectedPartInfo = requireEngine().selectPart(call.argument<String>("model").orEmpty())
        lastReadAvailable = false
        true
      }
      "autoDetectChip" -> runAsync(result, "AUTO_DETECT_ERROR") {
        requireCatalog()
        requireEngine().autoDetect().also {
          selectedPartInfo = it
          lastReadAvailable = false
        }
      }
      "eraseChip" -> runAsync(result, "ERASE_ERROR") {
        requireEngine().erase().also { erased ->
          if (erased) lastReadAvailable = false
        }
      }
      "blankCheck" -> runAsync(result, "BLANK_CHECK_ERROR") { requireEngine().blankCheck() }
      "readChip" -> runAsync(result, "READ_ERROR") {
        requireEngine().read().also { lastReadAvailable = true }
      }
      "saveHexFile", "saveReadHex" -> runAsync(result, "HEX_SAVE_ERROR") {
        if (!lastReadAvailable) throw IllegalStateException("Read the target before exporting")
        val path = call.argument<String>("path") ?: throw IllegalArgumentException("path is required")
        requireEngine().exportHex(path)
      }
      "getConfigWords" -> result.success(configWords())
      "setConfigWord" -> setConfigWord(call, result)
      "writeFirmware" -> runImageOperation(result, "WRITE_ERROR") { path ->
        requireEngine().writeHex(path).also { lastReadAvailable = false }
      }
      "verifyFirmware" -> runImageOperation(result, "VERIFY_ERROR") { path ->
        requireEngine().verifyHex(path)
      }
      else -> result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    backgroundExecutor.shutdownNow()
    nativeEngine?.close()
    nativeEngine = null
    usbDriver?.destroy()
    usbDriver = null
  }

  private fun connect(result: Result) {
    val driver = usbDriver
    if (driver == null) {
      result.error("USB_ERROR", "USB transport is unavailable", null)
      return
    }
    driver.connect(object : PICkitUsbDriver.UsbCallback {
      override fun onConnectionSuccess() {
        runAsync(result, "USB_ERROR") {
          val engine = requireEngine()
          try {
            if (!engine.attachUsb(driver.fileDescriptor(), driver.serialNumber())) {
              throw IllegalStateException("Unable to attach Android USB transport")
            }
            val info = engine.connect()
            serialNumber = info["serialNumber"]?.toString().orEmpty()
            firmwareVersion = info["firmwareVersion"]?.toString().orEmpty()
            selectedPartInfo = emptyMap()
            lastReadAvailable = false
            "Connected to PICkit 2 successfully!"
          } catch (error: Exception) {
            engine.disconnect()
            driver.disconnect()
            throw error
          }
        }
      }

      override fun onConnectionFailed(error: String) {
        result.error("USB_ERROR", error, null)
      }
    })
  }

  private fun loadChipData(call: MethodCall, result: Result) {
    runAsync(result, "CHIP_DATA_ERROR") {
      val catalogPath = call.argument<String>("catalogPath")
      val detectPath = call.argument<String>("detectPath")
      val catalogBytes = if (catalogPath.isNullOrBlank()) {
        context.assets.open("chip_catalog.csv").use { it.readBytes() }
      } else {
        File(catalogPath).readBytes()
      }
      val detectBytes = if (detectPath.isNullOrBlank()) {
        context.assets.open("chip_detect.json").use { it.readBytes() }
      } else {
        File(detectPath).readBytes()
      }
      val modelCount = chipCatalog.loadPrebuilt(catalogBytes, detectBytes)
      if (modelCount <= 0) throw IllegalStateException("No chip models found in the catalog")
      mapOf(
        "loaded" to true,
        "familyCount" to chipCatalog.families().size,
        "modelCount" to modelCount,
      )
    }
  }

  private fun loadHexFile(path: String?): Map<String, Any> {
    val file = requiredFile(path, "HEX")
    val parsedImage = ProgramImage().apply { setSource("hex", file.absolutePath) }
    var upperLinear = 0
    var upperSegment = 0
    var eof = false

    FileReader(file).useLines { lines ->
      lines.forEachIndexed { lineNumber, sourceLine ->
        val line = sourceLine.trim().uppercase()
        if (line.isEmpty()) return@forEachIndexed
        if (!line.startsWith(":") || line.length < 11 || line.length % 2 == 0) {
          throw IllegalArgumentException("Invalid Intel HEX record at line ${lineNumber + 1}")
        }
        val record = (1 until line.length step 2).map { line.substring(it, it + 2).toInt(16) }
        val count = record[0]
        if (record.size != count + 5 || record.sum().and(0xFF) != 0) {
          throw IllegalArgumentException("Invalid Intel HEX checksum at line ${lineNumber + 1}")
        }
        val offset = (record[1] shl 8) or record[2]
        when (record[3]) {
          0x00 -> {
            val base = (upperLinear shl 16) + (upperSegment shl 4) + offset
            repeat(count) { index -> parsedImage.putByte(base + index, record[4 + index]) }
          }
          0x01 -> eof = true
          0x02 -> {
            upperSegment = (record[4] shl 8) or record[5]
            upperLinear = 0
          }
          0x04 -> {
            upperLinear = (record[4] shl 8) or record[5]
            upperSegment = 0
          }
        }
      }
    }
    if (!eof || parsedImage.isEmpty()) {
      throw IllegalArgumentException("Intel HEX file is empty or missing its end record")
    }
    loadedImage.replaceWith(parsedImage)
    return loadedImage.summary()
  }

  private fun loadBinFile(path: String?, baseAddress: Int): Map<String, Any> {
    val file = requiredFile(path, "BIN")
    require(baseAddress >= 0) { "baseAddress must not be negative" }
    val parsedImage = ProgramImage().apply { setSource("bin", file.absolutePath) }
    BufferedInputStream(file.inputStream()).use { input ->
      var offset = 0
      while (true) {
        val value = input.read()
        if (value < 0) break
        parsedImage.putByte(baseAddress + offset, value)
        offset++
      }
    }
    if (parsedImage.isEmpty()) throw IllegalArgumentException("BIN file is empty")
    loadedImage.replaceWith(parsedImage)
    return loadedImage.summary()
  }

  private fun handleDeviceDetached() {
    if (backgroundExecutor.isShutdown) return
    backgroundExecutor.execute {
      nativeEngine?.disconnect()
      serialNumber = ""
      firmwareVersion = ""
      selectedPartInfo = emptyMap()
      lastReadAvailable = false
      mainHandler.post { channel.invokeMethod("onDeviceDetached", null) }
    }
  }

  private fun loadedImageData(): Map<String, Any> {
    val data = ArrayList<Int>(loadedImage.size() * 2)
    loadedImage.getBytes().forEach { (address, value) ->
      data.add(address)
      data.add(value)
    }
    return loadedImage.summary() + mapOf("data" to data, "configWords" to configWords())
  }

  private fun configWords(): List<Map<String, Any?>> {
    val descriptors = selectedPartInfo["configWords"] as? List<*> ?: return emptyList()
    return descriptors.mapNotNull { raw ->
      val descriptor = (raw as? Map<*, *>)?.entries?.associate { it.key.toString() to it.value }
        ?: return@mapNotNull null
      val address = (descriptor["address"] as? Number)?.toInt() ?: return@mapNotNull descriptor
      val blank = (descriptor["blank"] as? Number)?.toInt() ?: 0xFFFF
      val byteCount = (descriptor["byteCount"] as? Number)?.toInt() ?: 2
      var value = 0
      repeat(byteCount) { offset ->
        val fallback = (blank ushr (offset * 8)) and 0xFF
        value = value or ((loadedImage.getByte(address + offset) ?: fallback) shl (offset * 8))
      }
      descriptor + ("value" to value)
    }
  }

  private fun setConfigWord(call: MethodCall, result: Result) {
    runCatchingResult(result, "INVALID_CONFIG") {
      if (loadedImage.isEmpty()) throw IllegalStateException("Load a firmware image first")
      val index = call.argument<Int>("index") ?: throw IllegalArgumentException("index is required")
      val requestedValue = call.argument<Int>("value") ?: throw IllegalArgumentException("value is required")
      val descriptor = configWords().firstOrNull { (it["index"] as? Number)?.toInt() == index }
        ?: throw IllegalArgumentException("Invalid configuration word")
      val address = (descriptor["address"] as Number).toInt()
      val byteCount = (descriptor["byteCount"] as? Number)?.toInt() ?: 2
      val mask = (descriptor["mask"] as? Number)?.toInt() ?: 0xFFFF
      val blank = (descriptor["blank"] as? Number)?.toInt() ?: 0xFFFF
      val sanitized = (requestedValue and mask) or (blank and mask.inv())
      repeat(byteCount) { offset ->
        loadedImage.putByte(address + offset, sanitized ushr (offset * 8))
      }
      descriptor + ("value" to sanitized)
    }
  }

  private fun runImageOperation(result: Result, code: String, operation: (String) -> Any) {
    if (loadedImage.isEmpty()) {
      result.error("NO_IMAGE", "Load a firmware image first", null)
      return
    }
    runAsync(result, code) {
      val temporary = File.createTempFile("pickit2-", ".hex", context.cacheDir)
      try {
        loadedImage.writeHex(temporary)
        operation(temporary.absolutePath)
      } finally {
        temporary.delete()
      }
    }
  }

  private fun prepareDeviceFile(): File {
    val directory = File(context.filesDir, "pickit2").apply { mkdirs() }
    val destination = File(directory, "PK2DeviceFile.dat")
    val bundled = context.assets.open("PK2DeviceFile.dat").use { it.readBytes() }
    if (!destination.exists() || !destination.readBytes().contentEquals(bundled)) {
      destination.writeBytes(bundled)
    }
    return destination
  }

  private fun requireEngine(): NativePk2Engine {
    return nativeEngine ?: throw IllegalStateException(
      startupError?.message ?: "PICkit 2 native engine is unavailable",
    )
  }

  private fun requireCatalog() {
    if (!chipCatalog.isLoaded()) throw IllegalStateException("Load chip data first")
  }

  private fun requiredFile(path: String?, type: String): File {
    val value = path?.takeIf(String::isNotBlank)
      ?: throw IllegalArgumentException("$type file path is required")
    return File(value).takeIf(File::isFile)
      ?: throw IllegalArgumentException("$type file not found: $value")
  }

  private fun catalogResult(result: Result, operation: () -> Any) {
    runCatchingResult(result, "CHIP_DATA_NOT_LOADED") {
      requireCatalog()
      operation()
    }
  }

  private fun runCatchingResult(result: Result, code: String, operation: () -> Any) {
    try {
      result.success(operation())
    } catch (error: Exception) {
      result.error(code, error.message, null)
    }
  }

  private fun runAsync(result: Result, code: String, operation: () -> Any) {
    backgroundExecutor.execute {
      try {
        val value = operation()
        mainHandler.post { result.success(value) }
      } catch (error: Exception) {
        mainHandler.post { result.error(code, error.message, null) }
      }
    }
  }
}
