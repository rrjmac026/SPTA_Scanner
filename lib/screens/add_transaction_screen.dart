import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../helpers/database_helper.dart';
import '../models/models.dart';
import 'widgets/student_info_form.dart';
import 'widgets/payment_details_form.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseHelper _db = DatabaseHelper();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _lrnController = TextEditingController();
  final _amountController = TextEditingController();

  String _selectedGrade = 'Grade 7';
  bool _isSaving = false;
  bool _lrnExists = false;
  bool _lrnChecked = false;
  StudentPaymentInfo? _existingInfo;
  double _totalFee = 750;

  final List<String> _grades = [
    'Grade 7', 'Grade 8', 'Grade 9',
    'Grade 10', 'Grade 11', 'Grade 12',
  ];

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        duration: const Duration(milliseconds: 350), vsync: this);
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _loadFee();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _lrnController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadFee() async {
    final fee = await _db.getTotalFee();
    if (mounted) setState(() => _totalFee = fee);
  }

  Future<void> _checkLrn(String lrn) async {
    if (lrn.trim().isEmpty) {
      setState(() {
        _lrnExists = false;
        _lrnChecked = false;
        _existingInfo = null;
      });
      return;
    }
    final info = await _db.getStudentPaymentInfo(lrn.trim());
    if (mounted) {
      setState(() {
        _lrnChecked = true;
        _lrnExists = info != null;
        _existingInfo = info;
        if (info != null) {
          _nameController.text = info.student.name;
          _selectedGrade = info.student.grade.isNotEmpty
              ? info.student.grade
              : 'Grade 7';
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final lrn = _lrnController.text.trim();
    final name = _nameController.text.trim();
    final amount = double.parse(_amountController.text.trim());
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    setState(() => _isSaving = true);

    int studentId;

    if (_lrnExists && _existingInfo != null) {
      final remaining = _existingInfo!.remainingBalance;
      if (amount > remaining) {
        setState(() => _isSaving = false);
        _showError(
            'Amount exceeds remaining balance of ₱${remaining.toStringAsFixed(2)}');
        return;
      }
      studentId = _existingInfo!.student.id!;
    } else {
      final student = Student(
          name: name, lrn: lrn, grade: _selectedGrade, createdAt: now);
      final id = await _db.insertStudent(student);
      if (id == null) {
        setState(() => _isSaving = false);
        _showError('A student with this LRN already exists.');
        return;
      }
      studentId = id;
    }

    final savedPayment = await _db.addPayment(Payment(
      studentId: studentId,
      amount: amount,
      note: 'Manual entry',
      createdAt: now,
    ));

    final updatedInfo = await _db.getStudentPaymentInfo(lrn);
    setState(() => _isSaving = false);

    if (mounted) {
      _showSuccessSheet(
        name: name,
        lrn: lrn,
        amount: amount,
        isNew: !_lrnExists,
        isFullyPaid: updatedInfo?.isFullyPaid ?? false,
        remaining: updatedInfo?.remainingBalance ?? 0,
        transactionNumber: savedPayment.transactionNumber,
      );
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFFDC2626),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _showSuccessSheet({
    required String name,
    required String lrn,
    required double amount,
    required bool isNew,
    required bool isFullyPaid,
    required double remaining,
    required String transactionNumber,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      // Allow the sheet to size itself taller than half-screen when needed
      isScrollControlled: true,
      builder: (sheetContext) {
        final bottomPadding = MediaQuery.of(sheetContext).viewInsets.bottom +
            MediaQuery.of(sheetContext).padding.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24)),
            // SingleChildScrollView prevents overflow on small screens
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Icon ────────────────────────────────────────────────
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: isFullyPaid
                          ? const Color(0xFFCCFBF1)
                          : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      isFullyPaid
                          ? Icons.celebration_rounded
                          : Icons.check_circle_rounded,
                      color: isFullyPaid
                          ? const Color(0xFF0D9488)
                          : const Color(0xFF16A34A),
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Title ───────────────────────────────────────────────
                  Text(
                    isFullyPaid ? 'Fully Paid! 🎉' : 'Payment Recorded!',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isFullyPaid
                            ? const Color(0xFF0D9488)
                            : const Color(0xFF16A34A)),
                  ),
                  const SizedBox(height: 8),
                  Text(name,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF14532D))),
                  Text('LRN: $lrn',
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 12)),

                  // ── Transaction number ───────────────────────────────────
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: transactionNumber));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Copied: $transactionNumber'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: const Color(0xFF1D4ED8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.all(16),
                      ));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFF3B82F6)
                                .withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.confirmation_number_rounded,
                              size: 15, color: Color(0xFF3B82F6)),
                          const SizedBox(width: 6),
                          Text(transactionNumber,
                              style: const TextStyle(
                                  color: Color(0xFF1D4ED8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'monospace',
                                  letterSpacing: 0.5)),
                          const SizedBox(width: 6),
                          const Icon(Icons.copy_rounded,
                              size: 13, color: Color(0xFF3B82F6)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Tap to copy transaction number',
                      style:
                          TextStyle(color: Colors.grey[400], fontSize: 10)),

                  // ── Stats ────────────────────────────────────────────────
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _successStat(
                            'Amount Paid',
                            '₱${amount.toStringAsFixed(2)}',
                            const Color(0xFF16A34A)),
                        Container(
                            width: 1,
                            height: 36,
                            color: Colors.grey[200]),
                        _successStat(
                            'Balance',
                            '₱${remaining.toStringAsFixed(2)}',
                            isFullyPaid
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFDC2626)),
                        Container(
                            width: 1,
                            height: 36,
                            color: Colors.grey[200]),
                        _successStat(
                            'Status',
                            isFullyPaid ? 'Paid ✓' : 'Partial',
                            isFullyPaid
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFF97316)),
                      ],
                    ),
                  ),

                  // ── New student badge ────────────────────────────────────
                  if (isNew) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_add_rounded,
                              color: Color(0xFF16A34A), size: 16),
                          SizedBox(width: 6),
                          Text('New student registered',
                              style: TextStyle(
                                  color: Color(0xFF16A34A),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],

                  // ── Buttons ──────────────────────────────────────────────
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[600],
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(
                                vertical: 13),
                          ),
                          child: const Text('Done',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _resetForm();
                          },
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add Another',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(
                                vertical: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _successStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(color: Colors.grey[500], fontSize: 10)),
      ],
    );
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _lrnController.clear();
    _amountController.clear();
    setState(() {
      _selectedGrade = 'Grade 7';
      _lrnExists = false;
      _lrnChecked = false;
      _existingInfo = null;
    });
  }

  Widget _sectionCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required Widget child,
  }) {
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
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      color: Color(0xFF14532D),
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _existingInfo?.remainingBalance ?? _totalFee;
    final amountPaid = _existingInfo?.amountPaid ?? 0;

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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add Transaction',
                style:
                    TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            Text('Manual student entry',
                style: TextStyle(fontSize: 11, color: Colors.white60)),
          ],
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFF16A34A).withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: Color(0xFF16A34A), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Use this form to manually record a student\'s payment when their QR code is unavailable.',
                          style: TextStyle(
                              color: Color(0xFF166534),
                              fontSize: 12,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                _sectionCard(
                  icon: Icons.person_rounded,
                  iconColor: const Color(0xFF16A34A),
                  iconBg: const Color(0xFFF0FDF4),
                  title: 'Student Information',
                  child: StudentInfoForm(
                    lrnController: _lrnController,
                    nameController: _nameController,
                    selectedGrade: _selectedGrade,
                    grades: _grades,
                    lrnChecked: _lrnChecked,
                    lrnExists: _lrnExists,
                    existingInfo: _existingInfo,
                    amountPaid: amountPaid,
                    remaining: remaining,
                    onLrnChanged: (v) {
                      if (v.length >= 6) _checkLrn(v);
                      if (v.isEmpty) {
                        setState(() {
                          _lrnExists = false;
                          _lrnChecked = false;
                          _existingInfo = null;
                        });
                      }
                    },
                    onGradeChanged: (v) =>
                        setState(() => _selectedGrade = v!),
                  ),
                ),
                const SizedBox(height: 16),

                _sectionCard(
                  icon: Icons.payments_rounded,
                  iconColor: const Color(0xFF0D9488),
                  iconBg: const Color(0xFFCCFBF1),
                  title: 'Payment Details',
                  child: PaymentDetailsForm(
                    amountController: _amountController,
                    totalFee: _totalFee,
                    amountPaid: amountPaid,
                    remaining: remaining,
                    lrnExists: _lrnExists,
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed:
                        (_isSaving || (_lrnExists && remaining <= 0))
                            ? null
                            : _submit,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white))
                        : const Icon(Icons.add_card_rounded, size: 22),
                    label: Text(
                      _isSaving
                          ? 'Recording...'
                          : (_lrnExists
                              ? 'Record Payment'
                              : 'Register & Record Payment'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                SizedBox(
                  height: 48,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel',
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}