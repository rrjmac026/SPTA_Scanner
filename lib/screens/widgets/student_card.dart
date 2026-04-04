import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../helpers/database_helper.dart';
import '../../models/models.dart';
import '../../widgets/app_input_decoration.dart';

/// A single student record card shown in the [RecordsScreen] list.
class StudentCard extends StatelessWidget {
  final StudentPaymentInfo info;
  final int index;
  final VoidCallback? onRecordChanged;

  const StudentCard({
    super.key,
    required this.info,
    required this.index,
    this.onRecordChanged,
  });

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

  /// Shows a bottom sheet to manually assign a real LRN to this temp record.
  void _showAssignLrnSheet(BuildContext context) {
    final lrnController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final db = DatabaseHelper();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24)),
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
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.link_rounded,
                          color: Color(0xFFF97316), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Assign LRN',
                              style: TextStyle(
                                  color: Color(0xFF14532D),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800)),
                          Text(info.student.name,
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Enter the student\'s real LRN to link this walk-in record.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                const SizedBox(height: 16),
                Text('Learner Reference Number (LRN)',
                    style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: lrnController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'LRN is required';
                    if (v.trim().length < 6) {
                      return 'LRN must be at least 6 digits';
                    }
                    return null;
                  },
                  decoration: appInputDecoration(
                    hint: 'e.g. 123456789012',
                    prefix: const Icon(Icons.numbers_rounded,
                        color: Color(0xFF94A3B8), size: 18),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                          side: BorderSide(color: Colors.grey[300]!),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel',
                            style:
                                TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: StatefulBuilder(
                        builder: (ctx2, setSt) {
                          bool isSaving = false;
                          return ElevatedButton.icon(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) {
                                      return;
                                    }
                                    setSt(() => isSaving = true);
                                    final success =
                                        await db.assignLrnToTemp(
                                      tempStudentId: info.student.id!,
                                      realLrn: lrnController.text.trim(),
                                    );
                                    setSt(() => isSaving = false);
                                    if (!ctx2.mounted) return;
                                    Navigator.pop(ctx2);
                                    if (success) {
                                      onRecordChanged?.call();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                        content: const Row(
                                          children: [
                                            Icon(Icons.link_rounded,
                                                color: Colors.white,
                                                size: 18),
                                            SizedBox(width: 8),
                                            Text('LRN assigned successfully!',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600)),
                                          ],
                                        ),
                                        backgroundColor:
                                            const Color(0xFF16A34A),
                                        behavior:
                                            SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        margin: const EdgeInsets.all(16),
                                      ));
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                        content: const Text(
                                            'LRN already in use by another student.'),
                                        backgroundColor:
                                            const Color(0xFFDC2626),
                                        behavior:
                                            SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        margin: const EdgeInsets.all(16),
                                      ));
                                    }
                                  },
                            icon: const Icon(Icons.save_rounded, size: 18),
                            label: Text(isSaving ? 'Saving...' : 'Assign LRN',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                            ),
                          );
                        },
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

  @override
  Widget build(BuildContext context) {
    final s = info.student;
    final isTemp = s.isTempRecord;
    final pct = info.totalFee > 0
        ? (info.amountPaid / info.totalFee).clamp(0.0, 1.0)
        : 0.0;

    final latestTxn = info.payments.isNotEmpty &&
            info.payments.last.transactionNumber.isNotEmpty
        ? info.payments.last.transactionNumber
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isTemp
            ? Border.all(
                color: const Color(0xFFF97316).withOpacity(0.4), width: 1.5)
            : null,
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
                      color: isTemp
                          ? const Color(0xFFFFEDD5)
                          : const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10)),
                  child: Center(
                    child: isTemp
                        ? const Icon(Icons.no_accounts_rounded,
                            color: Color(0xFFF97316), size: 18)
                        : Text('${index + 1}',
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
                      if (isTemp)
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEDD5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      color: Color(0xFFF97316), size: 9),
                                  SizedBox(width: 3),
                                  Text('No LRN',
                                      style: TextStyle(
                                          color: Color(0xFF9A3412),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(s.lrn,
                                style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 10,
                                    fontFamily: 'monospace')),
                          ],
                        )
                      else
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

            // ── "Link LRN" button for temp records ─────────────────────────
            if (isTemp) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showAssignLrnSheet(context),
                  icon: const Icon(Icons.link_rounded, size: 15),
                  label: const Text('Assign LRN manually',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF97316),
                    side: const BorderSide(
                        color: Color(0xFFF97316), width: 1.2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],

            // Latest transaction number badge
            if (latestTxn != null) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                      color: const Color(0xFF3B82F6).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.confirmation_number_rounded,
                        size: 11, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 5),
                    Text('Latest: $latestTxn',
                        style: const TextStyle(
                            color: Color(0xFF1D4ED8),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            letterSpacing: 0.4)),
                  ],
                ),
              ),
            ],

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