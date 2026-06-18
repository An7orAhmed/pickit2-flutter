package com.an7or.pickit2_flutter

import android.content.Context
import java.io.File
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

    } else if (call.method == "loadChipDataFromDat") {
      try {
        val filePath = call.argument<String>("filePath")
        val datBytes = if (filePath.isNullOrBlank()) {
          context.assets.open("PK2DeviceFile.dat").use { it.readBytes() }
        } else {
          File(filePath).readBytes()
        }

        val loadedModelCount = chipCatalog.loadFromDat(datBytes)
        if (loadedModelCount <= 0) {
          result.error("CHIP_DATA_ERROR", "No chip models parsed from .dat file", null)
        } else {
          result.success(
            mapOf(
              "loaded" to true,
              "familyCount" to chipCatalog.families().size,
              "modelCount" to loadedModelCount,
            ),
          )
        }
      } catch (e: Exception) {
        result.error("CHIP_DATA_ERROR", e.message, null)
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
        try {
          result.success(usbDriver?.autoDetectTarget(chipCatalog))
        } catch (e: Exception) {
          result.error("AUTO_DETECT_ERROR", e.message, null)
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
  }
}