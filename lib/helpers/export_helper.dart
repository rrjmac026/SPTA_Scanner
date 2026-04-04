import 'dart:io';
import '../models/models.dart';
import 'excel_export_helper.dart';
import 'pdf_export_helper.dart';

/// Public facade — screens import only this file, not the split helpers.
class ExportHelper {
  static Future<File> exportToExcel(List<StudentPaymentInfo> infos) =>
      ExcelExportHelper.exportToExcel(infos);

  static Future<File> exportToPdf(List<StudentPaymentInfo> infos) =>
      PdfExportHelper.exportToPdf(infos);
}