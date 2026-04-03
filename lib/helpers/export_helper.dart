import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'database_helper.dart';

class ExportHelper {
  static final _currency = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
  static final _dateFormat = DateFormat('MMM d, yyyy h:mm a');

  // ─── Excel Export ────────────────────────────────────────────────────────────

  static Future<File> exportToExcel(List<Student> students) async {
    final excel = Excel.createExcel();
    final sheet = excel['SPTA Payments'];
    excel.delete('Sheet1');

    // Header row styling
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#1A3A6B'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
    );

    final headers = ['#', 'Full Name', 'LRN', 'Grade', 'Amount', 'Status', 'Date Recorded'];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // Set column widths
    sheet.setColumnWidth(0, 6);
    sheet.setColumnWidth(1, 30);
    sheet.setColumnWidth(2, 18);
    sheet.setColumnWidth(3, 12);
    sheet.setColumnWidth(4, 14);
    sheet.setColumnWidth(5, 12);
    sheet.setColumnWidth(6, 24);

    // Data rows
    for (var i = 0; i < students.length; i++) {
      final s = students[i];
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
      setCell(4, DoubleCellValue(s.amount));
      setCell(5, TextCellValue(s.paymentStatus));
      setCell(6, TextCellValue(_formatDate(s.createdAt)));
    }

    // Summary row
    final summaryRowIndex = students.length + 1;
    final summaryStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#DBEAFE'),
    );

    final totalCell = sheet.cell(CellIndex.indexByColumnRow(
        columnIndex: 1, rowIndex: summaryRowIndex));
    totalCell.value = TextCellValue('TOTAL: ${students.length} students');
    totalCell.cellStyle = summaryStyle;

    final amountCell = sheet.cell(CellIndex.indexByColumnRow(
        columnIndex: 4, rowIndex: summaryRowIndex));
    final totalAmount = students.fold<double>(0, (sum, s) => sum + s.amount);
    amountCell.value = DoubleCellValue(totalAmount);
    amountCell.cellStyle = summaryStyle;

    // Save file
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath = '${dir.path}/SPTA_Payments_$timestamp.xlsx';
    final file = File(filePath);
    await file.writeAsBytes(excel.encode()!);
    return file;
  }

  // ─── PDF Export ──────────────────────────────────────────────────────────────

  static Future<File> exportToPdf(List<Student> students) async {
    final pdf = pw.Document();

    // Group students by grade for summary
    final gradeMap = <String, List<Student>>{};
    for (final s in students) {
      gradeMap.putIfAbsent(s.grade.isEmpty ? 'Unspecified' : s.grade, () => []).add(s);
    }

    final totalAmount = students.fold<double>(0, (sum, s) => sum + s.amount);
    final generatedDate = DateFormat('MMMM d, yyyy h:mm a').format(DateTime.now());

    // Primary color
    const primaryColor = PdfColor.fromInt(0xFF1A3A6B);
    const accentColor = PdfColor.fromInt(0xFF2563EB);
    const lightBlue = PdfColor.fromInt(0xFFEFF6FF);
    const greenColor = PdfColor.fromInt(0xFF16A34A);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildPdfHeader(
          generatedDate: generatedDate,
          totalStudents: students.length,
          totalAmount: totalAmount,
          primaryColor: primaryColor,
          accentColor: accentColor,
          lightBlue: lightBlue,
          greenColor: greenColor,
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('SPTA Payment Records',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
        build: (context) => [
          // Grade summary table
          pw.Text('Summary by Grade',
              style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor)),
          pw.SizedBox(height: 8),
          _buildGradeSummaryTable(gradeMap, primaryColor, lightBlue, accentColor),
          pw.SizedBox(height: 20),

          // Full records table
          pw.Text('All Payment Records',
              style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor)),
          pw.SizedBox(height: 8),
          _buildStudentTable(students, primaryColor, lightBlue, accentColor),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath = '${dir.path}/SPTA_Payments_$timestamp.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static pw.Widget _buildPdfHeader({
    required String generatedDate,
    required int totalStudents,
    required double totalAmount,
    required PdfColor primaryColor,
    required PdfColor accentColor,
    required PdfColor lightBlue,
    required PdfColor greenColor,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: primaryColor,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('SPTA Payment Records',
                  style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white)),
              pw.SizedBox(height: 4),
              pw.Text('School Parent-Teacher Association',
                  style: pw.TextStyle(fontSize: 11, color: PdfColors.white70)),
              pw.SizedBox(height: 12),
              pw.Row(
                children: [
                  _summaryChip('$totalStudents Students', greenColor),
                  pw.SizedBox(width: 10),
                  _summaryChip('₱${totalAmount.toStringAsFixed(2)} Total', accentColor),
                  pw.SizedBox(width: 10),
                  _summaryChip('Generated: $generatedDate', PdfColors.grey700),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
      ],
    );
  }

  static pw.Widget _summaryChip(String text, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: PdfColors.white24,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColors.white54),
      ),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 9, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
    );
  }

  static pw.Widget _buildGradeSummaryTable(
    Map<String, List<Student>> gradeMap,
    PdfColor primaryColor,
    PdfColor lightBlue,
    PdfColor accentColor,
  ) {
    final rows = gradeMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: primaryColor),
          children: ['Grade', 'No. of Students', 'Total Amount'].map((h) {
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: pw.Text(h,
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10)),
            );
          }).toList(),
        ),
        ...rows.asMap().entries.map((entry) {
          final grade = entry.value.key;
          final list = entry.value.value;
          final total = list.fold<double>(0, (s, st) => s + st.amount);
          final isEven = entry.key % 2 == 0;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
                color: isEven ? lightBlue : PdfColors.white),
            children: [
              grade,
              '${list.length}',
              '₱${total.toStringAsFixed(2)}',
            ].map((text) {
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  static pw.Widget _buildStudentTable(
    List<Student> students,
    PdfColor primaryColor,
    PdfColor lightBlue,
    PdfColor accentColor,
  ) {
    return pw.Table(
      columnWidths: {
        0: const pw.FixedColumnWidth(24),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FixedColumnWidth(44),
        4: const pw.FixedColumnWidth(56),
        5: const pw.FixedColumnWidth(42),
        6: const pw.FlexColumnWidth(2),
      },
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: primaryColor),
          children: ['#', 'Full Name', 'LRN', 'Grade', 'Amount', 'Status', 'Date'].map((h) {
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: pw.Text(h,
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 8)),
            );
          }).toList(),
        ),
        ...students.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          final isEven = i % 2 == 0;
          final cells = [
            '${i + 1}',
            s.name,
            s.lrn,
            s.grade,
            '₱${s.amount.toStringAsFixed(2)}',
            s.paymentStatus,
            _formatDateShort(s.createdAt),
          ];
          return pw.TableRow(
            decoration: pw.BoxDecoration(
                color: isEven ? lightBlue : PdfColors.white),
            children: cells.map((text) {
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: pw.Text(text,
                    style: const pw.TextStyle(fontSize: 7.5),
                    maxLines: 2),
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  static String _formatDate(String dateStr) {
    try {
      return _dateFormat.format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }

  static String _formatDateShort(String dateStr) {
    try {
      return DateFormat('MM/dd/yy HH:mm').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }
}
