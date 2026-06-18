import 'package:flutter/material.dart';
import 'package:pickit2_flutter/pickit2_flutter.dart';

class HomeController extends ChangeNotifier {
  final Pickit2Flutter _pickit2 = Pickit2Flutter();
  static const String _defaultPk2CmdDatPath = '/Users/an7or/MyWork/pk2cmd/PK2DeviceFile.dat';
  static const String allFamiliesOption = 'All';
  final Map<String, List<Map<String, String>>> chipCatalog = <String, List<Map<String, String>>>{};

  String connectionStatus = 'Disconnected';
  bool connected = false;
  int progress = 0;
  bool programming = false;

  String firmwareName = 'firmware_v1.2.hex';
  String firmwareSize = '128.45 KB';
  String firmwareType = 'Intel HEX';

  String deviceName = 'PICkit2';
  String targetDevice = 'PIC18F4550';
  String serialNumber = 'N/A';
  String deviceFamily = 'PIC18 Family';
  String flashSize = '32 KB';
  String ramSize = '2 KB';
  String eepromSize = '256 B';
  String programmerFirmware = '04.61.00';
  String deviceId = '0x0013';
  String selectedChipFamily = allFamiliesOption;
  bool chipCatalogLoaded = false;

  String get statusLabel => connected ? 'Ready' : 'Offline';

  List<String> get chipFamilies => <String>[allFamiliesOption, ...chipCatalog.keys];

  List<Map<String, String>> getModelsByFamily(String family) {
    if (family == allFamiliesOption) {
      final allModels = <Map<String, String>>[];
      for (final entry in chipCatalog.entries) {
        for (final row in entry.value) {
          allModels.add(<String, String>{
            ...row,
            'family': entry.key,
          });
        }
      }
      return allModels;
    }
    return chipCatalog[family] ?? const <Map<String, String>>[];
  }

  Future<bool> ensureChipCatalogLoaded({String? datFilePath}) async {
    if (chipCatalogLoaded && chipCatalog.isNotEmpty) {
      return true;
    }

    connectionStatus = 'Loading chip data...';
    notifyListeners();

    final preferredPath = (datFilePath == null || datFilePath.trim().isEmpty) ? _defaultPk2CmdDatPath : datFilePath;
    final loadResult = await _pickit2.loadChipDataFromDat(filePath: preferredPath) ??
      await _pickit2.loadChipDataFromDat();
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

        final familyModels = getModelsByFamily(preferredFamily);
        final currentModel = familyModels.firstWhere(
          (row) => row['model'] == targetDevice,
          orElse: () => familyModels.first,
        );
        selectChipByFamilyAndModel(preferredFamily, currentModel);
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
    connectionStatus = 'Selected chip: $targetDevice';
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
      connectionStatus = 'Chip auto-detect failed';
      notifyListeners();
      return;
    }

    final family = (detectedFamily != null && detectedFamily.isNotEmpty)
        ? detectedFamily
        : _findFamilyByModel(detectedModel);
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
    } catch (error) {
      connectionStatus = 'Disconnect failed';
      connected = false;
      serialNumber = 'N/A';
    }

    notifyListeners();
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
