import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';

class ExcelExportHelper {
  static final _dateFormat = DateFormat('MMM d, yyyy h:mm a');

  static Future<File> exportToExcel(List<StudentPaymentInfo> infos) async {
    final excel = Excel.createExcel();
    final sheet = excel['SPTA Payments'];
    excel.delete('Sheet1');

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#1A3A6B'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
    );

    final headers = [
      '#', 'Full Name', 'LRN', 'Grade',
      'Total Fee', 'Amount Paid', 'Balance', 'Status',
      'No. of Payments', 'Date Registered'
    ];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    sheet.setColumnWidth(0, 5);
    sheet.setColumnWidth(1, 28);
    sheet.setColumnWidth(2, 18);
    sheet.setColumnWidth(3, 12);
    sheet.setColumnWidth(4, 12);
    sheet.setColumnWidth(5, 12);
    sheet.setColumnWidth(6, 12);
    sheet.setColumnWidth(7, 14);
    sheet.setColumnWidth(8, 14);
    sheet.setColumnWidth(9, 22);

    for (var i = 0; i < infos.length; i++) {
      final info = infos[i];
      final s = info.student;
      final rowIndex = i + 1;
      final isEven = i % 2 == 0;

      final rowStyle = CellStyle(
        backgroundColorHex: isEven
            ? ExcelColor.fromHexString('#EFF6FF')
            : ExcelColor.fromHexString('#FFFFFF'),
      );

      void setCell(int col, CellValue value) {
        final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex));
        cell.value = value;
        cell.cellStyle = rowStyle;
      }

      setCell(0, IntCellValue(i + 1));
      setCell(1, TextCellValue(s.name));
      setCell(2, TextCellValue(s.lrn));
      setCell(3, TextCellValue(s.grade));
      setCell(4, DoubleCellValue(info.totalFee));
      setCell(5, DoubleCellValue(info.amountPaid));
      setCell(6, DoubleCellValue(info.remainingBalance));
      setCell(7, TextCellValue(info.paymentStatus));
      setCell(8, IntCellValue(info.payments.length));
      setCell(9, TextCellValue(_formatDate(s.createdAt)));
    }

    // Summary row
    final summaryRowIndex = infos.length + 1;
    final summaryStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#DBEAFE'),
    );

    void setSummaryCell(int col, CellValue value) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(
          columnIndex: col, rowIndex: summaryRowIndex));
      cell.value = value;
      cell.cellStyle = summaryStyle;
    }

    setSummaryCell(1, TextCellValue('TOTAL: ${infos.length} students'));
    setSummaryCell(4,
        DoubleCellValue(infos.fold<double>(0, (s, i) => s + i.totalFee)));
    setSummaryCell(5,
        DoubleCellValue(infos.fold<double>(0, (s, i) => s + i.amountPaid)));
    setSummaryCell(6,
        DoubleCellValue(infos.fold<double>(0, (s, i) => s + i.remainingBalance)));

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath = '${dir.path}/SPTA_Payments_$timestamp.xlsx';
    final file = File(filePath);
    await file.writeAsBytes(excel.encode()!);
    return file;
  }

  static String _formatDate(String dateStr) {
    try {
      return _dateFormat.format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }
}