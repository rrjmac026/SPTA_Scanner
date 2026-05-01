import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import 'edit_payment_sheet.dart';

/// A single payment row with role-based edit access.
///
/// - Admin: can edit any payment
/// - Teacher: can only edit their own payments
/// - Shows edit icon only when user has permission
///
/// Usage:
///   PaymentRow(
///     payment: payment,
///     student: student,
///     totalFee: totalFee,
///     onEdited: () => refreshData(),
///   )
class PaymentRow extends StatelessWidget {
  final Payment payment;
  final Student student;
  final double totalFee;
  final VoidCallback? onEdited;
  final bool isFirst;
  final bool isLast;

  const PaymentRow({
    super.key,
    required this.payment,
    required this.student,
    required this.totalFee,
    this.onEdited,
    this.isFirst = false,
    this.isLast = false,
  });

  bool _canEdit(AppUser? user) {
    if (user == null) return false;
    if (user.role == UserRole.admin) return true;
    if (user.role == UserRole.teacher) {
      return payment.processedByUid == user.uid;
    }
    return false;
  }

  String _fmtDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      const mo = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final m = dt.minute.toString().padLeft(2, '0');
      return '${mo[dt.month - 1]} ${dt.day}  $h:$m $ampm';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final canEdit = _canEdit(user);

    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(isFirst ? 12 : 0),
      topRight: Radius.circular(isFirst ? 12 : 0),
      bottomLeft: Radius.circular(isLast ? 12 : 0),
      bottomRight: Radius.circular(isLast ? 12 : 0),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius,
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : BorderSide(color: Colors.grey[100]!, width: 1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // ── Amount pill ────────────────────────────────────────────
            Container(
              width: 72,
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF16A34A).withOpacity(0.2)),
              ),
              child: Text(
                '₱${payment.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF16A34A),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 12),

            // ── Details ────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Transaction number
                  if (payment.transactionNumber.isNotEmpty)
                    Text(
                      payment.transactionNumber,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3B82F6),
                        fontFamily: 'monospace',
                        letterSpacing: 0.3,
                      ),
                    ),
                  const SizedBox(height: 2),
                  // Date and processor
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 10, color: Colors.grey[400]),
                      const SizedBox(width: 3),
                      Text(
                        _fmtDate(payment.createdAt),
                        style:
                            TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  if (payment.processedByName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.person_rounded,
                            size: 10, color: Colors.grey[400]),
                        const SizedBox(width: 3),
                        Text(
                          payment.processedByName,
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey[500]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                  if (payment.note.isNotEmpty &&
                      payment.note != 'Manual entry' &&
                      payment.note != 'Walk-in (no ID)') ...[
                    const SizedBox(height: 2),
                    Text(
                      payment.note,
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey[400]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // ── Sync + edit icons ──────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Sync status
                Icon(
                  payment.synced
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded,
                  size: 14,
                  color: payment.synced
                      ? const Color(0xFF16A34A)
                      : Colors.grey[400],
                ),
                if (canEdit) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final edited = await EditPaymentSheet.show(
                        context,
                        payment: payment,
                        student: student,
                        totalFee: totalFee,
                      );
                      if (edited == true && onEdited != null) {
                        onEdited!();
                      }
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color:
                                const Color(0xFFF59E0B).withOpacity(0.3)),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        size: 14,
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
    );
  }
}