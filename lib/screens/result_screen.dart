import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../helpers/database_helper.dart';
import 'scanner_screen.dart';

class ResultScreen extends StatefulWidget {
  final String name;
  final String lrn;

  const ResultScreen({super.key, required this.name, required this.lrn});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseHelper _db = DatabaseHelper();

  bool _isLoading = true;
  bool _isSavingPayment = false;

  StudentPaymentInfo? _info;
  String _selectedGrade = 'Grade 7';
  bool _isNewStudent = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final List<String> _grades = [
    'Grade 7', 'Grade 8', 'Grade 9',
    'Grade 10', 'Grade 11', 'Grade 12',
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        duration: const Duration(milliseconds: 450), vsync: this);
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _animController, curve: Curves.easeOut));
    _animController.forward();
    _loadOrCreateStudent();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadOrCreateStudent() async {
    setState(() => _isLoading = true);
    var info = await _db.getStudentPaymentInfo(widget.lrn);
    if (info == null) {
      setState(() { _isNewStudent = true; _isLoading = false; });
      return;
    }
    setState(() { _info = info; _isNewStudent = false; _isLoading = false; });
  }

  Future<void> _registerAndContinue() async {
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final student = Student(
      name: widget.name,
      lrn: widget.lrn,
      grade: _selectedGrade,
      createdAt: now,
    );
    final id = await _db.insertStudent(student);
    if (id == null) {
      await _loadOrCreateStudent();
      return;
    }
    await _loadOrCreateStudent();
  }

  Future<void> _showPaymentDialog() async {
    if (_info == null) return;
    final remaining = _info!.remainingBalance;
    if (remaining <= 0) return;

    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                          Text(
                            'Remaining: ₱${remaining.toStringAsFixed(2)}',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 12),
                          ),
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
                    if (amt == null || amt <= 0) return 'Enter a valid amount greater than 0';
                    if (amt > remaining) return 'Cannot exceed remaining balance of ₱${remaining.toStringAsFixed(2)}';
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: remaining.toStringAsFixed(2),
                    prefixIcon: Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      child: const Text('₱',
                          style: TextStyle(
                              color: Color(0xFF16A34A),
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Color(0xFF16A34A), width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    _quickFill('Full', remaining, controller),
                    if (remaining >= 500) _quickFill('₱500', 500, controller),
                    if (remaining >= 250) _quickFill('₱250', 250, controller),
                    if (remaining >= 100) _quickFill('₱100', 100, controller),
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
                        onPressed: () async {
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
    ).then((amt) async {
      if (amt == null) return;
      setState(() => _isSavingPayment = true);
      final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      await _db.addPayment(Payment(
        studentId: _info!.student.id!,
        amount: amt as double,
        createdAt: now,
      ));
      await _loadOrCreateStudent();
      setState(() => _isSavingPayment = false);
      if (mounted) {
        final isNowPaid = _info!.isFullyPaid;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isNowPaid
                      ? Icons.celebration_rounded
                      : Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isNowPaid
                        ? 'Payment complete! SPTA fully paid!'
                        : '₱${amt.toStringAsFixed(2)} recorded successfully!',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: isNowPaid
                ? const Color(0xFF0D9488)
                : const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  Widget _quickFill(String label, double amount, TextEditingController ctrl) {
    return GestureDetector(
      onTap: () => ctrl.text = amount.toStringAsFixed(2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14532D),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Scan Result',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ScannerScreen()),
            ),
            tooltip: 'Scan Another',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF16A34A)))
          : FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: _isNewStudent
                    ? _buildGradeSelector()
                    : _buildPaymentView(),
              ),
            ),
    );
  }

  Widget _buildGradeSelector() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStudentInfoCard(),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.school_rounded,
                          color: Color(0xFF16A34A), size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text('Select Grade Level',
                        style: TextStyle(
                            color: Color(0xFF14532D),
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 6),
                Text('This student is new. Select their grade to register.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFFF8FAFC),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedGrade,
                      isExpanded: true,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      borderRadius: BorderRadius.circular(12),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF16A34A)),
                      items: _grades.map((grade) {
                        return DropdownMenuItem(
                          value: grade,
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(8)),
                                child: Center(
                                  child: Text(grade.split(' ').last,
                                      style: const TextStyle(
                                          color: Color(0xFF16A34A),
                                          fontSize: 11,
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
                      onChanged: (v) => setState(() => _selectedGrade = v!),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _registerAndContinue,
                    icon: const Icon(Icons.person_add_rounded, size: 20),
                    label: const Text('Register & Continue',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _scanAnotherButton(),
        ],
      ),
    );
  }

  Widget _buildPaymentView() {
    final info = _info!;
    final student = info.student;
    final isFullyPaid = info.isFullyPaid;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStatusBanner(info),
          const SizedBox(height: 14),
          _buildStudentInfoCard(student: student),
          const SizedBox(height: 14),
          _buildPaymentSummaryCard(info),
          const SizedBox(height: 14),
          if (info.payments.isNotEmpty) ...[
            _buildPaymentHistoryCard(info.payments),
            const SizedBox(height: 14),
          ],
          if (!isFullyPaid) ...[
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isSavingPayment ? null : _showPaymentDialog,
                icon: _isSavingPayment
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Icon(Icons.add_card_rounded, size: 22),
                label: Text(
                  _isSavingPayment
                      ? 'Recording...'
                      : info.amountPaid > 0
                          ? 'Record Installment Payment'
                          : 'Record Payment',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          _scanAnotherButton(),
          const SizedBox(height: 10),
          _homeButton(),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(StudentPaymentInfo info) {
    final Color bg, border, textColor, iconColor;
    final IconData icon;
    final String message;

    if (info.isFullyPaid) {
      bg = const Color(0xFFDCFCE7);
      border = const Color(0xFF22C55E);
      textColor = const Color(0xFF166534);
      iconColor = const Color(0xFF16A34A);
      icon = Icons.verified_rounded;
      message = 'SPTA Fully Paid ✓';
    } else if (info.amountPaid > 0) {
      bg = const Color(0xFFFFF7ED);
      border = const Color(0xFFF97316);
      textColor = const Color(0xFF9A3412);
      iconColor = const Color(0xFFF97316);
      icon = Icons.pending_rounded;
      message = 'Partial Payment — Balance Remaining';
    } else {
      bg = const Color(0xFFFEE2E2);
      border = const Color(0xFFF87171);
      textColor = const Color(0xFF991B1B);
      iconColor = const Color(0xFFDC2626);
      icon = Icons.cancel_rounded;
      message = 'No Payment Recorded Yet';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    color: textColor,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentInfoCard({Student? student}) {
    final name = student?.name ?? widget.name;
    final lrn = student?.lrn ?? widget.lrn;
    final grade = student?.grade ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF14532D), Color(0xFF16A34A)]),
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Student Information',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      Text('Scanned from QR Code',
                          style: TextStyle(color: Colors.white60, fontSize: 11)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.4)),
                  ),
                  child: const Text('SCANNED',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _infoRow(Icons.badge_rounded, 'Full Name',
                    name.isNotEmpty ? name : 'Not detected',
                    valueColor: name.isNotEmpty
                        ? const Color(0xFF14532D)
                        : Colors.red),
                if (lrn.isNotEmpty) ...[
                  Divider(color: Colors.grey[100], height: 20),
                  _infoRow(Icons.numbers_rounded, 'LRN', lrn,
                      isMonospace: true,
                      valueColor: const Color(0xFF14532D)),
                ],
                if (grade.isNotEmpty) ...[
                  Divider(color: Colors.grey[100], height: 20),
                  _infoRow(Icons.school_rounded, 'Grade Level', grade,
                      valueColor: const Color(0xFF16A34A)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummaryCard(StudentPaymentInfo info) {
    final pct = info.totalFee > 0
        ? (info.amountPaid / info.totalFee).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.receipt_long_rounded,
                    color: Color(0xFF16A34A), size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Payment Summary',
                  style: TextStyle(
                      color: Color(0xFF14532D),
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                  child: _summaryStatBox('Total Fee',
                      '₱${info.totalFee.toStringAsFixed(2)}', const Color(0xFF14532D))),
              const SizedBox(width: 10),
              Expanded(
                  child: _summaryStatBox('Amount Paid',
                      '₱${info.amountPaid.toStringAsFixed(2)}', const Color(0xFF16A34A))),
              const SizedBox(width: 10),
              Expanded(
                  child: _summaryStatBox(
                      'Balance',
                      '₱${info.remainingBalance.toStringAsFixed(2)}',
                      info.isFullyPaid
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626))),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Payment Progress',
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  Text('${(pct * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                          color: Color(0xFF14532D),
                          fontSize: 12,
                          fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 12,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    info.isFullyPaid
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF4ADE80),
                  ),
                ),
              ),
            ],
          ),
          if (!info.isFullyPaid) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFFFCA5A5).withOpacity(0.6)),
              ),
              child: Column(
                children: [
                  const Text('REMAINING BALANCE',
                      style: TextStyle(
                          color: Color(0xFF991B1B),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 4),
                  Text(
                    '₱${info.remainingBalance.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryStatBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 10,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildPaymentHistoryCard(List<Payment> payments) {
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
              ],
            ),
          ),
          const Divider(height: 1),
          ...payments.asMap().entries.map((e) {
            final i = e.key;
            final p = e.value;
            final isLast = i == payments.length - 1;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatDate(p.createdAt),
                              style: const TextStyle(
                                  color: Color(0xFF64748B), fontSize: 11),
                            ),
                            if (p.note.isNotEmpty)
                              Text(p.note,
                                  style: TextStyle(
                                      color: Colors.grey[400], fontSize: 10)),
                          ],
                        ),
                      ),
                      Text('₱${p.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Color(0xFF16A34A),
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                    ],
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

  Widget _infoRow(IconData icon, String label, String value,
      {Color? valueColor, bool isMonospace = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: const Color(0xFF16A34A), size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      color: valueColor ?? const Color(0xFF14532D),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFamily: isMonospace ? 'monospace' : null,
                      letterSpacing: isMonospace ? 0.8 : 0)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scanAnotherButton() {
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ScannerScreen()),
        ),
        icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
        label: const Text('Scan Another Student',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF16A34A),
          side: const BorderSide(color: Color(0xFF16A34A), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _homeButton() {
    return SizedBox(
      height: 50,
      child: TextButton.icon(
        onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
        icon: const Icon(Icons.home_rounded, size: 20),
        label: const Text('Back to Home',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        style: TextButton.styleFrom(
          foregroundColor: Colors.grey[600],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      return DateFormat('MMM d, yyyy  h:mm a').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }
}