import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';

/// A single student record card shown in the [RecordsScreen] list.
class StudentCard extends StatelessWidget {
  final StudentPaymentInfo info;
  final int index;

  const StudentCard({super.key, required this.info, required this.index});

  static String formatDate(String dateStr) {
    try {
      return DateFormat('MMM d, yyyy  h:mm a').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }

  Widget _statusChip(String status) {
    late Color bg, text;
    late IconData icon;
    switch (status) {
      case 'Fully Paid':
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF16A34A);
        icon = Icons.check_circle_rounded;
        break;
      case 'Partial':
        bg = const Color(0xFFFFF7ED);
        text = const Color(0xFFF97316);
        icon = Icons.pending_rounded;
        break;
      default:
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFFDC2626);
        icon = Icons.cancel_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: text, size: 12),
          const SizedBox(width: 4),
          Text(status,
              style: TextStyle(
                  color: text, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.grey[400],
                fontSize: 10,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w800)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = info.student;
    final pct = info.totalFee > 0
        ? (info.amountPaid / info.totalFee).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10)),
                  child: Center(
                    child: Text('${index + 1}',
                        style: const TextStyle(
                            color: Color(0xFF16A34A),
                            fontWeight: FontWeight.w800,
                            fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name,
                          style: const TextStyle(
                              color: Color(0xFF14532D),
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                      const SizedBox(height: 1),
                      Text('LRN: ${s.lrn}',
                          style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                              fontFamily: 'monospace')),
                    ],
                  ),
                ),
                _statusChip(info.paymentStatus),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            Row(
              children: [
                if (s.grade.isNotEmpty) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(s.grade,
                        style: const TextStyle(
                            color: Color(0xFF16A34A),
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(formatDate(s.createdAt),
                    style: TextStyle(color: Colors.grey[400], fontSize: 10)),
              ],
            ),

            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: _miniStat('Total Fee',
                        '₱${info.totalFee.toStringAsFixed(2)}',
                        const Color(0xFF64748B))),
                Expanded(
                    child: _miniStat('Paid',
                        '₱${info.amountPaid.toStringAsFixed(2)}',
                        const Color(0xFF16A34A))),
                Expanded(
                    child: _miniStat(
                        'Balance',
                        '₱${info.remainingBalance.toStringAsFixed(2)}',
                        info.isFullyPaid
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626))),
              ],
            ),

            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(
                  info.isFullyPaid
                      ? const Color(0xFF16A34A)
                      : const Color(0xFF4ADE80),
                ),
              ),
            ),

            if (info.payments.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '${info.payments.length} payment${info.payments.length > 1 ? 's' : ''} recorded',
                style: TextStyle(color: Colors.grey[400], fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }
}