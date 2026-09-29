import 'dart:math' as math;

import 'package:flutter/material.dart';

class HexTableView extends StatelessWidget {
  static const double _minimumWidth = 820;
  static const double _addressWidth = 104;

  final List<int> data;
  final int baseAddress;

  const HexTableView({super.key, required this.data, this.baseAddress = 0});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(constraints.maxWidth, _minimumWidth);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            height: constraints.maxHeight,
            child: Column(
              children: [
                _HexRow(
                  backgroundColor: colors.surfaceContainerHigh,
                  address: 'Address',
                  values: List.generate(
                    16,
                    (index) => index.toRadixString(16).toUpperCase(),
                  ),
                  foregroundColor: colors.primary,
                  addressWidth: _addressWidth,
                  bold: true,
                ),
                Expanded(
                  child: ListView.builder(
                    itemExtent: 25,
                    itemCount: (data.length + 15) ~/ 16,
                    itemBuilder: (context, rowIndex) {
                      final start = rowIndex * 16;
                      return _HexDataRow(
                        data: data,
                        start: start,
                        address: baseAddress + start,
                        addressWidth: _addressWidth,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HexDataRow extends StatelessWidget {
  final List<int> data;
  final int start;
  final int address;
  final double addressWidth;

  const _HexDataRow({
    required this.data,
    required this.start,
    required this.address,
    required this.addressWidth,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final values = <String>[];
    final blank = <bool>[];
    for (var offset = 0; offset < 16; offset++) {
      final index = start + offset;
      final available = index < data.length;
      final value = available ? data[index] : 0xFF;
      values.add(value.toRadixString(16).toUpperCase().padLeft(2, '0'));
      blank.add(!available || value == 0xFF);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: (start ~/ 16).isEven
            ? colors.surfaceContainerLowest
            : colors.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: colors.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: addressWidth,
            child: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Text(
                address.toRadixString(16).toUpperCase().padLeft(6, '0'),
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontFamily: 'monospace',
                  fontSize: 10.5,
                ),
              ),
            ),
          ),
          for (var index = 0; index < values.length; index++)
            Expanded(
              child: Text(
                values[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: blank[index]
                      ? colors.onSurface.withValues(alpha: 0.24)
                      : colors.onSurface,
                  fontFamily: 'monospace',
                  fontSize: 10.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HexRow extends StatelessWidget {
  final Color backgroundColor;
  final Color foregroundColor;
  final String address;
  final List<String> values;
  final double addressWidth;
  final bool bold;

  const _HexRow({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.address,
    required this.values,
    required this.addressWidth,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: foregroundColor,
      fontFamily: 'monospace',
      fontSize: 10.5,
      fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
    );
    return Container(
      height: 28,
      color: backgroundColor,
      child: Row(
        children: [
          SizedBox(
            width: addressWidth,
            child: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Text(address, style: style),
            ),
          ),
          for (final value in values)
            Expanded(
              child: Text(value, textAlign: TextAlign.center, style: style),
            ),
        ],
      ),
    );
  }
}
