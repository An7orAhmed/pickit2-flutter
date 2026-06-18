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

  Future<void> _showDeviceSelectorSheet(BuildContext context, HomeController controller) async {
    final loaded = await controller.ensureChipCatalogLoaded();
    if (!context.mounted) return;

    if (!loaded) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(controller.connectionStatus)));
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111B2D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        final sheetHeight = MediaQuery.of(sheetContext).size.height * 0.7;
        String selectedFamily = controller.selectedChipFamily;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final families = controller.chipFamilies;
            final models = controller.getModelsByFamily(selectedFamily);

            return SizedBox(
              height: sheetHeight,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Select Target Chip',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      const Text('Step 1: Family  Step 2: Model', style: TextStyle(color: Colors.white54)),
                      const SizedBox(height: 14),
                      const Text(
                        'Family',
                        style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: families.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final family = families[index];
                            final selected = family == selectedFamily;
                            return ChoiceChip(
                              label: Text(family),
                              selected: selected,
                              selectedColor: const Color(0xFF1A3656),
                              backgroundColor: const Color(0xFF0E182A),
                              labelStyle: TextStyle(color: selected ? Colors.lightBlueAccent : Colors.white70, fontWeight: FontWeight.w600),
                              onSelected: (_) {
                                setModalState(() {
                                  selectedFamily = family;
                                });
                                controller.selectFamily(family);
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Model',
                        style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: models.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final model = models[index];
                            final modelName = model['model'] ?? 'Unknown';
                            final selected = modelName == controller.targetDevice;
                            final modelFamily = model['family'];
                            final subtitle = (modelFamily != null && selectedFamily == HomeController.allFamiliesOption)
                                ? '$modelFamily  ·  ID: ${model['deviceId'] ?? 'N/A'}'
                                : 'ID: ${model['deviceId'] ?? 'N/A'}';
                            return Material(
                              color: selected ? const Color(0xFF1A3656) : const Color(0xFF0E182A),
                              borderRadius: BorderRadius.circular(14),
                              child: ListTile(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                leading: FaIcon(
                                  FontAwesomeIcons.microchip,
                                  size: 16,
                                  color: selected ? Colors.lightBlueAccent : Colors.white60,
                                ),
                                title: Text(modelName, style: const TextStyle(color: Colors.white)),
                                subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54)),
                                trailing: selected
                                    ? const Icon(Icons.check_circle, color: Colors.lightBlueAccent)
                                    : const Icon(Icons.chevron_right, color: Colors.white38),
                                onTap: () {
                                  controller.selectChipByFamilyAndModel(selectedFamily, model);
                                  Navigator.of(sheetContext).pop();
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
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
                  _buildActionButton(FontAwesomeIcons.download, 'Program', enabled: controller.connected),
                  _buildActionButton(FontAwesomeIcons.shield, 'Verify', enabled: controller.connected),
                  _buildActionButton(FontAwesomeIcons.trash, 'Erase', enabled: controller.connected),
                  _buildActionButton(FontAwesomeIcons.file, 'Read', enabled: controller.connected),
                ],
              ),
              const SizedBox(height: 20),
              _buildFirmwareCard(controller),
              const SizedBox(height: 16),
              _buildTargetCard(controller, context),
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
                      Row(
                        children: [
                          Text(controller.deviceName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: controller.connected ? const Color(0xFF133422) : const Color(0xFF3E2A2A),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              controller.statusLabel,
                              style: TextStyle(
                                color: controller.connected ? const Color(0xFF8AF68F) : const Color(0xFFFF8A80),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(controller.serialNumber, style: const TextStyle(color: Colors.white70)),
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

  Widget _buildActionButton(IconData icon, String label, {required bool enabled}) {
    return Expanded(
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(color: const Color(0xFF111B2D), borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(icon, color: enabled ? Colors.blueAccent : Colors.white38, size: 20),
              const SizedBox(height: 10),
              Text(label, style: TextStyle(color: enabled ? Colors.white70 : Colors.white38, fontSize: 13)),
            ],
          ),
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

  Widget _buildTargetCard(HomeController controller, BuildContext context) {
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: controller.connected ? () => controller.autoDetectChip() : null,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.lightBlueAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    icon: const FaIcon(FontAwesomeIcons.wandMagicSparkles, size: 12, color: Colors.lightBlueAccent),
                    label: const Text('Auto Detect', style: TextStyle(color: Colors.lightBlueAccent)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => _showDeviceSelectorSheet(context, controller),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    child: const Text('Change'),
                  ),
                ],
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
