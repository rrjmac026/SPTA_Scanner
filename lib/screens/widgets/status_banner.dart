import 'package:flutter/material.dart';
import '../../models/models.dart';

/// Coloured banner at the top of [ResultScreen] showing payment status.
class StatusBanner extends StatelessWidget {
  final StudentPaymentInfo info;

  const StatusBanner({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    final Color bg, border, textColor, iconColor;
    final IconData icon;
    final String message;

    if (info.isFullyPaid) {
      bg = const Color(0xFFDCFCE7);
      border = const Color(0xFF22C55E);
      textColor = const Color(0xFF166534);
      iconColor = const Color(0xFF16A34A);
      icon = Icons.verified_rounded;
      message = 'SPTA Fully Paid ✓';
    } else if (info.amountPaid > 0) {
      bg = const Color(0xFFFFF7ED);
      border = const Color(0xFFF97316);
      textColor = const Color(0xFF9A3412);
      iconColor = const Color(0xFFF97316);
      icon = Icons.pending_rounded;
      message = 'Partial Payment — Balance Remaining';
    } else {
      bg = const Color(0xFFFEE2E2);
      border = const Color(0xFFF87171);
      textColor = const Color(0xFF991B1B);
      iconColor = const Color(0xFFDC2626);
      icon = Icons.cancel_rounded;
      message = 'No Payment Recorded Yet';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    color: textColor,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}