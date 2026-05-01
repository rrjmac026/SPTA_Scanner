import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../helpers/database_helper.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';

/// Full-screen bottom sheet for editing a payment amount.
///
/// Features:
///   - Shows current amount with visual diff preview
///   - Requires a non-empty reason (audit trail enforcement)
///   - Writes atomically: payment update + audit log in one DB transaction
///   - Calls FirestoreSyncService internally via DatabaseHelper
///
/// Usage:
///   final edited = await EditPaymentSheet.show(
///     context,
///     payment: payment,
///     student: student,
///     totalFee: totalFee,
///   );
///   if (edited == true) refreshData();
class EditPaymentSheet extends StatefulWidget {
  final Payment payment;
  final Student student;
  final double totalFee;

  const EditPaymentSheet._({
    required this.payment,
    required this.student,
    required this.totalFee,
  });

  static Future<bool?> show(
    BuildContext context, {
    required Payment payment,
    required Student student,
    required double totalFee,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditPaymentSheet._(
        payment: payment,
        student: student,
        totalFee: totalFee,
      ),
    );
  }

  @override
  State<EditPaymentSheet> createState() => _EditPaymentSheetState();
}

class _EditPaymentSheetState extends State<EditPaymentSheet>
    with SingleTickerProviderStateMixin {
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _amountFocus = FocusNode();
  final _reasonFocus = FocusNode();

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  bool _saving = false;
  bool _reasonTouched = false;
  String? _amountError;

  // ── Theming ──────────────────────────────────────────────────────────────
  static const _navy = Color(0xFF1A3A6B);
  static const _amber = Color(0xFFF59E0B);
  static const _amberDark = Color(0xFFD97706);
  static const _green = Color(0xFF16A34A);
  static const _red = Color(0xFFDC2626);
  static const _surface = Color(0xFFF8FAFF);
  static const _cardBg = Colors.white;

  // ── Derived values ───────────────────────────────────────────────────────
  double get _oldAmount => widget.payment.amount;
  double get _newAmount =>
      double.tryParse(_amountCtrl.text.trim()) ?? _oldAmount;
  double get _diff => _newAmount - _oldAmount;
  bool get _hasChange => _amountCtrl.text.trim().isNotEmpty &&
      (_newAmount - _oldAmount).abs() >= 0.01;
  bool get _reasonValid => _reasonCtrl.text.trim().isNotEmpty;
  bool get _canSave => _hasChange && _reasonValid && _amountError == null;

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = _oldAmount.toStringAsFixed(0);
    _amountCtrl.addListener(_onAmountChanged);

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
    _amountFocus.dispose();
    _reasonFocus.dispose();
    super.dispose();
  }

  void _onAmountChanged() {
    final text = _amountCtrl.text.trim();
    String? err;
    if (text.isNotEmpty) {
      final val = double.tryParse(text);
      if (val == null) {
        err = 'Enter a valid number';
      } else if (val <= 0) {
        err = 'Amount must be greater than ₱0';
      } else if (val > widget.totalFee * 2) {
        err = 'Amount seems unusually high — double-check';
      }
    }
    setState(() => _amountError = err);
  }

  Future<void> _save() async {
    setState(() => _reasonTouched = true);
    if (!_canSave) {
      if (!_reasonValid) _reasonFocus.requestFocus();
      return;
    }

    setState(() => _saving = true);

    try {
      final user = AuthService().currentUser;
      final now = DateTime.now().toIso8601String();

      final logId = await DatabaseHelper().editPaymentAmount(
        paymentId: widget.payment.id!,
        oldAmount: _oldAmount,
        newAmount: _newAmount,
        reason: _reasonCtrl.text.trim(),
        processedByUid: user?.uid ?? '',
        processedByName: user?.displayName ?? '',
        now: now,
      );

      if (!mounted) return;

      if (logId != null) {
        HapticFeedback.mediumImpact();
        _showSuccessToast();
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) Navigator.of(context).pop(true);
      } else {
        _showErrorSnack('Edit failed — payment not found.');
        setState(() => _saving = false);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnack('Something went wrong: $e');
        setState(() => _saving = false);
      }
    }
  }

  void _showSuccessToast() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              'Payment updated  •  Audit log recorded',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: _red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          decoration: const BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(bottom: bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHandle(),
              _buildHeader(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildStudentCard(),
                      const SizedBox(height: 16),
                      _buildAmountSection(),
                      const SizedBox(height: 16),
                      _buildDiffPreview(),
                      const SizedBox(height: 16),
                      _buildReasonSection(),
                      const SizedBox(height: 16),
                      _buildAuditNotice(),
                      const SizedBox(height: 20),
                      _buildSaveButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Handle ───────────────────────────────────────────────────────────────
  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _amber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.edit_rounded,
                color: _amberDark, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit Payment',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  widget.payment.transactionNumber,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3B82F6),
                    fontFamily: 'monospace',
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(false),
            icon: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close_rounded,
                  size: 18, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  // ── Student card ─────────────────────────────────────────────────────────
  Widget _buildStudentCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _navy.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _navy.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _navy,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                widget.student.name.isNotEmpty
                    ? widget.student.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.student.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _navy,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _pill(widget.student.lrn, Colors.blueGrey),
                    const SizedBox(width: 6),
                    if (widget.student.grade.isNotEmpty)
                      _pill('Grade ${widget.student.grade}', _navy),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  // ── Amount input ─────────────────────────────────────────────────────────
  Widget _buildAmountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'New Amount',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.black54,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _amountError != null
                  ? _red.withOpacity(0.6)
                  : _amber.withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _amber.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 16),
                decoration: BoxDecoration(
                  color: _amber.withOpacity(0.08),
                  borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(15)),
                ),
                child: const Text(
                  '₱',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _amberDark,
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _amountCtrl,
                  focusNode: _amountFocus,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                    letterSpacing: -0.5,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        _oldAmount.toStringAsFixed(0),
                    hintStyle: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey[300],
                    ),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
              // Clear / original badge
              if (_hasChange)
                GestureDetector(
                  onTap: () {
                    _amountCtrl.text = _oldAmount.toStringAsFixed(0);
                    _amountCtrl.selection = TextSelection.fromPosition(
                      TextPosition(offset: _amountCtrl.text.length),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'was ₱${_oldAmount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[500],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_amountError != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.warning_rounded, size: 12, color: _red),
              const SizedBox(width: 4),
              Text(
                _amountError!,
                style: const TextStyle(
                    fontSize: 11, color: _red, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ── Diff preview ─────────────────────────────────────────────────────────
  Widget _buildDiffPreview() {
    if (!_hasChange || _amountError != null) return const SizedBox.shrink();

    final isIncrease = _diff > 0;
    final diffColor = isIncrease ? _red : _green;
    final diffLabel = isIncrease ? 'Increase' : 'Reduction';
    final diffIcon =
        isIncrease ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;

    final newBalance = widget.totalFee - _newAmount;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: diffColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: diffColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(diffIcon, size: 14, color: diffColor),
              const SizedBox(width: 6),
              Text(
                '$diffLabel of ₱${_diff.abs().toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: diffColor,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: diffColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${isIncrease ? '+' : ''}₱${_diff.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: diffColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: diffColor.withOpacity(0.1), height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              _diffStat('Old Amount',
                  '₱${_oldAmount.toStringAsFixed(2)}', Colors.grey[600]!),
              _diffArrow(),
              _diffStat('New Amount',
                  '₱${_newAmount.toStringAsFixed(2)}', _navy),
              _diffArrow(),
              _diffStat(
                'New Balance',
                '₱${newBalance.toStringAsFixed(2)}',
                newBalance <= 0 ? _green : _red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _diffStat(String label, String value, Color valueColor) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: TextStyle(fontSize: 9, color: Colors.grey[500]),
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _diffArrow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(Icons.arrow_forward_rounded,
          size: 12, color: Colors.grey[400]),
    );
  }

  // ── Reason section ───────────────────────────────────────────────────────
  Widget _buildReasonSection() {
    final showError = _reasonTouched && !_reasonValid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Reason for Edit',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'REQUIRED',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: _red,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: showError
                  ? _red.withOpacity(0.6)
                  : Colors.grey[200]!,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextField(
            controller: _reasonCtrl,
            focusNode: _reasonFocus,
            maxLines: 3,
            minLines: 3,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText:
                  'e.g. Cashier mistyped amount, student paid ₱750 not ₱700…',
              hintStyle:
                  TextStyle(fontSize: 13, color: Colors.grey[400]),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ),
        if (showError) ...[
          const SizedBox(height: 6),
          const Row(
            children: [
              Icon(Icons.lock_rounded, size: 12, color: _red),
              SizedBox(width: 4),
              Text(
                'A reason is required to protect the audit trail',
                style: TextStyle(
                    fontSize: 11,
                    color: _red,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
        // Quick reason chips
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            'Wrong amount entered',
            'Partial payment adjustment',
            'Admin correction',
          ].map((r) => _reasonChip(r)).toList(),
        ),
      ],
    );
  }

  Widget _reasonChip(String text) {
    return GestureDetector(
      onTap: () {
        _reasonCtrl.text = text;
        setState(() {});
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _navy.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _navy.withOpacity(0.12)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _navy,
          ),
        ),
      ),
    );
  }

  // ── Audit notice ─────────────────────────────────────────────────────────
  Widget _buildAuditNotice() {
    final user = AuthService().currentUser;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _navy.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _navy.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_rounded, size: 16, color: _navy),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    height: 1.4),
                children: [
                  const TextSpan(
                    text: 'This edit will be permanently logged. ',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const TextSpan(
                    text: 'Recorded as: ',
                  ),
                  TextSpan(
                    text: user?.displayName ?? user?.email ?? 'Unknown',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _navy,
                    ),
                  ),
                  const TextSpan(
                    text:
                        '. Old and new amounts are both stored and synced to the cloud.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Save button ──────────────────────────────────────────────────────────
  Widget _buildSaveButton() {
    return AnimatedOpacity(
      opacity: _saving ? 0.7 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: _saving ? null : _save,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _canSave
                  ? [const Color(0xFF1E4D8C), _navy]
                  : [Colors.grey[300]!, Colors.grey[300]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: _canSave
                ? [
                    BoxShadow(
                      color: _navy.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _canSave
                            ? Icons.save_rounded
                            : Icons.lock_outline_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _canSave
                            ? 'Save & Record Audit Log'
                            : 'Fill in all fields to continue',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}