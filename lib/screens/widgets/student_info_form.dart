import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../widgets/app_input_decoration.dart';

/// Student identity section used inside [AddTransactionScreen].
class StudentInfoForm extends StatelessWidget {
  final TextEditingController lrnController;
  final TextEditingController nameController;
  final String selectedGrade;
  final List<String> grades;
  final bool lrnChecked;
  final bool lrnExists;
  final StudentPaymentInfo? existingInfo;
  final double amountPaid;
  final double remaining;
  final bool noLrnMode;
  final ValueChanged<String> onLrnChanged;
  final ValueChanged<String?> onGradeChanged;

  const StudentInfoForm({
    super.key,
    required this.lrnController,
    required this.nameController,
    required this.selectedGrade,
    required this.grades,
    required this.lrnChecked,
    required this.lrnExists,
    required this.existingInfo,
    required this.amountPaid,
    required this.remaining,
    required this.onLrnChanged,
    required this.onGradeChanged,
    this.noLrnMode = false,
  });

  Widget _fieldLabel(String label) => Text(label,
      style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3));

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── LRN field (hidden in no-LRN mode) ──────────────────────────
        if (!noLrnMode) ...[
          _fieldLabel('Learner Reference Number (LRN)'),
          const SizedBox(height: 8),
          TextFormField(
            controller: lrnController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: onLrnChanged,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'LRN is required' : null,
            decoration: appInputDecoration(
              hint: 'e.g. 123456789012',
              prefix: const Icon(Icons.numbers_rounded,
                  color: Color(0xFF94A3B8), size: 18),
              suffix: lrnChecked
                  ? Icon(
                      lrnExists
                          ? Icons.person_rounded
                          : Icons.person_add_rounded,
                      color: lrnExists
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF0D9488),
                      size: 20,
                    )
                  : null,
            ),
          ),

          if (lrnChecked && lrnExists && existingInfo != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF22C55E).withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF16A34A), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Student found: ${existingInfo!.student.name}',
                            style: const TextStyle(
                                color: Color(0xFF166534),
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                        Text(
                          '${existingInfo!.student.grade}  •  Paid: ₱${amountPaid.toStringAsFixed(2)}  •  Balance: ₱${remaining.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Color(0xFF166534), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (lrnChecked && !lrnExists) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF16A34A).withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.person_add_rounded,
                      color: Color(0xFF16A34A), size: 18),
                  SizedBox(width: 8),
                  Text('New student — will be registered',
                      style: TextStyle(
                          color: Color(0xFF166534),
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],

        // ── Walk-in notice (shown instead of LRN field) ─────────────────
        if (noLrnMode) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFFF97316).withOpacity(0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFF97316), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'LRN will be auto-assigned as TEMP. Ask student to show their QR next time to link the record.',
                    style: TextStyle(
                        color: Color(0xFF9A3412),
                        fontSize: 11,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Full name ───────────────────────────────────────────────────
        _fieldLabel('Full Name'),
        const SizedBox(height: 8),
        TextFormField(
          controller: nameController,
          readOnly: lrnExists && !noLrnMode,
          textCapitalization: TextCapitalization.words,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
          decoration: appInputDecoration(
            hint: 'e.g. Juan Dela Cruz',
            prefix: const Icon(Icons.badge_rounded,
                color: Color(0xFF94A3B8), size: 18),
            filled: lrnExists && !noLrnMode,
            fillOverride:
                (lrnExists && !noLrnMode) ? const Color(0xFFF1F5F9) : null,
          ),
        ),

        const SizedBox(height: 16),

        // ── Grade ────────────────────────────────────────────────────────
        _fieldLabel('Grade Level'),
        const SizedBox(height: 8),
        IgnorePointer(
          ignoring: lrnExists && !noLrnMode,
          child: Opacity(
            opacity: (lrnExists && !noLrnMode) ? 0.6 : 1.0,
            child: Container(
              decoration: BoxDecoration(
                color: (lrnExists && !noLrnMode)
                    ? const Color(0xFFF1F5F9)
                    : const Color(0xFFF8FAFC),
                border: Border.all(color: const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedGrade,
                  isExpanded: true,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  borderRadius: BorderRadius.circular(12),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF16A34A)),
                  items: grades.map((grade) {
                    return DropdownMenuItem(
                      value: grade,
                      child: Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(7)),
                            child: Center(
                              child: Text(grade.split(' ').last,
                                  style: const TextStyle(
                                      color: Color(0xFF16A34A),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(grade,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (lrnExists && !noLrnMode) ? null : onGradeChanged,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}