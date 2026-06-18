import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import 'controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _handleConnectButton(HomeController controller, BuildContext context) async {
    if (!controller.connected) {
      await controller.connect();
    } else {
      await controller.disconnect();
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(controller.connectionStatus)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08111E),
      appBar: AppBar(elevation: 0, backgroundColor: Colors.transparent, title: const Text('PICkit2 Programmer'), centerTitle: true),
      body: Consumer<HomeController>(
        builder: (context, controller, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildDeviceCard(controller, context),
              const SizedBox(height: 20),
              const Text('QUICK ACTIONS', style: TextStyle(letterSpacing: 1.2, color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildActionButton(FontAwesomeIcons.download, 'Program'),
                  _buildActionButton(FontAwesomeIcons.shield, 'Verify'),
                  _buildActionButton(FontAwesomeIcons.trash, 'Erase'),
                  _buildActionButton(FontAwesomeIcons.file, 'Read'),
                ],
              ),
              const SizedBox(height: 20),
              _buildFirmwareCard(controller),
              const SizedBox(height: 16),
              _buildTargetCard(controller),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDeviceCard(HomeController controller, BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF111B2D), borderRadius: BorderRadius.circular(22)),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(controller.deviceName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(controller.serialNumber, style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: controller.connected ? const Color(0xFF133422) : const Color(0xFF3E3E46),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        controller.statusLabel,
                        style: const TextStyle(color: Color(0xFF8AF68F), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(color: const Color(0xFF17263E), shape: BoxShape.circle),
                child: const Center(child: FaIcon(FontAwesomeIcons.microchip, color: Colors.lightBlueAccent)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _handleConnectButton(controller, context),
              style: ElevatedButton.styleFrom(
                backgroundColor: controller.connected ? Colors.redAccent : Colors.blueAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const FaIcon(FontAwesomeIcons.usb, size: 16, color: Colors.white),
              label: Text(controller.connected ? 'Disconnect' : 'Connect', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(color: const Color(0xFF111B2D), borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(icon, color: Colors.blueAccent, size: 20),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildFirmwareCard(HomeController controller) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF111B2D), borderRadius: BorderRadius.circular(22)),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(color: const Color(0xFF1E2D49), borderRadius: BorderRadius.circular(16)),
            child: const Center(child: FaIcon(FontAwesomeIcons.file, color: Colors.lightBlueAccent)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(controller.firmwareName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('${controller.firmwareSize} · ${controller.firmwareType}', style: const TextStyle(color: Colors.white54)),
              ],
            ),
          ),
          const FaIcon(FontAwesomeIcons.xmark, color: Colors.white38, size: 18),
        ],
      ),
    );
  }

  Widget _buildTargetCard(HomeController controller) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF111B2D), borderRadius: BorderRadius.circular(22)),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(color: const Color(0xFF17263E), borderRadius: BorderRadius.circular(18)),
                child: const Center(child: FaIcon(FontAwesomeIcons.memory, color: Colors.blueAccent)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(controller.targetDevice, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(controller.deviceFamily, style: const TextStyle(color: Colors.white54)),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  side: const BorderSide(color: Colors.blueAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Change', style: TextStyle(color: Colors.blueAccent)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatTile('Flash Size', controller.flashSize),
              _buildStatTile('RAM Size', controller.ramSize),
              _buildStatTile('EEPROM Size', controller.eepromSize),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatTile('Programmer Firmware', controller.programmerFirmware),
              _buildStatTile('Device ID', controller.deviceId),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
