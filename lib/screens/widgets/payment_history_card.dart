import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/payment.dart';

/// Scrollable list of individual payment entries shown in [ResultScreen].
class PaymentHistoryCard extends StatelessWidget {
  final List<Payment> payments;

  const PaymentHistoryCard({super.key, required this.payments});

  static String _formatDate(String dateStr) {
    try {
      return DateFormat('MMM d, yyyy  h:mm a').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.history_rounded,
                      color: Color(0xFF16A34A), size: 18),
                ),
                const SizedBox(width: 10),
                Text('Payment History (${payments.length})',
                    style: const TextStyle(
                        color: Color(0xFF14532D),
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const Divider(height: 1),
          ...payments.asMap().entries.map((e) {
            final i = e.key;
            final p = e.value;
            final isLast = i == payments.length - 1;
            final hasTxn = p.transactionNumber.isNotEmpty;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  color: Color(0xFF16A34A),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hasTxn)
                              GestureDetector(
                                onLongPress: () {
                                  Clipboard.setData(
                                      ClipboardData(text: p.transactionNumber));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Copied: ${p.transactionNumber}'),
                                      duration: const Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor:
                                          const Color(0xFF16A34A),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      margin: const EdgeInsets.all(16),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: const Color(0xFF3B82F6)
                                            .withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                          Icons.confirmation_number_rounded,
                                          size: 11,
                                          color: Color(0xFF3B82F6)),
                                      const SizedBox(width: 4),
                                      Text(p.transactionNumber,
                                          style: const TextStyle(
                                              color: Color(0xFF1D4ED8),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              fontFamily: 'monospace',
                                              letterSpacing: 0.5)),
                                    ],
                                  ),
                                ),
                              ),
                            if (hasTxn) const SizedBox(height: 4),
                            Text(_formatDate(p.createdAt),
                                style: const TextStyle(
                                    color: Color(0xFF64748B), fontSize: 11)),
                            if (p.note.isNotEmpty)
                              Text(p.note,
                                  style: TextStyle(
                                      color: Colors.grey[400], fontSize: 10)),
                          ],
                        ),
                      ),
                      Text('₱${p.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Color(0xFF16A34A),
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                    ],
                  ),
                ),
                if (!isLast)
                  Divider(color: Colors.grey[100], height: 1, indent: 16),
              ],
            );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}