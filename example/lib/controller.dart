import 'package:flutter/material.dart';
import 'package:pickit2_flutter/pickit2_flutter.dart';

class HomeController extends ChangeNotifier {
  final Pickit2Flutter _pickit2 = Pickit2Flutter();
  static const String allFamiliesOption = 'All';
  final Map<String, List<Map<String, String>>> chipCatalog =
      <String, List<Map<String, String>>>{};

  String connectionStatus = 'Disconnected';
  bool connected = false;
  bool busy = false;
  int progress = 0;
  bool programming = false;
  String writePhase = '';
  String writeMessage = '';

  String firmwareName = 'N/A';
  String firmwareSize = '0 B';
  String firmwareType = 'None';

  String deviceName = 'PICkit2';
  String targetDevice = 'Select a Chip';
  String serialNumber = 'N/A';
  String deviceFamily = 'Import Firmware';
  String flashSize = 'N/A';
  String ramSize = 'N/A';
  String eepromSize = 'N/A';
  String programmerFirmware = '0';
  String deviceId = 'N/A';
  String selectedChipFamily = allFamiliesOption;
  bool chipCatalogLoaded = false;
  bool chipSelected = false;

  List<int> readProgramMemory = [];
  List<int> readEepromMemory = [];
  List<int> readConfigMemory = [];
  int readProgramBaseAddress = 0;
  int readEepromBaseAddress = 0;
  int readConfigBaseAddress = 0;
  List<Map<String, dynamic>> configWords = [];

  HomeController() {
    _pickit2.onDeviceDetached = _handleDeviceDetached;
  }

  // Imported firmware image bytes (address → byte)
  Map<int, int> importedImageBytes = {};
  int importedMinAddr = 0;
  int importedMaxAddr = 0;

  String get statusLabel => connected ? 'Ready' : 'Offline';

  bool get hasImportedData => importedImageBytes.isNotEmpty;
  int get importedProgramBaseAddress => importedMinAddr;
  int get importedEepromBaseAddress => _eeStartAddr > 0 ? _eeStartAddr : 0;
  int get importedConfigBaseAddress =>
      _configStartAddr > 0 ? _configStartAddr : 0;

  /// Splits the imported image into program-memory bytes (contiguous from minAddr).
  List<int> get importedProgramMemory {
    if (importedImageBytes.isEmpty) return [];
    // Program memory: everything from minAddress up to the config boundary or max address
    final progEnd = _configStartAddr > importedMinAddr
        ? _configStartAddr
        : importedMaxAddr + 1;
    final result = <int>[];
    for (int addr = importedMinAddr; addr < progEnd; addr++) {
      result.add(importedImageBytes[addr] ?? 0xFF);
    }
    return result;
  }

  List<int> get importedEepromMemory {
    if (importedImageBytes.isEmpty) return [];
    // EEPROM typically sits at 0x2100+ or device-specific eeAddr
    final eeStart = _eeStartAddr;
    if (eeStart <= 0) return [];
    final eeEnd = eeStart + (_eeSize ?? 256);
    final result = <int>[];
    for (int addr = eeStart; addr < eeEnd; addr++) {
      final b = importedImageBytes[addr];
      if (b != null) result.add(b);
    }
    return result;
  }

  List<int> get importedConfigMemory {
    if (importedImageBytes.isEmpty) return [];
    final cfgStart = _configStartAddr;
    if (cfgStart <= 0) return [];
    final result = <int>[];
    for (
      int addr = cfgStart;
      addr <= importedMaxAddr && addr < cfgStart + 32;
      addr++
    ) {
      result.add(importedImageBytes[addr] ?? 0xFF);
    }
    return result;
  }

  int get _configStartAddr {
    if (configWords.isNotEmpty) {
      return configWords.first['address'] as int? ?? -1;
    }
    if (importedMaxAddr >= 0x300000) return 0x300000;
    if (importedMaxAddr >= 0x400E) return 0x400E;
    return -1;
  }

  int get _eeStartAddr {
    if (importedMinAddr <= 0xF00000 && importedMaxAddr > 0xF00000) {
      return 0xF00000;
    }
    if (importedMinAddr <= 0x4200 && importedMaxAddr >= 0x4200) return 0x4200;
    return -1;
  }

  int? get _eeSize {
    final sizeStr = eepromSize;
    if (sizeStr == 'N/A') return null;
    return int.tryParse(sizeStr.replaceAll(RegExp(r'[^0-9]'), ''));
  }

  List<String> get chipFamilies => <String>[
    allFamiliesOption,
    ...chipCatalog.keys,
  ];

  List<Map<String, String>> getModelsByFamily(String family) {
    if (family == allFamiliesOption) {
      final allModels = <Map<String, String>>[];
      for (final entry in chipCatalog.entries) {
        for (final row in entry.value) {
          allModels.add(<String, String>{...row, 'family': entry.key});
        }
      }
      return allModels;
    }
    return chipCatalog[family] ?? const <Map<String, String>>[];
  }

  Future<bool> ensureChipCatalogLoaded() async {
    if (chipCatalogLoaded && chipCatalog.isNotEmpty) {
      return true;
    }

    connectionStatus = 'Loading chip data...';
    notifyListeners();

    final loadResult = await _pickit2.loadChipData();
    if (loadResult == null || loadResult['loaded'] != true) {
      connectionStatus = 'Failed to load chip data';
      notifyListeners();
      return false;
    }

    try {
      final catalog = await _pickit2.getChipCatalog();
      chipCatalog
        ..clear()
        ..addAll(catalog);

      chipCatalogLoaded = chipCatalog.isNotEmpty;
      if (chipCatalogLoaded) {
        final preferredFamily = chipCatalog.containsKey(deviceFamily)
            ? deviceFamily
            : allFamiliesOption;
        selectedChipFamily = preferredFamily;
        connectionStatus = 'Chip data loaded';
      } else {
        connectionStatus = 'No chip data available';
      }

      notifyListeners();
      return chipCatalogLoaded;
    } catch (_) {
      connectionStatus = 'Failed to parse chip catalog';
      notifyListeners();
      return false;
    }
  }

  void selectFamily(String family) {
    if (family != allFamiliesOption && !chipCatalog.containsKey(family)) {
      return;
    }
    selectedChipFamily = family;
    notifyListeners();
  }

  Future<void> selectChipByFamilyAndModel(
    String family,
    Map<String, String> model,
  ) async {
    selectedChipFamily = family;
    targetDevice = model['model'] ?? targetDevice;
    final resolvedFamily = model['family'] ?? family;
    deviceFamily = resolvedFamily;
    flashSize = model['flashSize'] ?? 'N/A';
    ramSize = model['ramSize'] ?? 'N/A';
    eepromSize = model['eepromSize'] ?? 'N/A';
    deviceId = model['deviceId'] ?? 'N/A';
    chipSelected = true;
    connectionStatus = 'Selected chip: $targetDevice';
    // Sync selected chip parameters to the native side so erase/read
    // operations use the correct memory layout for this chip.
    try {
      final selected = await _pickit2.selectChip(
        model: targetDevice,
        flashSize: flashSize,
        eepromSize: eepromSize,
      );
      if (selected != true) {
        chipSelected = false;
        connectionStatus = 'Failed to select chip: $targetDevice';
      }
    } catch (_) {
      chipSelected = false;
      connectionStatus = 'Failed to select chip: $targetDevice';
    }
    await refreshConfigWords();
    notifyListeners();
  }

  Future<void> autoDetectChip() async {
    final loaded = await ensureChipCatalogLoaded();
    if (!loaded) {
      return;
    }

    if (!connected) {
      connectionStatus = 'Connect PICkit2 first';
      notifyListeners();
      return;
    }

    if (busy) return;
    busy = true;
    connectionStatus = 'Detecting chip...';
    notifyListeners();

    try {
      final detected = await _pickit2.autoDetectChip();
      final found = detected?['found'] == true;
      final detectedModel = (detected?['model'] as String?)?.trim();
      final detectedFamily = (detected?['family'] as String?)?.trim();
      final detectedId = (detected?['deviceId'] as String?)?.trim();

      if (!found || detectedModel == null || detectedModel.isEmpty) {
        targetDevice = 'Unrecognised';
        deviceFamily = 'Unknown';
        flashSize = 'N/A';
        ramSize = 'N/A';
        eepromSize = 'N/A';
        deviceId = 'N/A';
        selectedChipFamily = allFamiliesOption;
        chipSelected = false;
        connectionStatus = 'Chip auto-detect failed';
        return;
      }

      final family = (detectedFamily != null && detectedFamily.isNotEmpty)
          ? detectedFamily
          : _findFamilyByModel(detectedModel);
      final familyModels = getModelsByFamily(family);
      final matched = familyModels.firstWhere(
        (row) =>
            (row['model'] ?? '').toUpperCase() == detectedModel.toUpperCase(),
        orElse: () => <String, String>{
          'model': detectedModel,
          'family': family,
          'deviceId': detectedId ?? 'N/A',
          'flashSize': flashSize,
          'ramSize': ramSize,
          'eepromSize': eepromSize,
        },
      );

      if (detectedId != null && detectedId.isNotEmpty) {
        matched['deviceId'] = detectedId;
      }

      await selectChipByFamilyAndModel(family, matched);
      if (chipSelected) {
        connectionStatus = 'Detected chip: $targetDevice';
      }
    } catch (_) {
      chipSelected = false;
      connectionStatus = 'Chip auto-detect failed';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> connect() async {
    if (busy) return;
    busy = true;
    connectionStatus = 'Connecting...';
    notifyListeners();

    try {
      final result = await _pickit2.connect();
      connected = !result.toLowerCase().startsWith('connection failed');
      connectionStatus = result;
      if (connected) {
        final serial = await _pickit2.getSerialNumber();
        serialNumber = (serial != null && serial.trim().isNotEmpty)
            ? serial
            : 'Unavailable';
        final fwVersion = await _pickit2.getFirmwareVersion();
        programmerFirmware = (fwVersion != null && fwVersion.trim().isNotEmpty)
            ? fwVersion
            : 'N/A';
      } else {
        serialNumber = 'N/A';
      }
    } catch (error) {
      connectionStatus = 'Connection failed';
      connected = false;
      serialNumber = 'N/A';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    if (busy) return;
    busy = true;
    connectionStatus = 'Disconnecting...';
    progress = 0;
    writePhase = '';
    writeMessage = '';
    programming = false;
    notifyListeners();

    try {
      await _pickit2.disconnect();
      connected = false;
      connectionStatus = "Disconnected";
      serialNumber = 'N/A';
      programmerFirmware = 'N/A';
      chipSelected = false;
    } catch (error) {
      connectionStatus = 'Disconnect failed';
      connected = false;
      serialNumber = 'N/A';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> loadFirmwareFile(String path) async {
    connectionStatus = 'Loading firmware file...';
    progress = 0;
    writePhase = '';
    writeMessage = '';
    notifyListeners();

    try {
      String lowerPath = path.toLowerCase();
      Map<String, dynamic>? result;
      if (lowerPath.endsWith('.hex')) {
        result = await _pickit2.loadHexFile(path);
      } else if (lowerPath.endsWith('.bin')) {
        result = await _pickit2.loadBinFile(path);
      } else {
        throw Exception('Unsupported file format. Use .hex or .bin');
      }

      if (result != null) {
        firmwareName = path.split('/').last;
        firmwareSize = _formatSize(result['loadedBytes'] as int? ?? 0);
        firmwareType = (result['sourceType'] as String? ?? 'Unknown')
            .toUpperCase();
        connectionStatus =
            'Firmware loaded: ${result['loadedBytes'] ?? 0} bytes';

        // Fetch the full image bytes for hex viewer display
        final imageData = await _pickit2.getLoadedImageData();
        if (imageData != null) {
          importedMinAddr = imageData['minAddress'] as int? ?? 0;
          importedMaxAddr = imageData['maxAddress'] as int? ?? 0;
          final flat = List<int>.from(imageData['data'] as List? ?? []);
          importedImageBytes = {};
          for (int i = 0; i + 1 < flat.length; i += 2) {
            importedImageBytes[flat[i]] = flat[i + 1] & 0xFF;
          }
          configWords = (imageData['configWords'] as List? ?? const [])
              .map((entry) => Map<String, dynamic>.from(entry as Map))
              .toList();
        } else {
          importedImageBytes = {};
          configWords = [];
        }
      } else {
        connectionStatus = 'Failed to load firmware file';
      }
      notifyListeners();
      return result;
    } catch (e) {
      if (!connected) {
        connectionStatus = 'Connect PICkit2 first';
      } else {
        connectionStatus = 'Load failed: ${e.toString()}';
      }
      notifyListeners();
      return null;
    }
  }

  Future<String?> pickFirmwarePath() => _pickit2.pickFirmwareFile();

  Future<String?> pickReadSavePath() =>
      _pickit2.pickHexSavePath(fileName: 'read_data.hex');

  Future<void> clearFirmware() async {
    await _pickit2.clearLoadedImage();
    firmwareName = 'N/A';
    firmwareSize = '0 B';
    firmwareType = 'None';
    progress = 0;
    writePhase = '';
    writeMessage = '';
    importedImageBytes = {};
    importedMinAddr = 0;
    importedMaxAddr = 0;
    configWords = [];
    connectionStatus = 'Firmware cleared';
    notifyListeners();
  }

  Future<Map<String, dynamic>?> getLoadedFirmwareInfo() async {
    return await _pickit2.getLoadedImageInfo();
  }

  Future<bool?> eraseChip() async {
    if (busy) return false;
    busy = true;
    connectionStatus = 'Erasing chip...';
    notifyListeners();
    try {
      final result = await _pickit2.eraseChip();
      connectionStatus = result == true
          ? 'Chip erased successfully'
          : 'Erase failed';
      return result;
    } catch (_) {
      connectionStatus = 'Erase failed';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> blankCheck() async {
    if (busy) return null;
    busy = true;
    connectionStatus = 'Blank checking chip...';
    notifyListeners();
    try {
      final result = await _pickit2.blankCheck();
      if (result == null) {
        connectionStatus = 'Blank check failed';
      } else {
        connectionStatus =
            result['message'] as String? ??
            (result['blank'] == true
                ? 'Device is blank'
                : 'Device is not blank');
      }
      return result;
    } catch (_) {
      connectionStatus = 'Blank check failed';
      return null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> readChip() async {
    if (busy) return null;
    busy = true;
    connectionStatus = 'Reading chip...';
    readProgramMemory = [];
    readEepromMemory = [];
    readConfigMemory = [];
    notifyListeners();
    try {
      final result = await _pickit2.readChip();
      if (result?["success"] == true) {
        readProgramMemory = List<int>.from(result?["programMemory"] ?? []);
        readEepromMemory = List<int>.from(result?["eepromMemory"] ?? []);
        readConfigMemory = List<int>.from(result?["configMemory"] ?? []);
        readProgramBaseAddress = result?["programBaseAddress"] as int? ?? 0;
        readEepromBaseAddress = result?["eepromBaseAddress"] as int? ?? 0;
        readConfigBaseAddress = result?["configBaseAddress"] as int? ?? 0;
        connectionStatus = 'Read complete';
      } else {
        connectionStatus = 'Read failed';
      }
      return result;
    } catch (_) {
      connectionStatus = 'Read failed';
      return null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool?> saveHexFile(
    String path,
    List<int> data,
    int addressIncrement,
    int bytesPerWord,
  ) async {
    return await _pickit2.saveReadHex(path);
  }

  Future<void> refreshConfigWords() async {
    configWords = await _pickit2.getConfigWords();
    notifyListeners();
  }

  Future<bool> updateConfigWord(int index, int value) async {
    final updated = await _pickit2.setConfigWord(index, value);
    if (updated == null) {
      connectionStatus = 'Failed to update configuration word';
      notifyListeners();
      return false;
    }
    final position = configWords.indexWhere((word) => word['index'] == index);
    if (position >= 0) {
      configWords[position] = updated;
    } else {
      configWords.add(updated);
    }
    connectionStatus = 'Configuration word updated';
    notifyListeners();
    return true;
  }

  String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    }
    return '$bytes B';
  }

  Future<bool> startProgramming() async {
    if (!connected || busy || !hasImportedData) return false;

    busy = true;
    programming = true;
    progress = 0;
    writePhase = '';
    writeMessage = 'Starting…';
    connectionStatus = 'Programming…';

    // Set up progress listener
    _pickit2.onWriteProgress = (phase, percent, message) {
      progress = percent;
      writePhase = phase;
      writeMessage = message;
      notifyListeners();
    };

    notifyListeners();

    try {
      final result = await _pickit2.writeFirmware();
      final success = result?['success'] == true;
      final msg = result?['message'] as String? ?? '';

      if (success) {
        progress = 100;
        writePhase = 'done';
        writeMessage = msg.isNotEmpty ? msg : 'Write complete';
        connectionStatus = 'Write complete';
      } else {
        writePhase = 'error';
        writeMessage = msg.isNotEmpty ? msg : 'Write failed';
        connectionStatus = 'Write failed';
      }
      return success;
    } catch (e) {
      writePhase = 'error';
      writeMessage = e.toString();
      connectionStatus = 'Write failed: ${e.toString()}';
      return false;
    } finally {
      programming = false;
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> verifyFirmware() async {
    if (!connected || busy || !hasImportedData) return false;
    busy = true;
    programming = true;
    progress = 0;
    writePhase = 'verify';
    writeMessage = 'Verifying…';
    connectionStatus = 'Verifying…';
    _pickit2.onWriteProgress = (phase, percent, message) {
      progress = percent;
      writePhase = phase;
      writeMessage = message;
      notifyListeners();
    };
    notifyListeners();

    try {
      final result = await _pickit2.verifyFirmware();
      final success = result?['success'] == true;
      connectionStatus = success
          ? 'Verification succeeded'
          : 'Verification failed';
      writeMessage = result?['message'] as String? ?? connectionStatus;
      writePhase = success ? 'done' : 'error';
      return success;
    } catch (_) {
      connectionStatus = 'Verification failed';
      writeMessage = connectionStatus;
      writePhase = 'error';
      return false;
    } finally {
      programming = false;
      busy = false;
      notifyListeners();
    }
  }

  String _findFamilyByModel(String modelName) {
    final normalized = modelName.trim().toUpperCase();
    for (final entry in chipCatalog.entries) {
      if (entry.value.any(
        (row) => (row['model'] ?? '').toUpperCase() == normalized,
      )) {
        return entry.key;
      }
    }
    return selectedChipFamily == allFamiliesOption
        ? deviceFamily
        : selectedChipFamily;
  }

  void _handleDeviceDetached() {
    connected = false;
    busy = false;
    programming = false;
    progress = 0;
    serialNumber = 'N/A';
    programmerFirmware = 'N/A';
    chipSelected = false;
    targetDevice = 'Select a Chip';
    deviceFamily = 'Import Firmware';
    connectionStatus = 'PICkit 2 disconnected';
    notifyListeners();
  }
}
