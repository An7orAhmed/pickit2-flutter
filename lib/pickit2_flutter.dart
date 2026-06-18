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
}
