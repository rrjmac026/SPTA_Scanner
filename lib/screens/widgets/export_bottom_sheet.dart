import 'package:flutter/material.dart';

/// Shows export format options (Excel / PDF) in a bottom sheet.
/// Call [ExportBottomSheet.show] from [RecordsScreen].
class ExportBottomSheet extends StatelessWidget {
  final int recordCount;
  final VoidCallback onExcelTap;
  final VoidCallback onPdfTap;

  const ExportBottomSheet({
    super.key,
    required this.recordCount,
    required this.onExcelTap,
    required this.onPdfTap,
  });

  static Future<void> show(
    BuildContext context, {
    required int recordCount,
    required VoidCallback onExcelTap,
    required VoidCallback onPdfTap,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ExportBottomSheet(
        recordCount: recordCount,
        onExcelTap: onExcelTap,
        onPdfTap: onPdfTap,
      ),
    );
  }

  Widget _exportTile({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: bgColor, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: color)),
                  Text(subtitle,
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Export Records',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF14532D))),
          const SizedBox(height: 4),
          Text('Exporting $recordCount records',
              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          const SizedBox(height: 20),
          _exportTile(
            context: context,
            icon: Icons.table_chart_rounded,
            color: const Color(0xFF16A34A),
            bgColor: const Color(0xFFDCFCE7),
            title: 'Export as Excel (.xlsx)',
            subtitle: 'Full spreadsheet with payment details',
            onTap: onExcelTap,
          ),
          const SizedBox(height: 12),
          _exportTile(
            context: context,
            icon: Icons.picture_as_pdf_rounded,
            color: const Color(0xFFDC2626),
            bgColor: const Color(0xFFFEE2E2),
            title: 'Export as PDF',
            subtitle: 'Printable report with grade summary',
            onTap: onPdfTap,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}