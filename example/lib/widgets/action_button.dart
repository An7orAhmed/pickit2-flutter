import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  const ActionButton({super.key, required this.icon, required this.label, required this.enabled, this.onTap});

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> with SingleTickerProviderStateMixin {
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
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.92).animate(CurvedAnimation(parent: _scaleController, curve: Curves.easeOut));
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
                    color: _hovering && widget.enabled ? Colors.blueAccent.withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.04),
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
