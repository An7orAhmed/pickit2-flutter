package com.an7or.pickit2_flutter

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.*
import android.os.Build
import android.util.Log

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
}