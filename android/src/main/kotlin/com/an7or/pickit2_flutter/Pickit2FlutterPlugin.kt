package com.an7or.pickit2_flutter

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class Pickit2FlutterPlugin : FlutterPlugin, MethodCallHandler {
  private lateinit var channel: MethodChannel
  private lateinit var context: Context
  private var usbDriver: PICkitUsbDriver? = null

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