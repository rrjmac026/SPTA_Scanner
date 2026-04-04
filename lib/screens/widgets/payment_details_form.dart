import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/app_input_decoration.dart';
import '../../widgets/quick_chip.dart';

/// Payment amount section used inside [AddTransactionScreen].
class PaymentDetailsForm extends StatelessWidget {
  final TextEditingController amountController;
  final double totalFee;
  final double amountPaid;
  final double remaining;
  final bool lrnExists;

  const PaymentDetailsForm({
    super.key,
    required this.amountController,
    required this.totalFee,
    required this.amountPaid,
    required this.remaining,
    required this.lrnExists,
  });

  Widget _feeRow(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(color: Colors.grey[500], fontSize: 10)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: _feeRow('Total Fee',
                    '₱${totalFee.toStringAsFixed(2)}', const Color(0xFF14532D)),
              ),
              if (lrnExists) ...[
                Container(width: 1, height: 36, color: Colors.grey[200]),
                Expanded(
                  child: _feeRow('Already Paid',
                      '₱${amountPaid.toStringAsFixed(2)}', const Color(0xFF16A34A)),
                ),
                Container(width: 1, height: 36, color: Colors.grey[200]),
                Expanded(
                  child: _feeRow(
                    'Balance',
                    '₱${remaining.toStringAsFixed(2)}',
                    remaining <= 0
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                  ),
                ),
              ],
            ],
          ),
        ),

        if (lrnExists && remaining <= 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_rounded,
                    color: Color(0xFF16A34A), size: 20),
                SizedBox(width: 8),
                Text('This student is already fully paid!',
                    style: TextStyle(
                        color: Color(0xFF166534),
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 16),
          Text('Payment Amount (₱)',
              style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3)),
          const SizedBox(height: 8),
          TextFormField(
            controller: amountController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Amount is required';
              final amt = double.tryParse(v.trim());
              if (amt == null || amt <= 0) return 'Enter a valid amount';
              if (amt > remaining) {
                return 'Cannot exceed balance of ₱${remaining.toStringAsFixed(2)}';
              }
              return null;
            },
            decoration: appInputDecoration(
              hint: remaining.toStringAsFixed(2),
              prefix: Container(
                alignment: Alignment.center,
                width: 38,
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
            runSpacing: 8,
            children: [
              QuickChip(label: 'Full', amount: remaining, controller: amountController),
              if (remaining >= 500)
                QuickChip(label: '₱500', amount: 500, controller: amountController),
              if (remaining >= 250)
                QuickChip(label: '₱250', amount: 250, controller: amountController),
              if (remaining >= 100)
                QuickChip(label: '₱100', amount: 100, controller: amountController),
            ],
          ),
        ],
      ],
    );
  }
}