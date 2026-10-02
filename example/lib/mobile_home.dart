import 'package:flutter/material.dart';

import 'controller.dart';

class MobileHomeView extends StatelessWidget {
  final HomeController controller;
  final int selectedPage;
  final bool darkMode;
  final ValueChanged<int> onSelectPage;
  final VoidCallback onShowAppInfo;
  final VoidCallback onToggleTheme;
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

  const MobileHomeView({
    super.key,
    required this.controller,
    required this.selectedPage,
    required this.darkMode,
    required this.onSelectPage,
    required this.onShowAppInfo,
    required this.onToggleTheme,
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
      appBar: AppBar(
        toolbarHeight: 56,
        titleSpacing: 12,
        title: Row(
          children: [
            Image.asset('assets/pickit2_logo.png', width: 32, height: 32),
            const SizedBox(width: 8),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PICKit2', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                Text('Microchip PIC programmer', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: onToggleTheme,
            tooltip: darkMode ? 'Use light theme' : 'Use dark theme',
            icon: Icon(darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
          ),
          IconButton(onPressed: onShowAppInfo, tooltip: 'About PICKit2', icon: const Icon(Icons.info_outline_rounded)),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: colors.outlineVariant),
        ),
      ),
      body: IndexedStack(
        index: selectedPage,
        children: [
          _ProgrammerPage(
            controller: controller,
            onConnect: onConnect,
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
          memoryView,
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 64,
        selectedIndex: selectedPage,
        onDestinationSelected: onSelectPage,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.developer_board_outlined), selectedIcon: Icon(Icons.developer_board), label: 'Programmer'),
          NavigationDestination(icon: Icon(Icons.grid_on_outlined), selectedIcon: Icon(Icons.grid_on_rounded), label: 'Memory'),
        ],
      ),
    );
  }
}

class _ProgrammerPage extends StatelessWidget {
  final HomeController controller;
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

  const _ProgrammerPage({
    required this.controller,
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
  });

  @override
  Widget build(BuildContext context) {
    final canUseTarget = controller.connected && controller.chipSelected && !controller.busy;
    final canUseImage = canUseTarget && controller.hasImportedData;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        children: [
          _ConnectionCard(controller: controller, onConnect: onConnect),
          const SizedBox(height: 8),
          _TargetCard(controller: controller, onAutoDetect: onAutoDetect, onChooseTarget: onChooseTarget),
          const SizedBox(height: 8),
          _FirmwareCard(controller: controller, onLoadFirmware: onLoadFirmware, onClearFirmware: onClearFirmware),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: Row(
              children: [
                Expanded(
                  child: _ActionTile(label: 'Program', icon: Icons.download_rounded, primary: true, enabled: canUseImage, onTap: onProgram),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionTile(label: 'Verify', icon: Icons.verified_outlined, enabled: canUseImage, onTap: onVerify),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: Row(
              children: [
                Expanded(
                  child: _ActionTile(label: 'Read', icon: Icons.file_download_outlined, enabled: canUseTarget, onTap: onRead),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionTile(
                    label: 'Erase',
                    icon: Icons.delete_outline_rounded,
                    destructive: true,
                    enabled: canUseTarget,
                    onTap: onErase,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canUseTarget ? onBlankCheck : null,
                    icon: const Icon(Icons.check_box_outline_blank_rounded, size: 18),
                    label: const Text('Blank check'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: controller.chipSelected && controller.hasImportedData && !controller.busy ? onFuseConfig : null,
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('Config bits'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  final HomeController controller;
  final VoidCallback onConnect;

  const _ConnectionCard({required this.controller, required this.onConnect});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final connected = controller.connected;
    final detail = controller.busy
        ? (controller.writeMessage.isNotEmpty ? controller.writeMessage : controller.connectionStatus)
        : connected
        ? '${controller.serialNumber} · FW ${controller.programmerFirmware}'
        : 'USB programmer disconnected';
    return Semantics(
      liveRegion: controller.busy,
      label: detail,
      child: _SectionCard(
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: BorderRadius.circular(12)),
              child: controller.busy
                  ? Padding(
                      padding: const EdgeInsets.all(11),
                      child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
                    )
                  : Icon(Icons.usb_rounded, color: colors.primary, size: 21),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Flexible(
                        child: Text('PICkit 2', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: connected ? const Color(0xFF27B36A) : colors.outline, shape: BoxShape.circle),
                      ),
                    ],
                  ),
                  Text(
                    controller.progress > 0 ? '$detail · ${controller.progress}%' : detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            FilledButton.tonal(
              onPressed: controller.busy ? null : onConnect,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14), visualDensity: VisualDensity.compact),
              child: Text(connected ? 'Disconnect' : 'Connect'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetCard extends StatelessWidget {
  final HomeController controller;
  final VoidCallback onAutoDetect;
  final VoidCallback onChooseTarget;

  const _TargetCard({required this.controller, required this.onAutoDetect, required this.onChooseTarget});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.memory_rounded, color: colors.primary, size: 22),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.targetDevice,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      controller.deviceFamily,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: controller.connected && !controller.busy ? onAutoDetect : null,
                tooltip: 'Auto detect target',
                icon: const Icon(Icons.radar_rounded, size: 20),
              ),
              const SizedBox(width: 6),
              IconButton.outlined(
                onPressed: controller.busy ? null : onChooseTarget,
                tooltip: 'Select target',
                icon: const Icon(Icons.search_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _Metric(label: 'DEVICE ID', value: controller.deviceId),
              _Metric(label: 'FLASH', value: controller.flashSize),
              _Metric(label: 'RAM', value: controller.ramSize),
              _Metric(label: 'EEPROM', value: controller.eepromSize),
            ],
          ),
        ],
      ),
    );
  }
}

class _FirmwareCard extends StatelessWidget {
  final HomeController controller;
  final VoidCallback onLoadFirmware;
  final VoidCallback onClearFirmware;

  const _FirmwareCard({required this.controller, required this.onLoadFirmware, required this.onClearFirmware});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loaded = controller.hasImportedData;
    return _SectionCard(
      onTap: controller.busy ? null : onLoadFirmware,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: colors.tertiaryContainer, borderRadius: BorderRadius.circular(12)),
            child: Icon(loaded ? Icons.description_rounded : Icons.note_add_outlined, color: colors.tertiary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loaded ? controller.firmwareName : 'Load firmware image',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                Text(
                  loaded ? '${controller.firmwareType} · ${controller.firmwareSize}' : 'Intel HEX or binary file',
                  style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (loaded)
            IconButton(
              onPressed: controller.busy ? null : onClearFirmware,
              tooltip: 'Clear firmware',
              icon: const Icon(Icons.close_rounded),
            )
          else
            const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final bool primary;
  final bool destructive;
  final VoidCallback onTap;

  const _ActionTile({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.primary = false,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = destructive ? colors.error : colors.primary;
    return FilledButton.tonalIcon(
      onPressed: enabled ? onTap : null,
      style: FilledButton.styleFrom(
        backgroundColor: primary && enabled ? colors.primary : null,
        foregroundColor: primary && enabled ? colors.onPrimary : foreground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, size: 19),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _SectionCard({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(10), child: child),
      ),
    );
  }
}
