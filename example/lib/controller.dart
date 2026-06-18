import 'package:flutter/material.dart';
import 'package:pickit2_flutter/pickit2_flutter.dart';

class HomeController extends ChangeNotifier {
  final Pickit2Flutter _pickit2 = Pickit2Flutter();

  String connectionStatus = 'Disconnected';
  bool connected = false;
  int progress = 0;
  bool programming = false;

  String firmwareName = 'firmware_v1.2.hex';
  String firmwareSize = '128.45 KB';
  String firmwareType = 'Intel HEX';

  String deviceName = 'PICkit2';
  String targetDevice = 'PIC18F4550';
  String serialNumber = 'PK2-123456';
  String deviceFamily = 'PIC18 Family';
  String flashSize = '32 KB';
  String ramSize = '2 KB';
  String eepromSize = '256 B';
  String programmerFirmware = '04.61.00';
  String deviceId = '0x0013';

  String get statusLabel => connected ? 'Ready' : 'Offline';

  Future<void> connect() async {
    connectionStatus = 'Connecting...';
    notifyListeners();

    try {
      final result = await _pickit2.connect();
      connected = result.toLowerCase().contains('connected') || result.toLowerCase().contains('ready');
      connectionStatus = result;
    } catch (error) {
      connectionStatus = 'Connection failed';
      connected = false;
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
    } catch (error) {
      connectionStatus = 'Disconnect failed';
      connected = false;
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
}
