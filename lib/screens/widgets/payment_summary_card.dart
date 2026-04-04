import 'package:flutter/material.dart';
import '../../models/models.dart';

/// Payment progress card shown in [ResultScreen].
class PaymentSummaryCard extends StatelessWidget {
  final StudentPaymentInfo info;

  const PaymentSummaryCard({super.key, required this.info});

  Widget _summaryStatBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 10,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pct = info.totalFee > 0
        ? (info.amountPaid / info.totalFee).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
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
                child: const Icon(Icons.receipt_long_rounded,
                    color: Color(0xFF16A34A), size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Payment Summary',
                  style: TextStyle(
                      color: Color(0xFF14532D),
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                  child: _summaryStatBox('Total Fee',
                      '₱${info.totalFee.toStringAsFixed(2)}',
                      const Color(0xFF14532D))),
              const SizedBox(width: 10),
              Expanded(
                  child: _summaryStatBox('Amount Paid',
                      '₱${info.amountPaid.toStringAsFixed(2)}',
                      const Color(0xFF16A34A))),
              const SizedBox(width: 10),
              Expanded(
                  child: _summaryStatBox(
                      'Balance',
                      '₱${info.remainingBalance.toStringAsFixed(2)}',
                      info.isFullyPaid
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Payment Progress',
                  style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              Text('${(pct * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      color: Color(0xFF14532D),
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 12,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                info.isFullyPaid
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF4ADE80),
              ),
            ),
          ),
          if (!info.isFullyPaid) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFFFCA5A5).withOpacity(0.6)),
              ),
              child: Column(
                children: [
                  const Text('REMAINING BALANCE',
                      style: TextStyle(
                          color: Color(0xFF991B1B),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 4),
                  Text(
                    '₱${info.remainingBalance.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}