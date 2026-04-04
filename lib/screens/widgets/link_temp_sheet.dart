import 'package:flutter/material.dart';
import '../../models/models.dart';

/// Bottom sheet shown after a QR scan when temp (walk-in) records might match
/// the scanned student. Returns the [StudentPaymentInfo] the user chose to
/// link, or null if they skipped.
class LinkTempSheet extends StatefulWidget {
  final String scannedName;
  final String scannedLrn;
  final List<StudentPaymentInfo> candidates;

  const LinkTempSheet({
    super.key,
    required this.scannedName,
    required this.scannedLrn,
    required this.candidates,
  });

  static Future<StudentPaymentInfo?> show(
    BuildContext context, {
    required String scannedName,
    required String scannedLrn,
    required List<StudentPaymentInfo> candidates,
  }) {
    return showModalBottomSheet<StudentPaymentInfo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LinkTempSheet(
        scannedName: scannedName,
        scannedLrn: scannedLrn,
        candidates: candidates,
      ),
    );
  }

  @override
  State<LinkTempSheet> createState() => _LinkTempSheetState();
}

class _LinkTempSheetState extends State<LinkTempSheet> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // ── Handle ───────────────────────────────────────────────────
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),

            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
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
                            const Text('Link Walk-in Record?',
                                style: TextStyle(
                                    color: Color(0xFF14532D),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800)),
                            Text('Scanned: ${widget.scannedName}',
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFFF97316).withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: Color(0xFFF97316), size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'We found unlinked walk-in record(s) that may match this student. Select one to merge, or skip to create a new record.',
                            style: TextStyle(
                                color: Color(0xFF9A3412),
                                fontSize: 11,
                                height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            // ── Candidate list ────────────────────────────────────────────
            Expanded(
              child: ListView.separated(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: widget.candidates.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final info = widget.candidates[i];
                  final s = info.student;
                  final isSelected = _selectedIndex == i;

                  return GestureDetector(
                    onTap: () => setState(() =>
                        _selectedIndex = isSelected ? null : i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFF0FDF4)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF16A34A)
                              : Colors.grey.withOpacity(0.2),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Selection indicator
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? const Color(0xFF16A34A)
                                  : Colors.transparent,
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF16A34A)
                                    : Colors.grey[400]!,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 14)
                                : null,
                          ),
                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.name,
                                    style: const TextStyle(
                                        color: Color(0xFF14532D),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14)),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: const Color(0xFFFFEDD5),
                                          borderRadius:
                                              BorderRadius.circular(6)),
                                      child: Text(s.lrn,
                                          style: const TextStyle(
                                              color: Color(0xFF9A3412),
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              fontFamily: 'monospace')),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(s.grade,
                                        style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 11)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _pill(
                                      '${info.payments.length} payment(s)',
                                      Icons.receipt_rounded,
                                      const Color(0xFF16A34A),
                                    ),
                                    const SizedBox(width: 6),
                                    _pill(
                                      '₱${info.amountPaid.toStringAsFixed(2)} paid',
                                      Icons.payments_rounded,
                                      const Color(0xFF0D9488),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Action buttons ────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  20 + MediaQuery.of(context).padding.bottom),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, null),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Skip / New Record',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _selectedIndex == null
                          ? null
                          : () => Navigator.pop(
                              context,
                              widget.candidates[_selectedIndex!]),
                      icon: const Icon(Icons.link_rounded, size: 18),
                      label: const Text('Link Record',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}