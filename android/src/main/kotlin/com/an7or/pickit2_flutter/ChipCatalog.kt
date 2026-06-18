package com.an7or.pickit2_flutter

import org.json.JSONArray
import org.json.JSONObject
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

  fun clear() {
    catalog.clear()
    familyDetect.clear()
    partDetect.clear()
    scriptByNumber.clear()
  }

  fun loadPrebuilt(catalogCsvBytes: ByteArray, detectJsonBytes: ByteArray): Int {
    clear()

    loadDetectMetadata(String(detectJsonBytes))
    loadCatalogRows(String(catalogCsvBytes))

    return totalModelCount()
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

  private fun loadDetectMetadata(jsonText: String) {
    val root = JSONObject(jsonText)

    val families = root.optJSONArray("families") ?: JSONArray()
    for (index in 0 until families.length()) {
      val item = families.optJSONObject(index) ?: continue
      val info = FamilyDetectInfo(
        familyId = item.optInt("familyId"),
        familyType = item.optInt("familyType"),
        searchPriority = item.optInt("searchPriority"),
        familyName = item.optString("familyName"),
        partDetect = item.optBoolean("partDetect"),
        progEntryScript = item.optInt("progEntryScript"),
        progEntryVppScript = item.optInt("progEntryVppScript"),
        progExitScript = item.optInt("progExitScript"),
        readDevIdScript = item.optInt("readDevIdScript"),
        deviceIdMask = item.optInt("deviceIdMask"),
        blankValue = item.optInt("blankValue"),
        progMemShift = item.optInt("progMemShift"),
        vpp = item.optDouble("vpp").toFloat(),
        bytesPerLocation = item.optInt("bytesPerLocation"),
        eeMemBytesPerWord = item.optInt("eeMemBytesPerWord"),
      )
      familyDetect[info.familyId] = info
    }

    val parts = root.optJSONArray("parts") ?: JSONArray()
    for (index in 0 until parts.length()) {
      val item = parts.optJSONObject(index) ?: continue
      val model = item.optString("model").trim().uppercase(Locale.US)
      val familyId = item.optInt("familyId")
      val deviceId = item.optInt("deviceId")
      if (model.isBlank() || deviceId == 0 || deviceId == 0xFFFF) {
        continue
      }
      partDetect.add(PartDetectInfo(model = model, familyId = familyId, deviceId = deviceId))
    }

    val scripts = root.optJSONArray("scripts") ?: JSONArray()
    for (index in 0 until scripts.length()) {
      val item = scripts.optJSONObject(index) ?: continue
      val scriptNumber = item.optInt("scriptNumber")
      val scriptBytes = item.optJSONArray("script") ?: JSONArray()
      if (scriptNumber <= 0 || scriptBytes.length() == 0) {
        continue
      }

      val bytes = ByteArray(scriptBytes.length())
      for (byteIndex in 0 until scriptBytes.length()) {
        bytes[byteIndex] = scriptBytes.optInt(byteIndex).toByte()
      }
      scriptByNumber[scriptNumber] = ScriptInfo(scriptNumber = scriptNumber, script = bytes)
    }
  }

  private fun loadCatalogRows(csvText: String) {
    val rows = parseCsv(csvText)
    if (rows.isEmpty()) {
      return
    }

    for (index in 1 until rows.size) {
      val row = rows[index]
      if (row.size < 6) {
        continue
      }
      val family = row[0].trim()
      val model = row[1].trim().uppercase(Locale.US)
      val deviceId = row[2].trim()
      if (family.isBlank() || model.isBlank() || deviceId.isBlank()) {
        continue
      }

      addRecord(
        family = family,
        model = model,
        deviceId = deviceId,
        flash = row[3].trim(),
        ram = row[4].trim(),
        eeprom = row[5].trim(),
      )
    }
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

  private fun parseCsv(csvText: String): List<List<String>> {
    val rows = mutableListOf<List<String>>()
    val currentRow = mutableListOf<String>()
    val currentField = StringBuilder()
    var inQuotes = false
    var index = 0

    while (index < csvText.length) {
      val ch = csvText[index]
      when {
        ch == '"' -> {
          if (inQuotes && index + 1 < csvText.length && csvText[index + 1] == '"') {
            currentField.append('"')
            index += 1
          } else {
            inQuotes = !inQuotes
          }
        }
        ch == ',' && !inQuotes -> {
          currentRow.add(currentField.toString())
          currentField.setLength(0)
        }
        (ch == '\n' || ch == '\r') && !inQuotes -> {
          if (ch == '\r' && index + 1 < csvText.length && csvText[index + 1] == '\n') {
            index += 1
          }
          currentRow.add(currentField.toString())
          currentField.setLength(0)
          if (currentRow.any { it.isNotEmpty() }) {
            rows.add(currentRow.toList())
          }
          currentRow.clear()
        }
        else -> currentField.append(ch)
      }
      index += 1
    }

    if (currentField.isNotEmpty() || currentRow.isNotEmpty()) {
      currentRow.add(currentField.toString())
      if (currentRow.any { it.isNotEmpty() }) {
        rows.add(currentRow.toList())
      }
    }

    return rows
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
