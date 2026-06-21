import 'package:flutter/material.dart';

class HexTableView extends StatelessWidget {
  final List<int> data;

  const HexTableView({super.key, required this.data});

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
