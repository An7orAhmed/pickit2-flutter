import 'package:flutter/services.dart';

class Pickit2Flutter {
  static const MethodChannel _channel = MethodChannel('pickit2_flutter');

  /// Requests USB permission and connects to the PICkit 2.
  Future<String> connect() async {
    try {
      final String result = await _channel.invokeMethod('connect');
      return result;
    } on PlatformException catch (e) {
      return "Connection Failed: ${e.message}";
    }
  }

  /// Disconnects and releases the USB interface.
  Future<void> disconnect() async {
    await _channel.invokeMethod('disconnect');
  }

  /// Returns the connected PICkit 2 serial number.
  Future<String?> getSerialNumber() async {
    try {
      return await _channel.invokeMethod<String>('getSerialNumber');
    } on PlatformException {
      return null;
    }
  }

  /// Loads chip catalog data from PK2DeviceFile.dat.
  /// If [filePath] is null, plugin loads the bundled Android asset.
  Future<Map<String, dynamic>?> loadChipDataFromDat({String? filePath}) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('loadChipDataFromDat', {
        if (filePath != null && filePath.trim().isNotEmpty) 'filePath': filePath,
      });
      return result == null ? null : Map<String, dynamic>.from(result);
    } on PlatformException {
      return null;
    }
  }

  /// Returns full chip catalog grouped by family.
  Future<Map<String, List<Map<String, String>>>> getChipCatalog() async {
    final raw = await _channel.invokeMethod<dynamic>('getChipCatalog');
    final map = (raw as Map<dynamic, dynamic>?) ?? const <dynamic, dynamic>{};
    final result = <String, List<Map<String, String>>>{};

    map.forEach((key, value) {
      final family = key.toString();
      final rows = (value as List<dynamic>? ?? const <dynamic>[])
          .map((entry) => Map<String, String>.from((entry as Map).map((k, v) => MapEntry(k.toString(), v.toString()))))
          .toList();
      result[family] = rows;
    });

    return result;
  }

  /// Performs hardware-backed target auto-detect using loaded device file scripts.
  Future<Map<String, dynamic>?> autoDetectChip() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('autoDetectChip');
      return result == null ? null : Map<String, dynamic>.from(result);
    } on PlatformException {
      return null;
    }
  }
}
