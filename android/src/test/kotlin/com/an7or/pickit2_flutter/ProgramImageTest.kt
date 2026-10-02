package com.an7or.pickit2_flutter

import java.nio.file.Files
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

internal class ProgramImageTest {
  @Test
  fun writeHex_preservesSparseAddressesAndChecksums() {
    val image = ProgramImage().apply {
      putByte(0x0000, 0x12)
      putByte(0x0001, 0x34)
      putByte(0x10000, 0xAB)
    }
    val path = Files.createTempFile("pickit2-program-image", ".hex")

    try {
      image.writeHex(path.toFile())
      val lines = Files.readAllLines(path)

      assertEquals(":020000040000FA", lines[0])
      assertEquals(":020000001234B8", lines[1])
      assertEquals(":020000040001F9", lines[2])
      assertEquals(":01000000AB54", lines[3])
      assertEquals(":00000001FF", lines[4])
      assertTrue(lines.all(::hasValidChecksum))
    } finally {
      Files.deleteIfExists(path)
    }
  }

  private fun hasValidChecksum(line: String): Boolean {
    return (1 until line.length step 2)
      .sumOf { line.substring(it, it + 2).toInt(16) }
      .and(0xFF) == 0
  }
}
