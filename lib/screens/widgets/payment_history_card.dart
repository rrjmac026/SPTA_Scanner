import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/payment.dart';
import '../../models/student.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../edit_payment_sheet.dart';

/// Scrollable list of individual payment entries shown in [ResultScreen].
/// Supports role-based edit access — same rules as [StudentDetailScreen].
class PaymentHistoryCard extends StatelessWidget {
  final List<Payment> payments;
  final Student student;
  final double totalFee;
  final VoidCallback onEdited;

  const PaymentHistoryCard({
    super.key,
    required this.payments,
    required this.student,
    required this.totalFee,
    required this.onEdited,
  });

  static String _formatDate(String dateStr) {
    try {
      return DateFormat('MMM d, yyyy  h:mm a').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }

  bool _canEdit(Payment p, AppUser? user) {
    if (user == null) return false;
    if (user.role == UserRole.admin) return true;
    if (user.role == UserRole.teacher) {
      return p.processedByUid == user.uid;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

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
          // ── Header ────────────────────────────────────────────────────
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
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '₱${payments.fold<double>(0, (s, p) => s + p.amount).toStringAsFixed(2)} total',
                    style: const TextStyle(
                        color: Color(0xFF16A34A),
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Payment rows ──────────────────────────────────────────────
          ...payments.asMap().entries.map((e) {
            final i = e.key;
            final p = e.value;
            final isLast = i == payments.length - 1;
            final hasTxn = p.transactionNumber.isNotEmpty;
            final canEdit = _canEdit(p, user);

            return Column(
              children: [
                InkWell(
                  onLongPress: hasTxn
                      ? () {
                          Clipboard.setData(
                              ClipboardData(text: p.transactionNumber));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Copied: ${p.transactionNumber}'),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: const Color(0xFF16A34A),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                        }
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Index badge ─────────────────────────────────
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

                        // ── Details ─────────────────────────────────────
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (hasTxn) ...[
                                Container(
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
                                      const SizedBox(width: 4),
                                      const Icon(Icons.copy_rounded,
                                          size: 9,
                                          color: Color(0xFF3B82F6)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 5),
                              ],
                              Text(_formatDate(p.createdAt),
                                  style: const TextStyle(
                                      color: Color(0xFF64748B), fontSize: 11)),
                              if (p.processedByName.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.person_rounded,
                                        size: 10, color: Colors.grey[400]),
                                    const SizedBox(width: 3),
                                    Text(p.processedByName,
                                        style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 10)),
                                  ],
                                ),
                              ],
                              if (p.note.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.notes_rounded,
                                        size: 11, color: Colors.grey[400]),
                                    const SizedBox(width: 3),
                                    Text(p.note,
                                        style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 10)),
                                  ],
                                ),
                              ],
                              // ── Sync indicator ───────────────────────
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Icon(
                                    p.synced
                                        ? Icons.cloud_done_rounded
                                        : Icons.cloud_off_rounded,
                                    size: 11,
                                    color: p.synced
                                        ? const Color(0xFF16A34A)
                                        : Colors.grey[400],
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    p.synced ? 'Synced' : 'Pending sync',
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: p.synced
                                            ? const Color(0xFF16A34A)
                                            : Colors.grey[400]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // ── Amount + edit button ─────────────────────────
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₱${p.amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: Color(0xFF16A34A),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text('payment',
                                style: TextStyle(
                                    color: Colors.grey[400], fontSize: 9)),
                            if (canEdit) ...[
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () async {
                                  final edited = await EditPaymentSheet.show(
                                    context,
                                    payment: p,
                                    student: student,
                                    totalFee: totalFee,
                                  );
                                  if (edited == true) onEdited();
                                },
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(9),
                                    border: Border.all(
                                        color: const Color(0xFFF59E0B)
                                            .withOpacity(0.35)),
                                  ),
                                  child: const Icon(
                                    Icons.edit_rounded,
                                    size: 15,
                                    color: Color(0xFFD97706),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
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