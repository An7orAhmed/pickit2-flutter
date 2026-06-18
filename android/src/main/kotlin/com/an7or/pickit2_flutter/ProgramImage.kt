package com.an7or.pickit2_flutter

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
}