import Cocoa
import FlutterMacOS

public final class Pickit2FlutterPlugin: NSObject, FlutterPlugin {
  private let operationQueue = DispatchQueue(label: "com.an7or.pickit2.native", qos: .userInitiated)
  private var channel: FlutterMethodChannel?
  private var bridge: Pk2NativeBridge?
  private var bridgeStartupError: Error?
  private var serialNumber = ""
  private var firmwareVersion = ""
  private var loadedImage: IntelHexImage?
  private var selectedPart: [String: Any] = [:]
  private var catalog: [String: [[String: String]]] = [:]
  private var lastReadAvailable = false

  override public init() {
    super.init()
    do {
      guard let deviceFileURL = Self.resourceURL(name: "PK2DeviceFile", extension: "dat") else {
        throw PluginError.resourceMissing("PK2DeviceFile.dat")
      }
      bridge = try Pk2NativeBridge(deviceFilePath: deviceFileURL.path)
    } catch {
      bridgeStartupError = error
    }
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "pickit2_flutter", binaryMessenger: registrar.messenger)
    let instance = Pickit2FlutterPlugin()
    instance.channel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "connect":
      run(result, code: "USB_ERROR") { bridge in
        let info = try bridge.connect()
        self.serialNumber = info["serialNumber"] as? String ?? ""
        self.firmwareVersion = info["firmwareVersion"] as? String ?? ""
        return "Connected to PICkit 2 successfully!"
      }
    case "disconnect":
      operationQueue.async {
        self.bridge?.disconnect()
        self.serialNumber = ""
        self.firmwareVersion = ""
        self.lastReadAvailable = false
        self.complete(result, value: "Disconnected")
      }
    case "getSerialNumber":
      result(serialNumber)
    case "getFirmwareVersion":
      result(firmwareVersion)
    case "loadHexFile":
      loadHexFile(call, result: result)
    case "loadBinFile":
      loadBinFile(call, result: result)
    case "clearLoadedImage":
      loadedImage = nil
      result(true)
    case "getLoadedImageInfo":
      result(loadedImage?.summary() ?? [:])
    case "getLoadedImageData":
      result(loadedImageData())
    case "loadChipData", "loadChipDataFromDat":
      loadChipCatalog(call, result: result)
    case "getChipCatalog":
      result(catalog)
    case "getChipFamilies":
      result(catalog.keys.sorted())
    case "getChipModelsByFamily":
      let family = arguments(call)["family"] as? String ?? ""
      result(catalog[family] ?? [])
    case "selectChip":
      let model = arguments(call)["model"] as? String ?? ""
      run(result, code: "CHIP_SELECT_ERROR") { bridge in
        let info = try bridge.selectPart(model)
        self.selectedPart = info
        return true
      }
    case "autoDetectChip":
      run(result, code: "AUTO_DETECT_ERROR") { bridge in
        let info = try bridge.autoDetect()
        self.selectedPart = info
        return info
      }
    case "eraseChip":
      run(result, code: "ERASE_ERROR") { bridge in
        try bridge.erase()
        return true
      }
    case "blankCheck":
      run(result, code: "BLANK_CHECK_ERROR") { bridge in
        try bridge.blankCheck()
      }
    case "readChip":
      run(result, code: "READ_ERROR") { bridge in
        let memory = try bridge.read()
        self.lastReadAvailable = true
        return memory
      }
    case "saveHexFile", "saveReadHex":
      saveReadHex(call, result: result)
    case "getConfigWords":
      result(configWords())
    case "setConfigWord":
      setConfigWord(call, result: result)
    case "writeFirmware":
      runImageOperation(result, code: "WRITE_ERROR") { bridge, path, progress in
        try bridge.writeHex(atPath: path, progress: progress)
      }
    case "verifyFirmware":
      runImageOperation(result, code: "VERIFY_ERROR") { bridge, path, progress in
        try bridge.verifyHex(atPath: path, progress: progress)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func loadHexFile(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let path = arguments(call)["path"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "path is required", details: nil))
      return
    }
    do {
      let image = try IntelHexImage(hexURL: URL(fileURLWithPath: path))
      loadedImage = image
      result(image.summary())
    } catch {
      result(flutterError("HEX_LOAD_ERROR", error))
    }
  }

  private func loadBinFile(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = arguments(call)
    guard let path = args["path"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "path is required", details: nil))
      return
    }
    do {
      let image = try IntelHexImage(
        binaryURL: URL(fileURLWithPath: path),
        baseAddress: args["baseAddress"] as? Int ?? 0
      )
      loadedImage = image
      result(image.summary())
    } catch {
      result(flutterError("BIN_LOAD_ERROR", error))
    }
  }

  private func loadChipCatalog(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    do {
      let suppliedPath = arguments(call)["catalogPath"] as? String
      let url: URL
      if let suppliedPath, !suppliedPath.isEmpty {
        url = URL(fileURLWithPath: suppliedPath)
      } else if let bundled = Self.resourceURL(name: "chip_catalog", extension: "csv") {
        url = bundled
      } else {
        throw PluginError.resourceMissing("chip_catalog.csv")
      }
      catalog = try Self.parseCatalog(url)
      result([
        "loaded": true,
        "familyCount": catalog.count,
        "modelCount": catalog.values.reduce(0) { $0 + $1.count },
      ])
    } catch {
      result(flutterError("CHIP_DATA_ERROR", error))
    }
  }

  private func saveReadHex(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard lastReadAvailable else {
      result(FlutterError(code: "NO_READ_DATA", message: "Read the target before exporting", details: nil))
      return
    }
    guard let path = arguments(call)["path"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "path is required", details: nil))
      return
    }
    run(result, code: "HEX_SAVE_ERROR") { bridge in
      try bridge.exportHex(atPath: path)
      return true
    }
  }

  private func setConfigWord(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard var image = loadedImage else {
      result(FlutterError(code: "NO_IMAGE", message: "Load a HEX or BIN image first", details: nil))
      return
    }
    let args = arguments(call)
    guard let index = args["index"] as? Int,
          let value = args["value"] as? Int,
          index >= 0,
          let descriptor = configDescriptor(at: index) else {
      result(FlutterError(code: "INVALID_CONFIG", message: "Invalid configuration word", details: nil))
      return
    }
    let mask = descriptor["mask"] as? Int ?? 0xFFFF
    let blank = descriptor["blank"] as? Int ?? 0xFFFF
    let byteCount = descriptor["byteCount"] as? Int ?? 2
    let sanitized = (value & mask) | (blank & ~mask)
    image.setWord(
      at: descriptor["address"] as? Int ?? 0,
      value: sanitized,
      byteCount: byteCount
    )
    loadedImage = image
    result(descriptor.merging(["value": sanitized]) { _, new in new })
  }

  private func runImageOperation(
    _ result: @escaping FlutterResult,
    code: String,
    operation: @escaping (Pk2NativeBridge, String, @escaping Pk2ProgressHandler) throws -> [AnyHashable: Any]
  ) {
    guard let image = loadedImage else {
      result(FlutterError(code: "NO_IMAGE", message: "Load a firmware image first", details: nil))
      return
    }
    operationQueue.async {
      guard let bridge = self.bridge else {
        self.complete(result, error: self.flutterError(code, self.bridgeStartupError ?? PluginError.bridgeUnavailable))
        return
      }
      let temporaryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("pickit2-\(UUID().uuidString)")
        .appendingPathExtension("hex")
      defer { try? FileManager.default.removeItem(at: temporaryURL) }
      do {
        try image.write(to: temporaryURL)
        let progress: Pk2ProgressHandler = { phase, percent, message in
          DispatchQueue.main.async {
            self.channel?.invokeMethod("onWriteProgress", arguments: [
              "phase": phase,
              "percent": percent,
              "message": message,
            ])
          }
        }
        let value = try operation(bridge, temporaryURL.path, progress)
        self.complete(result, value: value)
      } catch {
        self.complete(result, error: self.flutterError(code, error))
      }
    }
  }

  private func run(
    _ result: @escaping FlutterResult,
    code: String,
    operation: @escaping (Pk2NativeBridge) throws -> Any
  ) {
    operationQueue.async {
      guard let bridge = self.bridge else {
        self.complete(result, error: self.flutterError(code, self.bridgeStartupError ?? PluginError.bridgeUnavailable))
        return
      }
      do {
        self.complete(result, value: try operation(bridge))
      } catch {
        self.complete(result, error: self.flutterError(code, error))
      }
    }
  }

  private func loadedImageData() -> [String: Any] {
    guard let image = loadedImage else { return [:] }
    var data = image.summary()
    data["data"] = image.flattenedData()
    data["configWords"] = configWords()
    return data
  }

  private func configWords() -> [[String: Any]] {
    guard let image = loadedImage else { return [] }
    let nativeWords = selectedPart["configWords"] as? [[String: Any]] ?? []
    return nativeWords.map { descriptor in
      guard let address = descriptor["address"] as? Int else { return descriptor }
      let blank = descriptor["blank"] as? Int ?? 0xFFFF
      let byteCount = descriptor["byteCount"] as? Int ?? 2
      let value = (0..<byteCount).reduce(0) { result, offset in
        let fallback = UInt8(truncatingIfNeeded: blank >> (offset * 8))
        return result | (Int(image.bytes[address + offset] ?? fallback) << (offset * 8))
      }
      return descriptor.merging(["value": value]) { _, new in new }
    }
  }

  private func configDescriptor(at index: Int) -> [String: Any]? {
    let words = selectedPart["configWords"] as? [[String: Any]] ?? []
    return words.first { ($0["index"] as? Int) == index }
  }

  private func arguments(_ call: FlutterMethodCall) -> [String: Any] {
    call.arguments as? [String: Any] ?? [:]
  }

  private func complete(_ result: @escaping FlutterResult, value: Any) {
    DispatchQueue.main.async { result(value) }
  }

  private func complete(_ result: @escaping FlutterResult, error: FlutterError) {
    DispatchQueue.main.async { result(error) }
  }

  private func flutterError(_ code: String, _ error: Error) -> FlutterError {
    FlutterError(code: code, message: error.localizedDescription, details: nil)
  }

  private static func resourceURL(name: String, extension fileExtension: String) -> URL? {
    let hostBundle = Bundle(for: Pickit2FlutterPlugin.self)
    var bundles = [hostBundle, Bundle.main]
    for bundleName in ["pickit2_flutter", "pickit2_flutter_pickit2_flutter"] {
      if let url = hostBundle.url(forResource: bundleName, withExtension: "bundle"),
         let bundle = Bundle(url: url) {
        bundles.insert(bundle, at: 0)
      }
    }
    return bundles.lazy.compactMap { $0.url(forResource: name, withExtension: fileExtension) }.first
  }

  private static func parseCatalog(_ url: URL) throws -> [String: [[String: String]]] {
    let contents = try String(contentsOf: url, encoding: .utf8)
    var catalog: [String: [[String: String]]] = [:]
    for line in contents.components(separatedBy: .newlines).dropFirst() where !line.isEmpty {
      let columns = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
      guard columns.count >= 6 else { continue }
      catalog[columns[0], default: []].append([
        "model": columns[1],
        "deviceId": columns[2],
        "flashSize": columns[3],
        "ramSize": columns[4],
        "eepromSize": columns[5],
      ])
    }
    return catalog
  }
}

private enum PluginError: LocalizedError {
  case resourceMissing(String)
  case bridgeUnavailable

  var errorDescription: String? {
    switch self {
    case .resourceMissing(let name):
      return "Required resource \(name) is missing"
    case .bridgeUnavailable:
      return "PICkit 2 native engine is unavailable"
    }
  }
}
