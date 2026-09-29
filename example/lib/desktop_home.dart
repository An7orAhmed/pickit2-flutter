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
          _DesktopHeader(
            controller: controller,
            selectedPage: selectedPage,
            darkMode: darkMode,
            onToggleTheme: onToggleTheme,
            onSelectPage: onSelectPage,
            onConnect: onConnect,
          ),
          const Divider(height: 1),
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
                ColoredBox(
                  color: colors.surfaceContainerLowest,
                  child: memoryView,
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
  final int selectedPage;
  final bool darkMode;
  final VoidCallback onToggleTheme;
  final ValueChanged<int> onSelectPage;
  final VoidCallback onConnect;

  const _DesktopHeader({
    required this.controller,
    required this.selectedPage,
    required this.darkMode,
    required this.onToggleTheme,
    required this.onSelectPage,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      color: colors.surfaceContainer,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Image.asset(
              'assets/pickit2_logo.png',
              width: 32,
              height: 32,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PICKit2',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              Text(
                'Kitsware · Antor Ahmed',
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(width: 24),
          SegmentedButton<int>(
            showSelectedIcon: false,
            selected: {selectedPage},
            onSelectionChanged: (selection) => onSelectPage(selection.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 13),
              ),
              textStyle: const WidgetStatePropertyAll(
                TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
            ),
            segments: const [
              ButtonSegment(
                value: 0,
                icon: Icon(Icons.developer_board_rounded, size: 15),
                label: Text('Programmer'),
              ),
              ButtonSegment(
                value: 1,
                icon: Icon(Icons.grid_on_rounded, size: 15),
                label: Text('HEX Editor'),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: onToggleTheme,
            tooltip: darkMode ? 'Use light theme' : 'Use dark theme',
            icon: Icon(
              darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 18,
            ),
          ),
          const SizedBox(width: 6),
          _ConnectionIndicator(connected: controller.connected),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: controller.busy ? null : onConnect,
            style: FilledButton.styleFrom(
              minimumSize: const Size(126, 34),
              backgroundColor: controller.connected
                  ? colors.errorContainer
                  : colors.primary,
              foregroundColor: controller.connected
                  ? colors.onErrorContainer
                  : colors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            icon: Icon(
              controller.connected ? Icons.usb_off_rounded : Icons.usb_rounded,
              size: 16,
            ),
            label: Text(controller.connected ? 'Disconnect' : 'Connect'),
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
    final targetReady =
        controller.connected && controller.chipSelected && !controller.busy;
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
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: _TargetPanel(
                    controller: controller,
                    onChooseTarget: onChooseTarget,
                    onAutoDetect: onAutoDetect,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 5,
                  child: _FirmwarePanel(
                    controller: controller,
                    onLoadFirmware: onLoadFirmware,
                    onClearFirmware: onClearFirmware,
                  ),
                ),
              ],
            ),
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
      height: 52,
      color: colors.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        children: [
          _CommandButton(
            label: 'Program',
            icon: Icons.download_rounded,
            primary: true,
            enabled: imageReady,
            onPressed: onProgram,
          ),
          _CommandButton(
            label: 'Verify',
            icon: Icons.verified_outlined,
            enabled: imageReady,
            onPressed: onVerify,
          ),
          const _CommandSeparator(),
          _CommandButton(
            label: 'Read',
            icon: Icons.upload_file_outlined,
            enabled: targetReady,
            onPressed: onRead,
          ),
          _CommandButton(
            label: 'Blank Check',
            icon: Icons.check_box_outline_blank_rounded,
            enabled: targetReady,
            onPressed: onBlankCheck,
          ),
          _CommandButton(
            label: 'Erase',
            icon: Icons.delete_outline_rounded,
            destructive: true,
            enabled: targetReady,
            onPressed: onErase,
          ),
          const _CommandSeparator(),
          _CommandButton(
            label: 'Configuration',
            icon: Icons.tune_rounded,
            enabled:
                !controller.busy &&
                controller.chipSelected &&
                controller.hasImportedData,
            onPressed: onFuseConfig,
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

  const _FirmwarePanel({
    required this.controller,
    required this.onLoadFirmware,
    required this.onClearFirmware,
  });

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
            onPressed: controller.busy ? null : onLoadFirmware,
            icon: const Icon(Icons.folder_open_rounded, size: 15),
            label: Text(loaded ? 'Replace…' : 'Open…'),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: loaded && !controller.busy ? onClearFirmware : null,
            tooltip: 'Clear firmware image',
            icon: const Icon(Icons.close_rounded, size: 17),
          ),
        ],
      ),
      child: Column(
        children: [
          _PropertyRow(label: 'File', value: controller.firmwareName),
          _PropertyRow(label: 'Format', value: controller.firmwareType),
          _PropertyRow(
            label: 'Loaded size',
            value: controller.firmwareSize,
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _TargetPanel extends StatelessWidget {
  final HomeController controller;
  final VoidCallback onChooseTarget;
  final VoidCallback onAutoDetect;

  const _TargetPanel({
    required this.controller,
    required this.onChooseTarget,
    required this.onAutoDetect,
  });

  @override
  Widget build(BuildContext context) {
    return _DesktopPanel(
      title: 'Target device',
      icon: Icons.memory_rounded,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: controller.connected && !controller.busy
                ? onAutoDetect
                : null,
            tooltip: 'Auto detect target',
            icon: const Icon(Icons.radar_rounded, size: 17),
          ),
          IconButton.filledTonal(
            onPressed: controller.busy ? null : onChooseTarget,
            tooltip: 'Choose target',
            icon: const Icon(Icons.list_alt_rounded, size: 17),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _TargetHeading(
                  name: controller.targetDevice,
                  family: controller.deviceFamily,
                  selected: controller.chipSelected,
                ),
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

class _DesktopPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _DesktopPanel({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 45,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(7),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: colors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
    final active = controller.busy || controller.programming;
    final operationText = active && controller.writeMessage.isNotEmpty
        ? controller.writeMessage
        : controller.connectionStatus;
    final connectedColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF67D391)
        : const Color(0xFF197A43);
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1080;
          return Row(
            children: [
              Icon(
                active ? Icons.sync_rounded : Icons.info_outline_rounded,
                size: 12,
                color: active ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  operationText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              if (active) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: compact ? 105 : 150,
                  child: LinearProgressIndicator(
                    value: controller.programming
                        ? (controller.progress / 100).clamp(0.0, 1.0)
                        : null,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(2),
                    backgroundColor: colors.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 30,
                  child: Text(
                    controller.programming ? '${controller.progress}%' : '',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: colors.primary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
              const _StatusDivider(),
              _StatusValue(
                label: 'USB',
                value: controller.connected ? 'Connected' : 'Offline',
                valueColor: controller.connected
                    ? connectedColor
                    : colors.onSurfaceVariant,
                maxWidth: 94,
              ),
              const _StatusDivider(),
              _StatusValue(
                label: 'Model',
                value: controller.deviceName,
                maxWidth: 104,
              ),
              const _StatusDivider(),
              _StatusValue(
                label: 'S/N',
                value: controller.serialNumber,
                maxWidth: 118,
              ),
              const _StatusDivider(),
              _StatusValue(
                label: 'FW',
                value: controller.programmerFirmware,
                maxWidth: 78,
              ),
              if (!active && !compact) ...[
                const _StatusDivider(),
                _StatusValue(
                  label: 'Target',
                  value: controller.chipSelected
                      ? controller.targetDevice
                      : 'None',
                  maxWidth: 128,
                ),
                const _StatusDivider(),
                _StatusValue(
                  label: 'Image',
                  value: controller.hasImportedData
                      ? controller.firmwareName
                      : 'None',
                  maxWidth: 160,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _StatusDivider extends StatelessWidget {
  const _StatusDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 14,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

class _StatusValue extends StatelessWidget {
  final String label;
  final String value;
  final double maxWidth;
  final Color? valueColor;

  const _StatusValue({
    required this.label,
    required this.value,
    required this.maxWidth,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: '$label: $value',
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$label  ',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              TextSpan(
                text: value,
                style: TextStyle(
                  color: valueColor ?? colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10.5),
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
          backgroundColor: primary && enabled
              ? colors.primary
              : colors.surfaceContainerLow,
          disabledForegroundColor: colors.onSurface.withValues(alpha: 0.60),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(
              color: primary && enabled
                  ? colors.primary
                  : destructive
                  ? colors.error.withValues(alpha: enabled ? 0.55 : 0.28)
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
    final connectedColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF67D391)
        : const Color(0xFF197A43);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: connected
            ? connectedColor.withValues(alpha: 0.14)
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: connected
              ? connectedColor.withValues(alpha: 0.45)
              : colors.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: connected ? connectedColor : colors.onSurfaceVariant,
          ),
          const SizedBox(width: 7),
          Text(
            connected ? 'PICkit connected' : 'PICkit offline',
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _PropertyRow extends StatelessWidget {
  final String label;
  final String value;
  final bool showDivider;

  const _PropertyRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: colors.outlineVariant))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 122,
            child: Text(
              label,
              style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: colors.onSurface),
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

  const _TargetHeading({
    required this.name,
    required this.family,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.memory_rounded,
            size: 20,
            color: selected
                ? colors.primary
                : colors.onSurface.withValues(alpha: 0.3),
          ),
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
                  color: selected
                      ? colors.onSurface
                      : colors.onSurface.withValues(alpha: 0.38),
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
            Text(
              label,
              style: TextStyle(fontSize: 9.5, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}
