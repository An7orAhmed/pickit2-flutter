package com.an7or.pickit2_flutter

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.os.Build

class PICkitUsbDriver(
  private val context: Context,
  private val onDeviceDetached: () -> Unit,
) {
  interface UsbCallback {
    fun onConnectionSuccess()
    fun onConnectionFailed(error: String)
  }

  companion object {
    private const val ACTION_USB_PERMISSION = "com.an7or.pickit2_flutter.USB_PERMISSION"
    private const val PICKIT2_VID = 0x04D8
    private const val PICKIT2_PID = 0x0033
  }

  private val usbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager
  private var device: UsbDevice? = null
  private var connection: UsbDeviceConnection? = null
  private var usbInterface: UsbInterface? = null
  private var endpointIn: UsbEndpoint? = null
  private var endpointOut: UsbEndpoint? = null
  private var pendingCallback: UsbCallback? = null

  private val receiver = object : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
      when (intent.action) {
        ACTION_USB_PERMISSION -> handlePermissionResult(intent)
        UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
          intent.usbDevice()?.takeIf(::isPICkit2)?.let { device = it }
        }
        UsbManager.ACTION_USB_DEVICE_DETACHED -> {
          val detached = intent.usbDevice()
          if (detached != null && detached.deviceId == device?.deviceId) {
            disconnect()
            device = null
            onDeviceDetached()
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
      context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
    } else {
      context.registerReceiver(receiver, filter)
    }
    device = findPICkit2()
  }

  fun connect(callback: UsbCallback) {
    if (isOpen()) {
      callback.onConnectionSuccess()
      return
    }

    val attached = findPICkit2()
    if (attached == null) {
      callback.onConnectionFailed("PICkit 2 not found. Check the OTG cable and power.")
      return
    }
    device = attached
    pendingCallback = callback

    if (usbManager.hasPermission(attached)) {
      open(attached)
    } else {
      val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
      val permissionIntent = PendingIntent.getBroadcast(
        context,
        0,
        Intent(ACTION_USB_PERMISSION).setPackage(context.packageName),
        flags,
      )
      usbManager.requestPermission(attached, permissionIntent)
    }
  }

  fun disconnect() {
    disconnectConnectionOnly()
    pendingCallback = null
  }

  fun fileDescriptor(): Int {
    return connection?.fileDescriptor
      ?: throw IllegalStateException("PICkit 2 USB connection is not open")
  }

  fun serialNumber(): String {
    val attached = device ?: throw IllegalStateException("PICkit 2 is not attached")
    if (!usbManager.hasPermission(attached)) {
      throw SecurityException("USB permission is not granted")
    }
    return runCatching { attached.serialNumber }.getOrNull().orEmpty().trimEnd('\u0000')
  }

  fun destroy() {
    disconnect()
    runCatching { context.unregisterReceiver(receiver) }
  }

  private fun handlePermissionResult(intent: Intent) {
    val permittedDevice = intent.usbDevice()
    if (permittedDevice == null || !isPICkit2(permittedDevice)) {
      fail("USB permission response did not include the PICkit 2")
      return
    }
    if (!intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)) {
      fail("USB permission was denied")
      return
    }
    device = permittedDevice
    open(permittedDevice)
  }

  private fun open(attached: UsbDevice) {
    disconnectConnectionOnly()
    val targetInterface = (0 until attached.interfaceCount)
      .map(attached::getInterface)
      .firstOrNull { candidate ->
        (0 until candidate.endpointCount).map(candidate::getEndpoint).let { endpoints ->
          endpoints.any { it.type == UsbConstants.USB_ENDPOINT_XFER_INT && it.direction == UsbConstants.USB_DIR_IN } &&
            endpoints.any { it.type == UsbConstants.USB_ENDPOINT_XFER_INT && it.direction == UsbConstants.USB_DIR_OUT }
        }
      }
    if (targetInterface == null) {
      fail("PICkit 2 interrupt interface was not found")
      return
    }

    val opened = usbManager.openDevice(attached)
    if (opened == null) {
      fail("Unable to open the PICkit 2 USB device")
      return
    }
    if (!opened.claimInterface(targetInterface, true)) {
      opened.close()
      fail("Unable to claim the PICkit 2 USB interface")
      return
    }

    val endpoints = (0 until targetInterface.endpointCount).map(targetInterface::getEndpoint)
    val input = endpoints.firstOrNull {
      it.type == UsbConstants.USB_ENDPOINT_XFER_INT && it.direction == UsbConstants.USB_DIR_IN
    }
    val output = endpoints.firstOrNull {
      it.type == UsbConstants.USB_ENDPOINT_XFER_INT && it.direction == UsbConstants.USB_DIR_OUT
    }
    if (input == null || output == null) {
      opened.releaseInterface(targetInterface)
      opened.close()
      fail("PICkit 2 USB endpoints were not found")
      return
    }

    connection = opened
    usbInterface = targetInterface
    endpointIn = input
    endpointOut = output
    pendingCallback?.onConnectionSuccess()
    pendingCallback = null
  }

  private fun disconnectConnectionOnly() {
    val activeConnection = connection
    val activeInterface = usbInterface
    if (activeConnection != null && activeInterface != null) {
      activeConnection.releaseInterface(activeInterface)
    }
    activeConnection?.close()
    connection = null
    usbInterface = null
    endpointIn = null
    endpointOut = null
  }

  private fun fail(message: String) {
    disconnectConnectionOnly()
    pendingCallback?.onConnectionFailed(message)
    pendingCallback = null
  }

  private fun isOpen(): Boolean = connection != null && endpointIn != null && endpointOut != null

  private fun findPICkit2(): UsbDevice? = usbManager.deviceList.values.firstOrNull(::isPICkit2)

  private fun isPICkit2(candidate: UsbDevice): Boolean {
    return candidate.vendorId == PICKIT2_VID && candidate.productId == PICKIT2_PID
  }

  @Suppress("DEPRECATION")
  private fun Intent.usbDevice(): UsbDevice? {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
    } else {
      getParcelableExtra(UsbManager.EXTRA_DEVICE)
    }
  }
}
