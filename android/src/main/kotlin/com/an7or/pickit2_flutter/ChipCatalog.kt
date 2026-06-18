package com.an7or.pickit2_flutter

import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.Locale

private data class ChipRecord(
  val model: String,
  val deviceId: String,
  val flashSize: String,
  val ramSize: String,
  val eepromSize: String,
)

data class FamilyDetectInfo(
  val familyId: Int,
  val familyType: Int,
  val searchPriority: Int,
  val familyName: String,
  val partDetect: Boolean,
  val progEntryScript: Int,
  val progEntryVppScript: Int,
  val progExitScript: Int,
  val readDevIdScript: Int,
  val deviceIdMask: Int,
  val blankValue: Int,
  val progMemShift: Int,
  val vpp: Float,
  val bytesPerLocation: Int,
  val eeMemBytesPerWord: Int,
)

data class PartDetectInfo(
  val model: String,
  val familyId: Int,
  val deviceId: Int,
)

data class ScriptInfo(
  val scriptNumber: Int,
  val script: ByteArray,
)

class ChipCatalog {
  private val catalog = linkedMapOf<String, MutableList<ChipRecord>>()
  private val familyDetect = linkedMapOf<Int, FamilyDetectInfo>()
  private val partDetect = mutableListOf<PartDetectInfo>()
  private val scriptByNumber = linkedMapOf<Int, ScriptInfo>()

  private val defaultPartTrailerBytes = 0
  private val legacyPartTrailerBytes = 8

  fun clear() {
    catalog.clear()
    familyDetect.clear()
    partDetect.clear()
    scriptByNumber.clear()
  }

  fun loadFromDat(datBytes: ByteArray): Int {
    var firstError: Exception? = null
    val layouts = intArrayOf(defaultPartTrailerBytes, legacyPartTrailerBytes)

    for (layout in layouts) {
      clear()
      try {
        parseBinary(datBytes, layout)
        return totalModelCount()
      } catch (e: Exception) {
        if (firstError == null) {
          firstError = e
        }
      }
    }

    throw IllegalArgumentException(
      "Failed to parse PK2DeviceFile.dat: ${firstError?.message ?: "unknown error"}",
    )
  }

  fun isLoaded(): Boolean = catalog.isNotEmpty() && familyDetect.isNotEmpty() && scriptByNumber.isNotEmpty()

  fun families(): List<String> = catalog.keys.toList()

  fun modelsByFamily(family: String): List<Map<String, String>> {
    return catalog[family].orEmpty().map {
      mapOf(
        "model" to it.model,
        "deviceId" to it.deviceId,
        "flashSize" to it.flashSize,
        "ramSize" to it.ramSize,
        "eepromSize" to it.eepromSize,
      )
    }
  }

  fun all(): Map<String, List<Map<String, String>>> {
    return catalog.mapValues { (_, records) ->
      records.map {
        mapOf(
          "model" to it.model,
          "deviceId" to it.deviceId,
          "flashSize" to it.flashSize,
          "ramSize" to it.ramSize,
          "eepromSize" to it.eepromSize,
        )
      }
    }
  }

  fun detectFamilyOrder(): List<FamilyDetectInfo> {
    return familyDetect.values
      .filter { it.partDetect }
      .sortedWith(compareBy<FamilyDetectInfo> { it.searchPriority }.thenBy { it.familyType }.thenBy { it.familyId })
  }

  fun findPartByFamilyAndDeviceId(familyId: Int, deviceId: Int): PartDetectInfo? {
    return partDetect.firstOrNull { it.familyId == familyId && it.deviceId == deviceId }
  }

  fun scriptByNumber(scriptNumber: Int): ScriptInfo? = scriptByNumber[scriptNumber]

  private fun parseBinary(datBytes: ByteArray, partTrailerBytes: Int) {
    val reader = BinaryDatReader(datBytes)

    reader.readInt32()
    reader.readInt32()
    reader.readInt32()
    reader.readString()
    val numberFamilies = reader.readInt32()
    val numberParts = reader.readInt32()
    val numberScripts = reader.readInt32()
    reader.readUInt8()
    reader.readUInt8()
    reader.readUInt16()
    reader.readUInt32()

    repeat(numberFamilies) {
      val familyId = reader.readUInt16()
      val familyType = reader.readUInt16()
      val searchPriority = reader.readUInt16()
      val familyName = reader.readString().trim().ifBlank { "Family $familyId" }
      val progEntryScript = reader.readUInt16()
      val progExitScript = reader.readUInt16()
      val readDevIdScript = reader.readUInt16()
      val deviceIdMask = reader.readUInt32()
      val blankValue = reader.readUInt32()
      val bytesPerLocation = reader.readUInt8()
      reader.readUInt8()
      val partDetectEnabled = reader.readBool()
      val progEntryVppScript = reader.readUInt16()
      reader.readUInt16()
      val eeMemBytesPerWord = reader.readUInt8()
      reader.readUInt8()
      reader.readUInt8()
      reader.readUInt8()
      reader.readUInt8()
      reader.readUInt8()
      val progMemShift = reader.readUInt8()
      reader.readUInt32()
      reader.readUInt16()
      val vpp = reader.readFloat32()

      familyDetect[familyId] = FamilyDetectInfo(
        familyId = familyId,
        familyType = familyType,
        searchPriority = searchPriority,
        familyName = familyName,
        partDetect = partDetectEnabled,
        progEntryScript = progEntryScript,
        progEntryVppScript = progEntryVppScript,
        progExitScript = progExitScript,
        readDevIdScript = readDevIdScript,
        deviceIdMask = deviceIdMask,
        blankValue = blankValue,
        progMemShift = progMemShift,
        vpp = vpp,
        bytesPerLocation = bytesPerLocation,
        eeMemBytesPerWord = eeMemBytesPerWord,
      )
    }

    var parsedParts = 0
    var sanePartNames = 0

    repeat(numberParts) {
      val partName = reader.readString().trim().uppercase(Locale.US)
      val familyId = reader.readUInt16()
      val rawDeviceId = reader.readUInt32()
      val programMem = reader.readUInt32()
      val eeMem = reader.readUInt16()

      reader.readUInt32()
      reader.readUInt8()
      reader.readUInt32()
      reader.readUInt8()
      reader.readUInt32()
      reader.readUInt32()
      repeat(8) { reader.readUInt16() }
      repeat(8) { reader.readUInt16() }
      reader.readUInt16()
      reader.readUInt8()
      reader.readBool()
      reader.readUInt32()
      reader.readFloat32()
      reader.readFloat32()
      reader.readFloat32()
      reader.readUInt8()
      reader.readUInt16()
      reader.readUInt16()
      reader.readUInt8()
      reader.readUInt16()
      reader.readUInt16()
      reader.readUInt16()
      reader.readUInt16()
      reader.readUInt16()
      reader.readUInt16()
      reader.readUInt16()
      reader.readUInt16()
      reader.readUInt16()
      reader.readUInt16()
      reader.readUInt16()
      reader.readUInt16()
      reader.readUInt8()
      reader.readUInt32()
      reader.readUInt16()
      reader.readUInt16()
      reader.readUInt16()
      reader.readUInt16()
      reader.readUInt16()
      reader.readUInt16()
      reader.readUInt16()
      reader.readUInt16()
      reader.readUInt16()
      reader.readUInt16()
      reader.readUInt16()
      reader.readBool()
      reader.readBool()
      reader.readUInt16()
      reader.readUInt16()
      reader.readUInt32()
      reader.readUInt16()
      reader.readUInt16()
      reader.readUInt16()
      reader.readUInt16()
      reader.readUInt16()
      reader.readUInt16()
      reader.readUInt16()
      reader.readUInt16()
      reader.readUInt16()
      reader.readUInt16()
      reader.readBool()
      repeat(15) { reader.readUInt16() }
      reader.readUInt16()
      reader.skip(partTrailerBytes)

      if (partName.isBlank()) {
        return@repeat
      }

      parsedParts++
      if (isSanePartName(partName)) {
        sanePartNames++
      }

      val family = familyDetect[familyId]
      val familyName = family?.familyName ?: "Family $familyId"
      val bytesPerLocation = family?.bytesPerLocation ?: 1
      val eeBytesPerWord = family?.eeMemBytesPerWord ?: 1
      val maskedId = normalizeDeviceId(rawDeviceId, family)

      if (partName == "UNSUPPORTED PART" || maskedId == 0 || maskedId == 0xFFFF) {
        return@repeat
      }

      val flashBytes = programMem.toLong() * bytesPerLocation
      val eepromBytes = eeMem.toLong() * eeBytesPerWord

      partDetect.add(
        PartDetectInfo(
          model = partName,
          familyId = familyId,
          deviceId = maskedId,
        ),
      )

      addRecord(
        family = familyName,
        model = partName,
        deviceId = formatHex(maskedId),
        flash = formatBytes(flashBytes),
        ram = "N/A",
        eeprom = formatBytes(eepromBytes),
      )
    }

    repeat(numberScripts) {
      val scriptNumber = reader.readUInt16()
      reader.readString()
      reader.readUInt16()
      reader.readUInt32()
      val scriptLength = reader.readUInt16()
      val scriptBytes = ByteArray(scriptLength.coerceAtLeast(0))
      for (i in 0 until scriptLength) {
        scriptBytes[i] = (reader.readUInt16() and 0xFF).toByte()
      }
      reader.readString()

      if (scriptNumber > 0 && scriptBytes.isNotEmpty()) {
        scriptByNumber[scriptNumber] = ScriptInfo(scriptNumber = scriptNumber, script = scriptBytes)
      }
    }

    if (parsedParts > 0 && (parsedParts < minOf(200, numberParts / 2) || sanePartNames * 2 < parsedParts)) {
      throw IllegalArgumentException("Device file parsed with invalid part-name layout")
    }
  }

  private fun normalizeDeviceId(rawId: Int, family: FamilyDetectInfo?): Int {
    if (family == null) {
      return rawId
    }

    var deviceId = rawId
    repeat(family.progMemShift.coerceAtLeast(0)) {
      deviceId = deviceId ushr 1
    }

    deviceId = deviceId and family.deviceIdMask

    if (isEepromFamily(family) && family.deviceIdMask == 0x00FFFFFF) {
      deviceId = ((deviceId shl 16) and 0x00FF0000) or (deviceId and 0x0000FF00) or ((deviceId ushr 16) and 0x000000FF)
    }

    if (family.familyName.startsWith("Midrange/1.8V Min MSB1st")) {
      deviceId = reverse16Bits(deviceId)
      deviceId = deviceId ushr 2
    } else if (family.familyName.startsWith("PIC18/PIC18F MSB1st")) {
      deviceId = reverse16Bits(deviceId)
    }

    return deviceId and family.deviceIdMask
  }

  private fun isEepromFamily(family: FamilyDetectInfo): Boolean {
    return family.familyName.startsWith("EEPROMS")
  }

  private fun addRecord(
    family: String,
    model: String,
    deviceId: String,
    flash: String,
    ram: String,
    eeprom: String,
  ) {
    val normalizedFamily = family.trim().ifBlank { "Unknown Family" }
    val normalizedModel = model.trim().uppercase(Locale.US)

    val familyList = catalog.getOrPut(normalizedFamily) { mutableListOf() }
    if (familyList.any { it.model == normalizedModel }) {
      return
    }

    familyList.add(
      ChipRecord(
        model = normalizedModel,
        deviceId = deviceId,
        flashSize = flash,
        ramSize = ram,
        eepromSize = eeprom,
      ),
    )
  }

  private fun totalModelCount(): Int = catalog.values.sumOf { it.size }

  private fun formatHex(value: Int): String {
    return "0x${value.toUInt().toString(16).uppercase(Locale.US)}"
  }

  private fun formatBytes(value: Long): String {
    if (value <= 0L) {
      return "0 B"
    }

    return when {
      value >= 1024L * 1024L -> "${formatWithOneDecimal(value / (1024.0 * 1024.0))} MB"
      value >= 1024L -> "${formatWithOneDecimal(value / 1024.0)} KB"
      else -> "$value B"
    }
  }

  private fun formatWithOneDecimal(value: Double): String {
    return String.format(Locale.US, "%.1f", value)
  }

  private fun reverse16Bits(value: Int): Int {
    var result = 0
    var input = value and 0xFFFF
    for (i in 0 until 16) {
      result = (result shl 1) or (input and 1)
      input = input ushr 1
    }
    return result and 0xFFFF
  }

  private fun isSanePartName(name: String): Boolean {
    if (name.isBlank()) {
      return false
    }
    if (name == "UNSUPPORTED PART") {
      return true
    }
    if (!(name.startsWith("PIC") || name.startsWith("DSPIC") || name.startsWith("MCP") || name.startsWith("AT"))) {
      return false
    }
    return name.all { ch -> ch.code in 32..126 }
  }
}

private class BinaryDatReader(private val data: ByteArray) {
  private var offset = 0

  fun readUInt8(): Int {
    requireRemaining(1)
    return data[offset++].toInt() and 0xFF
  }

  fun readBool(): Boolean {
    return readUInt8() != 0
  }

  fun readUInt16(): Int {
    requireRemaining(2)
    val value = ByteBuffer.wrap(data, offset, 2).order(ByteOrder.LITTLE_ENDIAN).short.toInt() and 0xFFFF
    offset += 2
    return value
  }

  fun readInt32(): Int {
    requireRemaining(4)
    val value = ByteBuffer.wrap(data, offset, 4).order(ByteOrder.LITTLE_ENDIAN).int
    offset += 4
    return value
  }

  fun readUInt32(): Int {
    return readInt32()
  }

  fun readFloat32(): Float {
    requireRemaining(4)
    val value = ByteBuffer.wrap(data, offset, 4).order(ByteOrder.LITTLE_ENDIAN).float
    offset += 4
    return value
  }

  fun readString(): String {
    val first = readUInt8()
    var length = first and 0x7F
    if ((first and 0x80) != 0) {
      val second = readUInt8()
      length += second * 0x80
    }

    requireRemaining(length)
    val value = String(data, offset, length, Charsets.ISO_8859_1)
    offset += length
    return value
  }

  fun skip(bytes: Int) {
    if (bytes <= 0) {
      return
    }
    requireRemaining(bytes)
    offset += bytes
  }

  private fun requireRemaining(bytes: Int) {
    if (offset + bytes > data.size) {
      throw IllegalArgumentException("Unexpected end of PK2DeviceFile.dat at offset=$offset")
    }
  }
}
