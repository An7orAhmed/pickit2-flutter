import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import 'controller.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(controller.connectionStatus)));
    }
  }

  Future<void> _showDeviceSelectorSheet(HomeController controller) async {
    final loaded = await controller.ensureChipCatalogLoaded();
    if (!mounted) return;

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(controller.connectionStatus)));
    }
  }

  Future<void> _clearFirmware(HomeController controller) async {
    await controller.clearFirmware();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(controller.connectionStatus)));
  }

  Future<void> _handleErase(HomeController controller) async {
    final success = await controller.eraseChip();
    if (!mounted) return;
    if (success == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chip erased successfully')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(controller.connectionStatus)));
    }
  }

  Future<void> _handleRead(HomeController controller) async {
    final result = await controller.readChip();
    if (!mounted) return;
    if (result?["success"] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chip read successfully')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(controller.connectionStatus)));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data to save')));
      return;
    }

    final success = await controller.saveHexFile(result, allData, 1, 2);
    if (!mounted) return;
    if (success == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to $result')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(controller.connectionStatus)));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
                    child: _BottomNavItem(
                      label: 'Home',
                      icon: Icons.dashboard_rounded,
                      selected: selectedIndex == 0,
                      onTap: () => _tabController.animateTo(0),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _BottomNavItem(
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
            _buildActionButton(
              FontAwesomeIcons.download,
              'Program',
              enabled: controller.connected && controller.chipSelected,
              onTap: () => controller.startProgramming(),
            ),
            _buildActionButton(
              FontAwesomeIcons.shield,
              'Verify',
              enabled: controller.connected && controller.chipSelected,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verify not implemented')));
              },
            ),
            _buildActionButton(
              FontAwesomeIcons.trash,
              'Erase',
              enabled: controller.connected && controller.chipSelected,
              onTap: () => _handleErase(controller),
            ),
            _buildActionButton(
              FontAwesomeIcons.file,
              'Read',
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
          _HexTableView(data: data),
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

  Widget _buildActionButton(IconData icon, String label, {required bool enabled, required VoidCallback onTap}) {
    return _ActionButton(icon: icon, label: label, enabled: enabled, onTap: onTap);
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

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.enabled,
    this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.enabled) _scaleController.forward();
  }

  void _onTapUp(TapUpDetails _) => _scaleController.reverse();
  void _onTapCancel() => _scaleController.reverse();

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: AnimatedOpacity(
          opacity: widget.enabled ? 1.0 : 0.4,
          duration: const Duration(milliseconds: 200),
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovering = true),
            onExit: (_) => setState(() => _hovering = false),
            cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: _hovering && widget.enabled ? const Color(0xFF1C2E47) : const Color(0xFF111B2D),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _hovering && widget.enabled
                        ? Colors.blueAccent.withValues(alpha: 0.45)
                        : Colors.white.withValues(alpha: 0.04),
                  ),
                  boxShadow: _hovering && widget.enabled
                      ? [const BoxShadow(color: Color(0x331B6FFF), blurRadius: 14, offset: Offset(0, 6))]
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: widget.enabled ? widget.onTap : null,
                    onTapDown: _onTapDown,
                    onTapUp: _onTapUp,
                    onTapCancel: _onTapCancel,
                    splashColor: Colors.blueAccent.withValues(alpha: 0.28),
                    highlightColor: Colors.blueAccent.withValues(alpha: 0.10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: FaIcon(
                              widget.icon,
                              key: ValueKey(widget.enabled),
                              color: widget.enabled ? Colors.blueAccent : Colors.white38,
                              size: 20,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.label,
                            style: TextStyle(
                              color: widget.enabled ? Colors.white70 : Colors.white38,
                              fontSize: 13,
                              fontWeight: widget.enabled ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HexTableView extends StatelessWidget {
  final List<int> data;

  const _HexTableView({required this.data});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 4,
        headingRowHeight: 32,
        dataRowMinHeight: 24,
        dataRowMaxHeight: 24,
        headingRowColor: WidgetStateProperty.all(const Color(0xFF1A3656)),
        columns: const [
          DataColumn(
            label: Text('Addr', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 11)),
          ),
          DataColumn(
            label: Text('0', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 11)),
          ),
          DataColumn(
            label: Text('1', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 11)),
          ),
          DataColumn(
            label: Text('2', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 11)),
          ),
          DataColumn(
            label: Text('3', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 11)),
          ),
          DataColumn(
            label: Text('4', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 11)),
          ),
          DataColumn(
            label: Text('5', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 11)),
          ),
          DataColumn(
            label: Text('6', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 11)),
          ),
          DataColumn(
            label: Text('7', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 11)),
          ),
          DataColumn(
            label: Text('8', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 11)),
          ),
          DataColumn(
            label: Text('9', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 11)),
          ),
          DataColumn(
            label: Text('A', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 11)),
          ),
          DataColumn(
            label: Text('B', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 11)),
          ),
          DataColumn(
            label: Text('C', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 11)),
          ),
          DataColumn(
            label: Text('D', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 11)),
          ),
          DataColumn(
            label: Text('E', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 11)),
          ),
          DataColumn(
            label: Text('F', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 11)),
          ),
        ],
        rows: _buildRows(),
      ),
    );
  }

  List<DataRow> _buildRows() {
    final rows = <DataRow>[];
    for (int i = 0; i < data.length; i += 16) {
      final address = i;
      final rowCells = <DataCell>[];
      rowCells.add(DataCell(Text('0x${address.toHexString().toUpperCase()}', style: const TextStyle(color: Colors.white54, fontSize: 11))));
      for (int j = 0; j < 16; j++) {
        final idx = i + j;
        final cellValue = idx < data.length ? data[idx] : 0xFF;
        final isBlank = idx >= data.length || data[idx] == 0xFF;
        rowCells.add(
          DataCell(
            Text(
              '0x${cellValue.toHexString().toUpperCase().padLeft(2, '0')}',
              style: TextStyle(color: isBlank ? Colors.white24 : Colors.white, fontSize: 11),
            ),
          ),
        );
      }
      rows.add(DataRow(cells: rowCells));
    }
    return rows;
  }
}

extension IntExt on int {
  String toHexString() => toRadixString(16);
}

class _BottomNavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _BottomNavItem({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: selected
            ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2D8CFF), Color(0xFF1162FF)])
            : null,
        color: selected ? null : Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: selected ? Colors.white.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.06)),
        boxShadow: selected ? const [BoxShadow(color: Color(0x55156CFF), blurRadius: 18, offset: Offset(0, 10))] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: selected ? Colors.white : Colors.white70),
                const SizedBox(width: 10),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                  child: Text(label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
