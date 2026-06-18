package com.an7or.pickit2_flutter

import android.content.Context
import android.os.Handler
import android.os.Looper
import java.io.File
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