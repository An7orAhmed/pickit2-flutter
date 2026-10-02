import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import 'controller.dart';
import 'desktop_home.dart';
import 'mobile_home.dart';
import 'theme_controller.dart';
import 'widgets/hex_table_view.dart';

const _appVersion = '1.0.0';
const _pk2cmdLicense = '''Microchip Technology Inc. Software License Agreement

Copyright (c) 2005-2009, Microchip Technology Inc. All rights reserved.

You may use, copy, modify and distribute the Software for use with Microchip products only. If you distribute the Software or its derivatives, the Software must have this entire copyright and disclaimer notice prominently posted in a location where end users will see it (e.g., installation program, program headers, About Box, etc.).

To the maximum extent permitted by law, this Software is distributed "AS IS" and WITHOUT ANY WARRANTY INCLUDING BUT NOT LIMITED TO ANY IMPLIED WARRANTY OF MERCHANTABILITY, FITNESS FOR PARTICULAR PURPOSE, or NON-INFRINGEMENT. IN NO EVENT WILL MICROCHIP OR ITS LICENSORS BE LIABLE FOR ANY INCIDENTAL, SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OF ANY KIND ARISING FROM OR RELATED TO THE USE, MODIFICATION OR DISTRIBUTION OF THIS SOFTWARE OR ITS DERIVATIVES.

The incorporated pk2cmd-minus source also contains third-party portions with their own notices in the corresponding source files.''';

String _formatConfigWord(int value, int byteCount) {
  return '0x${value.toRadixString(16).toUpperCase().padLeft(byteCount * 2, '0')}';
}

int? _parseConfigWord(String input) {
  var value = input.trim();
  if (value.toLowerCase().startsWith('0x')) value = value.substring(2);
  if (value.isEmpty || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(value)) {
    return null;
  }
  return int.tryParse(value, radix: 16);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
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

    if (defaultTargetPlatform == TargetPlatform.macOS) {
      await _showDesktopDeviceSelectorDialog(controller);
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final sheetHeight = MediaQuery.of(sheetContext).size.height * 0.7;
        String selectedFamily = controller.selectedChipFamily;
        String searchQuery = '';

        return StatefulBuilder(
          builder: (context, setModalState) {
            final colors = Theme.of(context).colorScheme;
            final families = controller.chipFamilies;
            final query = searchQuery.trim().toLowerCase();
            final models = controller.getModelsByFamily(selectedFamily).where((
              model,
            ) {
              if (query.isEmpty) return true;
              return (model['model'] ?? '').toLowerCase().contains(query) ||
                  (model['deviceId'] ?? '').toLowerCase().contains(query) ||
                  (model['family'] ?? selectedFamily).toLowerCase().contains(
                    query,
                  );
            }).toList();

            return SizedBox(
              height: sheetHeight,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Target Chip',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Family',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: families.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final family = families[index];
                            final selected = family == selectedFamily;
                            return ChoiceChip(
                              label: Text(family),
                              selected: selected,
                              selectedColor: colors.primaryContainer,
                              backgroundColor: colors.surfaceContainerHigh,
                              labelStyle: TextStyle(
                                color: selected
                                    ? colors.onPrimaryContainer
                                    : colors.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
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
                      TextField(
                        onChanged: (value) {
                          setModalState(() => searchQuery = value);
                        },
                        textInputAction: TextInputAction.search,
                        decoration: const InputDecoration(
                          hintText: 'Search model, family, or device ID',
                          prefixIcon: Icon(Icons.search_rounded),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Model (${models.length})',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: models.isEmpty
                            ? Center(
                                child: Text(
                                  'No matching chips',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                itemCount: models.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final model = models[index];
                                  final modelName = model['model'] ?? 'Unknown';
                                  final selected =
                                      modelName == controller.targetDevice;
                                  final modelFamily = model['family'];
                                  final subtitle =
                                      (modelFamily != null &&
                                          selectedFamily ==
                                              HomeController.allFamiliesOption)
                                      ? '$modelFamily  ·  ID: ${model['deviceId'] ?? 'N/A'}'
                                      : 'ID: ${model['deviceId'] ?? 'N/A'}';
                                  return Material(
                                    color: selected
                                        ? colors.primaryContainer
                                        : colors.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(14),
                                    child: ListTile(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      leading: Icon(
                                        Icons.memory_rounded,
                                        size: 16,
                                        color: selected
                                            ? colors.primary
                                            : colors.onSurfaceVariant,
                                      ),
                                      title: Text(modelName),
                                      subtitle: Text(
                                        subtitle,
                                        style: TextStyle(
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                      trailing: Icon(
                                        selected
                                            ? Icons.check_circle
                                            : Icons.chevron_right,
                                        color: selected
                                            ? colors.primary
                                            : colors.onSurfaceVariant,
                                      ),
                                      onTap: () async {
                                        await controller
                                            .selectChipByFamilyAndModel(
                                              selectedFamily,
                                              model,
                                            );
                                        if (sheetContext.mounted) {
                                          Navigator.of(sheetContext).pop();
                                        }
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

  Future<void> _showDesktopDeviceSelectorDialog(
    HomeController controller,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        String selectedFamily = controller.selectedChipFamily;
        String searchQuery = '';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final colors = Theme.of(context).colorScheme;
            final families = controller.chipFamilies;
            final query = searchQuery.trim().toLowerCase();
            final models = controller.getModelsByFamily(selectedFamily).where((
              model,
            ) {
              if (query.isEmpty) return true;
              return (model['model'] ?? '').toLowerCase().contains(query) ||
                  (model['deviceId'] ?? '').toLowerCase().contains(query) ||
                  (model['family'] ?? selectedFamily).toLowerCase().contains(
                    query,
                  );
            }).toList();

            return Dialog(
              backgroundColor: colors.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: colors.outlineVariant),
              ),
              child: SizedBox(
                width: 820,
                height: 570,
                child: Column(
                  children: [
                    Container(
                      height: 58,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHigh,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(9),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.memory_rounded,
                            size: 20,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Select Target Device',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Choose a device family and model',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: Row(
                        children: [
                          SizedBox(
                            width: 235,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    15,
                                    16,
                                    9,
                                  ),
                                  child: Text(
                                    'DEVICE FAMILIES',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: colors.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    itemCount: families.length,
                                    itemBuilder: (context, index) {
                                      final family = families[index];
                                      final selected = family == selectedFamily;
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 3,
                                        ),
                                        child: Material(
                                          color: selected
                                              ? colors.primaryContainer
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          child: ListTile(
                                            dense: true,
                                            minLeadingWidth: 18,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            leading: Icon(
                                              Icons.folder_outlined,
                                              size: 16,
                                              color: selected
                                                  ? colors.onPrimaryContainer
                                                  : colors.onSurfaceVariant,
                                            ),
                                            title: Text(
                                              family,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: selected
                                                    ? colors.onPrimaryContainer
                                                    : colors.onSurfaceVariant,
                                              ),
                                            ),
                                            onTap: () {
                                              controller.selectFamily(family);
                                              setDialogState(() {
                                                selectedFamily = family;
                                              });
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    13,
                                    16,
                                    10,
                                  ),
                                  child: TextField(
                                    autofocus: true,
                                    onChanged: (value) {
                                      setDialogState(() {
                                        searchQuery = value;
                                      });
                                    },
                                    style: const TextStyle(fontSize: 12),
                                    decoration: InputDecoration(
                                      hintText: 'Search model or device ID',
                                      hintStyle: TextStyle(
                                        color: colors.onSurfaceVariant,
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.search_rounded,
                                        size: 17,
                                      ),
                                      suffixText: '${models.length} models',
                                      suffixStyle: TextStyle(
                                        fontSize: 10.5,
                                        color: colors.onSurfaceVariant,
                                      ),
                                      isDense: true,
                                      filled: true,
                                      fillColor: colors.surfaceContainerLowest,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 9,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: BorderSide(
                                          color: colors.outlineVariant,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: BorderSide(
                                          color: colors.outlineVariant,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: BorderSide(
                                          color: colors.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  height: 32,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceContainerLowest,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          'Model',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Device ID',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Flash',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Expanded(
                                  child: models.isEmpty
                                      ? Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.search_off_rounded,
                                                size: 28,
                                                color: colors.onSurface
                                                    .withValues(alpha: 0.24),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'No matching devices',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  color:
                                                      colors.onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : ListView.builder(
                                          padding: const EdgeInsets.fromLTRB(
                                            12,
                                            0,
                                            12,
                                            12,
                                          ),
                                          itemCount: models.length,
                                          itemBuilder: (context, index) {
                                            final model = models[index];
                                            final modelName =
                                                model['model'] ?? 'Unknown';
                                            final selected =
                                                modelName ==
                                                controller.targetDevice;
                                            return Material(
                                              color: selected
                                                  ? colors.primaryContainer
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                                onTap: () async {
                                                  await controller
                                                      .selectChipByFamilyAndModel(
                                                        selectedFamily,
                                                        model,
                                                      );
                                                  if (dialogContext.mounted) {
                                                    Navigator.of(
                                                      dialogContext,
                                                    ).pop();
                                                  }
                                                },
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 9,
                                                      ),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        flex: 3,
                                                        child: Row(
                                                          children: [
                                                            if (selected) ...[
                                                              Icon(
                                                                Icons
                                                                    .check_rounded,
                                                                size: 14,
                                                                color: colors
                                                                    .onPrimaryContainer,
                                                              ),
                                                              const SizedBox(
                                                                width: 6,
                                                              ),
                                                            ],
                                                            Flexible(
                                                              child: Text(
                                                                modelName,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style:
                                                                    const TextStyle(
                                                                      fontSize:
                                                                          11.5,
                                                                    ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Expanded(
                                                        flex: 2,
                                                        child: Text(
                                                          model['deviceId'] ??
                                                              'N/A',
                                                          style: TextStyle(
                                                            fontSize: 10.5,
                                                            color: colors
                                                                .onSurfaceVariant,
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        flex: 2,
                                                        child: Text(
                                                          model['flashSize'] ??
                                                              'N/A',
                                                          style: TextStyle(
                                                            fontSize: 10.5,
                                                            color: colors
                                                                .onSurfaceVariant,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickFirmwareFile(HomeController controller) async {
    final String? path;
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      path = await controller.pickFirmwarePath();
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['hex', 'bin'],
        dialogTitle: 'Select firmware file (.hex or .bin)',
      );
      path = result?.files.single.path;
    }
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
    final confirmed = await _confirmAction(
      title: 'Erase target?',
      message:
          'This permanently clears program memory, EEPROM, user IDs, and configuration memory.',
      confirmLabel: 'Erase',
    );
    if (!confirmed) return;
    final success = await controller.eraseChip();
    if (!mounted) return;
    if (success == true) {
      _showSnack('Chip erased successfully');
    } else {
      _showSnack(controller.connectionStatus);
    }
  }

  Future<void> _handleProgram(HomeController controller) async {
    final confirmed = await _confirmAction(
      title: 'Program ${controller.targetDevice}?',
      message:
          'The target will be erased, programmed, and verified using ${controller.firmwareName}.',
      confirmLabel: 'Program',
    );
    if (!confirmed) return;
    final success = await controller.startProgramming();
    if (!mounted) return;
    if (success) {
      await SystemSound.play(SystemSoundType.alert);
    }
    if (mounted) _showSnack(controller.connectionStatus);
  }

  Future<void> _handleVerify(HomeController controller) async {
    final success = await controller.verifyFirmware();
    if (!mounted) return;
    _showSnack(
      controller.connectionStatus,
      kind: success ? _SnackKind.success : _SnackKind.error,
    );
  }

  Future<void> _handleBlankCheck(HomeController controller) async {
    final result = await controller.blankCheck();
    if (!mounted) return;
    final blank = result?['blank'] == true;
    _showSnack(
      controller.connectionStatus,
      kind: blank ? _SnackKind.success : _SnackKind.warning,
    );
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _showFuseEditor(HomeController controller) async {
    await controller.refreshConfigWords();
    if (!mounted) return;
    if (controller.configWords.isEmpty) {
      _showSnack(
        'Load a firmware image containing configuration data first',
        kind: _SnackKind.warning,
      );
      return;
    }

    await _showConfigurationEditor(controller);
  }

  Future<void> _showConfigurationEditor(HomeController controller) async {
    final mobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final originalValues = <int, int>{
      for (final word in controller.configWords)
        word['index'] as int: word['value'] as int? ?? 0,
    };
    final editedValues = Map<int, int>.from(originalValues);
    final valueControllers = <int, TextEditingController>{
      for (final word in controller.configWords)
        word['index'] as int: TextEditingController(
          text: _formatConfigWord(
            word['value'] as int? ?? 0,
            word['byteCount'] as int? ?? 2,
          ),
        ),
    };
    final inputErrors = <int, String?>{};
    var preferredHeight = 142.0;
    for (final word in controller.configWords) {
      final mask = word['mask'] as int? ?? 0;
      final bitCount = (word['byteCount'] as int? ?? 2) * 8;
      var editableBitCount = 0;
      for (var bit = 0; bit < bitCount; bit++) {
        if ((mask & (1 << bit)) != 0) editableBitCount++;
      }
      final bitRows = (editableBitCount + 7) ~/ 8;
      preferredHeight +=
          (mobile ? 120 : 72) +
          (bitRows == 0 ? 24 : bitRows * 44 + (bitRows - 1) * 6);
    }
    preferredHeight += (controller.configWords.length - 1) * 12;
    final dialogHeight = preferredHeight.clamp(250.0, 520.0);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final colors = Theme.of(context).colorScheme;
          return Dialog(
            child: SizedBox(
              width: 620,
              height: dialogHeight,
              child: Column(
                children: [
                  Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHigh,
                      borderRadius: BorderRadius.all(Radius.circular(26)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 18,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            '${controller.targetDevice} Configuration',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: controller.configWords.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, wordPosition) {
                        final word = controller.configWords[wordPosition];
                        final index = word['index'] as int;
                        final address = word['address'] as int? ?? 0;
                        final mask = word['mask'] as int? ?? 0;
                        final byteCount = word['byteCount'] as int? ?? 2;
                        final value = editedValues[index] ?? 0;
                        final bitCount = byteCount * 8;
                        final maxValue = (1 << bitCount) - 1;
                        final editableBits = [
                          for (var bit = bitCount - 1; bit >= 0; bit--)
                            if ((mask & (1 << bit)) != 0) bit,
                        ];
                        void updateWord(String rawValue) {
                          final parsed = _parseConfigWord(rawValue);
                          setDialogState(() {
                            if (parsed == null ||
                                parsed < 0 ||
                                parsed > maxValue) {
                              inputErrors[index] =
                                  'Enter ${byteCount * 2} hex digits';
                              return;
                            }
                            inputErrors[index] = null;
                            editedValues[index] = parsed;
                          });
                        }

                        return DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: colors.outlineVariant),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'CONFIG${index + 1}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '@ 0x${address.toRadixString(16).toUpperCase()}',
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 10.5,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                    if (!mobile) ...[
                                      const Spacer(),
                                      _ConfigWordField(
                                        controller: valueControllers[index]!,
                                        byteCount: byteCount,
                                        errorText: inputErrors[index],
                                        onChanged: updateWord,
                                      ),
                                    ],
                                  ],
                                ),
                                if (mobile) ...[
                                  const SizedBox(height: 8),
                                  _ConfigWordField(
                                    controller: valueControllers[index]!,
                                    byteCount: byteCount,
                                    errorText: inputErrors[index],
                                    width: double.infinity,
                                    onChanged: updateWord,
                                  ),
                                ],
                                const SizedBox(height: 8),
                                if (editableBits.isEmpty)
                                  Text(
                                    'No editable bits',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  )
                                else
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      const spacing = 6.0;
                                      final tileWidth =
                                          (constraints.maxWidth - spacing * 7) /
                                          8;
                                      return Wrap(
                                        spacing: spacing,
                                        runSpacing: spacing,
                                        children: editableBits.map((bit) {
                                          final set = (value & (1 << bit)) != 0;
                                          return SizedBox(
                                            width: tileWidth,
                                            child: _ConfigBitToggle(
                                              bit: bit,
                                              value: set,
                                              onChanged: (nextValue) {
                                                setDialogState(() {
                                                  final updated = nextValue
                                                      ? value | (1 << bit)
                                                      : value & ~(1 << bit);
                                                  editedValues[index] = updated;
                                                  inputErrors[index] = null;
                                                  final text =
                                                      _formatConfigWord(
                                                        updated,
                                                        byteCount,
                                                      );
                                                  valueControllers[index]!
                                                      .value = TextEditingValue(
                                                    text: text,
                                                    selection:
                                                        TextSelection.collapsed(
                                                          offset: text.length,
                                                        ),
                                                  );
                                                });
                                              },
                                            ),
                                          );
                                        }).toList(),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed:
                              inputErrors.values.any((error) => error != null)
                              ? null
                              : () async {
                                  for (final entry in editedValues.entries) {
                                    if (entry.value ==
                                        originalValues[entry.key]) {
                                      continue;
                                    }
                                    if (!await controller.updateConfigWord(
                                      entry.key,
                                      entry.value,
                                    )) {
                                      return;
                                    }
                                  }
                                  if (dialogContext.mounted) {
                                    Navigator.of(dialogContext).pop(true);
                                  }
                                },
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    for (final valueController in valueControllers.values) {
      valueController.dispose();
    }
    if (saved == true && mounted) _showSnack('Configuration words updated');
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
    final String? result;
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      result = await controller.pickReadSavePath();
    } else {
      result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Read Data as HEX',
        fileName: 'read_data.hex',
        type: FileType.custom,
        allowedExtensions: ['hex'],
      );
    }
    if (result == null) return;
    if (!mounted) return;

    final allData = [
      ...controller.readProgramMemory,
      ...controller.readEepromMemory,
      ...controller.readConfigMemory,
    ];
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
    if (m.contains('fail') ||
        m.contains('error') ||
        m.contains('unavailable') ||
        m.contains('denied') ||
        m.contains('refused')) {
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
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final desktop = defaultTargetPlatform == TargetPlatform.macOS;

    final Color bgColor;
    final Color accentColor;
    final Color textColor;
    final IconData icon;

    switch (resolved) {
      case _SnackKind.success:
        bgColor = dark ? const Color(0xFF10261A) : const Color(0xFFDDF7E7);
        accentColor = dark ? const Color(0xFF67D391) : const Color(0xFF197A43);
        textColor = dark ? const Color(0xFFE6F6EB) : const Color(0xFF123D25);
        icon = Icons.check_circle_rounded;
      case _SnackKind.error:
        bgColor = colors.errorContainer;
        accentColor = colors.error;
        textColor = colors.onErrorContainer;
        icon = Icons.cancel_rounded;
      case _SnackKind.warning:
        bgColor = colors.tertiaryContainer;
        accentColor = colors.tertiary;
        textColor = colors.onTertiaryContainer;
        icon = Icons.warning_amber_rounded;
      case _SnackKind.info:
        bgColor = colors.primaryContainer;
        accentColor = colors.primary;
        textColor = colors.onPrimaryContainer;
        icon = Icons.info_rounded;
    }

    final toast = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.2),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
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
                color: textColor,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: desktop ? EdgeInsets.zero : null,
          margin: EdgeInsets.fromLTRB(16, 0, 16, desktop ? 42 : 12),
          duration: const Duration(seconds: 3),
          content: desktop
              ? Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(width: 380, child: toast),
                )
              : toast,
        ),
      );
  }

  Future<void> _showAppInfoDialog() async {
    final colors = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                decoration: BoxDecoration(color: colors.surfaceContainerHigh),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/pickit2_logo.png',
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PICKit2',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Microchip PIC Programmer  ·  Version $_appVersion',
                            style: TextStyle(fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      tooltip: 'Close',
                      icon: const Icon(Icons.close_rounded, size: 19),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const _AppCreditCard(
                      icon: Icons.person_outline_rounded,
                      role: 'Developer',
                      name: 'Antor Ahmed',
                      website: 'antor.pro.bd',
                    ),
                    const SizedBox(height: 10),
                    const _AppCreditCard(
                      icon: Icons.business_outlined,
                      role: 'Company',
                      name: 'Kitsware',
                      website: 'kitsware.com',
                    ),
                    const SizedBox(height: 16),
                    Divider(color: colors.outlineVariant),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => _showPk2cmdLicense(dialogContext),
                      icon: const Icon(Icons.description_outlined, size: 17),
                      label: const Text('Programming engine license'),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '© 2026 Kitsware. Developed by Antor Ahmed.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPk2cmdLicense(BuildContext parentContext) async {
    await showDialog<void>(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Programming engine license'),
        content: const SizedBox(
          width: 520,
          child: SingleChildScrollView(child: SelectableText(_pk2cmdLicense)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return Consumer<HomeController>(
        builder: (context, controller, child) {
          final themeController = context.watch<AppThemeController>();
          return AnimatedBuilder(
            animation: _tabController,
            builder: (context, child) {
              return DesktopHomeView(
                controller: controller,
                selectedPage: _tabController.index,
                darkMode: themeController.isDark,
                onShowAppInfo: _showAppInfoDialog,
                onToggleTheme: themeController.toggle,
                onSelectPage: _tabController.animateTo,
                onConnect: () => _handleConnectButton(controller),
                onLoadFirmware: () => _pickFirmwareFile(controller),
                onClearFirmware: () => _clearFirmware(controller),
                onChooseTarget: () => _showDeviceSelectorSheet(controller),
                onAutoDetect: () async {
                  await controller.autoDetectChip();
                  if (mounted) _showSnack(controller.connectionStatus);
                },
                onProgram: () => _handleProgram(controller),
                onVerify: () => _handleVerify(controller),
                onErase: () => _handleErase(controller),
                onRead: () => _handleRead(controller),
                onBlankCheck: () => _handleBlankCheck(controller),
                onFuseConfig: () => _showFuseEditor(controller),
                memoryView: _buildHexTableTab(controller, desktop: true),
              );
            },
          );
        },
      );
    }

    return Consumer<HomeController>(
      builder: (context, controller, child) {
        final themeController = context.watch<AppThemeController>();
        return AnimatedBuilder(
          animation: _tabController,
          builder: (context, child) => MobileHomeView(
            controller: controller,
            selectedPage: _tabController.index,
            darkMode: themeController.isDark,
            onSelectPage: _tabController.animateTo,
            onShowAppInfo: _showAppInfoDialog,
            onToggleTheme: themeController.toggle,
            onConnect: () => _handleConnectButton(controller),
            onLoadFirmware: () => _pickFirmwareFile(controller),
            onClearFirmware: () => _clearFirmware(controller),
            onChooseTarget: () => _showDeviceSelectorSheet(controller),
            onAutoDetect: () async {
              await controller.autoDetectChip();
              if (mounted) _showSnack(controller.connectionStatus);
            },
            onProgram: () => _handleProgram(controller),
            onVerify: () => _handleVerify(controller),
            onErase: () => _handleErase(controller),
            onRead: () => _handleRead(controller),
            onBlankCheck: () => _handleBlankCheck(controller),
            onFuseConfig: () => _showFuseEditor(controller),
            memoryView: _buildHexTableTab(controller),
          ),
        );
      },
    );
  }

  Widget _buildHexTableTab(HomeController controller, {bool desktop = false}) {
    final colors = Theme.of(context).colorScheme;
    final hasReadData =
        controller.readProgramMemory.isNotEmpty ||
        controller.readEepromMemory.isNotEmpty ||
        controller.readConfigMemory.isNotEmpty;
    final hasImportedData = controller.hasImportedData;
    final hasAnyData = hasReadData || hasImportedData;

    if (!hasAnyData) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No data yet.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              hasImportedData
                  ? ''
                  : 'Load a firmware file or use Read to read chip memory.',
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.48),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    // Determine which source tabs to show
    final sourceTabs = <_HexSource>[];
    if (hasImportedData) sourceTabs.add(_HexSource.imported);
    if (hasReadData) sourceTabs.add(_HexSource.read);
    if (sourceTabs.isEmpty) sourceTabs.add(_HexSource.imported); // fallback

    return _HexViewer(
      sourceTabs: sourceTabs,
      controller: controller,
      onSaveRead: () => _saveReadToHex(controller),
      hasReadData: hasReadData,
      desktop: desktop,
    );
  }
}

// ── Hex Viewer with Imported + Read source tabs ────────────────────────────

enum _HexSource { imported, read }

class _HexViewer extends StatefulWidget {
  final List<_HexSource> sourceTabs;
  final HomeController controller;
  final VoidCallback onSaveRead;
  final bool hasReadData;
  final bool desktop;

  const _HexViewer({
    required this.sourceTabs,
    required this.controller,
    required this.onSaveRead,
    required this.hasReadData,
    this.desktop = false,
  });

  @override
  State<_HexViewer> createState() => _HexViewerState();
}

class _HexViewerState extends State<_HexViewer> with TickerProviderStateMixin {
  late TabController _sourceTabController;
  late TabController _memTabController;
  _HexSource _activeSource = _HexSource.imported;

  @override
  void initState() {
    super.initState();
    _activeSource = widget.sourceTabs.first;
    _sourceTabController = TabController(
      length: widget.sourceTabs.length,
      vsync: this,
    );
    _memTabController = TabController(length: 3, vsync: this);
    _sourceTabController.addListener(_onSourceChanged);
  }

  @override
  void didUpdateWidget(covariant _HexViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.sourceTabs, widget.sourceTabs)) {
      _sourceTabController
        ..removeListener(_onSourceChanged)
        ..dispose();
      final activeIndex = widget.sourceTabs.indexOf(_activeSource);
      _sourceTabController = TabController(
        length: widget.sourceTabs.length,
        initialIndex: activeIndex < 0 ? 0 : activeIndex,
        vsync: this,
      );
      _sourceTabController.addListener(_onSourceChanged);
      _activeSource = widget.sourceTabs[_sourceTabController.index];
      _memTabController.index = 0;
    }
  }

  void _onSourceChanged() {
    if (!_sourceTabController.indexIsChanging) {
      setState(() {
        _activeSource = widget.sourceTabs[_sourceTabController.index];
        _memTabController.index = 0;
      });
    }
  }

  @override
  void dispose() {
    _sourceTabController.removeListener(_onSourceChanged);
    _sourceTabController.dispose();
    _memTabController.dispose();
    super.dispose();
  }

  List<int> _progMem() => _activeSource == _HexSource.imported
      ? widget.controller.importedProgramMemory
      : widget.controller.readProgramMemory;

  List<int> _eeMem() => _activeSource == _HexSource.imported
      ? widget.controller.importedEepromMemory
      : widget.controller.readEepromMemory;

  List<int> _cfgMem() => _activeSource == _HexSource.imported
      ? widget.controller.importedConfigMemory
      : widget.controller.readConfigMemory;

  int _programBase() => _activeSource == _HexSource.imported
      ? widget.controller.importedProgramBaseAddress
      : widget.controller.readProgramBaseAddress;

  int _eepromBase() => _activeSource == _HexSource.imported
      ? widget.controller.importedEepromBaseAddress
      : widget.controller.readEepromBaseAddress;

  int _configBase() => _activeSource == _HexSource.imported
      ? widget.controller.importedConfigBaseAddress
      : widget.controller.readConfigBaseAddress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final prog = _progMem();
    final ee = _eeMem();
    final cfg = _cfgMem();
    final sourceLabel = _activeSource == _HexSource.imported
        ? 'Imported'
        : 'Read';

    return Column(
      children: [
        // Source tabs (Imported / Read)
        Container(
          margin: const EdgeInsets.only(top: 8),
          child: TabBar(
            controller: _sourceTabController,
            indicatorColor: colors.primary,
            labelColor: colors.onSurface,
            unselectedLabelColor: colors.onSurfaceVariant,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            tabs: widget.sourceTabs.map((s) {
              final label = s == _HexSource.imported ? 'Imported' : 'Read';
              final icon = s == _HexSource.imported
                  ? Icons.file_open_rounded
                  : Icons.memory_rounded;
              return Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14),
                    const SizedBox(width: 6),
                    Text(label),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        // Memory region sub-tabs (Program / EEPROM / Config)
        TabBar(
          controller: _memTabController,
          indicatorColor: colors.primary,
          labelColor: colors.primary,
          unselectedLabelColor: colors.onSurfaceVariant,
          indicatorWeight: 2,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(fontSize: 12),
          tabs: const [
            Tab(text: 'Program'),
            Tab(text: 'EEPROM'),
            Tab(text: 'Config'),
          ],
        ),
        // Memory hex tables
        Expanded(
          child: TabBarView(
            controller: _memTabController,
            children: [
              _buildMemSection(
                prog,
                '$sourceLabel Program Memory',
                _programBase(),
              ),
              _buildMemSection(ee, '$sourceLabel EEPROM', _eepromBase()),
              _buildMemSection(cfg, '$sourceLabel Config', _configBase()),
            ],
          ),
        ),
        // Footer — Save HEX button only for read data
        if (widget.hasReadData)
          Padding(
            padding: EdgeInsets.all(widget.desktop ? 10 : 16),
            child: Align(
              alignment: widget.desktop
                  ? Alignment.centerRight
                  : Alignment.center,
              child: SizedBox(
                width: widget.desktop ? 168 : double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.onSaveRead,
                  icon: Icon(Icons.save, color: colors.onPrimary, size: 18),
                  label: Text(
                    'Save Read HEX',
                    style: TextStyle(color: colors.onPrimary),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    padding: EdgeInsets.symmetric(
                      vertical: widget.desktop ? 10 : 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        widget.desktop ? 6 : 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMemSection(List<int> data, String title, int baseAddr) {
    final colors = Theme.of(context).colorScheme;
    if (data.isEmpty) {
      return Center(
        child: Text(
          'No $title data',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '$title (${data.length} bytes)',
              style: TextStyle(
                color: colors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: HexTableView(data: data, baseAddress: baseAddr),
          ),
        ],
      ),
    );
  }
}

class _AppCreditCard extends StatelessWidget {
  final IconData icon;
  final String role;
  final String name;
  final String website;

  const _AppCreditCard({
    required this.icon,
    required this.role,
    required this.name,
    required this.website,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 19, color: colors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SelectableText(
            website,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: colors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigWordField extends StatelessWidget {
  final TextEditingController controller;
  final int byteCount;
  final String? errorText;
  final double width;
  final ValueChanged<String> onChanged;

  const _ConfigWordField({
    required this.controller,
    required this.byteCount,
    required this.errorText,
    required this.onChanged,
    this.width = 154,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-FxX]')),
          LengthLimitingTextInputFormatter(byteCount * 2 + 2),
        ],
        textAlign: TextAlign.right,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          prefixText: 'Word:',
          errorText: errorText,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 9,
          ),
        ),
      ),
    );
  }
}

class _ConfigBitToggle extends StatelessWidget {
  final int bit;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ConfigBitToggle({
    required this.bit,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final mobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return Semantics(
      button: true,
      selected: value,
      label: 'Bit $bit',
      value: value ? '1' : '0',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(6),
          child: Ink(
            height: 44,
            decoration: BoxDecoration(
              color: value
                  ? colors.primaryContainer.withValues(alpha: 0.55)
                  : colors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: value
                    ? colors.primary.withValues(alpha: 0.7)
                    : colors.outlineVariant,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  mobile ? 'B$bit' : 'BIT $bit',
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value ? '1' : '0',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: value ? colors.primary : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _SnackKind { success, error, warning, info }
