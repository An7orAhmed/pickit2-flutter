import Foundation

enum IntelHexError: LocalizedError {
  case invalidRecord(Int)
  case invalidChecksum(Int)
  case unsupportedRecord(Int, Int)

  var errorDescription: String? {
    switch self {
    case .invalidRecord(let line):
      return "Invalid Intel HEX record on line \(line)"
    case .invalidChecksum(let line):
      return "Intel HEX checksum mismatch on line \(line)"
    case .unsupportedRecord(let type, let line):
      return String(format: "Unsupported Intel HEX record type %02X on line %d", type, line)
    }
  }
}

struct IntelHexImage {
  var bytes: [Int: UInt8]
  let sourceType: String
  let sourcePath: String

  init(hexURL: URL) throws {
    bytes = [:]
    sourceType = "hex"
    sourcePath = hexURL.path

    let contents = try String(contentsOf: hexURL, encoding: .utf8)
    var baseAddress = 0

    for (index, rawLine) in contents.components(separatedBy: .newlines).enumerated() {
      let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !line.isEmpty, !line.hasPrefix(";") else { continue }
      guard line.first == ":", line.count >= 11 else {
        throw IntelHexError.invalidRecord(index + 1)
      }

      let payload = String(line.dropFirst())
      guard payload.count.isMultiple(of: 2) else {
        throw IntelHexError.invalidRecord(index + 1)
      }

      var record: [UInt8] = []
      record.reserveCapacity(payload.count / 2)
      var cursor = payload.startIndex
      while cursor < payload.endIndex {
        let end = payload.index(cursor, offsetBy: 2)
        guard let value = UInt8(payload[cursor..<end], radix: 16) else {
          throw IntelHexError.invalidRecord(index + 1)
        }
        record.append(value)
        cursor = end
      }

      guard record.count >= 5,
            record.count == Int(record[0]) + 5 else {
        throw IntelHexError.invalidRecord(index + 1)
      }
      guard record.reduce(0, { ($0 + Int($1)) & 0xFF }) == 0 else {
        throw IntelHexError.invalidChecksum(index + 1)
      }

      let count = Int(record[0])
      let address = (Int(record[1]) << 8) | Int(record[2])
      let type = Int(record[3])
      let data = record[4..<(4 + count)]

      switch type {
      case 0x00:
        for (offset, value) in data.enumerated() {
          bytes[baseAddress + address + offset] = value
        }
      case 0x01:
        return
      case 0x02:
        guard data.count == 2 else { throw IntelHexError.invalidRecord(index + 1) }
        baseAddress = ((Int(data[data.startIndex]) << 8) | Int(data[data.index(after: data.startIndex)])) << 4
      case 0x03, 0x05:
        continue
      case 0x04:
        guard data.count == 2 else { throw IntelHexError.invalidRecord(index + 1) }
        baseAddress = ((Int(data[data.startIndex]) << 8) | Int(data[data.index(after: data.startIndex)])) << 16
      default:
        throw IntelHexError.unsupportedRecord(type, index + 1)
      }
    }
  }

  init(binaryURL: URL, baseAddress: Int) throws {
    let data = try Data(contentsOf: binaryURL)
    bytes = Dictionary(uniqueKeysWithValues: data.enumerated().map { (baseAddress + $0.offset, $0.element) })
    sourceType = "bin"
    sourcePath = binaryURL.path
  }

  init(bytes: [Int: UInt8], sourceType: String = "hex", sourcePath: String = "") {
    self.bytes = bytes
    self.sourceType = sourceType
    self.sourcePath = sourcePath
  }

  var minAddress: Int { bytes.keys.min() ?? 0 }
  var maxAddress: Int { bytes.keys.max() ?? 0 }

  func summary() -> [String: Any] {
    [
      "sourceType": sourceType,
      "sourcePath": sourcePath,
      "loadedBytes": bytes.count,
      "minAddress": minAddress,
      "maxAddress": maxAddress,
    ]
  }

  func flattenedData() -> [Int] {
    bytes.keys.sorted().flatMap { [$0, Int(bytes[$0] ?? 0xFF)] }
  }

  mutating func setWord(at address: Int, value: Int, byteCount: Int = 2) {
    for offset in 0..<byteCount {
      bytes[address + offset] = UInt8(truncatingIfNeeded: value >> (offset * 8))
    }
  }

  func contiguousBytes(in range: Range<Int>, blank: UInt8 = 0xFF) -> [Int] {
    guard !range.isEmpty else { return [] }
    return range.map { Int(bytes[$0] ?? blank) }
  }

  func existingBytes(in range: Range<Int>) -> (base: Int, data: [Int])? {
    let addresses = bytes.keys.filter(range.contains).sorted()
    guard let first = addresses.first, let last = addresses.last else { return nil }
    return (first, contiguousBytes(in: first..<(last + 1)))
  }

  func write(to url: URL) throws {
    var lines: [String] = []
    let addresses = bytes.keys.sorted()
    var index = 0
    var currentUpper = -1

    while index < addresses.count {
      let startAddress = addresses[index]
      let upper = (startAddress >> 16) & 0xFFFF
      if upper != currentUpper {
        lines.append(Self.record(address: 0, type: 0x04, data: [UInt8(upper >> 8), UInt8(upper & 0xFF)]))
        currentUpper = upper
      }

      let lowAddress = startAddress & 0xFFFF
      var data: [UInt8] = []
      while index < addresses.count,
            addresses[index] == startAddress + data.count,
            (addresses[index] >> 16) == upper,
            data.count < 16 {
        data.append(bytes[addresses[index]] ?? 0xFF)
        index += 1
      }
      lines.append(Self.record(address: lowAddress, type: 0x00, data: data))
    }

    lines.append(":00000001FF")
    try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
  }

  private static func record(address: Int, type: Int, data: [UInt8]) -> String {
    var values = [UInt8(data.count), UInt8((address >> 8) & 0xFF), UInt8(address & 0xFF), UInt8(type)]
    values.append(contentsOf: data)
    let checksum = UInt8(truncatingIfNeeded: -values.reduce(0) { $0 + Int($1) })
    values.append(checksum)
    return ":" + values.map { String(format: "%02X", $0) }.joined()
  }
}
