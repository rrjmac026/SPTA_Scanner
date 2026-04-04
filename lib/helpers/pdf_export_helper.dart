import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/models.dart';

class PdfExportHelper {
  static Future<File> exportToPdf(List<StudentPaymentInfo> infos) async {
    final pdf = pw.Document();

    final gradeMap = <String, List<StudentPaymentInfo>>{};
    for (final info in infos) {
      final grade =
          info.student.grade.isEmpty ? 'Unspecified' : info.student.grade;
      gradeMap.putIfAbsent(grade, () => []).add(info);
    }

    final totalCollected =
        infos.fold<double>(0, (s, i) => s + i.amountPaid);
    final totalBalance =
        infos.fold<double>(0, (s, i) => s + i.remainingBalance);
    final fullyPaid = infos.where((i) => i.isFullyPaid).length;
    final generatedDate =
        DateFormat('MMMM d, yyyy h:mm a').format(DateTime.now());

    const primaryColor = PdfColor.fromInt(0xFF1A3A6B);
    const lightBlue = PdfColor.fromInt(0xFFEFF6FF);
    const greenColor = PdfColor.fromInt(0xFF16A34A);
    const redColor = PdfColor.fromInt(0xFFDC2626);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (context) => _buildPdfHeader(
          generatedDate: generatedDate,
          totalStudents: infos.length,
          fullyPaid: fullyPaid,
          totalCollected: totalCollected,
          totalBalance: totalBalance,
          primaryColor: primaryColor,
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
          pw.Text('Summary by Grade',
              style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor)),
          pw.SizedBox(height: 8),
          _buildGradeSummaryTable(gradeMap, primaryColor, lightBlue),
          pw.SizedBox(height: 20),
          pw.Text('All Payment Records',
              style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor)),
          pw.SizedBox(height: 8),
          _buildStudentTable(
              infos, primaryColor, lightBlue, greenColor, redColor),
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
    required int fullyPaid,
    required double totalCollected,
    required double totalBalance,
    required PdfColor primaryColor,
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
                  style: pw.TextStyle(
                      fontSize: 11, color: const PdfColor(1, 1, 1, 0.7))),
              pw.SizedBox(height: 10),
              pw.Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _chip('$totalStudents Students'),
                  _chip('$fullyPaid Fully Paid'),
                  _chip('₱${totalCollected.toStringAsFixed(2)} Collected'),
                  _chip('₱${totalBalance.toStringAsFixed(2)} Pending'),
                  _chip('Generated: $generatedDate'),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
      ],
    );
  }

  static pw.Widget _chip(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: const PdfColor(1, 1, 1, 0.15),
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: const PdfColor(1, 1, 1, 0.4)),
      ),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold)),
    );
  }

  static pw.Widget _buildGradeSummaryTable(
    Map<String, List<StudentPaymentInfo>> gradeMap,
    PdfColor primaryColor,
    PdfColor lightBlue,
  ) {
    final rows = gradeMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: primaryColor),
          children:
              ['Grade', 'Students', 'Fully Paid', 'Collected', 'Pending']
                  .map((h) => _headerCell(h))
                  .toList(),
        ),
        ...rows.asMap().entries.map((entry) {
          final grade = entry.value.key;
          final list = entry.value.value;
          final collected =
              list.fold<double>(0, (s, i) => s + i.amountPaid);
          final pending =
              list.fold<double>(0, (s, i) => s + i.remainingBalance);
          final fp = list.where((i) => i.isFullyPaid).length;
          final isEven = entry.key % 2 == 0;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
                color: isEven ? lightBlue : PdfColors.white),
            children: [
              grade,
              '${list.length}',
              '$fp',
              '₱${collected.toStringAsFixed(2)}',
              '₱${pending.toStringAsFixed(2)}',
            ].map((text) => _dataCell(text)).toList(),
          );
        }),
      ],
    );
  }

  static pw.Widget _buildStudentTable(
    List<StudentPaymentInfo> infos,
    PdfColor primaryColor,
    PdfColor lightBlue,
    PdfColor greenColor,
    PdfColor redColor,
  ) {
    return pw.Table(
      columnWidths: {
        0: const pw.FixedColumnWidth(20),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FixedColumnWidth(34),
        4: const pw.FixedColumnWidth(46),
        5: const pw.FixedColumnWidth(46),
        6: const pw.FixedColumnWidth(46),
        7: const pw.FixedColumnWidth(44),
      },
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: primaryColor),
          children: ['#', 'Full Name', 'LRN', 'Grade',
            'Total Fee', 'Paid', 'Balance', 'Status']
              .map((h) => _headerCell(h))
              .toList(),
        ),
        ...infos.asMap().entries.map((entry) {
          final i = entry.key;
          final info = entry.value;
          final s = info.student;
          final isEven = i % 2 == 0;
          final statusColor = info.isFullyPaid
              ? greenColor
              : (info.amountPaid > 0
                  ? const PdfColor.fromInt(0xFFF97316)
                  : redColor);

          return pw.TableRow(
            decoration: pw.BoxDecoration(
                color: isEven ? lightBlue : PdfColors.white),
            children: [
              _dataCell('${i + 1}'),
              _dataCell(s.name),
              _dataCell(s.lrn),
              _dataCell(s.grade),
              _dataCell('₱${info.totalFee.toStringAsFixed(2)}'),
              _dataCell('₱${info.amountPaid.toStringAsFixed(2)}'),
              _dataCell('₱${info.remainingBalance.toStringAsFixed(2)}',
                  color: info.isFullyPaid ? greenColor : redColor),
              _dataCell(info.paymentStatus, color: statusColor),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _headerCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: pw.Text(text,
          style: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 8)),
    );
  }

  static pw.Widget _dataCell(String text, {PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: pw.Text(text,
          style: pw.TextStyle(fontSize: 7.5, color: color), maxLines: 2),
    );
  }
}