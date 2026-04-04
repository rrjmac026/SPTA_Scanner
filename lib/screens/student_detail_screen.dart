import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../helpers/database_helper.dart';
import '../models/models.dart';

class StudentDetailScreen extends StatefulWidget {
  final StudentPaymentInfo info;

  const StudentDetailScreen({super.key, required this.info});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen>
    with SingleTickerProviderStateMixin {
  late StudentPaymentInfo _info;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _info = widget.info;
    _animController = AnimationController(
        duration: const Duration(milliseconds: 400), vsync: this);
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
            CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final db = DatabaseHelper();
    final updated = await db.getStudentPaymentInfo(_info.student.lrn);
    if (updated != null && mounted) {
      setState(() => _info = updated);
    }
  }

  static String _formatDate(String dateStr) {
    try {
      return DateFormat('MMM d, yyyy  h:mm a').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }

  Color get _statusColor {
    if (_info.isFullyPaid) return const Color(0xFF16A34A);
    if (_info.amountPaid > 0) return const Color(0xFFF97316);
    return const Color(0xFFDC2626);
  }

  Color get _statusBg {
    if (_info.isFullyPaid) return const Color(0xFFDCFCE7);
    if (_info.amountPaid > 0) return const Color(0xFFFFF7ED);
    return const Color(0xFFFEE2E2);
  }

  IconData get _statusIcon {
    if (_info.isFullyPaid) return Icons.verified_rounded;
    if (_info.amountPaid > 0) return Icons.pending_rounded;
    return Icons.cancel_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final s = _info.student;
    final pct = _info.totalFee > 0
        ? (_info.amountPaid / _info.totalFee).clamp(0.0, 1.0)
        : 0.0;
    final isTemp = s.isTempRecord;

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      body: CustomScrollView(
        slivers: [
          // ── Collapsible app bar ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: const Color(0xFF14532D),
            foregroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _refresh,
                tooltip: 'Refresh',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF14532D), Color(0xFF16A34A)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            // Avatar
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1.5),
                              ),
                              child: Center(
                                child: Text(
                                  s.name.isNotEmpty
                                      ? s.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.name,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.3)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      if (s.grade.isNotEmpty) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(s.grade,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600)),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      if (isTemp)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF97316)
                                                .withOpacity(0.3),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.warning_amber_rounded,
                                                  color: Colors.white,
                                                  size: 10),
                                              SizedBox(width: 3),
                                              Text('No LRN',
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w700)),
                                            ],
                                          ),
                                        )
                                      else
                                        Text(s.lrn,
                                            style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 11,
                                                fontFamily: 'monospace')),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Status badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _statusBg.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_statusIcon,
                                      color: _statusColor, size: 13),
                                  const SizedBox(width: 4),
                                  Text(_info.paymentStatus,
                                      style: TextStyle(
                                          color: _statusColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Progress bar in header
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '₱${_info.amountPaid.toStringAsFixed(2)} of ₱${_info.totalFee.toStringAsFixed(2)} paid',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 11),
                                ),
                                Text(
                                  '${(pct * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 8,
                                backgroundColor:
                                    Colors.white.withOpacity(0.25),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _info.isFullyPaid
                                      ? const Color(0xFF4ADE80)
                                      : Colors.white,
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
            ),
          ),

          // ── Body content ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Payment stats row ──────────────────────────────
                      Row(
                        children: [
                          Expanded(
                              child: _statCard(
                            label: 'Total Fee',
                            value: '₱${_info.totalFee.toStringAsFixed(2)}',
                            icon: Icons.receipt_rounded,
                            color: const Color(0xFF14532D),
                            bg: const Color(0xFFF0FDF4),
                          )),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _statCard(
                            label: 'Amount Paid',
                            value:
                                '₱${_info.amountPaid.toStringAsFixed(2)}',
                            icon: Icons.payments_rounded,
                            color: const Color(0xFF16A34A),
                            bg: const Color(0xFFDCFCE7),
                          )),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _statCard(
                            label: 'Balance',
                            value:
                                '₱${_info.remainingBalance.toStringAsFixed(2)}',
                            icon: _info.isFullyPaid
                                ? Icons.check_circle_rounded
                                : Icons.pending_rounded,
                            color: _info.isFullyPaid
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFDC2626),
                            bg: _info.isFullyPaid
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFFEE2E2),
                          )),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Student info card ──────────────────────────────
                      _infoCard(s),
                      const SizedBox(height: 16),

                      // ── Payment history ────────────────────────────────
                      _paymentHistorySection(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration:
                BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(color: Colors.grey[500], fontSize: 10)),
        ],
      ),
    );
  }

  Widget _infoCard(Student s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.person_rounded,
                    color: Color(0xFF16A34A), size: 16),
              ),
              const SizedBox(width: 10),
              const Text('Student Details',
                  style: TextStyle(
                      color: Color(0xFF14532D),
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _detailRow(Icons.badge_rounded, 'Full Name', s.name),
          const SizedBox(height: 10),
          _detailRow(Icons.numbers_rounded, 'LRN', s.lrn, monospace: true),
          if (s.grade.isNotEmpty) ...[
            const SizedBox(height: 10),
            _detailRow(Icons.school_rounded, 'Grade', s.grade),
          ],
          const SizedBox(height: 10),
          _detailRow(
              Icons.calendar_today_rounded, 'Registered', _formatDate(s.createdAt)),
          const SizedBox(height: 10),
          _detailRow(
              Icons.receipt_long_rounded,
              'Payments',
              '${_info.payments.length} transaction${_info.payments.length != 1 ? 's' : ''}'),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value,
      {bool monospace = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: Colors.grey[400]),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text(label,
              style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  color: const Color(0xFF14532D),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: monospace ? 'monospace' : null)),
        ),
      ],
    );
  }

  Widget _paymentHistorySection() {
    if (_info.payments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.receipt_long_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('No payments recorded yet',
                style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Payments will appear here once recorded.',
                style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(9)),
                  child: const Icon(Icons.history_rounded,
                      color: Color(0xFF16A34A), size: 16),
                ),
                const SizedBox(width: 10),
                Text(
                    'Payment History (${_info.payments.length})',
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
                    '₱${_info.amountPaid.toStringAsFixed(2)} total',
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
          // Payments list — newest first
          ...(_info.payments.reversed.toList().asMap().entries.map((entry) {
            final i = entry.key;
            final p = entry.value;
            final realIndex = _info.payments.length - i; // display number
            final isLast = i == _info.payments.length - 1;
            final hasTxn = p.transactionNumber.isNotEmpty;

            return Column(
              children: [
                InkWell(
                  onLongPress: hasTxn
                      ? () {
                          Clipboard.setData(
                              ClipboardData(text: p.transactionNumber));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text('Copied: ${p.transactionNumber}'),
                              backgroundColor: const Color(0xFF16A34A),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              margin: const EdgeInsets.all(16),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Index badge
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text('$realIndex',
                                style: const TextStyle(
                                    color: Color(0xFF16A34A),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 12),
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
                                      color: Color(0xFF64748B),
                                      fontSize: 11)),
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
                            ],
                          ),
                        ),
                        // Amount
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₱${p.amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: Color(0xFF16A34A),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            Text('payment',
                                style: TextStyle(
                                    color: Colors.grey[400], fontSize: 9)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (!isLast)
                  Divider(
                      color: Colors.grey[100], height: 1, indent: 16),
              ],
            );
          })),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}