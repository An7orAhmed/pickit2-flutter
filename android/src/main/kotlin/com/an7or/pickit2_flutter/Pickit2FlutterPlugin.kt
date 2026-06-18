package com.an7or.pickit2_flutter

import android.content.Context
import android.os.Handler
import android.os.Looper
import java.io.BufferedInputStream
import java.io.BufferedReader
import java.io.File
import java.io.FileReader
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class Pickit2FlutterPlugin : FlutterPlugin, MethodCallHandler {
  private lateinit var channel: MethodChannel
  private lateinit var context: Context
  private var usbDriver: PICkitUsbDriver? = null
  private val chipCatalog = ChipCatalog()
  private val backgroundExecutor: ExecutorService = Executors.newSingleThreadExecutor()
  private val mainHandler = Handler(Looper.getMainLooper())

  private val loadedImage = ProgramImage()

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    context = flutterPluginBinding.applicationContext
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "pickit2_flutter")
    channel.setMethodCallHandler(this)

    // Initialize driver immediately so it can auto-detect the USB
    usbDriver = PICkitUsbDriver(context)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    if (call.method == "connect") {
      usbDriver?.connect(object : PICkitUsbDriver.UsbCallback {
        override fun onConnectionSuccess() {
          result.success("Connected to PICkit 2 successfully!")
        }

        override fun onConnectionFailed(error: String) {
          result.error("USB_ERROR", error, null)
        }
      })

    } else if (call.method == "disconnect") {
      usbDriver?.disconnect()
      result.success("Disconnected")

    } else if (call.method == "getSerialNumber") {
      try {
        result.success(usbDriver?.getSerialNumber())
      } catch (e: Exception) {
        result.error("SERIAL_ERROR", e.message, null)
      }

    } else if (call.method == "loadHexFile") {
      val path = call.argument<String>("path")
      try {
        result.success(loadHexFile(path))
      } catch (e: Exception) {
        result.error("HEX_LOAD_ERROR", e.message, null)
      }

    } else if (call.method == "loadBinFile") {
      val path = call.argument<String>("path")
      val baseAddress = call.argument<Int>("baseAddress") ?: 0
      try {
        result.success(loadBinFile(path, baseAddress))
      } catch (e: Exception) {
        result.error("BIN_LOAD_ERROR", e.message, null)
      }

    } else if (call.method == "clearLoadedImage") {
      loadedImage.clear()
      result.success(true)

    } else if (call.method == "getLoadedImageInfo") {
      result.success(loadedImage.summary())

    } else if (call.method == "loadChipData" || call.method == "loadChipDataFromDat") {
      runAsync(
        result = result,
        errorCode = "CHIP_DATA_ERROR",
      ) {
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

    } else if (call.method == "getChipCatalog") {
      if (!chipCatalog.isLoaded()) {
        result.error("CHIP_DATA_NOT_LOADED", "Load chip data first using loadChipDataFromDat", null)
      } else {
        result.success(chipCatalog.all())
      }

    } else if (call.method == "getChipFamilies") {
      if (!chipCatalog.isLoaded()) {
        result.error("CHIP_DATA_NOT_LOADED", "Load chip data first using loadChipDataFromDat", null)
      } else {
        result.success(chipCatalog.families())
      }

    } else if (call.method == "getChipModelsByFamily") {
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

    } else if (call.method == "autoDetectChip") {
      if (!chipCatalog.isLoaded()) {
        result.error("CHIP_DATA_NOT_LOADED", "Load chip data first using loadChipDataFromDat", null)
      } else {
        runAsync(
          result = result,
          errorCode = "AUTO_DETECT_ERROR",
        ) {
          usbDriver?.autoDetectTarget(chipCatalog)
            ?: throw IllegalStateException("USB driver is unavailable")
        }
      }

    } else if (call.method == "getFirmwareVersion") {
      try {
        result.success(usbDriver?.getFirmwareVersion())
      } catch (e: Exception) {
        result.error("FW_VERSION_ERROR", e.message, null)
      }

    } else {
      result.notImplemented()
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
        var trimmed = line.trim().uppercase()
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
}