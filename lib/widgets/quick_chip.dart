import 'package:flutter/material.dart';

/// A tappable chip that fills [controller] with [amount] when tapped.
class QuickChip extends StatelessWidget {
  final String label;
  final double amount;
  final TextEditingController controller;

  const QuickChip({
    super.key,
    required this.label,
    required this.amount,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => controller.text = amount.toStringAsFixed(2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.3)),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Color(0xFF16A34A),
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}