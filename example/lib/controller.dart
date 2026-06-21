import 'package:flutter/material.dart';
import 'package:pickit2_flutter/pickit2_flutter.dart';

class HomeController extends ChangeNotifier {
  final Pickit2Flutter _pickit2 = Pickit2Flutter();
  static const String allFamiliesOption = 'All';
  final Map<String, List<Map<String, String>>> chipCatalog = <String, List<Map<String, String>>>{};

  String connectionStatus = 'Disconnected';
  bool connected = false;
  int progress = 0;
  bool programming = false;

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

  String get statusLabel => connected ? 'Ready' : 'Offline';

  List<String> get chipFamilies => <String>[allFamiliesOption, ...chipCatalog.keys];

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
        final preferredFamily = chipCatalog.containsKey(deviceFamily) ? deviceFamily : allFamiliesOption;
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

  void selectChipByFamilyAndModel(String family, Map<String, String> model) {
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
    _pickit2.selectChip(model: targetDevice, flashSize: flashSize, eepromSize: eepromSize);
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

    connectionStatus = 'Detecting chip...';
    notifyListeners();

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
      notifyListeners();
      return;
    }

    final family = (detectedFamily != null && detectedFamily.isNotEmpty) ? detectedFamily : _findFamilyByModel(detectedModel);
    final familyModels = getModelsByFamily(family);
    final matched = familyModels.firstWhere(
      (row) => (row['model'] ?? '').toUpperCase() == detectedModel.toUpperCase(),
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

    selectChipByFamilyAndModel(family, matched);
    connectionStatus = 'Detected chip: $targetDevice';
    notifyListeners();
  }

  Future<void> connect() async {
    connectionStatus = 'Connecting...';
    notifyListeners();

    try {
      final result = await _pickit2.connect();
      connected = !result.toLowerCase().startsWith('connection failed');
      connectionStatus = result;
      if (connected) {
        final serial = await _pickit2.getSerialNumber();
        serialNumber = (serial != null && serial.trim().isNotEmpty) ? serial : 'Unavailable';
        final fwVersion = await _pickit2.getFirmwareVersion();
        programmerFirmware = (fwVersion != null && fwVersion.trim().isNotEmpty) ? fwVersion : 'N/A';
      } else {
        serialNumber = 'N/A';
      }
    } catch (error) {
      connectionStatus = 'Connection failed';
      connected = false;
      serialNumber = 'N/A';
    }

    notifyListeners();
  }

  Future<void> disconnect() async {
    connectionStatus = 'Disconnecting...';
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
    }

    notifyListeners();
  }

  Future<Map<String, dynamic>?> loadFirmwareFile(String path) async {
    connectionStatus = 'Loading firmware file...';
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
        firmwareType = (result['sourceType'] as String? ?? 'Unknown').toUpperCase();
        connectionStatus = 'Firmware loaded: ${result['loadedBytes'] ?? 0} bytes';
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

  Future<void> clearFirmware() async {
    await _pickit2.clearLoadedImage();
    firmwareName = 'N/A';
    firmwareSize = '0 B';
    firmwareType = 'None';
    connectionStatus = 'Firmware cleared';
    notifyListeners();
  }

  Future<Map<String, dynamic>?> getLoadedFirmwareInfo() async {
    return await _pickit2.getLoadedImageInfo();
  }

  Future<bool?> eraseChip() async {
    connectionStatus = 'Erasing chip...';
    notifyListeners();
    final result = await _pickit2.eraseChip();
    if (result == true) {
      connectionStatus = 'Chip erased successfully';
    } else {
      connectionStatus = 'Erase failed';
    }
    notifyListeners();
    return result;
  }

  Future<Map<String, dynamic>?> readChip() async {
    connectionStatus = 'Reading chip...';
    readProgramMemory = [];
    readEepromMemory = [];
    readConfigMemory = [];
    notifyListeners();
    final result = await _pickit2.readChip();
    if (result?["success"] == true) {
      readProgramMemory = List<int>.from(result?["programMemory"] ?? []);
      readEepromMemory = List<int>.from(result?["eepromMemory"] ?? []);
      readConfigMemory = List<int>.from(result?["configMemory"] ?? []);
      connectionStatus =
          'Chip read: ${readProgramMemory.length} prog, ${readEepromMemory.length} eeprom, ${readConfigMemory.length} config bytes';
    } else {
      connectionStatus = 'Read failed';
    }
    notifyListeners();
    return result;
  }

  Future<bool?> saveHexFile(String path, List<int> data, int addressIncrement, int bytesPerWord) async {
    return await _pickit2.saveHexFile(path, data, addressIncrement, bytesPerWord);
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

  Future<void> startProgramming() async {
    if (!connected || programming) return;

    programming = true;
    progress = 0;
    connectionStatus = 'Programming...';
    notifyListeners();

    while (progress < 100) {
      await Future.delayed(const Duration(milliseconds: 120));
      progress += 8;
      if (progress > 100) progress = 100;
      notifyListeners();
    }

    programming = false;
    connectionStatus = 'Program complete';
    notifyListeners();
  }

  String _findFamilyByModel(String modelName) {
    final normalized = modelName.trim().toUpperCase();
    for (final entry in chipCatalog.entries) {
      if (entry.value.any((row) => (row['model'] ?? '').toUpperCase() == normalized)) {
        return entry.key;
      }
    }
    return selectedChipFamily == allFamiliesOption ? deviceFamily : selectedChipFamily;
  }
}
