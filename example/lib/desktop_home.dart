import 'package:flutter/material.dart';

import 'controller.dart';

class DesktopHomeView extends StatelessWidget {
  final HomeController controller;
  final int selectedPage;
  final bool darkMode;
  final VoidCallback onToggleTheme;
  final ValueChanged<int> onSelectPage;
  final VoidCallback onConnect;
  final VoidCallback onLoadFirmware;
  final VoidCallback onClearFirmware;
  final VoidCallback onChooseTarget;
  final VoidCallback onAutoDetect;
  final VoidCallback onProgram;
  final VoidCallback onVerify;
  final VoidCallback onErase;
  final VoidCallback onRead;
  final VoidCallback onBlankCheck;
  final VoidCallback onFuseConfig;
  final Widget memoryView;

  const DesktopHomeView({
    super.key,
    required this.controller,
    required this.selectedPage,
    required this.darkMode,
    required this.onToggleTheme,
    required this.onSelectPage,
    required this.onConnect,
    required this.onLoadFirmware,
    required this.onClearFirmware,
    required this.onChooseTarget,
    required this.onAutoDetect,
    required this.onProgram,
    required this.onVerify,
    required this.onErase,
    required this.onRead,
    required this.onBlankCheck,
    required this.onFuseConfig,
    required this.memoryView,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: Column(
        children: [
          _DesktopHeader(controller: controller, darkMode: darkMode, onToggleTheme: onToggleTheme, onConnect: onConnect),
          const Divider(height: 1),
          Expanded(
            child: Row(
              children: [
                _DesktopSidebar(controller: controller, selectedPage: selectedPage, onSelectPage: onSelectPage),
                const VerticalDivider(width: 1),
                Expanded(
                  child: IndexedStack(
                    index: selectedPage,
                    children: [
                      _ProgrammerWorkspace(
                        controller: controller,
                        onLoadFirmware: onLoadFirmware,
                        onClearFirmware: onClearFirmware,
                        onChooseTarget: onChooseTarget,
                        onAutoDetect: onAutoDetect,
                        onProgram: onProgram,
                        onVerify: onVerify,
                        onErase: onErase,
                        onRead: onRead,
                        onBlankCheck: onBlankCheck,
                        onFuseConfig: onFuseConfig,
                      ),
                      ColoredBox(color: colors.surfaceContainerLowest, child: memoryView),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _DesktopStatusBar(controller: controller),
        ],
      ),
    );
  }
}

class _DesktopHeader extends StatelessWidget {
  final HomeController controller;
  final bool darkMode;
  final VoidCallback onToggleTheme;
  final VoidCallback onConnect;

  const _DesktopHeader({required this.controller, required this.darkMode, required this.onToggleTheme, required this.onConnect});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      color: colors.surfaceContainer,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(7)),
            child: Icon(Icons.memory_rounded, size: 20, color: colors.onPrimary),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('PICkit 2 Programmer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Text('Native USB programming workspace', style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: onToggleTheme,
            tooltip: darkMode ? 'Use light theme' : 'Use dark theme',
            icon: Icon(darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 18),
          ),
          const SizedBox(width: 6),
          _ConnectionIndicator(connected: controller.connected),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: onConnect,
            style: FilledButton.styleFrom(
              minimumSize: const Size(126, 34),
              backgroundColor: controller.connected ? colors.errorContainer : colors.primary,
              foregroundColor: controller.connected ? colors.onErrorContainer : colors.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            icon: Icon(controller.connected ? Icons.usb_off_rounded : Icons.usb_rounded, size: 16),
            label: Text(controller.connected ? 'Disconnect' : 'Connect'),
          ),
        ],
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  final HomeController controller;
  final int selectedPage;
  final ValueChanged<int> onSelectPage;

  const _DesktopSidebar({required this.controller, required this.selectedPage, required this.onSelectPage});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 210,
      color: colors.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
            child: Text(
              'WORKSPACE',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.1),
            ),
          ),
          _NavigationItem(
            icon: Icons.developer_board_rounded,
            label: 'Programmer',
            selected: selectedPage == 0,
            onTap: () => onSelectPage(0),
          ),
          _NavigationItem(icon: Icons.grid_on_rounded, label: 'Memory View', selected: selectedPage == 1, onTap: () => onSelectPage(1)),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'SESSION',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.1),
            ),
          ),
          const SizedBox(height: 12),
          _SidebarValue(label: 'Target', value: controller.targetDevice),
          _SidebarValue(label: 'Firmware', value: controller.firmwareName),
          _SidebarValue(label: 'Programmer', value: controller.connected ? controller.serialNumber : 'Offline'),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 15, color: colors.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Erase and Program require confirmation', style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgrammerWorkspace extends StatelessWidget {
  final HomeController controller;
  final VoidCallback onLoadFirmware;
  final VoidCallback onClearFirmware;
  final VoidCallback onChooseTarget;
  final VoidCallback onAutoDetect;
  final VoidCallback onProgram;
  final VoidCallback onVerify;
  final VoidCallback onErase;
  final VoidCallback onRead;
  final VoidCallback onBlankCheck;
  final VoidCallback onFuseConfig;

  const _ProgrammerWorkspace({
    required this.controller,
    required this.onLoadFirmware,
    required this.onClearFirmware,
    required this.onChooseTarget,
    required this.onAutoDetect,
    required this.onProgram,
    required this.onVerify,
    required this.onErase,
    required this.onRead,
    required this.onBlankCheck,
    required this.onFuseConfig,
  });

  @override
  Widget build(BuildContext context) {
    final targetReady = controller.connected && controller.chipSelected && !controller.programming;
    final imageReady = targetReady && controller.hasImportedData;

    return Column(
      children: [
        _CommandBar(
          controller: controller,
          targetReady: targetReady,
          imageReady: imageReady,
          onProgram: onProgram,
          onVerify: onVerify,
          onErase: onErase,
          onRead: onRead,
          onBlankCheck: onBlankCheck,
          onFuseConfig: onFuseConfig,
        ),
        const Divider(height: 1),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final leftColumn = Column(
                children: [
                  _ProgrammerPanel(controller: controller),
                  const SizedBox(height: 14),
                  _FirmwarePanel(controller: controller, onLoadFirmware: onLoadFirmware, onClearFirmware: onClearFirmware),
                ],
              );
              final rightColumn = Column(
                children: [
                  _TargetPanel(controller: controller, onChooseTarget: onChooseTarget, onAutoDetect: onAutoDetect),
                  const SizedBox(height: 14),
                  _OperationPanel(controller: controller),
                ],
              );

              return SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: constraints.maxWidth >= 860
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: leftColumn),
                          const SizedBox(width: 14),
                          Expanded(flex: 6, child: rightColumn),
                        ],
                      )
                    : Column(children: [leftColumn, const SizedBox(height: 14), rightColumn]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CommandBar extends StatelessWidget {
  final HomeController controller;
  final bool targetReady;
  final bool imageReady;
  final VoidCallback onProgram;
  final VoidCallback onVerify;
  final VoidCallback onErase;
  final VoidCallback onRead;
  final VoidCallback onBlankCheck;
  final VoidCallback onFuseConfig;

  const _CommandBar({
    required this.controller,
    required this.targetReady,
    required this.imageReady,
    required this.onProgram,
    required this.onVerify,
    required this.onErase,
    required this.onRead,
    required this.onBlankCheck,
    required this.onFuseConfig,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 58,
      color: colors.surfaceContainerLow,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            _CommandButton(label: 'Program', icon: Icons.download_rounded, primary: true, enabled: imageReady, onPressed: onProgram),
            _CommandButton(label: 'Verify', icon: Icons.verified_outlined, enabled: imageReady, onPressed: onVerify),
            const _CommandSeparator(),
            _CommandButton(label: 'Read', icon: Icons.upload_file_outlined, enabled: targetReady, onPressed: onRead),
            _CommandButton(
              label: 'Blank Check',
              icon: Icons.check_box_outline_blank_rounded,
              enabled: targetReady,
              onPressed: onBlankCheck,
            ),
            _CommandButton(label: 'Erase', icon: Icons.delete_outline_rounded, destructive: true, enabled: targetReady, onPressed: onErase),
            const _CommandSeparator(),
            _CommandButton(
              label: 'Configuration',
              icon: Icons.tune_rounded,
              enabled: controller.chipSelected && controller.hasImportedData,
              onPressed: onFuseConfig,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgrammerPanel extends StatelessWidget {
  final HomeController controller;

  const _ProgrammerPanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final connectedColor = Theme.of(context).brightness == Brightness.dark ? const Color(0xFF67D391) : const Color(0xFF197A43);
    return _DesktopPanel(
      title: 'Programmer',
      icon: Icons.usb_rounded,
      child: Column(
        children: [
          _PropertyRow(label: 'Model', value: controller.deviceName),
          _PropertyRow(label: 'Serial number', value: controller.serialNumber),
          _PropertyRow(label: 'Firmware version', value: controller.programmerFirmware),
          _PropertyRow(
            label: 'USB status',
            value: controller.connected ? 'Connected' : 'Disconnected',
            valueColor: controller.connected ? connectedColor : colors.error,
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _FirmwarePanel extends StatelessWidget {
  final HomeController controller;
  final VoidCallback onLoadFirmware;
  final VoidCallback onClearFirmware;

  const _FirmwarePanel({required this.controller, required this.onLoadFirmware, required this.onClearFirmware});

  @override
  Widget build(BuildContext context) {
    final loaded = controller.hasImportedData;
    return _DesktopPanel(
      title: 'Firmware image',
      icon: Icons.insert_drive_file_outlined,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            onPressed: onLoadFirmware,
            icon: const Icon(Icons.folder_open_rounded, size: 15),
            label: Text(loaded ? 'Replace…' : 'Open…'),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: loaded ? onClearFirmware : null,
            tooltip: 'Clear firmware image',
            icon: const Icon(Icons.close_rounded, size: 17),
          ),
        ],
      ),
      child: Column(
        children: [
          _PropertyRow(label: 'File', value: controller.firmwareName),
          _PropertyRow(label: 'Format', value: controller.firmwareType),
          _PropertyRow(label: 'Loaded size', value: controller.firmwareSize, showDivider: false),
        ],
      ),
    );
  }
}

class _TargetPanel extends StatelessWidget {
  final HomeController controller;
  final VoidCallback onChooseTarget;
  final VoidCallback onAutoDetect;

  const _TargetPanel({required this.controller, required this.onChooseTarget, required this.onAutoDetect});

  @override
  Widget build(BuildContext context) {
    return _DesktopPanel(
      title: 'Target device',
      icon: Icons.memory_rounded,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            onPressed: controller.connected ? onAutoDetect : null,
            icon: const Icon(Icons.radar_rounded, size: 15),
            label: const Text('Auto Detect'),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: onChooseTarget,
            icon: const Icon(Icons.list_alt_rounded, size: 15),
            label: const Text('Choose…'),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _TargetHeading(name: controller.targetDevice, family: controller.deviceFamily, selected: controller.chipSelected),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _TargetMetric(label: 'Device ID', value: controller.deviceId),
              _TargetMetric(label: 'Flash', value: controller.flashSize),
              _TargetMetric(label: 'RAM', value: controller.ramSize),
              _TargetMetric(label: 'EEPROM', value: controller.eepromSize),
            ],
          ),
        ],
      ),
    );
  }
}

class _OperationPanel extends StatelessWidget {
  final HomeController controller;

  const _OperationPanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    final active = controller.programming || controller.progress > 0;
    final colors = Theme.of(context).colorScheme;
    return _DesktopPanel(
      title: 'Operation',
      icon: Icons.monitor_heart_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  controller.writeMessage.isNotEmpty ? controller.writeMessage : controller.connectionStatus,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
              if (active) ...[
                const SizedBox(width: 12),
                Text(
                  '${controller.progress}%',
                  style: TextStyle(color: colors.primary, fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: active ? (controller.progress / 100).clamp(0.0, 1.0) : 0,
            minHeight: 5,
            borderRadius: BorderRadius.circular(3),
            backgroundColor: colors.surfaceContainerHighest,
            color: colors.primary,
          ),
        ],
      ),
    );
  }
}

class _DesktopPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _DesktopPanel({required this.title, required this.icon, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Theme.of(context).brightness == Brightness.dark ? const Color(0xFF67D391) : const Color(0xFF197A43);
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 45,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: colors.primary),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const Spacer(),
                trailing ?? const SizedBox.shrink(),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );
  }
}

class _DesktopStatusBar extends StatelessWidget {
  final HomeController controller;

  const _DesktopStatusBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final connectedColor = Theme.of(context).brightness == Brightness.dark ? const Color(0xFF67D391) : const Color(0xFF197A43);
    return Container(
      height: 27,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        children: [
          Icon(
            controller.connected ? Icons.circle : Icons.circle_outlined,
            size: 9,
            color: controller.connected ? connectedColor : colors.onSurfaceVariant,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              controller.connectionStatus,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: colors.onSurfaceVariant),
            ),
          ),
          Text(
            controller.chipSelected ? controller.targetDevice : 'No target',
            style: TextStyle(fontSize: 10.5, color: colors.onSurfaceVariant),
          ),
          const SizedBox(width: 18),
          Text(
            controller.hasImportedData ? controller.firmwareName : 'No image',
            style: TextStyle(fontSize: 10.5, color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavigationItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? colors.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            child: Row(
              children: [
                Icon(icon, size: 17, color: selected ? colors.onPrimaryContainer : colors.onSurfaceVariant),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? colors.onPrimaryContainer : colors.onSurfaceVariant,
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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

class _CommandButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final bool primary;
  final bool destructive;
  final VoidCallback onPressed;

  const _CommandButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
    this.primary = false,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = destructive
        ? colors.error
        : primary
        ? colors.onPrimary
        : colors.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: TextButton.icon(
        onPressed: enabled ? onPressed : null,
        style: TextButton.styleFrom(
          foregroundColor: foreground,
          backgroundColor: primary ? colors.primary : null,
          disabledForegroundColor: colors.onSurface.withValues(alpha: 0.28),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(
              color: primary
                  ? colors.primary
                  : destructive
                  ? colors.error.withValues(alpha: 0.45)
                  : colors.outlineVariant,
            ),
          ),
        ),
        icon: Icon(icon, size: 16),
        label: Text(label),
      ),
    );
  }
}

class _CommandSeparator extends StatelessWidget {
  const _CommandSeparator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 5),
      child: SizedBox(height: 24, child: VerticalDivider(width: 1)),
    );
  }
}

class _ConnectionIndicator extends StatelessWidget {
  final bool connected;

  const _ConnectionIndicator({required this.connected});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final connectedColor = Theme.of(context).brightness == Brightness.dark ? const Color(0xFF67D391) : const Color(0xFF197A43);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: connected ? connectedColor.withValues(alpha: 0.14) : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: connected ? connectedColor.withValues(alpha: 0.45) : colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: connected ? connectedColor : colors.onSurfaceVariant),
          const SizedBox(width: 7),
          Text(connected ? 'PICkit connected' : 'PICkit offline', style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

class _SidebarValue extends StatelessWidget {
  final String label;
  final String value;

  const _SidebarValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant)),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: colors.onSurface),
          ),
        ],
      ),
    );
  }
}

class _PropertyRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool showDivider;

  const _PropertyRow({required this.label, required this.value, this.valueColor, this.showDivider = true});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: showDivider ? Border(bottom: BorderSide(color: colors.outlineVariant)) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 122,
            child: Text(label, style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: valueColor ?? colors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetHeading extends StatelessWidget {
  final String name;
  final String family;
  final bool selected;

  const _TargetHeading({required this.name, required this.family, required this.selected});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
          child: Icon(Icons.memory_rounded, size: 20, color: selected ? colors.primary : colors.onSurface.withValues(alpha: 0.3)),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: selected ? colors.onSurface : colors.onSurface.withValues(alpha: 0.38),
                ),
              ),
              Text(
                family,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TargetMetric extends StatelessWidget {
  final String label;
  final String value;

  const _TargetMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 7),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 9.5, color: colors.onSurfaceVariant)),
            const SizedBox(height: 3),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5)),
          ],
        ),
      ),
    );
  }
}
