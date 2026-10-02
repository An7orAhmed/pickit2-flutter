package com.an7or.pickit2_flutter

import org.json.JSONArray
import org.json.JSONObject

class NativePk2Engine(
  deviceFilePath: String,
  private val progress: (String, Int, String) -> Unit,
) : AutoCloseable {
  companion object {
    init {
      System.loadLibrary("pickit2_flutter")
    }
  }

  private var handle = nativeCreate(deviceFilePath)

  @Synchronized
  fun attachUsb(fileDescriptor: Int, serialNumber: String): Boolean {
    return nativeAttachUsb(checkedHandle(), fileDescriptor, serialNumber)
  }

  @Synchronized
  fun connect(): Map<String, Any?> = parseObject(nativeConnect(checkedHandle()))

  @Synchronized
  fun disconnect() {
    if (handle != 0L) nativeDisconnect(handle)
  }

  @Synchronized
  fun selectPart(partName: String): Map<String, Any?> {
    return parseObject(nativeSelectPart(checkedHandle(), partName))
  }

  @Synchronized
  fun autoDetect(): Map<String, Any?> = parseObject(nativeAutoDetect(checkedHandle()))

  @Synchronized
  fun erase(): Boolean = nativeErase(checkedHandle())

  @Synchronized
  fun blankCheck(): Map<String, Any?> = parseObject(nativeBlankCheck(checkedHandle()))

  @Synchronized
  fun read(): Map<String, Any?> = parseObject(nativeRead(checkedHandle()))

  @Synchronized
  fun writeHex(path: String): Map<String, Any?> {
    return parseObject(nativeWriteHex(checkedHandle(), path))
  }

  @Synchronized
  fun verifyHex(path: String): Map<String, Any?> {
    return parseObject(nativeVerifyHex(checkedHandle(), path))
  }

  @Synchronized
  fun exportHex(path: String): Boolean = nativeExportHex(checkedHandle(), path)

  @Suppress("unused")
  private fun onNativeProgress(phase: String, percent: Int, message: String) {
    progress(phase, percent, message)
  }

  @Synchronized
  override fun close() {
    if (handle != 0L) {
      nativeDestroy(handle)
      handle = 0L
    }
  }

  private fun checkedHandle(): Long {
    check(handle != 0L) { "PICkit 2 native engine is closed" }
    return handle
  }

  private fun parseObject(json: String): Map<String, Any?> = JSONObject(json).toMap()

  private fun JSONObject.toMap(): Map<String, Any?> {
    return keys().asSequence().associateWith { key -> get(key).toKotlinValue() }
  }

  private fun JSONArray.toList(): List<Any?> {
    return (0 until length()).map { index -> get(index).toKotlinValue() }
  }

  private fun Any.toKotlinValue(): Any? {
    return when (this) {
      JSONObject.NULL -> null
      is JSONObject -> toMap()
      is JSONArray -> toList()
      else -> this
    }
  }

  private external fun nativeCreate(deviceFilePath: String): Long
  private external fun nativeDestroy(handle: Long)
  private external fun nativeAttachUsb(handle: Long, fileDescriptor: Int, serialNumber: String): Boolean
  private external fun nativeConnect(handle: Long): String
  private external fun nativeDisconnect(handle: Long)
  private external fun nativeSelectPart(handle: Long, partName: String): String
  private external fun nativeAutoDetect(handle: Long): String
  private external fun nativeErase(handle: Long): Boolean
  private external fun nativeBlankCheck(handle: Long): String
  private external fun nativeRead(handle: Long): String
  private external fun nativeWriteHex(handle: Long, path: String): String
  private external fun nativeVerifyHex(handle: Long, path: String): String
  private external fun nativeExportHex(handle: Long, path: String): Boolean
}
