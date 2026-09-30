import 'package:flutter/material.dart';

import 'controller.dart';

class DesktopHomeView extends StatelessWidget {
  final HomeController controller;
  final int selectedPage;
  final bool darkMode;
  final VoidCallback onShowAppInfo;
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
    required this.onShowAppInfo,
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
    final palette = _DesktopPalette.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: palette.backgroundGradient),
        child: Column(
          children: [
            _DesktopHeader(
              controller: controller,
              selectedPage: selectedPage,
              darkMode: darkMode,
              onShowAppInfo: onShowAppInfo,
              onToggleTheme: onToggleTheme,
              onSelectPage: onSelectPage,
              onConnect: onConnect,
            ),
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
                    onViewFirmware: () => onSelectPage(1),
                  ),
                  ColoredBox(color: palette.editorBackground, child: memoryView),
                ],
              ),
            ),
            _DesktopStatusBar(controller: controller),
          ],
        ),
      ),
    );
  }
}

class _DesktopHeader extends StatelessWidget {
  final HomeController controller;
  final int selectedPage;
  final bool darkMode;
  final VoidCallback onShowAppInfo;
  final VoidCallback onToggleTheme;
  final ValueChanged<int> onSelectPage;
  final VoidCallback onConnect;

  const _DesktopHeader({
    required this.controller,
    required this.selectedPage,
    required this.darkMode,
    required this.onShowAppInfo,
    required this.onToggleTheme,
    required this.onSelectPage,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _DesktopPalette.of(context);
    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        gradient: palette.headerGradient,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/pickit2_logo.png', width: 52, height: 52, fit: BoxFit.contain),
                const SizedBox(width: 14),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PICKit2',
                      style: TextStyle(color: palette.text, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Microchip PIC Programmer',
                      style: TextStyle(color: palette.mutedText, fontSize: 11.5, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _WorkspaceSwitcher(selectedPage: selectedPage, onSelectPage: onSelectPage),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HeaderIconButton(icon: Icons.info_outline_rounded, tooltip: 'About PICKit2', onPressed: onShowAppInfo),
                const SizedBox(width: 4),
                _HeaderIconButton(
                  icon: darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  tooltip: darkMode ? 'Use light theme' : 'Use dark theme',
                  onPressed: onToggleTheme,
                ),
                Container(width: 1, height: 32, margin: const EdgeInsets.symmetric(horizontal: 14), color: palette.border),
                _ConnectButton(connected: controller.connected, enabled: !controller.busy, onPressed: onConnect),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceSwitcher extends StatelessWidget {
  final int selectedPage;
  final ValueChanged<int> onSelectPage;

  const _WorkspaceSwitcher({required this.selectedPage, required this.onSelectPage});

  @override
  Widget build(BuildContext context) {
    final palette = _DesktopPalette.of(context);
    return Container(
      width: 354,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: palette.controlBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.borderStrong),
        boxShadow: palette.controlShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: _WorkspaceTab(
              label: 'Programmer',
              icon: Icons.developer_board_rounded,
              selected: selectedPage == 0,
              onPressed: () => onSelectPage(0),
            ),
          ),
          Expanded(
            child: _WorkspaceTab(
              label: 'HEX Viewer',
              icon: Icons.grid_on_rounded,
              selected: selectedPage == 1,
              onPressed: () => onSelectPage(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  const _WorkspaceTab({required this.label, required this.icon, required this.selected, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final palette = _DesktopPalette.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(9),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            gradient: selected ? palette.primaryGradient : null,
            borderRadius: BorderRadius.circular(9),
            border: selected ? Border.all(color: palette.primaryBorder) : null,
            boxShadow: selected ? palette.primaryShadow : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: selected ? Colors.white : palette.mutedText),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(color: selected ? Colors.white : palette.mutedText, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _HeaderIconButton({required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final palette = _DesktopPalette.of(context);
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 22),
      color: palette.text,
      hoverColor: palette.hover,
      style: IconButton.styleFrom(
        minimumSize: const Size(40, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    );
  }
}

class _ConnectButton extends StatelessWidget {
  final bool connected;
  final bool enabled;
  final VoidCallback onPressed;

  const _ConnectButton({required this.connected, required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final palette = _DesktopPalette.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.58,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            width: 132,
            height: 44,
            decoration: BoxDecoration(
              gradient: connected ? palette.disconnectGradient : palette.primaryGradient,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: connected ? palette.disconnectBorder : palette.primaryBorder),
              boxShadow: connected ? null : palette.primaryShadow,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  connected ? Icons.usb_off_rounded : Icons.usb_rounded,
                  size: 20,
                  color: connected ? palette.disconnectText : Colors.white,
                ),
                const SizedBox(width: 9),
                Text(
                  connected ? 'Disconnect' : 'Connect',
                  style: TextStyle(color: connected ? palette.disconnectText : Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
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
  final VoidCallback onViewFirmware;

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
    required this.onViewFirmware,
  });

  @override
  Widget build(BuildContext context) {
    final targetReady = controller.connected && controller.chipSelected && !controller.busy;
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
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TargetPanel(controller: controller, onChooseTarget: onChooseTarget, onAutoDetect: onAutoDetect),
                const SizedBox(height: 14),
                Expanded(
                  child: _FirmwarePanel(
                    controller: controller,
                    onLoadFirmware: onLoadFirmware,
                    onClearFirmware: onClearFirmware,
                    onViewFirmware: onViewFirmware,
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
    final palette = _DesktopPalette.of(context);
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      decoration: BoxDecoration(
        color: palette.toolbarBackground,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          _CommandButton(label: 'Program', icon: Icons.download_rounded, primary: true, enabled: imageReady, onPressed: onProgram),
          const SizedBox(width: 10),
          _CommandButton(label: 'Verify', icon: Icons.verified_outlined, enabled: imageReady, onPressed: onVerify),
          const SizedBox(width: 10),
          _CommandButton(label: 'Read', icon: Icons.description_outlined, enabled: targetReady, onPressed: onRead),
          const SizedBox(width: 10),
          _CommandButton(
            label: 'Blank Check',
            icon: Icons.check_box_outline_blank_rounded,
            enabled: targetReady,
            flex: 12,
            onPressed: onBlankCheck,
          ),
          const SizedBox(width: 10),
          _CommandButton(label: 'Erase', icon: Icons.delete_outline_rounded, destructive: true, enabled: targetReady, onPressed: onErase),
          const SizedBox(width: 10),
          _CommandButton(
            label: 'Configuration',
            icon: Icons.tune_rounded,
            enabled: !controller.busy && controller.chipSelected && controller.hasImportedData,
            flex: 14,
            onPressed: onFuseConfig,
          ),
        ],
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
  final int flex;
  final VoidCallback onPressed;

  const _CommandButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
    this.primary = false,
    this.destructive = false,
    this.flex = 10,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _DesktopPalette.of(context);
    final textColor = enabled
        ? destructive
              ? palette.danger
              : primary
              ? Colors.white
              : palette.text
        : palette.disabledText;
    return Expanded(
      flex: flex,
      child: Opacity(
        opacity: enabled ? 1 : 0.72,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(10),
            child: Ink(
              height: 52,
              decoration: BoxDecoration(
                gradient: primary && enabled ? palette.primaryGradient : palette.controlGradient,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: primary && enabled
                      ? palette.primaryBorder
                      : destructive && enabled
                      ? palette.danger.withValues(alpha: 0.55)
                      : palette.borderStrong,
                ),
                boxShadow: primary && enabled ? palette.primaryShadow : palette.controlShadow,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 21, color: textColor),
                  const SizedBox(width: 9),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textColor, fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
      subtitle: 'Select a target device or auto-detect from the connected PICKit2.',
      icon: Icons.memory_rounded,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PanelActionButton(
            label: 'Auto Detect',
            icon: Icons.radar_rounded,
            enabled: controller.connected && !controller.busy,
            onPressed: onAutoDetect,
          ),
          const SizedBox(width: 10),
          _PanelActionButton(
            label: 'Select Chip',
            icon: Icons.list_alt_rounded,
            primary: true,
            enabled: !controller.busy,
            onPressed: onChooseTarget,
          ),
        ],
      ),
      child: SizedBox(
        height: 76,
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: _TargetHeading(name: controller.targetDevice, family: controller.deviceFamily, selected: controller.chipSelected),
            ),
            const _PanelDivider(),
            Expanded(
              flex: 8,
              child: Row(
                children: [
                  _TargetMetric(icon: Icons.memory_rounded, label: 'ID', value: controller.deviceId),
                  const SizedBox(width: 10),
                  _TargetMetric(icon: Icons.storage_rounded, label: 'Flash', value: controller.flashSize),
                  const SizedBox(width: 10),
                  _TargetMetric(icon: Icons.developer_board_outlined, label: 'RAM', value: controller.ramSize),
                  const SizedBox(width: 10),
                  _TargetMetric(icon: Icons.dns_outlined, label: 'EEPROM', value: controller.eepromSize),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FirmwarePanel extends StatelessWidget {
  final HomeController controller;
  final VoidCallback onLoadFirmware;
  final VoidCallback onClearFirmware;
  final VoidCallback onViewFirmware;

  const _FirmwarePanel({
    required this.controller,
    required this.onLoadFirmware,
    required this.onClearFirmware,
    required this.onViewFirmware,
  });

  @override
  Widget build(BuildContext context) {
    final loaded = controller.hasImportedData;
    return _DesktopPanel(
      title: 'Firmware image',
      subtitle: 'Load a HEX or BIN firmware file to program into the device.',
      icon: Icons.description_outlined,
      expandChild: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PanelActionButton(
            label: loaded ? 'Replace…' : 'Open…',
            icon: Icons.folder_open_rounded,
            primary: true,
            enabled: !controller.busy,
            onPressed: onLoadFirmware,
          ),
          if (loaded) ...[
            const SizedBox(width: 8),
            _PanelIconButton(
              tooltip: 'Clear firmware image',
              icon: Icons.close_rounded,
              enabled: !controller.busy,
              onPressed: onClearFirmware,
            ),
          ],
        ],
      ),
      child: loaded
          ? _LoadedFirmware(
              name: controller.firmwareName,
              type: controller.firmwareType,
              size: controller.firmwareSize,
              enabled: !controller.busy,
              onView: onViewFirmware,
            )
          : _EmptyFirmware(enabled: !controller.busy, onOpen: onLoadFirmware),
    );
  }
}

class _DesktopPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  final bool expandChild;

  const _DesktopPanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.trailing,
    this.expandChild = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _DesktopPalette.of(context);
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: palette.panelBodyGradient,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.border),
        ),
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        gradient: palette.panelGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.borderStrong),
        boxShadow: palette.panelShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Icon(icon, size: 27, color: palette.primary),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(color: palette.text, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: palette.mutedText, fontSize: 11.5, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[const SizedBox(width: 14), trailing!],
                ],
              ),
            ),
          ),
          if (expandChild) Expanded(child: body) else body,
        ],
      ),
    );
  }
}

class _PanelActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final bool primary;
  final VoidCallback onPressed;

  const _PanelActionButton({required this.label, required this.icon, required this.enabled, required this.onPressed, this.primary = false});

  @override
  Widget build(BuildContext context) {
    final palette = _DesktopPalette.of(context);
    final foreground = enabled
        ? primary
              ? palette.primaryActionText
              : palette.text
        : palette.disabledText;
    return Opacity(
      opacity: enabled ? 1 : 0.68,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(9),
          child: Ink(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              color: primary ? palette.primaryActionBackground : palette.hover,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: primary ? palette.primary : palette.borderStrong),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(color: foreground, fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  const _PanelIconButton({required this.tooltip, required this.icon, required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final palette = _DesktopPalette.of(context);
    return IconButton(
      onPressed: enabled ? onPressed : null,
      tooltip: tooltip,
      icon: Icon(icon, size: 18),
      color: palette.text,
      style: IconButton.styleFrom(
        minimumSize: const Size(38, 38),
        side: BorderSide(color: palette.borderStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    );
  }
}

class _PanelDivider extends StatelessWidget {
  const _PanelDivider();

  @override
  Widget build(BuildContext context) {
    final palette = _DesktopPalette.of(context);
    return Container(width: 1, height: 56, margin: const EdgeInsets.symmetric(horizontal: 16), color: palette.borderStrong);
  }
}

class _TargetHeading extends StatelessWidget {
  final String name;
  final String family;
  final bool selected;

  const _TargetHeading({required this.name, required this.family, required this.selected});

  @override
  Widget build(BuildContext context) {
    final palette = _DesktopPalette.of(context);
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: palette.controlGradient,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: palette.borderStrong),
          ),
          child: Icon(Icons.memory_rounded, size: 30, color: selected ? palette.primary : palette.disabledText),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: selected ? palette.text : palette.disabledText, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                family,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.mutedText, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TargetMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _TargetMetric({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final palette = _DesktopPalette.of(context);
    return Expanded(
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: palette.metricBackground,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: palette.borderStrong),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: palette.mutedText),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: palette.mutedText, fontSize: 10.5, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.text, fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFirmware extends StatelessWidget {
  final bool enabled;
  final VoidCallback onOpen;

  const _EmptyFirmware({required this.enabled, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final palette = _DesktopPalette.of(context);
    final title = Text(
      'No image loaded',
      style: TextStyle(color: palette.text, fontSize: 14.5, fontWeight: FontWeight.w700),
    );
    final description = Text(
      'Open a HEX or BIN firmware file to get started.',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: palette.mutedText, fontSize: 11),
    );
    final action = _PanelActionButton(label: 'Open…', icon: Icons.folder_open_rounded, primary: true, enabled: enabled, onPressed: onOpen);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < 145) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.file_present_outlined, size: 38, color: palette.primary),
              const SizedBox(width: 14),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 2), description],
                ),
              ),
              const SizedBox(width: 20),
              action,
            ],
          );
        }
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.file_present_outlined, size: 44, color: palette.primary),
              const SizedBox(height: 5),
              title,
              const SizedBox(height: 2),
              description,
              const SizedBox(height: 9),
              action,
            ],
          ),
        );
      },
    );
  }
}

class _LoadedFirmware extends StatelessWidget {
  final String name;
  final String type;
  final String size;
  final bool enabled;
  final VoidCallback onView;

  const _LoadedFirmware({required this.name, required this.type, required this.size, required this.enabled, required this.onView});

  @override
  Widget build(BuildContext context) {
    final palette = _DesktopPalette.of(context);
    return Row(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: palette.primaryActionBackground,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: palette.primary.withValues(alpha: 0.55)),
          ),
          child: Icon(Icons.description_rounded, size: 34, color: palette.primary),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.text, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 5),
              Text('$type  ·  $size', style: TextStyle(color: palette.mutedText, fontSize: 12)),
            ],
          ),
        ),
        _PanelActionButton(label: 'View', icon: Icons.grid_on_rounded, enabled: enabled, onPressed: onView),
      ],
    );
  }
}

class _DesktopStatusBar extends StatelessWidget {
  final HomeController controller;

  const _DesktopStatusBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final palette = _DesktopPalette.of(context);
    final active = controller.busy || controller.programming;
    final operationText = active && controller.writeMessage.isNotEmpty ? controller.writeMessage : controller.connectionStatus;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: palette.statusGradient,
        border: Border(top: BorderSide(color: palette.borderStrong)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1080;
          return Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: controller.connected ? palette.success.withValues(alpha: 0.18) : Colors.transparent,
                  border: Border.all(color: controller.connected ? palette.success : palette.mutedText, width: 1.5),
                ),
                child: active
                    ? Padding(
                        padding: const EdgeInsets.all(2.5),
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: palette.primary),
                      )
                    : null,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  operationText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.mutedText, fontSize: 11.5, fontWeight: FontWeight.w500),
                ),
              ),
              if (active) ...[
                const SizedBox(width: 12),
                SizedBox(
                  width: compact ? 110 : 160,
                  child: LinearProgressIndicator(
                    value: controller.programming ? (controller.progress / 100).clamp(0.0, 1.0) : null,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(2),
                    backgroundColor: palette.metricBackground,
                    color: palette.primary,
                  ),
                ),
                const SizedBox(width: 7),
                SizedBox(
                  width: 32,
                  child: Text(
                    controller.programming ? '${controller.progress}%' : '',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: palette.primary, fontSize: 10.5, fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ),
              ],
              const _StatusDivider(),
              _StatusValue(
                label: 'USB',
                value: controller.connected ? 'Connected' : 'Offline',
                valueColor: controller.connected ? palette.success : null,
                maxWidth: 100,
              ),
              const _StatusDivider(),
              _StatusValue(label: 'Model', value: controller.deviceName, maxWidth: 110),
              const _StatusDivider(),
              _StatusValue(label: 'S/N', value: controller.serialNumber, maxWidth: 120),
              const _StatusDivider(),
              _StatusValue(label: 'FW', value: controller.programmerFirmware, maxWidth: 78),
              if (!active && !compact) ...[
                const _StatusDivider(),
                _StatusValue(label: 'Target', value: controller.chipSelected ? controller.targetDevice : 'None', maxWidth: 132),
                const _StatusDivider(),
                _StatusValue(label: 'Image', value: controller.hasImportedData ? controller.firmwareName : 'None', maxWidth: 165),
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
    final palette = _DesktopPalette.of(context);
    return Container(width: 1, height: 17, margin: const EdgeInsets.symmetric(horizontal: 10), color: palette.borderStrong);
  }
}

class _StatusValue extends StatelessWidget {
  final String label;
  final String value;
  final double maxWidth;
  final Color? valueColor;

  const _StatusValue({required this.label, required this.value, required this.maxWidth, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final palette = _DesktopPalette.of(context);
    return Tooltip(
      message: '$label: $value',
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$label  ',
                style: TextStyle(color: palette.mutedText),
              ),
              TextSpan(
                text: value,
                style: TextStyle(color: valueColor ?? palette.text, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11),
        ),
      ),
    );
  }
}

class _DesktopPalette {
  final bool dark;
  final Color background;
  final Color editorBackground;
  final Color toolbarBackground;
  final Color controlBackground;
  final Color metricBackground;
  final Color primary;
  final Color primaryBorder;
  final Color primaryActionBackground;
  final Color primaryActionText;
  final Color border;
  final Color borderStrong;
  final Color text;
  final Color mutedText;
  final Color disabledText;
  final Color hover;
  final Color danger;
  final Color success;
  final Color disconnectText;
  final Color disconnectBorder;

  const _DesktopPalette({
    required this.dark,
    required this.background,
    required this.editorBackground,
    required this.toolbarBackground,
    required this.controlBackground,
    required this.metricBackground,
    required this.primary,
    required this.primaryBorder,
    required this.primaryActionBackground,
    required this.primaryActionText,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.mutedText,
    required this.disabledText,
    required this.hover,
    required this.danger,
    required this.success,
    required this.disconnectText,
    required this.disconnectBorder,
  });

  factory _DesktopPalette.of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return const _DesktopPalette(
        dark: true,
        background: Color(0xFF071220),
        editorBackground: Color(0xFF081423),
        toolbarBackground: Color(0xD90A1524),
        controlBackground: Color(0xFF111D2E),
        metricBackground: Color(0xB3071424),
        primary: Color(0xFF3A91FF),
        primaryBorder: Color(0xFF53B1FF),
        primaryActionBackground: Color(0x332C8DFF),
        primaryActionText: Color(0xFFE8F3FF),
        border: Color(0xFF26384E),
        borderStrong: Color(0xFF3B4D65),
        text: Color(0xFFF1F5FF),
        mutedText: Color(0xFFB6C3DD),
        disabledText: Color(0xFF718099),
        hover: Color(0xFF19263A),
        danger: Color(0xFFFF8B93),
        success: Color(0xFF69D49A),
        disconnectText: Color(0xFFFFC1C5),
        disconnectBorder: Color(0xFF7D4149),
      );
    }
    return const _DesktopPalette(
      dark: false,
      background: Color(0xFFF3F7FC),
      editorBackground: Color(0xFFF8FAFD),
      toolbarBackground: Color(0xF7EDF3FA),
      controlBackground: Color(0xFFFFFFFF),
      metricBackground: Color(0xFFF8FAFD),
      primary: Color(0xFF126FE5),
      primaryBorder: Color(0xFF3187EF),
      primaryActionBackground: Color(0xFFEAF3FF),
      primaryActionText: Color(0xFF0756B8),
      border: Color(0xFFD8E1ED),
      borderStrong: Color(0xFFBFCBDC),
      text: Color(0xFF142033),
      mutedText: Color(0xFF607089),
      disabledText: Color(0xFF8B98AA),
      hover: Color(0xFFF2F6FB),
      danger: Color(0xFFB32631),
      success: Color(0xFF197A43),
      disconnectText: Color(0xFF9D2531),
      disconnectBorder: Color(0xFFE6A7AD),
    );
  }

  LinearGradient get backgroundGradient => dark
      ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF07111F), Color(0xFF0A182A)])
      : const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF8FAFD), Color(0xFFEEF4FA)]);

  LinearGradient get headerGradient => dark
      ? const LinearGradient(colors: [Color(0xF2111F31), Color(0xF20A1728)])
      : const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFF2F6FB)]);

  LinearGradient get panelGradient => dark
      ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF17263A), Color(0xFF101D2D)])
      : const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFF7FAFD)]);

  LinearGradient get panelBodyGradient => dark
      ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xE60B1828), Color(0xF20A1625)])
      : const LinearGradient(colors: [Color(0xFFF9FBFE), Color(0xFFF3F7FB)]);

  LinearGradient get controlGradient => dark
      ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1C2A3E), Color(0xFF131F31)])
      : const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFEDF3F9)]);

  LinearGradient get primaryGradient =>
      const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2E91FF), Color(0xFF0967E8)]);

  LinearGradient get disconnectGradient => dark
      ? const LinearGradient(colors: [Color(0xFF3A2630), Color(0xFF291D27)])
      : const LinearGradient(colors: [Color(0xFFFFF2F3), Color(0xFFFCE7E9)]);

  LinearGradient get statusGradient => dark
      ? const LinearGradient(colors: [Color(0xFF152235), Color(0xFF111D2D)])
      : const LinearGradient(colors: [Color(0xFFF8FAFD), Color(0xFFEAF1F8)]);

  List<BoxShadow> get primaryShadow => [
    BoxShadow(
      color: primary.withValues(alpha: dark ? 0.28 : 0.18),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
  ];

  List<BoxShadow> get panelShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: dark ? 0.22 : 0.07),
      blurRadius: 14,
      offset: const Offset(0, 5),
    ),
  ];

  List<BoxShadow> get controlShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: dark ? 0.2 : 0.05),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];
}
