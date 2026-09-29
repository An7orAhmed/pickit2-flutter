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
import kotlin.math.min

class Pickit2FlutterPlugin : FlutterPlugin, MethodCallHandler {
  private lateinit var channel: MethodChannel
  private lateinit var context: Context
  private var usbDriver: PICkitUsbDriver? = null
  private val chipCatalog = ChipCatalog()
  private val backgroundExecutor: ExecutorService = Executors.newSingleThreadExecutor()
  private val mainHandler = Handler(Looper.getMainLooper())

  private val loadedImage = ProgramImage()
  private var selectedPartInfo: Map<String, Any> = emptyMap()

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    context = flutterPluginBinding.applicationContext
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "pickit2_flutter")
    channel.setMethodCallHandler(this)
    usbDriver = PICkitUsbDriver(context)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "connect" -> {
        usbDriver?.connect(object : PICkitUsbDriver.UsbCallback {
          override fun onConnectionSuccess() {
            result.success("Connected to PICkit 2 successfully!")
          }
          override fun onConnectionFailed(error: String) {
            result.error("USB_ERROR", error, null)
          }
        })
      }
      "disconnect" -> {
        usbDriver?.disconnect()
        result.success("Disconnected")
      }
      "getSerialNumber" -> {
        try {
          result.success(usbDriver?.getSerialNumber())
        } catch (e: Exception) {
          result.error("SERIAL_ERROR", e.message, null)
        }
      }
      "loadHexFile" -> {
        val path = call.argument<String>("path")
        try {
          result.success(loadHexFile(path))
        } catch (e: Exception) {
          result.error("HEX_LOAD_ERROR", e.message, null)
        }
      }
      "loadBinFile" -> {
        val path = call.argument<String>("path")
        val baseAddress = call.argument<Int>("baseAddress") ?: 0
        try {
          result.success(loadBinFile(path, baseAddress))
        } catch (e: Exception) {
          result.error("BIN_LOAD_ERROR", e.message, null)
        }
      }
      "clearLoadedImage" -> {
        loadedImage.clear()
        result.success(true)
      }
      "getLoadedImageInfo" -> {
        result.success(loadedImage.summary())
      }
      "getLoadedImageData" -> {
        // Returns the full loaded image as [address1, value1, address2, value2, ...]
        val bytes = loadedImage.getBytes()
        val flat = mutableListOf<Int>()
        for ((addr, value) in bytes) {
          flat.add(addr)
          flat.add(value)
        }
        result.success(mapOf(
          "sourceType" to (loadedImage.summary()["sourceType"] ?: ""),
          "loadedBytes" to loadedImage.size(),
          "minAddress" to loadedImage.minAddress(),
          "maxAddress" to loadedImage.maxAddress(),
          "data" to flat,
        ))
      }
      "loadChipData", "loadChipDataFromDat" -> {
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
          val loadedModelCount = chipCatalog.loadPrebuilt(catalogBytes, detectBytes)
          if (loadedModelCount <= 0) {
            throw IllegalStateException("No chip models parsed from generated assets")
          }
          mapOf(
            "loaded" to true,
            "familyCount" to chipCatalog.families().size,
            "modelCount" to loadedModelCount,
          )
        }
      }
      "getChipCatalog" -> {
        if (!chipCatalog.isLoaded()) {
          result.error("CHIP_DATA_NOT_LOADED", "Load chip data first using loadChipDataFromDat", null)
        } else {
          result.success(chipCatalog.all())
        }
      }
      "getChipFamilies" -> {
        if (!chipCatalog.isLoaded()) {
          result.error("CHIP_DATA_NOT_LOADED", "Load chip data first using loadChipDataFromDat", null)
        } else {
          result.success(chipCatalog.families())
        }
      }
      "getChipModelsByFamily" -> {
        if (!chipCatalog.isLoaded()) {
          result.error("CHIP_DATA_NOT_LOADED", "Load chip data first using loadChipDataFromDat", null)
        } else {
          val family = call.argument<String>("family")
          if (family.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "family is required", null)
          } else {
            result.success(chipCatalog.modelsByFamily(family))
          }
        }
      }
      "autoDetectChip" -> {
        if (!chipCatalog.isLoaded()) {
          result.error("CHIP_DATA_NOT_LOADED", "Load chip data first using loadChipDataFromDat", null)
        } else {
          runAsync(result, "AUTO_DETECT_ERROR") {
            val detected = usbDriver?.autoDetectTarget(chipCatalog)
              ?: throw IllegalStateException("USB driver is unavailable")
            if (detected["found"] == true) {
              selectedPartInfo = mapOf(
                "model" to (detected["model"] ?: ""),
                ("flashSize" to detected["flashSize"]?.toString()),
                ("eepromSize" to detected["eepromSize"]?.toString()),
                "bytesPerLocation" to 2,
                "eeMemBytesPerWord" to 1,
                "eeAddr" to 0,
                "configWords" to 0,
              ) as Map<String, Any>
            }
            detected
          }
        }
      }
      "selectChip" -> {
        val model = call.argument<String>("model") ?: ""
        val flashSize = call.argument<String>("flashSize") ?: "0"
        val eepromSize = call.argument<String>("eepromSize") ?: "0"
        val bytesPerLocation = call.argument<Int>("bytesPerLocation") ?: 2
        val eeMemBytesPerWord = call.argument<Int>("eeMemBytesPerWord") ?: 1
        val eeAddr = call.argument<Int>("eeAddr") ?: 0
        val configWords = call.argument<Int>("configWords") ?: 0
        selectedPartInfo = mapOf(
          "model" to model,
          "flashSize" to flashSize,
          "eepromSize" to eepromSize,
          "bytesPerLocation" to bytesPerLocation,
          "eeMemBytesPerWord" to eeMemBytesPerWord,
          "eeAddr" to eeAddr,
          "configWords" to configWords,
        )
        result.success(true)
      }
      "eraseChip" -> {
        if (!chipCatalog.isLoaded()) {
          result.error("CHIP_DATA_NOT_LOADED", "Load chip data first using loadChipDataFromDat", null)
        } else {
          runAsync(result, "ERASE_ERROR") {
            usbDriver?.eraseChip(chipCatalog) ?: throw IllegalStateException("USB driver is unavailable")
          }
        }
      }
      "readChip" -> {
        if (!chipCatalog.isLoaded()) {
          result.error("CHIP_DATA_NOT_LOADED", "Load chip data first using loadChipDataFromDat", null)
        } else {
          runAsync(result, "READ_ERROR") {
            usbDriver?.readChip(chipCatalog, selectedPartInfo) ?: throw IllegalStateException("USB driver is unavailable")
          }
        }
      }
      "saveHexFile" -> {
        val path = call.argument<String>("path")
        val data = call.argument<List<Int>>("data") ?: emptyList()
        val addressIncrement = call.argument<Int>("addressIncrement") ?: 1
        val bytesPerWord = call.argument<Int>("bytesPerWord") ?: 2
        try {
          val success = saveHexFile(path, data, addressIncrement, bytesPerWord)
          result.success(success)
        } catch (e: Exception) {
          result.error("HEX_SAVE_ERROR", e.message, null)
        }
      }
      "getFirmwareVersion" -> {
        try {
          result.success(usbDriver?.getFirmwareVersion())
        } catch (e: Exception) {
          result.error("FW_VERSION_ERROR", e.message, null)
        }
      }
      "writeFirmware" -> {
        if (!chipCatalog.isLoaded()) {
          result.error("CHIP_DATA_NOT_LOADED", "Load chip data first using loadChipData", null)
        } else if (selectedPartInfo.isEmpty()) {
          result.error("NO_CHIP_SELECTED", "Select a target chip first", null)
        } else if (!loadedImage.isEmpty()) {
          // Use the already-loaded image; write with progress callbacks
          runAsync(result, "WRITE_ERROR") {
            val totalSteps = 6
            var lastProgress = 0
            val success = usbDriver?.writeFirmware(
              catalog = chipCatalog,
              partInfo = selectedPartInfo,
              image = loadedImage,
              skipBlankCheck = false,
              progressCallback = { phase, percent, message ->
                lastProgress = percent
                mainHandler.post {
                  channel.invokeMethod("onWriteProgress", mapOf(
                    "phase" to phase,
                    "percent" to percent,
                    "message" to message,
                  ))
                }
              },
            ) ?: throw IllegalStateException("USB driver is unavailable")
            mapOf("success" to success, "message" to if (success) "Write complete" else "Write failed")
          }
        } else {
          result.error("NO_IMAGE", "Load a firmware file first", null)
        }
      }
      else -> result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    usbDriver?.destroy()
    usbDriver = null
    backgroundExecutor.shutdownNow()
  }

  private fun loadHexFile(path: String?): Map<String, Any> {
    if (path == null) {
      throw IllegalArgumentException("Path is required")
    }
    val file = File(path)
    if (!file.exists()) {
      throw IllegalArgumentException("HEX file not found: $path")
    }
    loadedImage.clear()
    loadedImage.setSource("hex", path)

    var upperLinear = 0
    var upperSegment = 0
    FileReader(file).useLines { lines ->
      for (line in lines) {
        val trimmed = line.trim().uppercase()
        if (trimmed.isEmpty()) continue
        if (!trimmed.startsWith(":") || trimmed.length < 11) continue

        val count = trimmed.substring(1, 3).toInt(16)
        val offset = trimmed.substring(3, 7).toInt(16)
        val recType = trimmed.substring(7, 9).toInt(16)
        val dataStart = 9

        when (recType) {
          0x00 -> {
            val base = (upperLinear shl 16) + (upperSegment shl 4) + offset
            for (i in 0 until count) {
              val b = trimmed.substring(dataStart + i * 2, dataStart + i * 2 + 2).toInt(16)
              loadedImage.putByte(base + i, b)
            }
          }
          0x01 -> return loadedImage.summary()
          0x02 -> {
            upperSegment = trimmed.substring(dataStart, dataStart + 4).toInt(16)
            upperLinear = 0
          }
          0x04 -> {
            upperLinear = trimmed.substring(dataStart, dataStart + 4).toInt(16)
            upperSegment = 0
          }
        }
      }
    }
    return loadedImage.summary()
  }

  private fun loadBinFile(path: String?, baseAddress: Int): Map<String, Any> {
    if (path == null) {
      throw IllegalArgumentException("Path is required")
    }
    val file = File(path)
    if (!file.exists()) {
      throw IllegalArgumentException("BIN file not found: $path")
    }
    loadedImage.clear()
    loadedImage.setSource("bin", path)

    BufferedInputStream(java.io.FileInputStream(file)).use { input ->
      var offset = 0
      var b: Int
      while (input.read().also { b = it } >= 0) {
        loadedImage.putByte(baseAddress + offset, b and 0xFF)
        offset++
      }
    }
    return loadedImage.summary()
  }

  private fun runAsync(
    result: Result,
    errorCode: String,
    task: () -> Any,
  ) {
    backgroundExecutor.execute {
      try {
        val value = task()
        mainHandler.post { result.success(value) }
      } catch (e: Exception) {
        mainHandler.post { result.error(errorCode, e.message, null) }
      }
    }
  }

  private fun saveHexFile(path: String?, data: List<Int>, addressIncrement: Int, bytesPerWord: Int): Boolean {
    if (path == null) {
      throw IllegalArgumentException("Path is required")
    }
    val file = File(path)
    file.printWriter().use { out ->
      out.println(":020000040000FA")
      val arrayIncrement = 16 / bytesPerWord
      for (arrayIndex in data.indices step arrayIncrement) {
        val endIndex = min(arrayIndex + arrayIncrement, data.size)
        val validBytes = (endIndex - arrayIndex) * bytesPerWord
        val fileAddress = arrayIndex / arrayIncrement * 16
        if (validBytes > 0) {
          val hexLine = buildString {
            append(":").append(String.format("%02X", validBytes)).append(String.format("%04X", fileAddress)).append("00")
            for (i in arrayIndex until endIndex) {
              val word = data[i] and 0xFFFFFF
              for (j in 0 until bytesPerWord) {
                append(String.format("%02X", (word shr (8 * (bytesPerWord - 1 - j)) and 0xFF)))
              }
            }
            val checksum = computeChecksum(this.toString())
            append(String.format("%02X", checksum))
          }
          out.println(hexLine)
        }
      }
      out.println(":00000001FF")
    }
    return true
  }

  private fun computeChecksum(line: String): Int {
    var checksum = 0
    for (i in 1 until line.length step 2) {
      checksum += line.substring(i, i + 2).toInt(16)
    }
    return (0 - checksum) and 0xFF
  }
}