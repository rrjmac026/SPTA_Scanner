import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/app_input_decoration.dart';
import '../../widgets/quick_chip.dart';

/// Shows a bottom-sheet payment entry form.
/// Returns the entered [double] amount, or null if cancelled.
Future<double?> showPaymentDialog(
  BuildContext context, {
  required double remaining,
}) {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();

  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.payments_rounded,
                        color: Color(0xFF16A34A), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Record Payment',
                            style: TextStyle(
                                color: Color(0xFF14532D),
                                fontSize: 16,
                                fontWeight: FontWeight.w800)),
                        Text('Remaining: ₱${remaining.toStringAsFixed(2)}',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Text('Payment Amount (₱)',
                  style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4)),
              const SizedBox(height: 8),

              TextFormField(
                controller: controller,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter an amount';
                  final amt = double.tryParse(v.trim());
                  if (amt == null || amt <= 0) {
                    return 'Enter a valid amount greater than 0';
                  }
                  if (amt > remaining) {
                    return 'Cannot exceed remaining balance of ₱${remaining.toStringAsFixed(2)}';
                  }
                  return null;
                },
                decoration: appInputDecoration(
                  hint: remaining.toStringAsFixed(2),
                  prefix: Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    child: const Text('₱',
                        style: TextStyle(
                            color: Color(0xFF16A34A),
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                children: [
                  QuickChip(
                      label: 'Full', amount: remaining, controller: controller),
                  if (remaining >= 500)
                    QuickChip(
                        label: '₱500', amount: 500, controller: controller),
                  if (remaining >= 250)
                    QuickChip(
                        label: '₱250', amount: 250, controller: controller),
                  if (remaining >= 100)
                    QuickChip(
                        label: '₱100', amount: 100, controller: controller),
                ],
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (!formKey.currentState!.validate()) return;
                        final amt = double.parse(controller.text.trim());
                        Navigator.pop(context, amt);
                      },
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Record',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}