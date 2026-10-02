import 'dart:async';

import 'package:flutter/services.dart';

class Pickit2Flutter {
  static const MethodChannel _channel = MethodChannel('pickit2_flutter');

  /// Callback for write firmware progress updates.
  void Function(String phase, int percent, String message)? onWriteProgress;
  void Function()? onDeviceDetached;

  Pickit2Flutter() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onWriteProgress':
        final phase = call.arguments['phase'] as String? ?? '';
        final percent = call.arguments['percent'] as int? ?? 0;
        final message = call.arguments['message'] as String? ?? '';
        onWriteProgress?.call(phase, percent, message);
        break;
      case 'onDeviceDetached':
        onDeviceDetached?.call();
        break;
    }
  }

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

  /// Returns the connected PICkit 2 firmware version.
  Future<String?> getFirmwareVersion() async {
    try {
      return await _channel.invokeMethod<String>('getFirmwareVersion');
    } on PlatformException {
      return null;
    }
  }

  /// Opens the native macOS firmware chooser and returns the selected path.
  Future<String?> pickFirmwareFile() async {
    try {
      return await _channel.invokeMethod<String>('pickFirmwareFile');
    } on PlatformException {
      return null;
    }
  }

  /// Opens the native macOS HEX save panel and returns the selected path.
  Future<String?> pickHexSavePath({String fileName = 'read_data.hex'}) async {
    try {
      return await _channel.invokeMethod<String>('pickHexSavePath', {
        'fileName': fileName,
      });
    } on PlatformException {
      return null;
    }
  }

  /// Loads a HEX file and returns summary info.
  Future<Map<String, dynamic>?> loadHexFile(String path) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'loadHexFile',
        {'path': path},
      );
      return result == null ? null : Map<String, dynamic>.from(result);
    } on PlatformException {
      return null;
    }
  }

  /// Loads a BIN file and returns summary info.
  Future<Map<String, dynamic>?> loadBinFile(
    String path, {
    int baseAddress = 0,
  }) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'loadBinFile',
        {'path': path, 'baseAddress': baseAddress},
      );
      return result == null ? null : Map<String, dynamic>.from(result);
    } on PlatformException {
      return null;
    }
  }

  /// Clears the loaded program image.
  Future<bool?> clearLoadedImage() async {
    try {
      return await _channel.invokeMethod<bool>('clearLoadedImage');
    } on PlatformException {
      return null;
    }
  }

  /// Gets info about the currently loaded program image.
  Future<Map<String, dynamic>?> getLoadedImageInfo() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'getLoadedImageInfo',
      );
      return result == null ? null : Map<String, dynamic>.from(result);
    } on PlatformException {
      return null;
    }
  }

  /// Returns the full loaded program image data as address-byte pairs.
  /// Result contains: sourceType, loadedBytes, minAddress, maxAddress,
  /// and a data list of [addr1, val1, addr2, val2, ...].
  Future<Map<String, dynamic>?> getLoadedImageData() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'getLoadedImageData',
      );
      return result == null ? null : Map<String, dynamic>.from(result);
    } on PlatformException {
      return null;
    }
  }

  /// Loads pre-generated chip catalog assets.
  /// If paths are omitted, the bundled Android assets are used.
  Future<Map<String, dynamic>?> loadChipData({
    String? catalogPath,
    String? detectPath,
  }) async {
    try {
      final result = await _channel
          .invokeMapMethod<String, dynamic>('loadChipData', {
            if (catalogPath != null && catalogPath.trim().isNotEmpty)
              'catalogPath': catalogPath,
            if (detectPath != null && detectPath.trim().isNotEmpty)
              'detectPath': detectPath,
          });
      return result == null ? null : Map<String, dynamic>.from(result);
    } on PlatformException {
      return null;
    }
  }

  /// Legacy alias kept so older callers continue to work after the runtime
  /// `.dat` parser was removed.
  Future<Map<String, dynamic>?> loadChipDataFromDat({String? filePath}) async {
    return loadChipData();
  }

  /// Returns full chip catalog grouped by family.
  Future<Map<String, List<Map<String, String>>>> getChipCatalog() async {
    final raw = await _channel.invokeMethod<dynamic>('getChipCatalog');
    final map = (raw as Map<dynamic, dynamic>?) ?? const <dynamic, dynamic>{};
    final result = <String, List<Map<String, String>>>{};

    map.forEach((key, value) {
      final family = key.toString();
      final rows = (value as List<dynamic>? ?? const <dynamic>[])
          .map(
            (entry) => Map<String, String>.from(
              (entry as Map).map(
                (k, v) => MapEntry(k.toString(), v.toString()),
              ),
            ),
          )
          .toList();
      result[family] = rows;
    });

    return result;
  }

  /// Performs hardware-backed target auto-detect using loaded device file scripts.
  Future<Map<String, dynamic>?> autoDetectChip() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'autoDetectChip',
      );
      return result == null ? null : Map<String, dynamic>.from(result);
    } on PlatformException {
      return null;
    }
  }

  /// Configures the native side with the manually selected chip parameters so
  /// that subsequent erase/read operations target the correct memory layout.
  Future<bool?> selectChip({
    required String model,
    required String flashSize,
    required String eepromSize,
    int bytesPerLocation = 2,
    int eeMemBytesPerWord = 1,
    int eeAddr = 0,
    int configWords = 0,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('selectChip', {
        'model': model,
        'flashSize': flashSize,
        'eepromSize': eepromSize,
        'bytesPerLocation': bytesPerLocation,
        'eeMemBytesPerWord': eeMemBytesPerWord,
        'eeAddr': eeAddr,
        'configWords': configWords,
      });
    } on PlatformException {
      return null;
    }
  }

  /// Erases the connected chip's program memory, EEPROM, and configuration.
  Future<bool?> eraseChip() async {
    try {
      return await _channel.invokeMethod<bool>('eraseChip');
    } on PlatformException {
      return null;
    }
  }

  /// Checks every supported target memory region against its blank value.
  Future<Map<String, dynamic>?> blankCheck() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'blankCheck',
      );
      return result == null ? null : Map<String, dynamic>.from(result);
    } on PlatformException {
      return null;
    }
  }

  /// Reads program memory, EEPROM, and config from the connected chip.
  Future<Map<String, dynamic>?> readChip() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'readChip',
      );
      return result == null ? null : Map<String, dynamic>.from(result);
    } on PlatformException {
      return null;
    }
  }

  /// Saves read data to a HEX file at the specified path.
  Future<bool?> saveHexFile(
    String path,
    List<int> data,
    int addressIncrement,
    int bytesPerWord,
  ) async {
    try {
      final result = await _channel.invokeMethod<bool>('saveHexFile', {
        'path': path,
        'data': data,
        'addressIncrement': addressIncrement,
        'bytesPerWord': bytesPerWord,
      });
      return result;
    } on PlatformException {
      return null;
    }
  }

  /// Saves the most recently read target image without flattening its address regions.
  Future<bool?> saveReadHex(String path) async {
    try {
      return await _channel.invokeMethod<bool>('saveReadHex', {'path': path});
    } on PlatformException {
      return null;
    }
  }

  /// Returns editable configuration words for the selected target and loaded image.
  Future<List<Map<String, dynamic>>> getConfigWords() async {
    try {
      final raw =
          await _channel.invokeListMethod<dynamic>('getConfigWords') ??
          const [];
      return raw
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList();
    } on PlatformException {
      return const [];
    }
  }

  /// Updates a raw configuration word, applying the device mask natively.
  Future<Map<String, dynamic>?> setConfigWord(int index, int value) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'setConfigWord',
        {'index': index, 'value': value},
      );
      return result == null ? null : Map<String, dynamic>.from(result);
    } on PlatformException {
      return null;
    }
  }

  /// Writes the currently loaded firmware image to the connected chip following
  /// the Microchip standard flow: erase → blank check → write → verify.
  ///
  /// Progress is reported via [onWriteProgress] callback.
  /// Returns a map with [success] and [message] keys.
  Future<Map<String, dynamic>?> writeFirmware() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'writeFirmware',
      );
      return result == null ? null : Map<String, dynamic>.from(result);
    } on PlatformException {
      return null;
    }
  }

  /// Verifies the connected target against the currently loaded image.
  Future<Map<String, dynamic>?> verifyFirmware() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'verifyFirmware',
      );
      return result == null ? null : Map<String, dynamic>.from(result);
    } on PlatformException {
      return null;
    }
  }
}
