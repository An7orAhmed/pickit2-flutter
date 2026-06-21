import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import 'controller.dart';
import 'widgets/action_button.dart';
import 'widgets/bottom_nav_item.dart';
import 'widgets/hex_table_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _handleConnectButton(HomeController controller) async {
    if (!controller.connected) {
      await controller.connect();
    } else {
      await controller.disconnect();
    }
    if (mounted) {
      _showSnack(controller.connectionStatus);
    }
  }

  Future<void> _showDeviceSelectorSheet(HomeController controller) async {
    final loaded = await controller.ensureChipCatalogLoaded();
    if (!mounted) return;

    if (!loaded) {
      _showSnack(controller.connectionStatus);
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

  Future<void> _pickFirmwareFile(HomeController controller) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['hex', 'bin'],
      dialogTitle: 'Select firmware file (.hex or .bin)',
    );
    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null) return;

    final loaded = await controller.loadFirmwareFile(path);
    if (loaded != null) {
      if (!mounted) return;
      _showSnack(controller.connectionStatus);
    }
  }

  Future<void> _clearFirmware(HomeController controller) async {
    await controller.clearFirmware();
    if (!mounted) return;
    _showSnack(controller.connectionStatus);
  }

  Future<void> _handleErase(HomeController controller) async {
    final success = await controller.eraseChip();
    if (!mounted) return;
    if (success == true) {
      _showSnack('Chip erased successfully');
    } else {
      _showSnack(controller.connectionStatus);
    }
  }

  Future<void> _handleRead(HomeController controller) async {
    final result = await controller.readChip();
    if (!mounted) return;
    if (result?["success"] == true) {
      _showSnack('Chip read successfully');
    } else {
      _showSnack(controller.connectionStatus);
    }
  }

  Future<void> _saveReadToHex(HomeController controller) async {
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Read Data as HEX',
      fileName: 'read_data.hex',
      type: FileType.custom,
      allowedExtensions: ['hex'],
    );
    if (result == null) return;
    if (!mounted) return;

    final allData = [...controller.readProgramMemory, ...controller.readEepromMemory, ...controller.readConfigMemory];
    if (allData.isEmpty) {
      _showSnack('No data to save', kind: _SnackKind.warning);
      return;
    }

    final success = await controller.saveHexFile(result, allData, 1, 2);
    if (!mounted) return;
    if (success == true) {
      _showSnack('Saved to $result');
    } else {
      _showSnack(controller.connectionStatus);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Snackbar helpers ─────────────────────────────────────────────────────

  _SnackKind _resolveSnackKind(String message) {
    final m = message.toLowerCase();
    if (m.contains('success') ||
        m.contains('complete') ||
        m.contains('connected') ||
        m.contains('loaded') ||
        m.contains('saved') ||
        m.contains('erased') ||
        m.contains('detected') ||
        m.contains('selected') ||
        m.contains('cleared') ||
        m.contains('read:') ||
        m.contains('read successfully')) {
      return _SnackKind.success;
    }
    if (m.contains('fail') || m.contains('error') || m.contains('unavailable') || m.contains('denied') || m.contains('refused')) {
      return _SnackKind.error;
    }
    if (m.contains('not implemented') ||
        m.contains('connect pickit') ||
        m.contains('no data') ||
        m.contains('unrecognised') ||
        m.contains('first')) {
      return _SnackKind.warning;
    }
    return _SnackKind.info;
  }

  void _showSnack(String message, {_SnackKind? kind}) {
    if (!mounted) return;
    final resolved = kind ?? _resolveSnackKind(message);

    final Color bgColor;
    final Color accentColor;
    final IconData icon;

    switch (resolved) {
      case _SnackKind.success:
        bgColor = const Color(0xFF0A2E1A);
        accentColor = const Color(0xFF4ADE80);
        icon = Icons.check_circle_rounded;
      case _SnackKind.error:
        bgColor = const Color(0xFF2E0A0A);
        accentColor = const Color(0xFFFF6B6B);
        icon = Icons.cancel_rounded;
      case _SnackKind.warning:
        bgColor = const Color(0xFF2E200A);
        accentColor = const Color(0xFFFFBB33);
        icon = Icons.warning_amber_rounded;
      case _SnackKind.info:
        bgColor = const Color(0xFF0A1B2E);
        accentColor = const Color(0xFF60BFFF);
        icon = Icons.info_rounded;
    }

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          duration: const Duration(seconds: 3),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1.2),
              boxShadow: [
                BoxShadow(color: accentColor.withValues(alpha: 0.18), blurRadius: 20, offset: const Offset(0, 8)),
                const BoxShadow(color: Color(0xCC040A12), blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                Icon(icon, color: accentColor, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08111E),
      appBar: AppBar(elevation: 0, backgroundColor: Colors.transparent, title: const Text('PICkit2 Programmer'), centerTitle: true),
      body: Consumer<HomeController>(
        builder: (context, controller, child) {
          return TabBarView(controller: _tabController, children: [_buildMainTab(controller), _buildHexTableTab(controller)]);
        },
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: AnimatedBuilder(
        animation: _tabController,
        builder: (context, child) {
          final selectedIndex = _tabController.index;

          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF16243A), Color(0xFF0A1322)],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              boxShadow: const [
                BoxShadow(color: Color(0x66040A12), blurRadius: 24, offset: Offset(0, 14)),
                BoxShadow(color: Color(0x221CA8FF), blurRadius: 20, spreadRadius: -8, offset: Offset(0, 4)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: BottomNavItem(
                      label: 'Home',
                      icon: Icons.dashboard_rounded,
                      selected: selectedIndex == 0,
                      onTap: () => _tabController.animateTo(0),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BottomNavItem(
                      label: 'Hex View',
                      icon: Icons.hexagon_rounded,
                      selected: selectedIndex == 1,
                      onTap: () => _tabController.animateTo(1),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainTab(HomeController controller) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildDeviceCard(controller),
        const SizedBox(height: 20),
        const Text('QUICK ACTIONS', style: TextStyle(letterSpacing: 1.2, color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ActionButton(
              icon: FontAwesomeIcons.download,
              label: 'Program',
              enabled: controller.connected && controller.chipSelected,
              onTap: () => controller.startProgramming(),
            ),
            ActionButton(
              icon: FontAwesomeIcons.shield,
              label: 'Verify',
              enabled: controller.connected && controller.chipSelected,
              onTap: () {
                _showSnack('Verify not implemented', kind: _SnackKind.warning);
              },
            ),
            ActionButton(
              icon: FontAwesomeIcons.trash,
              label: 'Erase',
              enabled: controller.connected && controller.chipSelected,
              onTap: () => _handleErase(controller),
            ),
            ActionButton(
              icon: FontAwesomeIcons.file,
              label: 'Read',
              enabled: controller.connected && controller.chipSelected,
              onTap: () => _handleRead(controller),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildFirmwareCard(controller),
        const SizedBox(height: 16),
        _buildTargetCard(controller),
      ],
    );
  }

  Widget _buildHexTableTab(HomeController controller) {
    final hasData =
        controller.readProgramMemory.isNotEmpty || controller.readEepromMemory.isNotEmpty || controller.readConfigMemory.isNotEmpty;
    if (!hasData) {
      return Center(
        child: Text('No data read yet. Use Read button to read chip memory.', style: const TextStyle(color: Colors.white54)),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            indicatorColor: Colors.blueAccent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [
              Tab(text: 'Program'),
              Tab(text: 'EEPROM'),
              Tab(text: 'Config'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildMemoryHexTable(controller.readProgramMemory, 'Program Memory'),
                _buildMemoryHexTable(controller.readEepromMemory, 'EEPROM'),
                _buildMemoryHexTable(controller.readConfigMemory, 'Config'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _saveReadToHex(controller),
                icon: const Icon(Icons.save, color: Colors.white, size: 18),
                label: const Text('Save HEX', style: TextStyle(color: Colors.white)),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryHexTable(List<int> data, String title) {
    if (data.isEmpty) {
      return Center(
        child: Text('No $title data', style: const TextStyle(color: Colors.white54)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '$title (${data.length} bytes)',
              style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          HexTableView(data: data),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(HomeController controller) {
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
                    Text(
                      "${controller.serialNumber} | OS v${controller.programmerFirmware}",
                      style: const TextStyle(color: Colors.white70),
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
              onPressed: () => _handleConnectButton(controller),
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
                Text(
                  controller.firmwareName == 'N/A' ? 'Import .hex/.bin' : controller.firmwareName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  controller.firmwareName == 'N/A' ? 'Load a firmware file' : '${controller.firmwareSize} · ${controller.firmwareType}',
                  style: const TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _pickFirmwareFile(controller),
            icon: const FaIcon(FontAwesomeIcons.folderOpen, color: Colors.lightBlueAccent, size: 18),
            tooltip: 'Load Firmware',
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: controller.firmwareName != 'N/A' ? () => _clearFirmware(controller) : null,
            icon: const FaIcon(FontAwesomeIcons.xmark, color: Colors.white38, size: 18),
            tooltip: 'Clear',
          ),
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
                    Text(
                      controller.targetDevice,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: controller.chipSelected ? Colors.white : Colors.white38,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(controller.deviceFamily, style: TextStyle(color: controller.chipSelected ? Colors.white54 : Colors.white24)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: controller.connected ? () => controller.autoDetectChip() : null,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.lightBlueAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  icon: const FaIcon(FontAwesomeIcons.wandMagicSparkles, size: 12, color: Colors.lightBlueAccent),
                  label: const Text('Auto Detect', style: TextStyle(color: Colors.lightBlueAccent)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => _showDeviceSelectorSheet(controller),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  child: const Text('Change'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatTile('Device ID', controller.deviceId),
              _buildStatTile('Flash Size', controller.flashSize),
              _buildStatTile('RAM Size', controller.ramSize),
              _buildStatTile('EEPROM Size', controller.eepromSize),
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

enum _SnackKind { success, error, warning, info }
