package com.an7or.pickit2_flutter

import java.io.File
import java.util.TreeMap

class ProgramImage {
  private val bytes = TreeMap<Int, Int>()
  private var sourcePath = ""
  private var sourceType = ""

  fun clear() {
    bytes.clear()
    sourcePath = ""
    sourceType = ""
  }

  fun copy(): ProgramImage {
    val out = ProgramImage()
    out.sourcePath = sourcePath
    out.sourceType = sourceType
    out.bytes.putAll(bytes)
    return out
  }

  fun replaceWith(source: ProgramImage) {
    sourcePath = source.sourcePath
    sourceType = source.sourceType
    bytes.clear()
    bytes.putAll(source.bytes)
  }

  fun setSource(sourceType: String, sourcePath: String) {
    this.sourceType = sourceType
    this.sourcePath = sourcePath
  }

  fun putByte(address: Int, value: Int) {
    if (address < 0) return
    bytes[address] = value and 0xFF
  }

  fun getByte(address: Int): Int? = bytes[address]

  fun isEmpty(): Boolean = bytes.isEmpty()

  fun minAddress(): Int = if (bytes.isEmpty()) 0 else bytes.firstKey()

  fun maxAddress(): Int = if (bytes.isEmpty()) 0 else bytes.lastKey()

  fun size(): Int = bytes.size

  fun checksum16(): Int {
    var checksum = 0
    for (value in bytes.values) {
      checksum = (checksum + (value and 0xFF)) and 0xFFFF
    }
    return checksum
  }

  fun readRange(startAddress: Int, length: Int, blankValue: Int): ByteArray {
    val out = ByteArray(length) { (blankValue and 0xFF).toByte() }
    for (i in 0 until length) {
      bytes[startAddress + i]?.let { v ->
        out[i] = (v and 0xFF).toByte()
      }
    }
    return out
  }

  fun summary(): Map<String, Any> {
    val map = TreeMap<String, Any>()
    map["sourceType"] = sourceType
    map["sourcePath"] = sourcePath
    map["loadedBytes"] = size()
    map["minAddress"] = minAddress()
    map["maxAddress"] = maxAddress()
    map["isEmpty"] = isEmpty()
    return map
  }

  fun getBytes(): Map<Int, Int> = bytes

  fun writeHex(file: File) {
    file.bufferedWriter().use { output ->
      var upperAddress = -1
      val entries = bytes.entries.toList()
      var index = 0
      while (index < entries.size) {
        val startAddress = entries[index].key
        val nextUpperAddress = startAddress ushr 16
        if (nextUpperAddress != upperAddress) {
          upperAddress = nextUpperAddress
          output.appendLine(record(0, 0x04, byteArrayOf(
            ((upperAddress ushr 8) and 0xFF).toByte(),
            (upperAddress and 0xFF).toByte(),
          )))
        }

        val data = ArrayList<Byte>(16)
        var expectedAddress = startAddress
        while (
          index < entries.size &&
          entries[index].key == expectedAddress &&
          entries[index].key ushr 16 == upperAddress &&
          data.size < 16
        ) {
          data.add(entries[index].value.toByte())
          expectedAddress++
          index++
        }
        output.appendLine(record(startAddress and 0xFFFF, 0x00, data.toByteArray()))
      }
      output.appendLine(":00000001FF")
    }
  }

  private fun record(address: Int, type: Int, data: ByteArray): String {
    val values = ArrayList<Int>(data.size + 4)
    values.add(data.size)
    values.add((address ushr 8) and 0xFF)
    values.add(address and 0xFF)
    values.add(type)
    data.forEach { values.add(it.toInt() and 0xFF) }
    val checksum = (-values.sum()) and 0xFF
    return buildString {
      append(':')
      values.forEach { append("%02X".format(it)) }
      append("%02X".format(checksum))
    }
  }
}
